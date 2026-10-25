import Flutter
import UIKit

/// One explicit foreground media transfer, followed by the system Files export.
/// No signed URLs, cookies, headers or URLSession errors are logged or persisted.
final class VideoDownloadPresenter: NSObject, URLSessionDownloadDelegate, UIDocumentPickerDelegate {
  private let channel: FlutterMethodChannel
  private var session: URLSession?
  private var task: URLSessionDownloadTask?
  private var completion: FlutterResult?
  private var job: String?
  private var fileName = "Video.mp4"
  private var temporaryDirectory: URL?
  private weak var picker: UIDocumentPickerViewController?
  private var received: Int64 = 0
  private var expected: Int64 = 0
  private var lastProgress = Date.distantPast
  private var redirectCount = 0

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "breeze.video.download", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result("unavailable"); return }
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "start": self.start(args, result: result)
      case "cancel":
        if let id = args["id"] as? String, id == self.job { self.finish("cancelled") }
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private func validHTTPS(_ url: URL) -> Bool {
    url.scheme == "https" && url.host?.isEmpty == false && url.user == nil &&
      url.password == nil && (url.port == nil || url.port == 443) && url.fragment == nil
  }

  private func start(_ args: [String: Any], result: @escaping FlutterResult) {
    guard job == nil else { result("busy"); return }
    guard let id = args["id"] as? String, !id.isEmpty, id.count <= 80,
          let raw = args["url"] as? String, raw.count <= 8192,
          let url = URL(string: raw), validHTTPS(url), url.pathExtension.lowercased() == "mp4",
          let refererRaw = args["referer"] as? String,
          let referer = URL(string: refererRaw), validHTTPS(referer), referer.path == "/watch",
          let parts = URLComponents(url: referer, resolvingAgainstBaseURL: false),
          let query = parts.queryItems, query.count == 1, query[0].name == "v",
          let videoID = query[0].value,
          videoID.range(of: "^[0-9]+$", options: .regularExpression) != nil else {
      result("failed"); return
    }
    guard presenter() != nil else { result("unavailable"); return }
    let title = String((args["title"] as? String ?? "Video").prefix(100))
    let quality = String((args["quality"] as? String ?? "").prefix(20))
    let unsafe = CharacterSet.controlCharacters.union(CharacterSet(charactersIn: "/\\:?%*|\"<>"))
    let name = "\(title) \(quality)".components(separatedBy: unsafe).joined(separator: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    fileName = "\(name.isEmpty ? "Video" : name).mp4"
    job = id
    completion = result
    received = 0
    expected = 0
    redirectCount = 0
    lastProgress = .distantPast
    let config = URLSessionConfiguration.ephemeral
    config.httpCookieStorage = nil
    config.httpShouldSetCookies = false
    config.urlCredentialStorage = nil
    config.urlCache = nil
    config.requestCachePolicy = .reloadIgnoringLocalCacheData
    config.timeoutIntervalForRequest = 45
    config.timeoutIntervalForResource = 3600
    let transport = URLSession(configuration: config, delegate: self, delegateQueue: .main)
    session = transport
    var request = URLRequest(url: url)
    request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")
    task = transport.downloadTask(with: request)
    progress(saving: false, force: true)
    task?.resume()
  }

  private func validMediaResponse(_ response: URLResponse?) -> Bool {
    guard let http = response as? HTTPURLResponse,
          (200...299).contains(http.statusCode), let url = http.url, validHTTPS(url) else { return false }
    let mime = http.mimeType?.lowercased() ?? ""
    return mime.isEmpty || ["video/mp4", "application/mp4", "application/octet-stream", "binary/octet-stream"].contains(mime)
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
      if self.session === session { finish("failed") }
      return
    }
    redirectCount += 1
    var safe = request
    // Redirects must never acquire cookie/auth headers. Do not leak watch
    // identifiers to a different CDN host beyond the first issued request.
    safe.setValue(nil, forHTTPHeaderField: "Cookie")
    safe.setValue(nil, forHTTPHeaderField: "Authorization")
    if request.url?.host != task.originalRequest?.url?.host {
      safe.setValue(nil, forHTTPHeaderField: "Referer")
    }
    completionHandler(safe)
  }

  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                  didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                  totalBytesExpectedToWrite: Int64) {
    guard self.session === session, self.task === downloadTask, job != nil else { return }
    guard validMediaResponse(downloadTask.response) else { finish("failed"); return }
    received = totalBytesWritten
    expected = totalBytesExpectedToWrite
    progress(saving: false)
  }

  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                  didFinishDownloadingTo location: URL) {
    guard self.session === session, self.task === downloadTask, job != nil else { return }
    do {
      guard validMediaResponse(downloadTask.response) else { finish("failed"); return }
      let attributes = try FileManager.default.attributesOfItem(atPath: location.path)
      let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
      guard size > 12 else { finish("failed"); return }
      let handle = try FileHandle(forReadingFrom: location)
      defer { try? handle.close() }
      let header = try handle.read(upToCount: 12) ?? Data()
      // MP4/ISO-BMFF files have an initial file-type box. A 200 HTML login,
      // challenge or CDN error page must never reach Files as a video.
      guard header.count == 12, String(data: header[4..<8], encoding: .ascii) == "ftyp" else {
        finish("failed"); return
      }
      guard expected <= 0 || size == expected else { finish("failed"); return }
      let folder = FileManager.default.temporaryDirectory.appendingPathComponent("breeze-video-\(UUID().uuidString)", isDirectory: true)
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false,
        attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
      temporaryDirectory = folder
      let file = folder.appendingPathComponent(fileName)
      try FileManager.default.moveItem(at: location, to: file)
      guard let view = presenter() else { finish("failed"); return }
      received = size
      expected = size
      progress(saving: true, force: true)
      let sheet = UIDocumentPickerViewController(forExporting: [file], asCopy: true)
      sheet.delegate = self
      sheet.shouldShowFileExtensions = true
      picker = sheet
      view.present(sheet, animated: !UIAccessibility.isReduceMotionEnabled)
    } catch {
      finish("failed")
    }
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard self.session === session, self.task === task, job != nil, error != nil else { return }
    finish((error as NSError?)?.code == NSURLErrorCancelled ? "cancelled" : "failed")
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

  private func finish(_ status: String) {
    guard job != nil else { return }
    job = nil
    let callback = completion
    completion = nil
    let documentPicker = picker
    picker = nil
    let transport = session
    session = nil
    task?.cancel()
    task = nil
    transport?.invalidateAndCancel()
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
    session?.invalidateAndCancel()
    if let folder = temporaryDirectory { try? FileManager.default.removeItem(at: folder) }
    channel.setMethodCallHandler(nil)
  }
}
