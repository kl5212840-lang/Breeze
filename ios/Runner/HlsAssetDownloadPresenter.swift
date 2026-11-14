import AVFoundation
import AVKit
import Flutter
import UIKit

/// AVFoundation owns the package location and transport. Only opaque bindings
/// and public metadata cross Flutter; every store access uses the same IO queue.
final class HlsAssetDownloadPresenter: NSObject, AVAssetDownloadDelegate {
  static let sessionPrefix = HlsAssetStore.sessionPrefix
  private static let pendingSessionsKey = "breeze.video.hls.sessions.v1"
  private var channel: FlutterMethodChannel?
  private let io = DispatchQueue(label: "breeze.video.hls.store", qos: .utility)
  private var store: HlsAssetStore?
  // IO queue only. A file URL is an ephemeral capability held until the
  // application's video_player controller acknowledges native disposal.
  private var playbackLeases: [String: (resource: String, asset: String, generation: String)] = [:]
  private var sessions: [String: AVAssetDownloadURLSession] = [:]
  private var jobs: [String: Job] = [:]
  private var running: [String: Job] = [:]
  private var expectations: [String: String] = [:] // Empty means no previous ready generation.
  private var liveRecovery: [String: String] = [:]
  private var recoveryDescriptors: [String: [String: Any]] = [:]
  private var reconnecting = Set<String>()
  private var inspectingRecovery = Set<String>()
  private var backgroundCompletions: [String: () -> Void] = [:]
  private var backgroundFinished = Set<String>()
  private var offline: HlsOfflinePlayerController?
#if DEBUG
  private let diagnosticLock = NSLock()
  private var diagnosticEvents: [[String: Any]] = []
#endif

  // Debug snapshots contain only fixed phases and error classifications. Never
  // serialize NSError.userInfo, descriptions, URLs, headers or package paths.
  private func diagnose(_ phase: String, error: Error? = nil, boundary: [String: Any]? = nil) {
#if DEBUG
    var event: [String: Any] = ["phase": phase]
    if let boundary {
      event["boundary"] = boundary.filter { $0.value is Bool || $0.value is Int }
    }
    if let failure = error as? HlsAssetStore.StoreError {
      let value: String
      switch failure {
      case .invalidIndex: value = "invalidIndex"
      case .invalidMetadata: value = "invalidMetadata"
      case .invalidPath: value = "invalidPath"
      case .staleBinding: value = "staleBinding"
      case .busy: value = "busy"
      case .missingPackage: value = "missingPackage"
      }
      event["storeError"] = value
    } else if let error {
      let failure = error as NSError
      let domains = [NSURLErrorDomain, NSCocoaErrorDomain, NSPOSIXErrorDomain,
        NSOSStatusErrorDomain, AVFoundationErrorDomain]
      event["domain"] = domains.contains(failure.domain) ? failure.domain : "other"
      event["code"] = failure.code
      if let underlying = failure.userInfo[NSUnderlyingErrorKey] as? NSError {
        event["underlyingDomain"] = domains.contains(underlying.domain) ? underlying.domain : "other"
        event["underlyingCode"] = underlying.code
      }
    }
    diagnosticLock.lock()
    diagnosticEvents.append(event)
    if diagnosticEvents.count > 64 { diagnosticEvents.removeFirst(diagnosticEvents.count - 64) }
    diagnosticLock.unlock()
#endif
  }

  private func classifiedFailure(_ stage: String, error: Error? = nil, status: String = "failed") -> [String: Any] {
    var value: [String: Any] = ["status": status, "failureStage": stage]
    if let failure = error as NSError? {
      let domains = [NSURLErrorDomain, NSCocoaErrorDomain, NSPOSIXErrorDomain,
        NSOSStatusErrorDomain, AVFoundationErrorDomain]
      value["failureDomain"] = domains.contains(failure.domain) ? failure.domain : "other"
      value["failureCode"] = failure.code
      let underlying = failure.userInfo[NSUnderlyingErrorKey] as? NSError
      if let underlying {
        value["underlyingDomain"] = domains.contains(underlying.domain) ? underlying.domain : "other"
        value["underlyingCode"] = underlying.code
      }
      if stage == "nativeTransfer", [failure, underlying].compactMap({ $0 }).contains(where: {
        $0.domain == NSURLErrorDomain &&
          [NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost, NSURLErrorDataNotAllowed].contains($0.code)
      }) {
        value["reason"] = "network"
      }
    }
    return value
  }

  private final class Job {
    let id: String, assetID: String, generation: String, resourceID: String
    let sessionID: String
    var metadata: [String: Any]
    var result: FlutterResult?
    var lease: OmoNetworkLease?
    var task: AVAssetDownloadTask?
    var location: URL?
    var cancelled = false
    var durable = false
    var recovered = false
    var preserveStaged = false
    var finalizing = false
    var lastProgress = Date.distantPast
    var lastPackageSample = Date.distantPast
    var packageSamplePending = false
    var packageBytes: Int64?
    var loadedTimeMs: Int64 = 0
    var totalTimeMs: Int64?
    init(id: String, assetID: String, generation: String, resourceID: String,
         sessionID: String, metadata: [String: Any], result: FlutterResult?) {
      self.id = id; self.assetID = assetID; self.generation = generation
      self.resourceID = resourceID; self.sessionID = sessionID
      self.metadata = metadata; self.result = result
    }
    var bindingKey: String { assetID + ":" + generation }
  }

  override init() {
    super.init()
    let previous = UserDefaults.standard.stringArray(forKey: Self.pendingSessionsKey) ?? []
    io.async { [weak self] in
      guard let self else { return }
      let journal = (try? self.ownedStore().recoveryIdentifiers()) ?? []
      DispatchQueue.main.async {
        for identifier in Set(previous + journal) {
          self.handleBackgroundSession(identifier, completion: nil)
        }
      }
    }
  }

  func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "breeze.video.hls", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result("unavailable"); return }
      self.handle(call, result: result)
    }
    self.channel = channel
  }

  private func ownedStore() throws -> HlsAssetStore {
    if let store { return store }
    let opened = try HlsAssetStore()
    store = opened
    return opened
  }

  private func perform(_ result: @escaping FlutterResult, phase: String = "storeOperation",
                       _ operation: @escaping (HlsAssetStore) throws -> Any?) {
    io.async { [weak self] in
      guard let self else { DispatchQueue.main.async { result("unavailable") }; return }
      do {
        self.diagnose(phase + ".begin")
        let value = try operation(self.ownedStore())
        self.diagnose(phase + ".succeeded")
        DispatchQueue.main.async { result(value) }
      } catch {
        self.diagnose(phase + ".failed", error: error)
        let code: String
        if let failure = error as? HlsAssetStore.StoreError {
          switch failure {
          case .busy: code = "busy"
          case .staleBinding: code = "staleBinding"
          default: code = "unavailable"
          }
        } else {
          code = "unavailable"
        }
        DispatchQueue.main.async {
          result(FlutterError(code: code, message: "Offline video operation could not be completed", details: nil))
        }
      }
    }
  }

  private func binding(_ args: [String: Any]) -> (String, String, String)? {
    guard let resource = args["resourceId"] as? String,
          let asset = args["assetId"] as? String,
          let generation = args["generation"] as? String else { return nil }
    return (resource, asset, generation)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
#if DEBUG
    case "diagnostics":
      diagnosticLock.lock()
      let events = diagnosticEvents
      diagnosticLock.unlock()
      result(["events": events, "running": !running.isEmpty])
#endif
    case "supported": result(ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 15)
    case "start": start(args, result: result)
    case "cancel":
      if let id = args["id"] as? String, let job = running[id] {
        job.cancelled = true
        if job.durable {
          io.async {
            _ = try? self.ownedStore().cancelRecovery(
              assetID: job.assetID, generation: job.generation, resourceID: job.resourceID)
          }
        }
        if let task = job.task {
          // Start remains pending until didCompleteWithError has acknowledged
          // cancellation and removed its package. Dart must retain its permit
          // and resource lease while this native writer still owns the asset.
          task.cancel()
        } else {
          complete(job, value: "cancelled")
          end(job)
        }
      }
      result(nil)
    case "list": perform(result) { try $0.list() }
    case "recoverySnapshot":
      let excluded = Set(liveRecovery.keys)
      perform(result) { try $0.recoverySnapshot(excluding: excluded) }
    case "ackRecovery":
      guard let (resource, asset, generation) = binding(args) else { result(false); return }
      let identifier = Self.sessionPrefix + asset + "." + generation
      perform({ value in
        if value as? Bool == true, self.liveRecovery[identifier] == resource {
          self.liveRecovery.removeValue(forKey: identifier)
        }
        result(value)
      }) {
        try $0.acknowledgeRecovery(assetID: asset, generation: generation, resourceID: resource)
      }
    case "releaseRecovery":
      guard let (resource, asset, generation) = binding(args) else { result(false); return }
      let identifier = Self.sessionPrefix + asset + "." + generation
      guard jobs[identifier] == nil, liveRecovery[identifier] == resource else { result(false); return }
      liveRecovery.removeValue(forKey: identifier)
      // The live transfer has ended. Retry any unfinished terminal journal
      // write before offering this receipt to the Dart recovery reader.
      io.async {
        do { try self.ownedStore().finishOrphanedRecovery(identifier) }
        catch { self.diagnose("recovery.release.failed", error: error) }
        DispatchQueue.main.async {
          result(true)
          self.recoveryChanged()
        }
      }
    case "cancelRecovery":
      guard let (resource, asset, generation) = binding(args) else { result(false); return }
      let identifier = Self.sessionPrefix + asset + "." + generation
      cancelRecovered(identifier, resource: resource, asset: asset, generation: generation, result: result)
    case "hideTasks":
      guard let keys = args["keys"] as? [String] else { result(false); return }
      perform(result) { try $0.hideTasks(keys: keys); return true }
    case "commit":
      guard let (resource, asset, generation) = binding(args) else { result(false); return }
      let key = asset + ":" + generation
      let expected = expectations[key]
      perform(result, phase: "commit") { store in
        let current = try store.list().first { $0["resourceId"] as? String == resource }
        let actual = current?["generation"] as? String ?? ""
        // Idempotent replay of an already published binding remains valid.
        if actual != generation {
          let durable = store.recoveryDescriptor(Self.sessionPrefix + asset + "." + generation)
          guard let expected = (durable?["expected"] as? String) ?? expected,
            actual == expected else { throw HlsAssetStore.StoreError.staleBinding }
        }
        return try store.commit(assetID: asset, generation: generation, resourceID: resource)
      }
    case "discard":
      guard let asset = args["assetId"] as? String, let generation = args["generation"] as? String else { result(false); return }
      expectations.removeValue(forKey: asset + ":" + generation)
      perform(result) {
        try $0.discard(assetID: asset, generation: generation, rejectRecovery: true)
      }
    case "delete":
      guard let (resource, asset, generation) = binding(args) else { result(false); return }
      perform(result) { try $0.delete(resourceID: resource, assetID: asset, generation: generation) }
    case "stageRemoval":
      guard let source = args["source"] as? String, let resources = args["resources"] as? [[String: Any]] else { result(false); return }
      perform(result) { try $0.stageRemoval(source: source, resources: resources) }
    case "commitRemoval", "rollbackRemoval":
      guard let token = args["token"] as? String else { result(false); return }
      perform(result) { store in
        if call.method == "commitRemoval" { return try store.commitRemoval(token: token) }
        return try store.rollbackRemoval(token: token)
      }
    case "poster":
      guard let (resource, asset, generation) = binding(args) else { result(nil); return }
      io.async { [weak self] in
        guard let self else { DispatchQueue.main.async { result(nil) }; return }
        do {
          let store = try self.ownedStore()
          let url = try store.hold(resourceID: resource, assetID: asset, generation: generation)
          DispatchQueue.main.async {
            guard AVURLAsset(url: url).assetCache?.isPlayableOffline == true else {
              self.io.async {
                store.release(resourceID: resource, assetID: asset, generation: generation)
                DispatchQueue.main.async { result(nil) }
              }
              return
            }
            LocalVideoPosterGenerator.generate(file: url) { data in
              self.io.async {
                store.release(resourceID: resource, assetID: asset, generation: generation)
                DispatchQueue.main.async { result(data.map { FlutterStandardTypedData(bytes: $0) }) }
              }
            }
          }
        } catch { DispatchQueue.main.async { result(nil) } }
      }
    case "openOffline": openOffline(args, result: result)
    case "acquirePlayback":
      guard let (resource, asset, generation) = binding(args) else { result(false); return }
      perform({ value in
        guard let url = value as? URL else { result(value); return }
        // Refuse a partial or damaged package before video_player can inspect
        // it. The existing native hold protects this main-queue cache check.
        guard AVURLAsset(url: url).assetCache?.isPlayableOffline == true else {
          self.io.async {
            self.store?.release(resourceID: resource, assetID: asset, generation: generation)
            DispatchQueue.main.async {
              result(FlutterError(code: "unavailable", message: "Offline video is unavailable", details: nil))
            }
          }
          return
        }
        let token = UUID().uuidString.lowercased()
        self.io.async {
          self.playbackLeases[token] = (resource, asset, generation)
          DispatchQueue.main.async {
            // Only this response contains a path, never an index/descriptor.
            result(["leaseId": token, "fileURL": url.absoluteString])
          }
        }
      }, phase: "acquirePlayback") { store in
        try store.hold(resourceID: resource, assetID: asset, generation: generation)
      }
    case "releasePlayback":
      guard let token = args["leaseId"] as? String,
            let (resource, asset, generation) = binding(args) else { result(false); return }
      perform(result, phase: "releasePlayback") { store in
        guard let held = self.playbackLeases[token] else { return true }
        guard held.resource == resource, held.asset == asset, held.generation == generation else {
          throw HlsAssetStore.StoreError.staleBinding
        }
        store.release(resourceID: resource, assetID: asset, generation: generation)
        self.playbackLeases.removeValue(forKey: token)
        return true
      }
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func validHTTPS(_ url: URL) -> Bool {
    url.scheme?.lowercased() == "https" && url.host?.isEmpty == false &&
      url.user == nil && url.password == nil && (url.port == nil || url.port == 443) && url.fragment == nil
  }

  private static func milliseconds(_ seconds: Double) -> Int64? {
    guard seconds.isFinite, seconds >= 0, seconds <= Double(Int64.max / 1000) else { return nil }
    return Int64(seconds * 1000)
  }

  private func publicHeaders(_ raw: Any?, referer: URL) -> [String: String]? {
    guard raw == nil || raw is NSNull || raw is [String: String] else { return nil }
    let supplied = raw as? [String: String] ?? [:]
    guard supplied.count <= 3 else { return nil }
    var headers = ["Referer": referer.absoluteString]
    for (name, value) in supplied {
      guard let canonical = ["referer": "Referer", "origin": "Origin", "user-agent": "User-Agent"][name.lowercased()],
            value.count <= 2048, value.rangeOfCharacter(from: .controlCharacters) == nil else { return nil }
      if canonical != "User-Agent" {
        guard let url = URL(string: value), validHTTPS(url), url.host == referer.host,
              (url.port ?? 443) == (referer.port ?? 443),
              canonical != "Origin" || (url.query == nil && (url.path.isEmpty || url.path == "/")) else { return nil }
        if url.query != nil {
          guard canonical == "Referer", let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
                let query = parts.queryItems, !query.isEmpty,
                query.allSatisfy({ ["v", "line", "episode"].contains($0.name) && !($0.value ?? "").isEmpty && ($0.value?.count ?? 0) <= 300 }) else { return nil }
        }
      }
      headers[canonical] = value
    }
    return headers
  }

  private func start(_ args: [String: Any], result: @escaping FlutterResult) {
    diagnose("start.received")
    guard #available(iOS 15.0, *) else { result("unsupported"); return }
    guard running.count < 3 else { result("busy"); return }
    guard let id = args["id"] as? String, !id.isEmpty, id.count <= 120, running[id] == nil,
          let resource = args["managedId"] as? String,
          resource.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil,
          let raw = args["url"] as? String, raw.count <= 8192,
          let url = URL(string: raw), validHTTPS(url),
          let refererRaw = args["referer"] as? String, refererRaw.count <= 8192,
          let referer = URL(string: refererRaw), validHTTPS(referer),
          let source = args["source"] as? String, source.count <= 200,
          let video = args["video"] as? String, video.count <= 4096,
          let title = args["title"] as? String, title.count <= 300,
          let quality = args["quality"] as? String, quality.count <= 80,
          let taskKey = args["taskKey"] as? String, taskKey.count <= 2048,
          let headers = publicHeaders(args["headers"], referer: referer) else { result(classifiedFailure("nativePreflight")); return }
    guard !running.values.contains(where: { $0.resourceID == resource }) else { result("busy"); return }
    var lease: OmoNetworkLease?
    if let token = args["networkContext"], !(token is NSNull) {
      guard let token = token as? String, let owned = OmoNetwork.shared.lease(token),
            owned.sourceIdentifier == source.lowercased(), owned.isFirstParty(referer) else { result("routeUnavailable"); return }
      lease = owned
    }
    let assetID = UUID().uuidString.lowercased(), generation = UUID().uuidString.lowercased()
    let sessionID = Self.sessionPrefix + assetID + "." + generation
    var metadata: [String: Any] = ["source": source, "video": video, "title": title,
      "quality": quality, "taskKey": taskKey, "showTask": true,
      "at": Int64(Date().timeIntervalSince1970 * 1000)]
    for key in ["cover", "durationMs", "sourceDuration"] {
      if let value = args[key], !(value is NSNull) { metadata[key] = value }
    }
    let pendingMetadata = metadata
    // Reserve cancellation ownership without placing unvalidated values in the
    // job/OS recovery descriptor. The IO preflight supplies the public snapshot.
    let job = Job(id: id, assetID: assetID, generation: generation, resourceID: resource,
      sessionID: sessionID, metadata: [:], result: result)
    job.lease = lease
    running[job.id] = job
    let expected = args["expectedGeneration"] as? String ?? ""
    let wifiOnly = args["wifiOnly"] as? Bool == true
    io.async { [weak self] in
      guard let self else { return }
      do {
        let store = try self.ownedStore()
        try store.requireNoRecoverableWriter(resourceID: resource)
        let publicMetadata = try store.normalizedMetadata(pendingMetadata)
        let ready = try store.list().first { $0["resourceId"] as? String == resource }
        guard (ready?["generation"] as? String ?? "") == expected else { throw HlsAssetStore.StoreError.staleBinding }
        DispatchQueue.main.async {
          guard !job.cancelled, self.running[job.id] === job else { return }
          job.metadata = publicMetadata
          self.expectations[job.bindingKey] = expected
          self.begin(job, url: url, title: title, headers: headers, wifiOnly: wifiOnly,
            expected: expected, attempt: args["attempt"] as? Int, scope: args["recoveryScope"] as? String)
        }
      } catch {
        self.diagnose("start.preflight.failed", error: error)
        DispatchQueue.main.async {
          self.complete(job, value: self.classifiedFailure("nativePreflight", error: error,
            status: (error as? HlsAssetStore.StoreError) == .busy ? "busy" : "failed"))
          self.end(job)
        }
      }
    }
  }

  @available(iOS 15.0, *)
  private func begin(_ job: Job, url: URL, title: String, headers: [String: String],
    wifiOnly: Bool, expected: String, attempt: Int?, scope: String?) {
    let configuration: URLSessionConfiguration
    if let lease = job.lease {
      guard #available(iOS 17.0, *), let routed = lease.assetDownloadConfiguration(identifier: job.sessionID) else {
        complete(job, value: "routeUnavailable"); end(job); return
      }
      configuration = routed
    } else { configuration = Self.backgroundConfiguration(job.sessionID) }
    configuration.allowsCellularAccess = !wifiOnly
    var outgoing = configuration.httpAdditionalHeaders as? [String: String] ?? [:]
    for (name, value) in headers { outgoing[name] = value }
    configuration.httpAdditionalHeaders = outgoing
    var direct = job.lease == nil
    if #available(iOS 17.0, *), job.lease != nil {
      direct = configuration.proxyConfigurations.isEmpty
    }
    // Only the OS route and public headers we can reproduce are recoverable.
    if direct, let attempt, let scope, let referer = outgoing["Referer"],
      outgoing["User-Agent"].map(HlsAssetStore.recoverableUserAgent) ?? true,
      canRecoverReferer(referer, page: job.metadata["url"] as? String, origin: outgoing["Origin"]) {
      let metadata = job.metadata
      liveRecovery[job.sessionID] = job.resourceID
      io.async {
        do {
          try self.ownedStore().registerRecovery(identifier: job.sessionID, id: job.id,
            assetID: job.assetID, generation: job.generation, resourceID: job.resourceID,
            metadata: metadata, attempt: attempt, scope: scope, expected: expected,
            wifiOnly: wifiOnly, referer: referer, origin: outgoing["Origin"],
            userAgent: outgoing["User-Agent"])
          DispatchQueue.main.async {
            job.durable = true
            guard self.running[job.id] === job, !job.cancelled else {
              self.io.async {
                try? self.ownedStore().finishRecovery(job.sessionID, status: "cancelled")
                _ = try? self.ownedStore().acknowledgeRecovery(
                  assetID: job.assetID, generation: job.generation, resourceID: job.resourceID)
              }
              self.liveRecovery.removeValue(forKey: job.sessionID)
              return
            }
            self.resume(job, url: url, title: title, configuration: configuration, outgoing: outgoing, wifiOnly: wifiOnly)
          }
        } catch {
          DispatchQueue.main.async {
            self.liveRecovery.removeValue(forKey: job.sessionID)
            self.complete(job, value: self.classifiedFailure("nativePreflight", error: error,
              status: (error as? HlsAssetStore.StoreError) == .busy ? "busy" : "failed"))
            self.end(job)
          }
        }
      }
    } else {
      resume(job, url: url, title: title, configuration: configuration, outgoing: outgoing, wifiOnly: wifiOnly)
    }
  }

  private func canRecoverReferer(_ raw: String, page: String?, origin: String?) -> Bool {
    guard let page, let publicPage = URL(string: page), let referer = URL(string: raw),
      referer.host == publicPage.host,
      raw == page || (referer.path == publicPage.path && referer.query == nil),
      let host = publicPage.host else { return false }
    return origin == nil || origin == "https://" + host || origin == "https://" + host + "/"
  }

  @available(iOS 15.0, *)
  private func resume(_ job: Job, url: URL, title: String,
    configuration: URLSessionConfiguration, outgoing: [String: String], wifiOnly: Bool) {
    var options: [String: Any] = [:]
    if wifiOnly { options[AVURLAssetAllowsCellularAccessKey] = false }
    if #available(iOS 16.0, *), let agent = outgoing["User-Agent"] { options[AVURLAssetHTTPUserAgentKey] = agent }
    let asset = AVURLAsset(url: url, options: options)
    // Do not load the remote asset before it belongs to the configured session:
    // an independent AVURLAsset preflight could bypass the selected route.
    let session = AVAssetDownloadURLSession(configuration: configuration,
      assetDownloadDelegate: self, delegateQueue: .main)
    let download = session.makeAssetDownloadTask(downloadConfiguration: AVAssetDownloadConfiguration(asset: asset, title: title))
    // Task descriptions are persisted by the OS. Store only the same public
    // metadata as the index, never the media URL, headers or network context.
    let descriptor: [String: Any] = ["id": job.id, "assetId": job.assetID,
      "generation": job.generation, "resourceId": job.resourceID, "metadata": job.metadata]
    if let data = try? JSONSerialization.data(withJSONObject: descriptor) {
      download.taskDescription = String(data: data, encoding: .utf8)
    }
    job.task = download
    jobs[job.sessionID] = job
    sessions[job.sessionID] = session
    remember(job.sessionID, present: true)
    progress(job, task: download, loaded: 0, total: nil, saving: false, force: true)
    download.resume()
    diagnose("task.resumed")
  }

  static func backgroundConfiguration(_ identifier: String) -> URLSessionConfiguration {
    let configuration = URLSessionConfiguration.background(withIdentifier: identifier)
    configuration.isDiscretionary = false
    configuration.sessionSendsLaunchEvents = true
    configuration.httpCookieStorage = nil
    configuration.httpShouldSetCookies = false
    configuration.urlCredentialStorage = nil
    configuration.urlCache = nil
    configuration.timeoutIntervalForRequest = 45
    configuration.timeoutIntervalForResource = 86400
    return configuration
  }

  private func remember(_ identifier: String, present: Bool) {
    var identifiers = Set(UserDefaults.standard.stringArray(forKey: Self.pendingSessionsKey) ?? [])
    if present { identifiers.insert(identifier) } else { identifiers.remove(identifier) }
    UserDefaults.standard.set(Array(identifiers), forKey: Self.pendingSessionsKey)
  }

  func handleBackgroundSession(_ identifier: String, completion: (() -> Void)?) {
    guard identifier.hasPrefix(Self.sessionPrefix), identifier.count <= 240 else { completion?(); return }
    if let completion { backgroundCompletions[identifier] = completion }
    guard sessions[identifier] == nil else { return }
    if backgroundFinished.contains(identifier) {
      finishBackgroundIfReady(identifier)
      return
    }
    guard reconnecting.insert(identifier).inserted else { return }
    io.async {
      let descriptor = try? self.ownedStore().recoveryDescriptor(identifier)
      DispatchQueue.main.async {
        self.reconnect(identifier, descriptor: descriptor)
      }
    }
  }

  private func reconnect(_ identifier: String, descriptor: [String: Any]?) {
    reconnecting.remove(identifier)
    if let descriptor,
      (descriptor["hasAsset"] as? Bool == true || descriptor["status"] as? String != "running"),
      backgroundCompletions[identifier] == nil {
      remember(identifier, present: false)
      return
    }
    let configuration = Self.backgroundConfiguration(identifier)
    if let descriptor {
      configuration.allowsCellularAccess = descriptor["wifiOnly"] as? Bool != true
      var headers = [String: String]()
      if let value = descriptor["referer"] as? String { headers["Referer"] = value }
      if let value = descriptor["origin"] as? String { headers["Origin"] = value }
      if let value = descriptor["userAgent"] as? String { headers["User-Agent"] = value }
      configuration.httpAdditionalHeaders = headers
      recoveryDescriptors[identifier] = descriptor
    }
    let session = AVAssetDownloadURLSession(configuration: configuration,
      assetDownloadDelegate: self, delegateQueue: .main)
    sessions[identifier] = session
    inspectingRecovery.insert(identifier)
    session.getAllTasks { tasks in
      DispatchQueue.main.async {
        guard self.sessions[identifier] === session else { return }
        var keepingTask = false
        for task in tasks {
          if let assetTask = task as? AVAssetDownloadTask,
            let job = self.recoveredJob(identifier, task: assetTask), !job.cancelled {
            keepingTask = true
            // A valid, already-submitted task continues under system ownership.
            // Do not manufacture a new request if the old one disappeared.
            self.recoveryChanged()
          } else {
            task.cancel()
          }
        }
        if keepingTask {
          self.inspectingRecovery.remove(identifier)
          self.finishBackgroundIfReady(identifier)
        } else {
          session.finishTasksAndInvalidate()
        }
      }
    }
  }

  private func complete(_ job: Job, value: Any) {
    if running[job.id] === job { running.removeValue(forKey: job.id) }
    let result = job.result
    job.result = nil
    let status = (value as? [String: Any])?["status"] as? String ?? value as? String
    if status != "staged" { expectations.removeValue(forKey: job.bindingKey) }
    if job.durable {
      var row = value as? [String: Any] ?? ["status": status ?? "failed"]
      row["assetId"] = job.assetID
      row["generation"] = job.generation
      row["resourceId"] = job.resourceID
      result?(row)
    } else {
      result?(value)
    }
  }

  private func recoveredJob(_ identifier: String, task: AVAssetDownloadTask) -> Job? {
    if let job = jobs[identifier] { return job.task?.taskIdentifier == task.taskIdentifier ? job : nil }
    guard let description = task.taskDescription, description.utf8.count <= 16384,
          let data = description.data(using: .utf8),
          let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let id = raw["id"] as? String, let asset = raw["assetId"] as? String,
          let generation = raw["generation"] as? String, let resource = raw["resourceId"] as? String,
          let metadata = raw["metadata"] as? [String: Any] else { return nil }
    guard identifier == Self.sessionPrefix + asset + "." + generation else { return nil }
    let descriptor = recoveryDescriptors[identifier]
    let matches = descriptor?["id"] as? String == id &&
      descriptor?["assetId"] as? String == asset &&
      descriptor?["generation"] as? String == generation &&
      descriptor?["resourceId"] as? String == resource
    let trusted = matches && descriptor?["canReattach"] as? Bool == true
    let job = Job(id: "recover-" + asset, assetID: asset, generation: generation, resourceID: resource,
      sessionID: identifier, metadata: metadata, result: nil)
    job.recovered = true
    job.durable = matches
    job.cancelled = !trusted
    job.preserveStaged = matches && descriptor?["hasAsset"] as? Bool == true &&
      descriptor?["cancellationRequested"] as? Bool != true
    if trusted, let descriptor {
      job.metadata = descriptor
      job.location = descriptor["location"] as? URL
      running[job.id] = job
    }
    job.task = task
    jobs[identifier] = job
    return job
  }

  private func cancelRecovered(_ identifier: String, resource: String,
    asset: String, generation: String, result: @escaping FlutterResult) {
    guard liveRecovery[identifier] == nil else { result(false); return }
    perform({ value in
      guard value as? Bool == true else { result(value); return }
      if let job = self.jobs[identifier] {
        job.cancelled = true
        job.task?.cancel()
      } else if self.sessions[identifier] != nil || self.reconnecting.contains(identifier) {
        self.recoveryDescriptors[identifier]?["canReattach"] = false
        self.sessions[identifier]?.getAllTasks { tasks in
          for task in tasks { task.cancel() }
        }
      } else {
        self.handleBackgroundSession(identifier, completion: nil)
      }
      result(true)
    }, phase: "cancelRecovery") { store in
      guard try store.cancelRecovery(assetID: asset, generation: generation, resourceID: resource) else { return false }
      if store.recoveryDescriptor(identifier)?["hasAsset"] as? Bool == true {
        _ = try store.discard(assetID: asset, generation: generation, rejectRecovery: true)
        DispatchQueue.main.async { self.recoveryChanged() }
      }
      return true
    }
  }

  private func recoveryChanged() {
    channel?.invokeMethod("recoveryChanged", arguments: nil)
  }

  private func end(_ job: Job) {
    if running[job.id] === job { running.removeValue(forKey: job.id) }
    jobs.removeValue(forKey: job.sessionID)
    recoveryDescriptors.removeValue(forKey: job.sessionID)
    inspectingRecovery.remove(job.sessionID)
    sessions.removeValue(forKey: job.sessionID)?.finishTasksAndInvalidate()
    job.lease = nil
    remember(job.sessionID, present: false)
    finishBackgroundIfReady(job.sessionID)
  }

  private func progress(_ job: Job, task: URLSessionTask, loaded: Int64, total: Int64?, saving: Bool, force: Bool = false) {
    guard !job.cancelled, force || Date().timeIntervalSince(job.lastProgress) >= 0.2 else { return }
    job.lastProgress = Date()
    job.loadedTimeMs = loaded
    job.totalTimeMs = total
    samplePackageBytes(job, task: task)
    var value: [String: Any] = ["id": job.id, "loadedTimeMs": max(0, loaded), "saving": saving]
    if let bytes = job.packageBytes {
      value["packageBytes"] = bytes
    }
    if task.countOfBytesReceived > 0 {
      value["networkBytes"] = task.countOfBytesReceived
      if task.countOfBytesExpectedToReceive > 0,
         task.countOfBytesExpectedToReceive >= task.countOfBytesReceived {
        value["networkTotal"] = task.countOfBytesExpectedToReceive
        value["total"] = task.countOfBytesExpectedToReceive
      }
      value["received"] = task.countOfBytesReceived
      value["receivedSource"] = "network"
    } else if let bytes = job.packageBytes {
      value["received"] = bytes
      value["receivedSource"] = "package"
    }
    if let total, total > 0 { value["totalTimeMs"] = total }
    channel?.invokeMethod("progress", arguments: value)
  }

  private func samplePackageBytes(_ job: Job, task: URLSessionTask) {
    guard !job.cancelled, !job.finalizing, !job.packageSamplePending,
      let location = job.location,
      Date().timeIntervalSince(job.lastPackageSample) >= 1 else { return }
    job.lastPackageSample = Date()
    job.packageSamplePending = true
    // Enumeration runs only on the existing store IO queue, at most once per
    // second/job. Paths, file names and headers never cross the Dart bridge.
    io.async { [weak self] in
      guard let self else { return }
      let bytes = try? self.ownedStore().downloadedPackageBytes(at: location)
      DispatchQueue.main.async {
        job.packageSamplePending = false
        job.lastPackageSample = Date()
        guard self.running[job.id] === job, !job.cancelled, !job.finalizing,
          job.task === task, let bytes, bytes >= 0 else { return }
        job.packageBytes = bytes
        self.progress(job, task: task, loaded: job.loadedTimeMs,
          total: job.totalTimeMs, saving: false, force: true)
      }
    }
  }

  func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask,
                  didLoad timeRange: CMTimeRange, totalTimeRangesLoaded ranges: [NSValue],
                  timeRangeExpectedToLoad expected: CMTimeRange) {
    guard let identifier = session.configuration.identifier,
      let job = recoveredJob(identifier, task: assetDownloadTask) else { return }
    let totalSeconds = CMTimeGetSeconds(expected.duration)
    let total = totalSeconds > 0 ? Self.milliseconds(totalSeconds) : nil
    let intervals = ranges.map(\.timeRangeValue).compactMap { range -> (Double, Double)? in
      let start = CMTimeGetSeconds(range.start), end = CMTimeGetSeconds(CMTimeRangeGetEnd(range))
      return start.isFinite && end.isFinite && end >= start ? (start, end) : nil
    }.sorted { $0.0 < $1.0 }
    var duration = 0.0, previousStart = 0.0, previousEnd = 0.0
    for (index, interval) in intervals.enumerated() {
      if index == 0 { previousStart = interval.0; previousEnd = interval.1 }
      else if interval.0 <= previousEnd { previousEnd = max(previousEnd, interval.1) }
      else { duration += previousEnd - previousStart; previousStart = interval.0; previousEnd = interval.1 }
    }
    if !intervals.isEmpty { duration += previousEnd - previousStart }
    let loaded = Self.milliseconds(max(0, duration)) ?? 0
    progress(job, task: assetDownloadTask, loaded: min(loaded, total ?? loaded), total: total, saving: false)
  }

  @available(iOS 18.0, *)
  func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, willDownloadTo location: URL) {
    guard let identifier = session.configuration.identifier,
          let job = recoveredJob(identifier, task: assetDownloadTask) else { return }
    // This callback announces the destination before the package is complete.
    // Only didCompleteWithError may validate and stage the finished package.
    job.location = location
    rememberLocation(job, location)
    diagnose("task.willDownloadTo")
#if DEBUG
    io.async { [weak self] in
      guard let self, let store = self.store else { return }
      self.diagnose("task.pathBoundary", boundary: store.debugPathBoundary(location))
    }
#endif
  }

  func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {
    guard let identifier = session.configuration.identifier,
          let job = recoveredJob(identifier, task: assetDownloadTask) else { return }
    job.location = location
    rememberLocation(job, location)
    diagnose("task.didFinishDownloadingTo")
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard let identifier = session.configuration.identifier, let assetTask = task as? AVAssetDownloadTask,
          let job = recoveredJob(identifier, task: assetTask) else { return }
    guard !job.finalizing else { return }
    job.finalizing = true
    if job.preserveStaged {
      end(job)
      recoveryChanged()
      return
    }
    if let error { diagnose("task.completion.failed", error: error) }
    else { diagnose("task.completion.succeeded") }
    if job.cancelled { diagnose("task.cancelled") }
    if job.location == nil { diagnose("task.locationMissing") }
    guard error == nil, !job.cancelled, let location = job.location else {
      cleanup(job, completion: { [weak self] in
        guard let self else { return }
        let cancelled = job.cancelled || (error as NSError?)?.code == NSURLErrorCancelled
        let value: Any = cancelled ? "cancelled" as Any : self.classifiedFailure("nativeTransfer", error: error)
        self.settle(job, value: value)
      })
      return
    }
    guard #available(iOS 15.0, *) else { cleanup(job) { self.settle(job, value: "unsupported") }; return }
    let local = AVURLAsset(url: location)
    guard local.assetCache?.isPlayableOffline == true else {
      diagnose(local.assetCache == nil ? "offline.cacheMissing" : "offline.cacheNotPlayable")
      cleanup(job) { self.settle(job, value: self.classifiedFailure("offlineValidation", status: "unsupported")) }; return
    }
    diagnose("offline.cachePlayable")
    Task { @MainActor [weak self] in
      guard let self else { return }
      do {
        let protected = try await local.load(.hasProtectedContent)
        let playable = try await local.load(.isPlayable)
        if protected { self.diagnose("offline.protected") }
        if !playable { self.diagnose("offline.notPlayable") }
        guard !protected, playable else { throw URLError(.unsupportedURL) }
        let time = CMTimeGetSeconds(try await local.load(.duration))
        let duration = time > 0 ? Self.milliseconds(time) : nil
        if let duration { job.metadata["durationMs"] = duration }
        job.metadata["at"] = Int64(Date().timeIntervalSince1970 * 1000)
        self.progress(job, task: task, loaded: duration ?? 0,
          total: duration, saving: true, force: true)
        let metadata = job.metadata
        self.diagnose("offline.validated")
        self.io.async {
          do {
            self.diagnose("stage.begin")
            let store = try self.ownedStore()
            var row = try store.stage(url: location, assetID: job.assetID, generation: job.generation,
              resourceID: job.resourceID, metadata: metadata)
            self.diagnose("stage.succeeded")
            row["status"] = "staged"
            DispatchQueue.main.async {
              if job.cancelled {
                self.cleanup(job) { self.settle(job, value: "cancelled") }
              } else {
                var progress: [String: Any] = ["id": job.id, "received": row["bytes"] ?? 0, "packageBytes": row["bytes"] ?? 0, "receivedSource": "package", "saving": true]
                if let duration = row["durationMs"] { progress["loadedTimeMs"] = duration; progress["totalTimeMs"] = duration }
                self.channel?.invokeMethod("progress", arguments: progress)
                self.settle(job, value: row)
              }
            }
          } catch {
            self.diagnose("stage.failed", error: error)
#if DEBUG
            if let store = self.store {
              self.diagnose("stage.pathBoundary", boundary: store.debugPathBoundary(location))
            }
#endif
            self.cleanup(job) {
              self.settle(job, value: job.cancelled ? "cancelled" as Any : self.classifiedFailure("nativeStorage", error: error))
            }
          }
        }
      } catch {
        self.diagnose("offline.load.failed", error: error)
        self.cleanup(job) {
          self.settle(job, value: job.cancelled ? "cancelled" as Any : self.classifiedFailure("offlineValidation", error: error, status: "unsupported"))
        }
      }
    }
  }

  private func rememberLocation(_ job: Job, _ location: URL) {
    guard job.durable, !job.cancelled else { return }
    io.async {
      do { try self.ownedStore().rememberRecoveryLocation(job.sessionID, url: location) }
      catch { self.diagnose("recovery.location.failed", error: error) }
    }
  }

  private func settle(_ job: Job, value: Any) {
    let status = (value as? [String: Any])?["status"] as? String ?? value as? String
    let finish = {
      self.complete(job, value: value)
      self.end(job)
      if job.recovered && job.durable { self.recoveryChanged() }
    }
    if !job.durable || status == "staged" {
      finish()
      return
    }
    let reason = (value as? [String: Any])?["reason"] as? String
    io.async {
      do {
        try self.ownedStore().finishRecovery(job.sessionID,
          status: status == "cancelled" ? "cancelled" : "failed", reason: reason)
      } catch {
        self.diagnose("recovery.settle.failed", error: error)
      }
      DispatchQueue.main.async(execute: finish)
    }
  }

  private func cleanup(_ job: Job, completion: @escaping () -> Void) {
    io.async { [weak self] in
      guard let self else { DispatchQueue.main.async(execute: completion); return }
      do {
        self.diagnose("cleanup.begin")
        let removed = try self.ownedStore().discard(assetID: job.assetID, generation: job.generation)
        self.diagnose(removed ? "cleanup.discarded" : "cleanup.notStaged")
        if !removed, let location = job.location { self.removeUnstagedPackage(location) }
      } catch {
        self.diagnose("cleanup.failed", error: error)
        /* Never delete a path after the store refused its ownership. */
      }
      DispatchQueue.main.async(execute: completion)
    }
  }

  private func removeUnstagedPackage(_ url: URL) {
    let library = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
      .appendingPathComponent("Library", isDirectory: true).resolvingSymlinksInPath().path + "/"
    guard url.isFileURL, url.pathExtension == "movpkg", url.standardizedFileURL.path == url.resolvingSymlinksInPath().path,
          url.path.hasPrefix(library) else { diagnose("cleanup.pathRejected"); return }
    do {
      try FileManager.default.removeItem(at: url)
      diagnose("cleanup.packageRemoved")
    } catch { diagnose("cleanup.packageRemoveFailed", error: error) }
  }

  func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    guard let identifier = session.configuration.identifier else { return }
    backgroundFinished.insert(identifier)
    finishBackgroundIfReady(identifier)
  }

  func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
    guard let identifier = session.configuration.identifier, jobs[identifier] == nil else { return }
    guard sessions[identifier] === session else { return }
    sessions.removeValue(forKey: identifier)
    let recovering = recoveryDescriptors.removeValue(forKey: identifier) != nil
    remember(identifier, present: false)
    backgroundFinished.insert(identifier)
    if recovering {
      io.async {
        do { try self.ownedStore().finishOrphanedRecovery(identifier) }
        catch { self.diagnose("recovery.orphan.failed", error: error) }
        DispatchQueue.main.async {
          self.inspectingRecovery.remove(identifier)
          self.recoveryChanged()
          self.finishBackgroundIfReady(identifier)
        }
      }
      return
    }
    inspectingRecovery.remove(identifier)
    finishBackgroundIfReady(identifier)
  }

  private func finishBackgroundIfReady(_ identifier: String) {
    guard jobs[identifier]?.finalizing != true, !reconnecting.contains(identifier),
          !inspectingRecovery.contains(identifier),
          backgroundFinished.contains(identifier),
          let completion = backgroundCompletions.removeValue(forKey: identifier) else { return }
    backgroundFinished.remove(identifier)
    io.async { DispatchQueue.main.async(execute: completion) }
  }

  private func presenter() -> UIViewController? {
    let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }.flatMap { $0.windows }
    guard var view = windows.first(where: { $0.isKeyWindow })?.rootViewController else { return nil }
    while let shown = view.presentedViewController { view = shown }
    guard view.viewIfLoaded?.window != nil, !view.isBeingDismissed,
          !(view is UIAlertController), !(view is UIDocumentPickerViewController) else { return nil }
    return view
  }

  private func openOffline(_ args: [String: Any], result: @escaping FlutterResult) {
    guard #available(iOS 15.0, *), offline == nil,
          let (resource, assetID, generation) = binding(args) else { result("unavailable"); return }
    // Reserve this slot before asynchronous disk validation, preventing two
    // queued callers from both taking a reader lease and presenting players.
    let controller = HlsOfflinePlayerController()
    offline = controller
    io.async { [weak self] in
      guard let self else { return }
      do {
        let url = try self.ownedStore().hold(resourceID: resource, assetID: assetID, generation: generation)
        DispatchQueue.main.async {
          let local = AVURLAsset(url: url)
          guard local.assetCache?.isPlayableOffline == true else {
            self.releaseOffline(resource, assetID, generation)
            self.offline = nil; result("unavailable"); return
          }
          Task { @MainActor in
            do {
              let protected = try await local.load(.hasProtectedContent)
              let playable = try await local.load(.isPlayable)
              guard !protected, playable else { throw URLError(.unsupportedURL) }
              let duration = CMTimeGetSeconds(try await local.load(.duration))
              guard let durationMs = Self.milliseconds(duration), durationMs > 0,
                    let parent = self.presenter() else { throw URLError(.cannotOpenFile) }
              let player = AVPlayer(playerItem: AVPlayerItem(asset: local))
              player.appliesMediaSelectionCriteriaAutomatically = false
              controller.player = player
              controller.durationMs = durationMs
              controller.modalPresentationStyle = .fullScreen
              controller.onFinished = { [weak self] position, duration, completed in
                player.pause()
                self?.releaseOffline(resource, assetID, generation)
                self?.offline = nil
                result(["positionMs": position, "durationMs": duration, "completed": completed])
              }
              let initial = (args["initialPositionMs"] as? NSNumber)?.int64Value ?? 0
              let position = initial >= controller.durationMs ? 0 : max(0, initial)
              let rate = (args["speed"] as? NSNumber)?.doubleValue ?? 1
              let speed = Float(rate.isFinite && rate > 0 && rate <= 4 ? rate : 1)
              let autoplay = args["autoplay"] as? Bool ?? true
              parent.present(controller, animated: !UIAccessibility.isReduceMotionEnabled) {
                player.seek(to: CMTime(value: position, timescale: 1000), toleranceBefore: .zero, toleranceAfter: .zero) { [weak controller] finished in
                  DispatchQueue.main.async {
                    if finished && controller?.finished == false && autoplay { player.rate = speed }
                  }
                }
              }
            } catch {
              self.releaseOffline(resource, assetID, generation)
              self.offline = nil; result("unavailable")
            }
          }
        }
      } catch {
        DispatchQueue.main.async { self.offline = nil; result("unavailable") }
      }
    }
  }

  private func releaseOffline(_ resource: String, _ assetID: String, _ generation: String) {
    io.async { [weak self] in
      guard let self, let store = try? self.ownedStore() else { return }
      store.release(resourceID: resource, assetID: assetID, generation: generation)
    }
  }
}

private final class HlsOfflinePlayerController: AVPlayerViewController {
  var durationMs: Int64 = 0
  var onFinished: ((Int64, Int64, Bool) -> Void)?
  private(set) var finished = false
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    guard !finished, isBeingDismissed || presentingViewController == nil else { return }
    finished = true
    let seconds = player.map { CMTimeGetSeconds($0.currentTime()) } ?? 0
    let position = seconds.isFinite ? min(durationMs, max(0, Int64(seconds * 1000))) : 0
    onFinished?(position, durationMs, durationMs > 0 && Double(position) >= Double(durationMs) * 0.98)
    onFinished = nil
  }
}
