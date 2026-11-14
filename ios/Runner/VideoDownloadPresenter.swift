import AVFoundation
import Flutter
import UIKit

/// Owns independent MP4 jobs. A worker keeps all transport, stage, response
/// validation and cleanup state private; channel dispatch is installed once.
final class VideoDownloadPresenter: NSObject {
  private let channel: FlutterMethodChannel
  private let exports: VideoDownloadTransfer
  private var jobs: [String: VideoDownloadTransfer] = [:]
  private static let cleanupInterruptedExports: Void = {
    let cutoff = Date()
    DispatchQueue.global(qos: .utility).async {
      let manager = FileManager.default
      removeInterruptedExports(in: manager.temporaryDirectory, before: cutoff) { name in
        let prefix = "breeze-video-"
        return name.hasPrefix(prefix) && UUID(uuidString: String(name.dropFirst(prefix.count))) != nil
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
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result("unavailable"); return }
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "start":
        // Legacy Files presentation remains a single UI transaction.
        guard args["managedId"] != nil else { self.exports.handle(call, result: result); return }
        guard let id = args["id"] as? String, !id.isEmpty, id.count <= 80 else {
          result(["status": "failed", "reason": "invalidRequest"]); return
        }
        guard self.jobs[id] == nil, self.jobs.count < 3 else { result("busy"); return }
        let worker = VideoDownloadTransfer(channel: channel)
        self.jobs[id] = worker
        worker.handle(call) { [weak self, weak worker] value in
          if let self, let worker, self.jobs[id] === worker { self.jobs.removeValue(forKey: id) }
          result(value)
        }
      case "cancel":
        if let id = args["id"] as? String, let worker = self.jobs[id] {
          worker.handle(call, result: result)
        } else {
          self.exports.handle(call, result: result)
        }
      default:
        self.exports.handle(call, result: result)
      }
    }
  }

  deinit { channel.setMethodCallHandler(nil) }
}

/// One media transfer, staged for the app or presented in the system Files picker.
/// No signed URLs, cookies, headers or URLSession errors are logged or persisted.
private final class VideoDownloadTransfer: NSObject, URLSessionDownloadDelegate, UIDocumentPickerDelegate {
  private let channel: FlutterMethodChannel
  private var session: URLSession?
  private var task: URLSessionDownloadTask?
  private var networkLease: OmoNetworkLease?
  private var completion: FlutterResult?
  private var job: String?
  private var managedID: String?
  private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
  private var fileName = "Video.mp4"
  private var temporaryDirectory: URL?
  private weak var picker: UIDocumentPickerViewController?
  private var received: Int64 = 0
  private var expected: Int64 = 0
  private var checkedCapacity = false
  private var wifiOnly = false
  private var lastProgress = Date.distantPast
  private var redirectCount = 0

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "start": self.start(args, result: result)
      case "export": self.exportManaged(args, result: result)
      case "exportArchive": self.exportArchive(args, result: result)
      case "poster": self.localPoster(args, result: result)
      case "cancel":
        if let id = args["id"] as? String, id == self.job { self.finish("cancelled") }
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

  private func start(_ args: [String: Any], result: @escaping FlutterResult) {
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
    guard requestedID != nil || presenter() != nil else { result("unavailable"); return }
    managedID = requestedID
    let title = String((args["title"] as? String ?? "Video").prefix(100))
    let quality = String((args["quality"] as? String ?? "").prefix(20))
    fileName = VideoExportFilename.make("\(title) \(quality)", fallback: "Video", suffix: ".mp4")
    job = id
    completion = result
    received = 0
    expected = 0
    checkedCapacity = false
    wifiOnly = args["wifiOnly"] as? Bool == true
    redirectCount = 0
    lastProgress = .distantPast
    var request = URLRequest(url: url)
    request.allowsCellularAccess = !wifiOnly
    request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")
    for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
    if let lease {
      // A routed export borrows the source's existing pool and immutable route.
      // It must never invalidate that pool when the export finishes.
      guard let (transport, download) = lease.downloadTask(with: request, delegate: self) else { finish(failure(.routeUnavailable)); return }
      networkLease = lease
      session = transport
      task = download
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
      task = transport.downloadTask(with: request)
    }
    if requestedID != nil, let task { requestBackgroundTime(for: task) }
    progress(saving: false, force: true)
    task?.resume()
  }

  // Keep the existing redirect-checked transport running briefly when an
  // in-flight managed download enters the background.
  private func requestBackgroundTime(for download: URLSessionDownloadTask) {
    let application = UIApplication.shared
    guard application.applicationState != .background else { return }
    let identifier = application.beginBackgroundTask(withName: "Breeze MP4 download") { [weak self, weak download] in
      guard let self, let download, self.task === download else { return }
      if UIApplication.shared.applicationState == .background {
        self.finish(self.failure(.timeout))
      } else {
        self.endBackgroundTime()
      }
    }
    if task === download {
      backgroundTask = identifier
    } else if identifier != .invalid {
      application.endBackgroundTask(identifier)
    }
  }

  private func endBackgroundTime() {
    let identifier = backgroundTask
    guard identifier != .invalid else { return }
    backgroundTask = .invalid
    UIApplication.shared.endBackgroundTask(identifier)
  }

  private func validID(_ value: String) -> Bool {
    value.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil
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
      if self.session === session { finish(failure(.redirectRejected, response: response)) }
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
    completionHandler(safe)
  }

  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                  didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                  totalBytesExpectedToWrite: Int64) {
    guard self.session === session, self.task === downloadTask, job != nil else { return }
    if let rejected = mediaResponseFailure(downloadTask.response) { finish(rejected); return }
    if !checkedCapacity && totalBytesExpectedToWrite > 0 {
      checkedCapacity = true
      let remaining = totalBytesExpectedToWrite - totalBytesWritten
      if remaining > 0,
         let attributes = try? FileManager.default.attributesOfFileSystem(forPath: FileManager.default.temporaryDirectory.path),
         let free = attributes[.systemFreeSize] as? NSNumber,
         remaining > free.int64Value {
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
    do {
      if let rejected = mediaResponseFailure(downloadTask.response) { finish(rejected); return }
      let attributes = try FileManager.default.attributesOfItem(atPath: location.path)
      let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
      guard size > 12 else { finish(failure(.incomplete, response: downloadTask.response)); return }
      let handle = try FileHandle(forReadingFrom: location)
      defer { try? handle.close() }
      let header = try handle.read(upToCount: 12) ?? Data()
      // MP4/ISO-BMFF files have an initial file-type box. A 200 HTML login,
      // challenge or CDN error page must never reach Files as a video.
      guard header.count == 12, String(data: header[4..<8], encoding: .ascii) == "ftyp" else {
        finish(failure(.mediaRejected, response: downloadTask.response)); return
      }
      guard expected <= 0 || size == expected else {
        finish(failure(.incomplete, response: downloadTask.response)); return
      }
      if let id = managedID {
        let cache = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask,
          appropriateFor: nil, create: true)
        let root = cache.appendingPathComponent("breeze-video-staging", isDirectory: true)
        guard root.resolvingSymlinksInPath().path == cache.resolvingSymlinksInPath().appendingPathComponent("breeze-video-staging", isDirectory: true).path else {
          finish(failure(.storage, response: downloadTask.response)); return
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
      finish(errorFailure(error, fallback: .storage, response: downloadTask.response))
    }
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard self.session === session, self.task === task, job != nil, error != nil else { return }
    guard let error else { return }
    let native = error as NSError
    if native.domain == NSURLErrorDomain && native.code == NSURLErrorCancelled {
      finish("cancelled")
    } else if let response = task.response as? HTTPURLResponse,
              !(200...299).contains(response.statusCode),
              let rejected = mediaResponseFailure(response) {
      finish(rejected)
    } else {
      finish(errorFailure(error, fallback: .network, response: task.response))
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

  private func finish(_ status: Any) {
    guard job != nil else { return }
    defer { endBackgroundTime() }
    job = nil
    managedID = nil
    let callback = completion
    completion = nil
    let documentPicker = picker
    picker = nil
    let transport = session
    session = nil
    task?.cancel()
    if let task { networkLease?.removeDownload(task) }
    task = nil
    if networkLease == nil { transport?.invalidateAndCancel() }
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
    task?.cancel()
    if let task { networkLease?.removeDownload(task) }
    if networkLease == nil { session?.invalidateAndCancel() }
    networkLease = nil
    if let folder = temporaryDirectory { try? FileManager.default.removeItem(at: folder) }
    endBackgroundTime()
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
