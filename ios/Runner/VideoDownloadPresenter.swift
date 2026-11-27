import AVFoundation
import CoreImage
import Flutter
import UIKit

/// Owns independent MP4 jobs. A worker keeps all transport, stage, response
/// validation and cleanup state private; channel dispatch is installed once.
final class VideoDownloadPresenter: NSObject {
  private let channel: FlutterMethodChannel
  private let exports: VideoDownloadTransfer
  private let partials = MP4PartialCache()
  private var jobs: [String: VideoDownloadTransfer] = [:]
  private var foreground = UIApplication.shared.applicationState == .active
  private static let cleanupInterruptedExports: Void = {
    let cutoff = Date()
    DispatchQueue.global(qos: .utility).async {
      let manager = FileManager.default
      removeInterruptedExports(in: manager.temporaryDirectory, before: cutoff) { name in
        ["breeze-video-", MP4DownloadSpool.directoryPrefix].contains { prefix in
          name.hasPrefix(prefix) && UUID(uuidString: String(name.dropFirst(prefix.count))) != nil
        }
      }
      if let cache = manager.urls(for: .cachesDirectory, in: .userDomainMask).first {
        let root = cache.resolvingSymlinksInPath().appendingPathComponent("breeze-comic-export")
        guard root.resolvingSymlinksInPath().path == root.path else { return }
        removeInterruptedExports(in: root, before: cutoff) { name in
          name.range(of: "^[a-f0-9]{32}$", options: .regularExpression) != nil
        }
      }
    }
  }()

  private static func removeInterruptedExports(in root: URL, before cutoff: Date,
                                               matches: (String) -> Bool) {
    let manager = FileManager.default
    let keys: Set<URLResourceKey> = [.creationDateKey, .isDirectoryKey, .isSymbolicLinkKey]
    guard let folders = try? manager.contentsOfDirectory(at: root, includingPropertiesForKeys: Array(keys)) else { return }
    for folder in folders where matches(folder.lastPathComponent) {
      guard let info = try? folder.resourceValues(forKeys: keys),
            info.isDirectory == true, info.isSymbolicLink == false,
            let created = info.creationDate, created < cutoff else { continue }
      try? manager.removeItem(at: folder)
    }
  }

  init(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "breeze.video.download", binaryMessenger: messenger)
    self.channel = channel
    self.exports = VideoDownloadTransfer(channel: channel)
    super.init()
    _ = Self.cleanupInterruptedExports
    NotificationCenter.default.addObserver(self, selector: #selector(enteredBackground),
      name: UIApplication.didEnterBackgroundNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(enteredForeground),
      name: UIApplication.didBecomeActiveNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(enteredBackground),
      name: UIScene.didEnterBackgroundNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(enteredForeground),
      name: UIScene.didActivateNotification, object: nil)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result("unavailable"); return }
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "start":
        // Legacy Files presentation remains a single UI transaction.
        guard args["managedId"] != nil else { self.exports.handle(call, foreground: self.foreground, result: result); return }
        guard let id = args["id"] as? String, !id.isEmpty, id.count <= 80 else {
          result(["status": "failed", "reason": "invalidRequest"]); return
        }
        guard self.jobs[id] == nil, self.jobs.count < 3 else { result("busy"); return }
        let worker = VideoDownloadTransfer(channel: channel, partials: self.partials)
        self.jobs[id] = worker
        worker.handle(call, foreground: self.foreground) { [weak self, weak worker] value in
          if let self, let worker, self.jobs[id] === worker { self.jobs.removeValue(forKey: id) }
          result(value)
        }
      case "cancel":
        if let id = args["id"] as? String, let worker = self.jobs[id] {
          worker.handle(call, result: result)
        } else {
          self.exports.handle(call, result: result)
        }
      case "discardPartial":
        if let id = args["managedId"] as? String, id.utf8.count == 64,
           id.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil { self.partials.discard(id) }
        result(nil)
      default:
        self.exports.handle(call, result: result)
      }
    }
  }

  @objc private func enteredBackground() { setForeground(false) }
  @objc private func enteredForeground() { setForeground(true) }

  private func setForeground(_ allowed: Bool) {
    foreground = allowed
    exports.setForeground(allowed)
    for worker in jobs.values { worker.setForeground(allowed) }
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
    channel.setMethodCallHandler(nil)
  }
}

/// One media transfer, staged for the app or presented in the system Files picker.
/// No signed URLs, cookies, headers or URLSession errors are logged or persisted.
private final class VideoDownloadTransfer: NSObject, URLSessionDataDelegate, URLSessionDownloadDelegate, UIDocumentPickerDelegate {
  private let channel: FlutterMethodChannel
  private let partials: MP4PartialCache?
  private var session: URLSession?
  private var task: URLSessionTask?
  private var networkLease: OmoNetworkLease?
  private var completion: FlutterResult?
  private var job: String?
  private var managedID: String?
  private var transferResumed = false
  private var fileName = "Video.mp4"
  private var temporaryDirectory: URL?
  private weak var picker: UIDocumentPickerViewController?
  private var received: Int64 = 0
  private var expected: Int64 = 0
  private var checkedCapacity = false
  private var wifiOnly = false
  private var lastProgress = Date.distantPast
  private var redirectCount = 0
  private var foregroundAllowed = false
  private var resumeScope: String?
  private var spool: MP4DownloadSpool?
  private var originalRequest: URLRequest?
  private var rangeRequested = false
  private var retryBudget = MP4RetryBudget()
  private var retryTimer: DispatchWorkItem?

  init(channel: FlutterMethodChannel, partials: MP4PartialCache? = nil) {
    self.channel = channel
    self.partials = partials
    super.init()
  }

  func handle(_ call: FlutterMethodCall, foreground: Bool = true, result: @escaping FlutterResult) {
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "start": self.start(args, foreground: foreground, result: result)
      case "export": self.exportManaged(args, result: result)
      case "exportArchive": self.exportArchive(args, result: result)
      case "poster": self.localPoster(args, result: result)
      case "cancel":
        if let id = args["id"] as? String, id == self.job {
          self.finish("cancelled", retainPartial: args["preservePartial"] as? Bool == true)
        }
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
  }

  private func validHTTPS(_ url: URL) -> Bool {
    url.scheme == "https" && url.host?.isEmpty == false && url.user == nil &&
      url.password == nil && (url.port == nil || url.port == 443) && url.fragment == nil
  }

  private func publicPage(_ url: URL) -> Bool {
    guard validHTTPS(url), let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
    if url.path == "/watch" {
      let query = parts.queryItems ?? []
      return query.count == 1 && query[0].name == "v" &&
        query[0].value?.range(of: "^[0-9]+$", options: .regularExpression) != nil
    }
    guard parts.query == nil else { return false }
    return [#"^/voddetail/[1-9][0-9]{0,14}\.html$"#,
      #"^/index\.php/vod/detail/id/[1-9][0-9]{0,14}\.html$"#,
      #"^/vod/[1-9][0-9]{0,14}/$"#, #"^/anime/[a-f0-9]{16,64}\.html$"#,
      #"^/videos/[A-Za-z0-9_-]{1,64}$"#].contains { url.path.range(of: $0, options: .regularExpression) != nil }
  }

  private func publicHeaders(_ raw: Any?, page: URL) -> [String: String]? {
    guard let raw, !(raw is NSNull) else { return [:] }
    guard let values = raw as? [String: String], values.count <= 3 else { return nil }
    var result: [String: String] = [:]
    for (key, value) in values {
      let names = ["referer": "Referer", "origin": "Origin", "user-agent": "User-Agent"]
      guard let name = names[key.lowercased()], value.count <= 2000,
            value.rangeOfCharacter(from: .controlCharacters) == nil else { return nil }
      if name != "User-Agent" {
        guard let url = URL(string: value), validHTTPS(url), url.host == page.host,
              (url.port ?? 443) == (page.port ?? 443),
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        if name == "Origin" {
          guard parts.query == nil, url.path.isEmpty || url.path == "/" else { return nil }
        } else if parts.query != nil && !publicPage(url) {
          let query = parts.queryItems ?? []
          var base = parts
          base.query = nil
          guard let publicURL = base.url, publicPage(publicURL), query.count == 2,
                Set(query.map(\.name)) == Set(["line", "episode"]),
                query.allSatisfy({ !($0.value ?? "").isEmpty && ($0.value?.count ?? 0) <= 300 }) else { return nil }
        }
      }
      result[name] = value
    }
    return result
  }

  private func start(_ args: [String: Any], foreground: Bool, result: @escaping FlutterResult) {
    guard job == nil else { result("busy"); return }
    let lease: OmoNetworkLease?
    if let context = args["networkContext"], !(context is NSNull) {
      guard let token = context as? String, let owner = OmoNetwork.shared.lease(token) else { result(failure(.routeUnavailable)); return }
      lease = owner
    } else { lease = nil }
    guard let id = args["id"] as? String, !id.isEmpty, id.count <= 80,
          let raw = args["url"] as? String, raw.count <= 8192,
          let url = URL(string: raw), validHTTPS(url), url.pathExtension.lowercased() == "mp4",
          let refererRaw = args["referer"] as? String, refererRaw.count <= 8192,
          let referer = URL(string: refererRaw), validHTTPS(referer) else {
      result(failure(.invalidRequest)); return
    }
    guard publicPage(referer), let headers = publicHeaders(args["headers"], page: referer) else {
      result(failure(.invalidRequest)); return
    }
    if let lease {
      guard lease.isFirstParty(referer) else { result(failure(.invalidRequest)); return }
    }
    let requestedID = args["managedId"] as? String
    if args["managedId"] != nil && (requestedID == nil || !validID(requestedID!)) { result(failure(.invalidRequest)); return }
    let scope = (args["resumeScope"] as? String).flatMap { validID($0) ? $0 : nil }
    guard requestedID != nil || presenter() != nil else { result("unavailable"); return }
    managedID = requestedID
    retryBudget = MP4RetryBudget()
    if let id = managedID, let scope {
      resumeScope = scope
      spool = partials?.take(id: id, scope: scope)
    } else if let id = managedID { partials?.discard(id) }
    let title = String((args["title"] as? String ?? "Video").prefix(100))
    let quality = String((args["quality"] as? String ?? "").prefix(20))
    fileName = VideoExportFilename.make("\(title) \(quality)", fallback: "Video", suffix: ".mp4")
    job = id
    completion = result
    received = 0
    expected = 0
    wifiOnly = args["wifiOnly"] as? Bool == true
    lastProgress = .distantPast
    var request = URLRequest(url: url)
    request.allowsCellularAccess = !wifiOnly
    request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")
    for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
    if resumeScope != nil { request.setValue("identity", forHTTPHeaderField: "Accept-Encoding") }
    networkLease = lease
    originalRequest = request
    foregroundAllowed = foreground && UIApplication.shared.applicationState != .background
    progress(saving: false, force: true)
    launch()
  }

  private func launch() {
    guard var request = originalRequest else { return }
    redirectCount = 0
    checkedCapacity = false
    if let spool { spool.validator?.applyRange(to: &request, from: spool.size) }
    rangeRequested = request.value(forHTTPHeaderField: "Range") != nil
    if let lease = networkLease {
      // A routed export borrows the source's existing pool and immutable route.
      // It must never invalidate that pool when the export finishes.
      guard let (transport, transfer) = lease.downloadTask(with: request, streaming: resumeScope != nil, delegate: self) else {
        finish(failure(.routeUnavailable)); return
      }
      session = transport
      task = transfer
    } else {
      let config = URLSessionConfiguration.ephemeral
      config.allowsCellularAccess = request.allowsCellularAccess
      config.httpCookieStorage = nil
      config.httpShouldSetCookies = false
      config.urlCredentialStorage = nil
      config.urlCache = nil
      config.requestCachePolicy = .reloadIgnoringLocalCacheData
      config.timeoutIntervalForRequest = 45
      config.timeoutIntervalForResource = 3600
      let transport = URLSession(configuration: config, delegate: self, delegateQueue: .main)
      session = transport
      task = resumeScope != nil ? transport.dataTask(with: request) : transport.downloadTask(with: request)
    }
    setForeground(foregroundAllowed)
  }

  /// Keep the same managed transfer while the network recovers. Every retry
  /// goes through the existing Range and staging validation.
  private func retryTransfer() -> Bool {
    guard resumeScope != nil, let retiringJob = job, let delay = retryBudget.nextDelay() else {
      return false
    }
    if let spool, (try? spool.close()) == nil || !spool.canResume {
      self.spool = nil
      received = 0
      expected = 0
      progress(saving: false, force: true)
    }
    closeTransport()
    let work = DispatchWorkItem { [weak self] in
      guard let self, self.job == retiringJob, self.retryTimer?.isCancelled == false else { return }
      self.retryTimer = nil
      self.launch()
    }
    retryTimer = work
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    return true
  }

  func setForeground(_ allowed: Bool) {
    // A foreground session can finish in-flight work before iOS suspends
    // the app. Managed background sessions have their own pause policy.
    foregroundAllowed = allowed
    guard allowed, !transferResumed, let task,
      task.state != .completed, task.state != .canceling else { return }
    transferResumed = true
    task.resume()
  }

  private func validID(_ value: String) -> Bool {
    value.utf8.count == 64 && value.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil
  }

  private func managedRoot() throws -> URL {
    let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
      appropriateFor: nil, create: true)
    let root = support.appendingPathComponent("files/downloads/video-v1", isDirectory: true)
    let expected = support.resolvingSymlinksInPath().appendingPathComponent("files/downloads/video-v1", isDirectory: true)
    guard root.resolvingSymlinksInPath().standardizedFileURL.path == expected.standardizedFileURL.path else {
      throw NSError(domain: "VideoResource", code: 1)
    }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
      attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
    guard (try root.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink != true else {
      throw NSError(domain: "VideoResource", code: 1)
    }
    return root
  }

  private func localPoster(_ args: [String: Any], result: @escaping FlutterResult) {
    guard let id = args["resourceId"] as? String, validID(id) else { result(nil); return }
    do {
      let root = try managedRoot()
      let file = root.appendingPathComponent("\(id).mp4")
      let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
      guard values.isRegularFile == true, values.isSymbolicLink != true,
            (values.fileSize ?? 0) > 12,
            file.resolvingSymlinksInPath().deletingLastPathComponent().path == root.path else { result(nil); return }
      LocalVideoPosterGenerator.generate(file: file) { data in
        result(data.map { FlutterStandardTypedData(bytes: $0) })
      }
    } catch { result(nil) }
  }

  private func exportManaged(_ args: [String: Any], result: @escaping FlutterResult) {
    guard job == nil else { result("busy"); return }
    guard let id = args["resourceId"] as? String, validID(id), presenter() != nil else {
      result("unavailable"); return
    }
    do {
      let file = try managedRoot().appendingPathComponent("\(id).mp4")
      let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
      guard values.isRegularFile == true, values.isSymbolicLink != true else { result("failed"); return }
      let folder = FileManager.default.temporaryDirectory.appendingPathComponent("breeze-video-\(UUID().uuidString)", isDirectory: true)
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
      let title = String((args["title"] as? String ?? "Video").prefix(100))
      let name = VideoExportFilename.make(title, fallback: "Video", suffix: ".mp4")
      let copy = folder.appendingPathComponent(name)
      let token = "video-export-\(UUID().uuidString)"
      temporaryDirectory = folder
      job = token
      completion = result
      // Large Files exports must not synchronously copy an entire movie on
      // the UI thread. The managed original remains independent of this copy.
      DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        do {
          try FileManager.default.copyItem(at: file, to: copy)
          DispatchQueue.main.async { [weak self] in
            guard let self = self, self.job == token else {
              try? FileManager.default.removeItem(at: folder); return
            }
            guard let view = self.presenter() else { self.finish("unavailable"); return }
            let sheet = UIDocumentPickerViewController(forExporting: [copy], asCopy: true)
            sheet.delegate = self
            sheet.shouldShowFileExtensions = true
            self.picker = sheet
            view.present(sheet, animated: !UIAccessibility.isReduceMotionEnabled)
          }
        } catch {
          DispatchQueue.main.async { [weak self] in
            if let self = self, self.job == token { self.finish("failed") }
            else { try? FileManager.default.removeItem(at: folder) }
          }
        }
      }
    } catch { result("failed") }
  }

  // Only a Dart-owned private archive capability enters this bridge. A caller
  // cannot export an arbitrary path, original download or HLS package.
  private func exportArchive(_ args: [String: Any], result: @escaping FlutterResult) {
    guard job == nil else { result("busy"); return }
    guard let id = args["archiveId"] as? String,
          id.range(of: "^[a-f0-9]{32}$", options: .regularExpression) != nil,
          let view = presenter() else { result("unavailable"); return }
    do {
      guard let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
        result("failed"); return
      }
      let root = cache.resolvingSymlinksInPath().appendingPathComponent("breeze-comic-export")
      let folder = root.appendingPathComponent(id)
      let file = folder.appendingPathComponent("archive.zip")
      let info = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
      guard root.resolvingSymlinksInPath().path == root.path,
            folder.resolvingSymlinksInPath().path == folder.path,
            file.resolvingSymlinksInPath().path == file.path,
            info.isRegularFile == true, info.isSymbolicLink != true,
            (info.fileSize ?? 0) >= 4 else { result("failed"); return }
      let title = String((args["title"] as? String ?? "Comic").prefix(100))
      let name = VideoExportFilename.make(title, fallback: "Comic", suffix: ".zip")
      let named = folder.appendingPathComponent(name)
      // Same-volume rename only, after packing. Originals are never touched.
      if named.path != file.path { try FileManager.default.moveItem(at: file, to: named) }
      job = "comic-export-\(id)"
      completion = result
      let sheet = UIDocumentPickerViewController(forExporting: [named], asCopy: true)
      sheet.delegate = self
      sheet.shouldShowFileExtensions = true
      picker = sheet
      view.present(sheet, animated: !UIAccessibility.isReduceMotionEnabled)
    } catch { result("failed") }
  }

  private enum FailureReason: String {
    case loginRequired, httpForbidden, httpNotFound, httpError
    case mediaRejected, incomplete, timeout, network, storage, outOfSpace
    case routeUnavailable, invalidRequest, redirectRejected, unavailable, downloadFailed
  }

  private func failure(_ reason: FailureReason, response: URLResponse? = nil) -> [String: Any] {
    var row: [String: Any] = ["status": "failed", "reason": reason.rawValue]
    if let http = response as? HTTPURLResponse, (100...599).contains(http.statusCode) {
      row["httpStatus"] = http.statusCode
    }
    return row
  }

  private func mediaResponseFailure(_ response: URLResponse?) -> [String: Any]? {
    guard let http = response as? HTTPURLResponse else { return failure(.network) }
    guard (200...299).contains(http.statusCode) else {
      let reason: FailureReason
      switch http.statusCode {
      case 401: reason = .loginRequired
      case 403: reason = .httpForbidden
      case 404: reason = .httpNotFound
      default: reason = .httpError
      }
      return failure(reason, response: http)
    }
    guard let url = http.url, validHTTPS(url) else {
      return failure(.redirectRejected, response: http)
    }
    let mime = http.mimeType?.lowercased() ?? ""
    return mime.isEmpty || ["video/mp4", "application/mp4", "application/octet-stream", "binary/octet-stream"].contains(mime)
      ? nil : failure(.mediaRejected, response: http)
  }

  private func errorFailure(_ error: Error, fallback: FailureReason,
                            response: URLResponse? = nil) -> [String: Any] {
    // Inspect only finite domains/codes, including a bounded underlying error.
    // Raw NSError descriptions/userInfo may contain credentials or signed URLs.
    var current = error as NSError
    for _ in 0..<3 {
      if current.domain == NSCocoaErrorDomain {
        if current.code == NSFileWriteOutOfSpaceError { return failure(.outOfSpace, response: response) }
      }
      if current.domain == NSPOSIXErrorDomain && current.code == Int(POSIXErrorCode.ENOSPC.rawValue) {
        return failure(.outOfSpace, response: response)
      }
      if current.domain == NSURLErrorDomain {
        if current.code == NSURLErrorTimedOut { return failure(.timeout, response: response) }
        if [NSURLErrorCannotCreateFile, NSURLErrorCannotOpenFile,
            NSURLErrorCannotCloseFile, NSURLErrorCannotWriteToFile].contains(current.code) {
          return failure(.storage, response: response)
        }
      }
      guard let underlying = current.userInfo[NSUnderlyingErrorKey] as? NSError else { break }
      current = underlying
    }
    return failure(fallback, response: response)
  }

  private func presenter() -> UIViewController? {
    let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }.flatMap { $0.windows }
    guard let root = windows.first(where: { $0.isKeyWindow })?.rootViewController else { return nil }
    var view = root
    while let presented = view.presentedViewController { view = presented }
    guard view.viewIfLoaded?.window != nil, !view.isBeingDismissed,
          !(view is UIAlertController), !(view is UIActivityViewController),
          !(view is UIDocumentPickerViewController) else { return nil }
    return view
  }

  private func progress(saving: Bool, force: Bool = false) {
    guard let id = job else { return }
    guard force || Date().timeIntervalSince(lastProgress) >= 0.15 else { return }
    lastProgress = Date()
    channel.invokeMethod("progress", arguments: [
      "id": id, "received": received, "total": expected, "saving": saving,
    ])
  }

  func urlSession(_ session: URLSession, task: URLSessionTask,
                  willPerformHTTPRedirection response: HTTPURLResponse,
                  newRequest request: URLRequest,
                  completionHandler: @escaping (URLRequest?) -> Void) {
    guard self.session === session, self.task === task, job != nil,
          let url = request.url, validHTTPS(url), redirectCount < 5 else {
      completionHandler(nil)
      if self.session === session, self.task === task { finish(failure(.redirectRejected, response: response)) }
      return
    }
    redirectCount += 1
    var safe = request
    safe.allowsCellularAccess = !wifiOnly
    // Redirects must never acquire cookie/auth headers. Do not leak watch
    // identifiers to a different CDN host beyond the first issued request.
    safe.setValue(nil, forHTTPHeaderField: "Cookie")
    safe.setValue(nil, forHTTPHeaderField: "Authorization")
    if request.url?.host != task.originalRequest?.url?.host {
      safe.setValue(nil, forHTTPHeaderField: "Referer")
      safe.setValue(nil, forHTTPHeaderField: "Origin")
    }
    if resumeScope != nil {
      safe.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
      if let spool { spool.validator?.applyRange(to: &safe, from: spool.size) }
      rangeRequested = safe.value(forHTTPHeaderField: "Range") != nil
    }
    completionHandler(safe)
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                  completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
    guard self.session === session, self.task === dataTask, job != nil else { completionHandler(.cancel); return }
    let http = response as? HTTPURLResponse
    let status = http?.statusCode
    let decision = MP4ResumeResponse(http, spool: spool, rangeRequested: rangeRequested)
    if decision == .restart {
      completionHandler(.cancel)
      // This endpoint cannot satisfy the checkpoint. Reset once to an
      // ordinary GET before any response bytes can reach the local file.
      spool = nil
      closeTransport()
      launch()
      return
    }
    if let rejected = mediaResponseFailure(response) {
      completionHandler(.cancel)
      if let status, MP4RetryBudget.transientHTTP(status), retryTransfer() { return }
      let retain = status.map { [401, 403, 404, 408, 410, 429].contains($0) || (500...599).contains($0) } ?? false
      finish(rejected, retainPartial: retain)
      return
    }
    guard let http, decision == .append || status == 200 else {
      completionHandler(.cancel)
      finish(failure(.incomplete, response: response)); return
    }
    do {
      if decision == .append, let spool, let validator = spool.validator {
        received = spool.size
        expected = validator.total
      } else {
        spool = nil
        let fresh = try MP4DownloadSpool()
        fresh.validator = MP4ResumeValidator(http)
        spool = fresh
        received = 0
        expected = fresh.validator?.total ?? (MP4ResumeValidator.identityEncoding(http) ? max(0, http.expectedContentLength) : 0)
      }
      guard hasRemainingCapacity(expected - received) else {
        completionHandler(.cancel)
        finish(failure(.outOfSpace, response: response)); return
      }
      progress(saving: false, force: true)
      completionHandler(.allow)
    } catch {
      completionHandler(.cancel)
      finish(errorFailure(error, fallback: .storage, response: response))
    }
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    guard self.session === session, self.task === dataTask, job != nil, let spool else { return }
    guard expected <= 0 || Int64(data.count) <= expected - spool.size else {
      finish(failure(.incomplete, response: dataTask.response)); return
    }
    do {
      try spool.append(data)
      received = spool.size
      progress(saving: false)
    } catch {
      finish(errorFailure(error, fallback: .storage, response: dataTask.response))
    }
  }

  private func hasRemainingCapacity(_ remaining: Int64) -> Bool {
    guard remaining > 0,
          let attributes = try? FileManager.default.attributesOfFileSystem(forPath: FileManager.default.temporaryDirectory.path),
          let free = attributes[.systemFreeSize] as? NSNumber else { return true }
    return remaining <= free.int64Value
  }

  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                  didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                  totalBytesExpectedToWrite: Int64) {
    guard self.session === session, self.task === downloadTask, job != nil else { return }
    if let rejected = mediaResponseFailure(downloadTask.response) { finish(rejected); return }
    if !checkedCapacity && totalBytesExpectedToWrite > 0 {
      checkedCapacity = true
      if !hasRemainingCapacity(totalBytesExpectedToWrite - totalBytesWritten) {
        finish(failure(.outOfSpace, response: downloadTask.response)); return
      }
    }
    received = totalBytesWritten
    expected = totalBytesExpectedToWrite
    progress(saving: false)
  }

  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                  didFinishDownloadingTo location: URL) {
    guard self.session === session, self.task === downloadTask, job != nil else { return }
    completeDownload(at: location, response: downloadTask.response)
  }

  private func completeDownload(at location: URL, response: URLResponse?) {
    do {
      if let rejected = mediaResponseFailure(response) { finish(rejected); return }
      let attributes = try FileManager.default.attributesOfItem(atPath: location.path)
      let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
      guard size > 12 else { finish(failure(.incomplete, response: response)); return }
      let handle = try FileHandle(forReadingFrom: location)
      defer { try? handle.close() }
      let header = try handle.read(upToCount: 12) ?? Data()
      // MP4/ISO-BMFF files have an initial file-type box. A 200 HTML login,
      // challenge or CDN error page must never reach Files as a video.
      guard header.count == 12, String(data: header[4..<8], encoding: .ascii) == "ftyp" else {
        finish(failure(.mediaRejected, response: response)); return
      }
      guard expected <= 0 || size == expected else {
        finish(failure(.incomplete, response: response), retainPartial: true); return
      }
      if let id = managedID {
        let cache = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask,
          appropriateFor: nil, create: true)
        let root = cache.appendingPathComponent("breeze-video-staging", isDirectory: true)
        guard root.resolvingSymlinksInPath().path == cache.resolvingSymlinksInPath().appendingPathComponent("breeze-video-staging", isDirectory: true).path else {
          finish(failure(.storage, response: response)); return
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
          attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        let stageID = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let stage = root.appendingPathComponent("\(stageID).mp4")
        try FileManager.default.moveItem(at: location, to: stage)
        received = size
        expected = size
        progress(saving: true, force: true)
        // Dart owns the short storage transaction: final rename and index
        // commit share the same exclusion queue as backup export/import.
        finish(["status": "staged", "resourceId": id, "stageId": stageID, "bytes": size])
        return
      }
      let folder = FileManager.default.temporaryDirectory.appendingPathComponent("breeze-video-\(UUID().uuidString)", isDirectory: true)
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false,
        attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
      temporaryDirectory = folder
      let file = folder.appendingPathComponent(fileName)
      try FileManager.default.moveItem(at: location, to: file)
      guard let view = presenter() else { finish(failure(.unavailable)); return }
      received = size
      expected = size
      progress(saving: true, force: true)
      let sheet = UIDocumentPickerViewController(forExporting: [file], asCopy: true)
      sheet.delegate = self
      sheet.shouldShowFileExtensions = true
      picker = sheet
      view.present(sheet, animated: !UIAccessibility.isReduceMotionEnabled)
    } catch {
      finish(errorFailure(error, fallback: .storage, response: response))
    }
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard self.session === session, self.task === task, job != nil else { return }
    guard let error else {
      guard task is URLSessionDataTask else { return }
      guard let spool else { finish(failure(.incomplete, response: task.response)); return }
      if expected > 0, spool.size < expected, retryTransfer() { return }
      do {
        try spool.close()
        completeDownload(at: spool.file, response: task.response)
      } catch { finish(errorFailure(error, fallback: .storage, response: task.response)) }
      return
    }
    let native = error as NSError
    if native.domain == NSURLErrorDomain && native.code == NSURLErrorCancelled {
      finish("cancelled")
    } else if let response = task.response as? HTTPURLResponse,
              !(200...299).contains(response.statusCode),
              let rejected = mediaResponseFailure(response) {
      if MP4RetryBudget.transientHTTP(response.statusCode), retryTransfer() { return }
      finish(rejected)
    } else {
      let retain = MP4RetryBudget.transient(native)
      if retain && retryTransfer() { return }
      finish(errorFailure(error, fallback: .network, response: task.response), retainPartial: retain)
    }
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard picker === controller, job != nil else { return }
    // The export delegate is the save acknowledgment. Merely finishing the
    // network task or presenting Files never reports a saved file.
    finish(urls.isEmpty ? "failed" : "saved")
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    guard picker === controller, job != nil else { return }
    finish("cancelled")
  }

  private func closeTransport() {
    let transport = session
    session = nil
    if let task {
      networkLease?.removeDownload(task)
      task.cancel()
    }
    task = nil
    transferResumed = false
    if networkLease == nil { transport?.invalidateAndCancel() }
  }

  private func finish(_ status: Any, retainPartial: Bool = false) {
    guard job != nil else { return }
    retryTimer?.cancel()
    retryTimer = nil
    if let scope = resumeScope, let id = managedID {
      if retainPartial, let partials, let spool, (try? spool.close()) != nil, spool.canResume {
        partials.retain(spool, id: id, scope: scope)
        received = spool.size
        expected = spool.validator?.total ?? 0
        progress(saving: false, force: true)
      } else if (status as? [String: Any])?["status"] as? String == "failed" || status as? String == "cancelled" {
        received = 0
        expected = 0
        progress(saving: false, force: true)
      }
    }
    spool = nil
    resumeScope = nil
    originalRequest = nil
    job = nil
    managedID = nil
    let callback = completion
    completion = nil
    let documentPicker = picker
    picker = nil
    closeTransport()
    networkLease = nil
    let folder = temporaryDirectory
    temporaryDirectory = nil
    let done = {
      if let folder = folder { try? FileManager.default.removeItem(at: folder) }
      callback?(status)
    }
    if let documentPicker = documentPicker, documentPicker.presentingViewController != nil,
       !documentPicker.isBeingDismissed {
      documentPicker.dismiss(animated: !UIAccessibility.isReduceMotionEnabled, completion: done)
    } else {
      done()
    }
  }

  deinit {
    closeTransport()
    networkLease = nil
    if let folder = temporaryDirectory { try? FileManager.default.removeItem(at: folder) }
  }
}

/// Bounded local-only presentation metadata. Never opens a remote URL or logs
/// asset paths/errors. Existing channel owners authorize the resource binding.
enum LocalVideoPosterGenerator {
  static func generate(file: URL, completion: @escaping (Data?) -> Void) {
    guard file.isFileURL else { completion(nil); return }
    let asset = AVURLAsset(url: file, options: [
      AVURLAssetReferenceRestrictionsKey: AVAssetReferenceRestrictions.forbidLocalReferenceToRemote.rawValue
    ])
    let queue = DispatchQueue(label: "breeze.video.local-poster")
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 320, height: 480)
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = CMTime(seconds: 0.25, preferredTimescale: 600)
    var finished = false
    var remaining = 0
    var frames: [Int: CGImage] = [:]
    func finish(_ data: Data?) {
      guard !finished else { return }
      finished = true
      generator.cancelAllCGImageGeneration()
      asset.cancelLoading()
      DispatchQueue.main.async { completion(data) }
    }
    queue.asyncAfter(deadline: .now() + 6) { finish(nil) }
    asset.loadValuesAsynchronously(forKeys: ["hasProtectedContent", "tracks", "duration", "playable"]) {
      queue.async {
        guard !finished else { return }
        let keys = ["hasProtectedContent", "tracks", "duration", "playable"]
        guard keys.allSatisfy({ asset.statusOfValue(forKey: $0, error: nil) == .loaded }),
              !asset.hasProtectedContent, asset.isPlayable,
              !asset.tracks(withMediaType: .video).isEmpty else { finish(nil); return }
        let duration = CMTimeGetSeconds(asset.duration)
        guard duration.isFinite, duration > 0 else { finish(nil); return }
        let seconds = [0.0, 0.3, 1.0, 3.0].filter { $0 < duration }
        let times = seconds.map { NSValue(time: CMTime(seconds: $0, preferredTimescale: 600)) }
        remaining = times.count
        generator.generateCGImagesAsynchronously(forTimes: times) { requested, image, _, status, _ in
          queue.async {
            guard !finished else { return }
            if status == .succeeded, let image,
               let index = seconds.firstIndex(where: { abs($0 - CMTimeGetSeconds(requested)) < 0.01 }),
               isVisible(image) { frames[index] = image }
            remaining -= 1
            if remaining == 0 {
              let image = frames.keys.sorted().first.flatMap { frames[$0] }
              let data = image.flatMap { UIImage(cgImage: $0).pngData() }
              finish(data.flatMap { $0.count <= 1024 * 1024 ? $0 : nil })
            }
          }
        }
      }
    }
  }

  private static func isVisible(_ image: CGImage) -> Bool {
    let width = 24, height = 24
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
      guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
      context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
      return true
    }
    guard drawn else { return false }
    var visible = 0
    for index in stride(from: 0, to: pixels.count, by: 4) {
      if max(pixels[index], max(pixels[index + 1], pixels[index + 2])) > 24 { visible += 1 }
    }
    return visible > width * height / 20
  }
}

/// Takes a bounded thumbnail from the exact URL already assigned to the player.
/// A loopback relay URL retains its upstream routing and request headers.
final class VideoSeekPreviewPresenter: NSObject {
  private struct Source: Equatable {
    let owner: Int
    let url: URL
    let headers: [String: String]
    let wideThumbnail: Bool

    var thumbnailSize: CGSize {
      wideThumbnail ? CGSize(width: 640, height: 360) : CGSize(width: 256, height: 144)
    }

    func asset() -> AVURLAsset {
      let restrictions: AVAssetReferenceRestrictions = url.isFileURL
        ? .forbidLocalReferenceToRemote : .forbidRemoteReferenceToLocal
      var options: [String: Any] = [AVURLAssetReferenceRestrictionsKey: restrictions.rawValue]
      if !headers.isEmpty { options["AVURLAssetHTTPHeaderFieldsKey"] = headers }
      return AVURLAsset(url: url, options: options)
    }
  }

  private struct Request {
    let id: Int
    let owner: Int
    let started: CFTimeInterval
    let reader: String
    let deadline: DispatchWorkItem
    let result: FlutterResult
    var stop: (() -> Void)?
  }

  private let channel: FlutterMethodChannel
  private let encodeQueue = DispatchQueue(label: "breeze.video.seek-preview", qos: .userInitiated)
  private var active: Request?
  private var stream: (source: Source, frames: VideoSeekStreamFrames)?
  private var file: (source: Source, asset: AVURLAsset, generator: AVAssetImageGenerator)?
  private var prepared: (source: Source, asset: AVURLAsset, timeout: DispatchWorkItem?)?
  private var idle: DispatchWorkItem?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "breeze.video.seek-preview", binaryMessenger: messenger)
    super.init()
    NotificationCenter.default.addObserver(self, selector: #selector(closeAll),
      name: UIApplication.willResignActiveNotification, object: nil)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      switch call.method {
      case "frame": self.frame(call.arguments, result: result)
      case "prepare":
        self.prepare(call.arguments)
        result(nil)
      case "cancel":
        if let id = call.arguments as? Int { self.finish(id, data: nil, outcome: "cancelled") }
        result(nil)
      case "close":
        if let owner = call.arguments as? Int { self.close(owner) }
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private func source(_ args: [String: Any]) -> Source? {
    guard UIApplication.shared.applicationState == .active,
          let owner = args["owner"] as? Int,
          let rawURL = args["url"] as? String, let url = URL(string: rawURL),
          let headers = args["headers"] as? [String: String],
          url.isFileURL || ((url.scheme == "https" || url.scheme == "http") &&
            url.host?.isEmpty == false && url.user == nil && url.password == nil) else {
      return nil
    }
    return Source(owner: owner, url: url, headers: headers,
      wideThumbnail: args["wideThumbnail"] as? Bool == true)
  }

  private func prepare(_ arguments: Any?) {
    guard let args = arguments as? [String: Any], let source = source(args),
          !source.url.isFileURL, args["streaming"] as? Bool != true,
          active == nil, stream?.source != source, prepared?.source != source else { return }
    releasePrepared()
    let asset = source.asset()
    let timeout = DispatchWorkItem { [weak self, weak asset] in
      guard let self, self.prepared?.asset === asset,
        self.prepared?.timeout != nil else { return }
      self.releasePrepared()
    }
    prepared = (source, asset, timeout)
    DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: timeout)
    // Load the file index only after visible playback is advancing. The
    // preview will use this same asset without starting another player here.
    asset.loadValuesAsynchronously(forKeys: ["tracks"]) { [weak self, weak asset] in
      DispatchQueue.main.async {
        guard let self, let asset, self.prepared?.asset === asset,
          self.prepared?.timeout != nil else { return }
        if asset.statusOfValue(forKey: "tracks", error: nil) == .loaded {
          self.prepared?.timeout?.cancel()
          self.prepared?.timeout = nil
        } else {
          self.releasePrepared()
        }
      }
    }
  }

  private func frame(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any], let source = source(args),
          let id = args["id"] as? Int,
          let milliseconds = args["milliseconds"] as? Int, milliseconds >= 0 else {
      result(nil)
      return
    }
    if let previous = active { finish(previous.id, data: nil, outcome: "superseded") }
    idle?.cancel()
    idle = nil
    let url = source.url
    if stream?.source != source || stream?.frames.hasFailed == true { releaseStream() }
    if file?.source != source { releaseFile() }
    if prepared?.source != source { releasePrepared() }
    let pathExtension = url.pathExtension.lowercased()
    let loopback = url.scheme == "http" && url.host == "127.0.0.1"
    let keyframeTrack = loopback && args["keyframeTrack"] as? Bool == true
    let hls = args["streaming"] as? Bool == true ||
      pathExtension == "m3u8" || pathExtension == "movpkg"
    let usePlayer = !keyframeTrack && (hls || !url.isFileURL)
    let cachedWindow = loopback && hls && args["cachedWindow"] as? Bool == true
    let reader = keyframeTrack ? "iframe" : cachedWindow ? "cached-hls" :
      hls ? "hls" : url.isFileURL ? "file" : "progressive"
    let deadline = DispatchWorkItem { [weak self] in
      self?.finish(id, data: nil, outcome: "deadline")
    }
    active = Request(id: id, owner: source.owner, started: CACurrentMediaTime(),
      reader: reader, deadline: deadline, result: result)
    let budget: TimeInterval = cachedWindow ? 0.7 : (usePlayer ? 5.75 : 1.75)
    DispatchQueue.main.asyncAfter(deadline: .now() + budget, execute: deadline)
    let time = CMTime(value: Int64(milliseconds), timescale: 1000)
    if usePlayer {
      readStream(source, id: id, time: time, hls: hls)
    } else {
      readFile(source, id: id, time: time, keyframeTrack: keyframeTrack)
    }
  }

  private func readFile(_ source: Source, id: Int, time: CMTime, keyframeTrack: Bool) {
    let asset: AVURLAsset
    let generator: AVAssetImageGenerator
    let reusable = source.url.isFileURL || keyframeTrack
    let tolerance: TimeInterval = keyframeTrack ? 3 : 1
    if let file {
      asset = file.asset
      generator = file.generator
    } else {
      asset = source.asset()
      generator = AVAssetImageGenerator(asset: asset)
      generator.appliesPreferredTrackTransform = true
      generator.maximumSize = source.thumbnailSize
      generator.requestedTimeToleranceBefore = CMTime(seconds: tolerance, preferredTimescale: 600)
      generator.requestedTimeToleranceAfter = generator.requestedTimeToleranceBefore
      if reusable { file = (source, asset, generator) }
    }
    active?.stop = {
      generator.cancelAllCGImageGeneration()
      if !reusable { asset.cancelLoading() }
    }
    generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) {
      [weak self] _, image, actualTime, status, _ in
      let data: Data?
      if status == .succeeded, let image,
          !keyframeTrack || abs(CMTimeGetSeconds(CMTimeSubtract(actualTime, time))) <= tolerance {
        data = UIImage(cgImage: image).jpegData(compressionQuality: 0.78)
      } else {
        data = nil
      }
      DispatchQueue.main.async { self?.finish(id, data: data) }
    }
  }

  private func readStream(_ source: Source, id: Int, time: CMTime, hls: Bool) {
    let frames: VideoSeekStreamFrames
    if let stream {
      frames = stream.frames
    } else {
      let asset = hls ? source.asset() : progressiveAsset(for: source)
      #if DEBUG
      if !hls {
        NSLog("[BreezePreview] progressive index_loaded=%d",
          asset.statusOfValue(forKey: "tracks", error: nil) == .loaded ? 1 : 0)
      }
      #endif
      frames = VideoSeekStreamFrames(asset: asset, hls: hls)
    }
    stream = (source, frames)
    active?.stop = { frames.stop() }
    frames.read(at: time) { [weak self] pixelBuffer in
      guard let self, let pixelBuffer else { self?.finish(id, data: nil); return }
      self.encodeQueue.async { [weak self] in
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let limit = source.thumbnailSize
        let scale = min(1, limit.width / image.extent.width, limit.height / image.extent.height)
        let preview = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let frame = Self.imageContext.createCGImage(preview, from: preview.extent)
        let jpeg = frame.flatMap { UIImage(cgImage: $0).jpegData(compressionQuality: 0.78) }
        DispatchQueue.main.async { self?.finish(id, data: jpeg) }
      }
    }
  }

  private func progressiveAsset(for source: Source) -> AVURLAsset {
    if let prepared, prepared.source == source,
        prepared.asset.statusOfValue(forKey: "tracks", error: nil) != .failed {
      // The gesture now owns the pending index load, but the asset survives
      // the idle decoder release for this same playback owner.
      prepared.timeout?.cancel()
      self.prepared?.timeout = nil
      return prepared.asset
    }
    releasePrepared()
    let asset = source.asset()
    prepared = (source, asset, nil)
    return asset
  }

  private static let imageContext = CIContext(options: [.cacheIntermediates: false])

  private func finish(_ id: Int, data: Data?, outcome: String = "completed") {
    guard let request = active, request.id == id else { return }
    active = nil
    request.deadline.cancel()
    request.stop?()
    #if DEBUG
    let elapsed = Int((CACurrentMediaTime() - request.started) * 1000)
    NSLog("[BreezePreview] %@ %@ frame=%d elapsed_ms=%d stage=%@", request.reader, outcome,
      data == nil ? 0 : 1, elapsed, stream?.frames.readStage ?? "image")
    #endif
    request.result(data.map { FlutterStandardTypedData(bytes: $0) })
    if stream != nil || file != nil {
      idle?.cancel()
      let work = DispatchWorkItem { [weak self] in self?.releaseReaders() }
      idle = work
      DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: work)
    }
  }

  private func close(_ owner: Int) {
    if let request = active, request.owner == owner { finish(request.id, data: nil) }
    if stream?.source.owner == owner || file?.source.owner == owner { releaseReaders() }
    if prepared?.source.owner == owner { releasePrepared() }
  }

  private func releasePrepared() {
    prepared?.timeout?.cancel()
    prepared?.asset.cancelLoading()
    prepared = nil
  }

  private func releaseStream() {
    if let stream {
      stream.frames.close(cancelAssetLoading: prepared?.source != stream.source)
    }
    stream = nil
  }

  private func releaseFile() {
    file?.asset.cancelLoading()
    file = nil
  }

  private func releaseReaders() {
    idle?.cancel()
    idle = nil
    releaseStream()
    releaseFile()
  }

  @objc private func closeAll() {
    if let request = active { finish(request.id, data: nil) }
    releaseReaders()
    releasePrepared()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
    closeAll()
  }
}

/// Keep a muted decoder and its buffered data between nearby online requests.
/// This also handles regular HLS without an advertised I-frame rendition.
private final class VideoSeekStreamFrames {
  private let asset: AVURLAsset
  private let item: AVPlayerItem
  private let player: AVPlayer
  private let hls: Bool
  private let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
  ])
  private var poll: Timer?
  private var seekID: UUID?
  private(set) var readStage = "ready"
  var hasFailed: Bool { item.status == .failed }

  init(asset: AVURLAsset, hls: Bool) {
    self.asset = asset
    self.hls = hls
    item = AVPlayerItem(asset: asset)
    if hls {
      item.preferredPeakBitRate = 800_000
      item.preferredMaximumResolution = CGSize(width: 640, height: 360)
    }
    item.preferredForwardBufferDuration = 0.5
    item.canUseNetworkResourcesForLiveStreamingWhilePaused = false
    item.add(output)
    player = AVPlayer(playerItem: item)
    player.isMuted = true
    player.volume = 0
    player.allowsExternalPlayback = false
    player.preventsDisplaySleepDuringVideoPlayback = false
  }

  func read(at target: CMTime, completion: @escaping (CVPixelBuffer?) -> Void) {
    stop()
    let token = UUID()
    seekID = token
    var seekStarted = false
    var seekCompleted = false
    var waitUntilReady = !hls || asset.url.isFileURL
    readStage = "ready"
    let timer = Timer(timeInterval: 0.033, repeats: true) { [weak self] _ in
      guard let self, self.seekID == token else { return }
      if self.item.status == .failed {
        self.readStage = "item_failed"
        self.stop()
        completion(nil)
        return
      }
      if !seekStarted {
        let ready = self.item.status == .readyToPlay
        guard ready || !waitUntilReady else { return }
        seekStarted = true
        self.readStage = "seek"
        // A thumbnail can use a nearby frame within the display tolerance.
        let tolerance = CMTime(seconds: 0.35, preferredTimescale: 600)
        self.player.seek(to: target, toleranceBefore: tolerance, toleranceAfter: tolerance) { [weak self] ok in
          DispatchQueue.main.async {
            guard let self, self.seekID == token else { return }
            if !ok {
              if !ready {
                waitUntilReady = true
                seekStarted = false
                self.readStage = "ready"
                return
              }
              self.stop()
              self.readStage = "seek_failed"
              completion(nil)
              return
            }
            seekCompleted = true
            self.readStage = "pixel"
            self.player.playImmediately(atRate: 1)
          }
        }
      }
      guard seekCompleted else { return }
      let time = self.player.currentTime()
      var displayTime = CMTime.invalid
      let chosenTime = abs(CMTimeGetSeconds(CMTimeSubtract(time, target))) <= 0.8
        ? time : target
      guard let buffer = self.output.copyPixelBuffer(
        forItemTime: chosenTime, itemTimeForDisplay: &displayTime),
        abs(CMTimeGetSeconds(CMTimeSubtract(displayTime, target))) <= 0.8 else { return }
      self.stop()
      completion(buffer)
    }
    poll = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  func stop() {
    poll?.invalidate()
    poll = nil
    seekID = nil
    item.cancelPendingSeeks()
    player.pause()
  }

  func close(cancelAssetLoading: Bool) {
    stop()
    player.replaceCurrentItem(with: nil)
    if cancelAssetLoading { asset.cancelLoading() }
  }
}
