import Flutter
import Foundation
import Network
import WebKit

/// Each source owns an immutable route, WebKit store and connection pool.
/// Concurrent visits to that source lease it; other sources never share it.
final class OmoNetwork: NSObject {
  static let shared = OmoNetwork()
  static let source = "ccc2fe17-c0a8-4fd8-a596-835772686404"
  private var channel: FlutterMethodChannel?
  private var sources: [UUID: OmoNetworkVisit] = [:]
  private var visits: [String: OmoNetworkVisit] = [:]

  func register(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "breeze.video.network", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result) }
    self.channel = channel
  }

  func store(_ token: String?) -> WKWebsiteDataStore? {
    guard let token else { return nil }
    return visits[token]?.store
  }

  func lease(_ token: String) -> OmoNetworkLease? {
    guard let visit = visits[token] else { return nil }
    visit.owners += 1
    return OmoNetworkLease(visit: visit) { [weak self] in self?.release(token) }
  }

  private func release(_ token: String) {
    guard let visit = visits[token] else { return }
    visit.owners -= 1
    if visit.owners == 0 {
      visits.removeValue(forKey: token)
      sources.removeValue(forKey: visit.source)
      visit.close()
    }
  }

  func observeUserAgent(_ value: String, store: WKWebsiteDataStore) {
    guard value.count <= 2048, !value.contains("\r"), !value.contains("\n"),
          let visit = visits.values.first(where: { $0.store === store }) else { return }
    visit.userAgent = value
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    if call.method == "supported" { result(ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 17); return }
    if call.method == "open" {
      guard #available(iOS 17.0, *) else {
        result(FlutterError(code: "unsupported", message: "Network routing requires iOS 17", details: nil)); return
      }
      do {
        // Validate even when leasing an existing route. New preferences take
        // effect only after all users of this source release the current visit.
        let options = try OmoNetworkOptions(args)
        if let visit = sources[options.source] {
          visit.clients += 1; visit.owners += 1; visit.whenReady { result(visit.token) }; return
        }
        let visit = OmoNetworkVisit(options)
        sources[options.source] = visit
        visits[visit.token] = visit
        visit.migrateCookies { visit.didBecomeReady(); result(visit.token) }
      } catch { result(FlutterError(code: "configuration", message: "Invalid source network configuration", details: nil)) }
      return
    }
    guard let token = args["context"] as? String, let visit = visits[token] else {
      result(FlutterError(code: "closed", message: "Network session closed", details: nil)); return
    }
    switch call.method {
    case "close":
      if visit.clients > 0 { visit.clients -= 1; release(token) }
      result(nil)
    case "start": visit.start(args, result)
    case "read": visit.read(args["request"] as? String ?? "", result)
    case "cancel": visit.cancel(args["request"] as? String ?? ""); result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }
}

/// Native browser/download owners keep a source alive even after Dart releases
/// its own handle. All calls and URLSession delegates run on the main queue.
final class OmoNetworkLease {
  private let visit: OmoNetworkVisit
  private var release: (() -> Void)?
  fileprivate init(visit: OmoNetworkVisit, release: @escaping () -> Void) {
    self.visit = visit; self.release = release
  }
  var store: WKWebsiteDataStore { visit.store }
  var sourceIdentifier: String { visit.source.uuidString.lowercased() }
  @available(iOS 17.0, *)
  func assetDownloadConfiguration(identifier: String) -> URLSessionConfiguration? {
    visit.assetDownloadConfiguration(identifier: identifier)
  }
  func isFirstParty(_ url: URL) -> Bool { visit.firstParty(url) }
  func downloadTask(with request: URLRequest, delegate: URLSessionDownloadDelegate) -> (URLSession, URLSessionDownloadTask)? {
    visit.downloadTask(with: request, delegate: delegate)
  }
  func removeDownload(_ task: URLSessionDownloadTask) { visit.removeDownload(task) }
  deinit {
    let callback = release
    if Thread.isMainThread { callback?() } else { DispatchQueue.main.async { callback?() } }
  }
}

private struct OmoNetworkOptions {
  let source: UUID
  let origins: Set<String>
  let proxy: URL?

  static func origin(_ url: URL) -> String? {
    guard OmoNetworkTransfer.publicURL(url), url.port == nil || url.port == 443,
          let host = url.host?.lowercased() else { return nil }
    return "https://" + host
  }

  init(_ args: [String: Any]) throws {
    guard let raw = args["source"] as? String, let source = UUID(uuidString: raw),
          let entries = args["siteOrigins"] as? [String], !entries.isEmpty, entries.count <= 32,
          let address = args["proxy"] as? String, address.count <= 2048 else { throw URLError(.badURL) }
    var origins = Set<String>()
    for entry in entries {
      guard entry.count <= 2048, let url = URL(string: entry), let origin = Self.origin(url),
            url.path.isEmpty || url.path == "/", url.query == nil, url.fragment == nil else { throw URLError(.badURL) }
      origins.insert(origin)
    }
    self.source = source
    self.origins = origins
    if address.isEmpty { proxy = nil; return }
    guard let url = URL(string: address), let host = url.host, !host.isEmpty,
          let port = url.port, (1...65535).contains(port), url.user == nil, url.password == nil,
          ["http", "socks5"].contains(url.scheme ?? ""), url.path.isEmpty || url.path == "/",
          url.query == nil, url.fragment == nil else { throw URLError(.badURL) }
    proxy = url
  }
}

private final class OmoNetworkVisit {
  let token = UUID().uuidString
  let source: UUID
  private let siteOrigins: Set<String>
  var owners = 1
  var clients = 1
  let store: WKWebsiteDataStore
  var userAgent: String?
  private let configuration: URLSessionConfiguration
  private var transfers: [String: OmoNetworkTransfer] = [:]
  private var taskTransfers: [Int: OmoNetworkTransfer] = [:]
  private var downloads: [Int: OmoNetworkDownloadObserver] = [:]
  private let sessionDelegate = OmoNetworkSessionDelegate()
  private var session: URLSession?
  private var closed = false
  private var ready = false
  private var readiness: [() -> Void] = []
  func whenReady(_ callback: @escaping () -> Void) { if ready { callback() } else { readiness.append(callback) } }
  func didBecomeReady() { ready = true; let callbacks = readiness; readiness.removeAll(); for callback in callbacks { callback() } }

  @available(iOS 17.0, *)
  init(_ options: OmoNetworkOptions) {
    source = options.source
    siteOrigins = options.origins
    configuration = .ephemeral
    configuration.urlCache = nil
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    configuration.httpShouldSetCookies = false
    configuration.httpCookieStorage = nil
    configuration.urlCredentialStorage = nil
    configuration.timeoutIntervalForRequest = 30
    configuration.timeoutIntervalForResource = 1800
    configuration.httpMaximumConnectionsPerHost = 6
    // The source UUID preserves the original Omo store identifier.
    store = WKWebsiteDataStore(forIdentifier: options.source)
    var proxies: [ProxyConfiguration] = []
    if let url = options.proxy, let host = url.host, let port = url.port {
      let endpoint = NWEndpoint.hostPort(host: .init(host), port: .init(rawValue: UInt16(port))!)
      var proxy = url.scheme == "socks5" ? ProxyConfiguration(socksv5Proxy: endpoint) :
        ProxyConfiguration(httpCONNECTProxy: endpoint, tlsOptions: nil)
      proxy.allowFailover = false
      proxies = [proxy]
    }
    // [] means the OS network path. It does not bypass a VPN/TUN.
    configuration.proxyConfigurations = proxies
    store.proxyConfigurations = proxies
    // One immutable route and connection pool for the whole visit. The session
    // retains its delegate, so the delegate must only weakly reference us.
    sessionDelegate.visit = self
    session = URLSession(configuration: configuration, delegate: sessionDelegate, delegateQueue: .main)
  }

  fileprivate func firstParty(_ url: URL) -> Bool {
    guard let origin = OmoNetworkOptions.origin(url) else { return false }
    return siteOrigins.contains(origin)
  }

  func migrateCookies(_ completion: @escaping () -> Void) {
    let key = source.uuidString.lowercased() == OmoNetwork.source
      ? "breeze.omo.network.cookies.migrated.v1"
      : "breeze.source.network.cookies.migrated.v1." + source.uuidString.lowercased()
    guard !UserDefaults.standard.bool(forKey: key) else { completion(); return }
    WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
      guard let self else { return }
      self.store.httpCookieStore.getAllCookies { existing in
        let group = DispatchGroup()
        let hosts = self.siteOrigins.compactMap { URL(string: $0)?.host }
        for cookie in cookies {
          let domain = cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
          guard hosts.contains(where: { $0 == domain || $0.hasSuffix("." + domain) }),
                (cookie.expiresDate ?? .distantFuture) > Date(),
                !existing.contains(where: { $0.name == cookie.name && $0.domain == cookie.domain && $0.path == cookie.path }) else { continue }
          // Preserve both the default store and any newer source-store login.
          group.enter(); self.store.httpCookieStore.setCookie(cookie) { group.leave() }
        }
        group.notify(queue: .main) { UserDefaults.standard.set(true, forKey: key); completion() }
      }
    }
  }

  fileprivate func prepare(_ request: URLRequest, siteCookies: Bool = true, completion: @escaping (URLRequest) -> Void) {
    var safe = request
    safe.setValue(nil, forHTTPHeaderField: "Cookie")
    guard siteCookies, let url = request.url, firstParty(url) else { completion(safe); return }
    store.httpCookieStore.getAllCookies { [weak self] cookies in
      guard let self, !self.closed else { completion(safe); return }
      let scoped = cookies.filter { cookie in
        let domain = cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        let path = url.path.isEmpty ? "/" : url.path
        let cookiePath = cookie.path.isEmpty ? "/" : cookie.path
        let pathMatches = path == cookiePath || (path.hasPrefix(cookiePath) &&
          (cookiePath.hasSuffix("/") || path.dropFirst(cookiePath.count).first == "/"))
        return (url.host?.lowercased() == domain || url.host?.lowercased().hasSuffix("." + domain) == true) &&
          pathMatches && (!cookie.isSecure || url.scheme == "https") && (cookie.expiresDate ?? .distantFuture) > Date()
      }
      for (key, value) in HTTPCookie.requestHeaderFields(with: scoped) { safe.setValue(value, forHTTPHeaderField: key) }
      completion(safe)
    }
  }

  func start(_ args: [String: Any], _ result: @escaping FlutterResult) {
    guard !closed, transfers.count < 32, let id = args["request"] as? String, id.count <= 80,
          transfers[id] == nil, let raw = args["url"] as? String, raw.count <= 8192,
          let url = URL(string: raw), OmoNetworkTransfer.publicURL(url),
          ["GET", "HEAD"].contains(args["method"] as? String ?? "GET") else {
      result(FlutterError(code: "request", message: "Invalid network request", details: nil)); return
    }
    var request = URLRequest(url: url)
    request.httpMethod = args["method"] as? String ?? "GET"
    request.timeoutInterval = min(30, max(1, args["timeout"] as? Double ?? 20))
    let allowed = ["accept", "range", "referer", "origin", "user-agent", "if-range"]
    for (name, value) in args["headers"] as? [String: String] ?? [:] where allowed.contains(name.lowercased()) && value.count < 8192 && !value.contains("\r") && !value.contains("\n") {
      request.setValue(value, forHTTPHeaderField: name)
    }
    if request.value(forHTTPHeaderField: "User-Agent") == nil, let userAgent { request.setValue(userAgent, forHTTPHeaderField: "User-Agent") }
    let siteCookies = args["siteCookies"] as? Bool ?? true
    let transfer = OmoNetworkTransfer(visit: self, siteCookies: siteCookies, result: result)
    transfers[id] = transfer
    // Only declared first-party origins receive this source's cookies.
    // CDN/parser requests use the same route without site credentials.
    prepare(request, siteCookies: siteCookies) { [weak self, weak transfer] authenticated in
      guard let self, !self.closed, let transfer, self.transfers[id] === transfer else { return }
      transfer.start(authenticated)
    }
  }

  func read(_ id: String, _ result: @escaping FlutterResult) {
    guard let transfer = transfers[id] else { result(FlutterError(code: "closed", message: "Request closed", details: nil)); return }
    transfer.read(result)
  }
  func cancel(_ id: String) { transfers.removeValue(forKey: id)?.cancel() }
  fileprivate func task(_ request: URLRequest, transfer: OmoNetworkTransfer) -> URLSessionDataTask? {
    guard !closed, let session else { return nil }
    let task = session.dataTask(with: request)
    taskTransfers[task.taskIdentifier] = transfer
    return task
  }
  fileprivate func transfer(_ task: URLSessionTask) -> OmoNetworkTransfer? {
    taskTransfers[task.taskIdentifier]
  }
  fileprivate func removeTask(_ task: URLSessionTask) {
    taskTransfers.removeValue(forKey: task.taskIdentifier)
  }
  fileprivate func complete(_ task: URLSessionTask, error: Error?) {
    // The request-id map retains completed transfers until Dart consumes their
    // remaining bytes and cancels them; only delegate routing ends here.
    taskTransfers.removeValue(forKey: task.taskIdentifier)?.complete(error)
  }
  fileprivate func downloadTask(with request: URLRequest, delegate: URLSessionDownloadDelegate) -> (URLSession, URLSessionDownloadTask)? {
    guard !closed, let session, let url = request.url, OmoNetworkTransfer.publicURL(url),
          request.httpMethod == nil || request.httpMethod == "GET" else { return nil }
    // Export media never receives website cookies, even on a first-party host.
    var safe = request
    safe.setValue(nil, forHTTPHeaderField: "Cookie")
    safe.setValue(nil, forHTTPHeaderField: "Authorization")
    if safe.value(forHTTPHeaderField: "User-Agent") == nil, let userAgent { safe.setValue(userAgent, forHTTPHeaderField: "User-Agent") }
    let task = session.downloadTask(with: safe)
    downloads[task.taskIdentifier] = OmoNetworkDownloadObserver(delegate)
    return (session, task)
  }
  @available(iOS 17.0, *)
  fileprivate func assetDownloadConfiguration(identifier: String) -> URLSessionConfiguration? {
    guard !closed else { return nil }
    let copy = HlsAssetDownloadPresenter.backgroundConfiguration(identifier)
    // Preserve this visit's explicit route and failover policy for AVFoundation.
    copy.proxyConfigurations = configuration.proxyConfigurations
    if let userAgent { copy.httpAdditionalHeaders = ["User-Agent": userAgent] }
    return copy
  }
  fileprivate func downloadDelegate(_ task: URLSessionTask) -> URLSessionDownloadDelegate? { downloads[task.taskIdentifier]?.delegate }
  fileprivate func removeDownload(_ task: URLSessionTask) { downloads.removeValue(forKey: task.taskIdentifier) }

  func close() {
    closed = true
    for item in transfers.values { item.cancel() }
    transfers.removeAll(); taskTransfers.removeAll(); downloads.removeAll()
    sessionDelegate.visit = nil
    let closing = session; session = nil
    closing?.invalidateAndCancel()
  }
}

/// URLSession retains its delegate until invalidation. A weak owner avoids a
/// session/visit cycle, while task identifiers keep concurrent responses apart.
private final class OmoNetworkDownloadObserver {
  weak var delegate: URLSessionDownloadDelegate?
  init(_ delegate: URLSessionDownloadDelegate) { self.delegate = delegate }
}

private final class OmoNetworkSessionDelegate: NSObject, URLSessionDataDelegate, URLSessionDownloadDelegate {
  weak var visit: OmoNetworkVisit?
  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                  completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
    guard let transfer = visit?.transfer(dataTask) else { completionHandler(.cancel); return }
    transfer.receive(response, completionHandler: completionHandler)
  }
  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    visit?.transfer(dataTask)?.receive(data)
  }
  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    if let delegate = visit?.downloadDelegate(task) {
      visit?.removeDownload(task)
      delegate.urlSession?(session, task: task, didCompleteWithError: error)
    } else { visit?.complete(task, error: error) }
  }
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    visit?.downloadDelegate(downloadTask)?.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: location)
  }
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                  totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
    visit?.downloadDelegate(downloadTask)?.urlSession?(session, downloadTask: downloadTask,
      didWriteData: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
  }
  func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                  newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
    if let delegate = visit?.downloadDelegate(task) {
      delegate.urlSession?(session, task: task, willPerformHTTPRedirection: response, newRequest: request, completionHandler: completionHandler)
      return
    }
    guard let transfer = visit?.transfer(task) else { completionHandler(nil); return }
    transfer.redirect(response, request: request, completionHandler: completionHandler)
  }
}

/// Pull-based, bounded streaming. A slow AVPlayer consumer suspends upstream
/// reads; no media is buffered in full or written into a disk cache.
private final class OmoNetworkTransfer {
  private weak var visit: OmoNetworkVisit?
  private let siteCookies: Bool
  private var task: URLSessionDataTask?
  private var started: FlutterResult?
  private var pendingRead: FlutterResult?
  private var chunks: [Data] = []
  private var queuedBytes = 0
  private var suspended = false
  private var ended = false
  private var failed = false
  private var networkErrorCode: Int?
  private var idle: Timer?
  init(visit: OmoNetworkVisit, siteCookies: Bool, result: @escaping FlutterResult) {
    self.visit = visit; self.siteCookies = siteCookies; started = result
    armIdle()
  }
  static func publicURL(_ url: URL) -> Bool {
    guard url.scheme == "https", url.user == nil, url.password == nil,
          let host = url.host?.lowercased(), host.contains("."), host.count <= 253,
          !host.hasSuffix(".local"), !host.hasSuffix(".localhost"),
          !host.contains(":"), !host.allSatisfy({ $0.isNumber || $0 == "." }) else { return false }
    return true
  }
  func start(_ request: URLRequest) {
    guard !ended else { return }
    guard let task = visit?.task(request, transfer: self) else { cancel(); return }
    self.task = task; task.resume()
  }
  private func armIdle() {
    idle?.invalidate()
    idle = Timer.scheduledTimer(withTimeInterval: 40, repeats: false) { [weak self] _ in self?.cancel() }
  }
  func read(_ callback: @escaping FlutterResult) {
    armIdle()
    guard pendingRead == nil else { callback(FlutterError(code: "concurrent_read", message: "Read already pending", details: nil)); return }
    pendingRead = callback; drain()
  }
  private func drain() {
    guard let callback = pendingRead else { return }
    if !chunks.isEmpty {
      let data = chunks.removeFirst(); queuedBytes -= data.count; pendingRead = nil
      callback(FlutterStandardTypedData(bytes: data))
      if suspended && queuedBytes < 64 * 1024 && !ended { suspended = false; task?.resume() }
    } else if ended {
      pendingRead = nil
      callback(failed ? FlutterError(code: "network", message: "Connection failed (\(networkErrorCode ?? -1))", details: nil) : nil)
    }
  }
  func cancel() {
    ended = true; failed = true; chunks.removeAll(); queuedBytes = 0
    idle?.invalidate()
    if let task { visit?.removeTask(task); task.cancel() }
    task = nil
    started?(FlutterError(code: "cancelled", message: "Request cancelled", details: nil)); started = nil; drain()
  }
  func receive(_ response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
    guard let response = response as? HTTPURLResponse, let url = response.url, Self.publicURL(url) else { completionHandler(.cancel); cancel(); return }
    let allowed = ["content-type", "content-length", "content-range", "accept-ranges", "last-modified", "etag"]
    var headers: [String: String] = [:]
    for (key, value) in response.allHeaderFields { let name = String(describing: key).lowercased(); if allowed.contains(name) { headers[name] = String(describing: value) } }
    started?(["status": response.statusCode, "url": url.absoluteString, "headers": headers]); started = nil
    completionHandler(.allow)
  }
  func receive(_ data: Data) {
    guard !ended else { return }
    queuedBytes += data.count
    if queuedBytes > 4 * 1024 * 1024 { cancel(); return }
    // Small bridge messages; even a large URLSession callback stays bounded.
    var offset = 0
    while offset < data.count { let end = min(offset + 65536, data.count); chunks.append(data.subdata(in: offset..<end)); offset = end }
    // Backpressure uses a window. Suspending after every small TLS packet
    // turns the media stream into serial Dart/native round trips and starves
    // AVPlayer's startup buffer despite successful HTTP responses.
    if !suspended && queuedBytes >= 256 * 1024 { suspended = true; task?.suspend() }
    drain()
  }
  func complete(_ error: Error?) {
    task = nil
    ended = true; failed = error != nil; networkErrorCode = (error as NSError?)?.code; idle?.invalidate()
    started?(FlutterError(code: "network", message: "Connection failed (\(networkErrorCode ?? -1))", details: nil)); started = nil
    drain()
  }
  func redirect(_ response: HTTPURLResponse, request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
    guard let url = request.url, Self.publicURL(url) else { completionHandler(nil); cancel(); return }
    guard let visit else { completionHandler(nil); cancel(); return }
    visit.prepare(request, siteCookies: siteCookies) { [weak self] safe in
      guard let self, !self.ended else { completionHandler(nil); return }
      completionHandler(safe)
    }
  }
}
