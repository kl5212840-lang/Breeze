import Flutter
import UIKit
import WebKit

/// Explicit, source-scoped website authentication entries. This only offers a
/// Dart-side user decision; it never launches a browser or forwards OAuth data.
struct VideoSiteExternalAuthenticationPolicy {
  private let home: URL?
  private var entries = Set<String>()

  init(home: URL?, entries: [String]) {
    self.home = home
    update(entries)
  }

  private func canonical(_ url: URL) -> String? {
    guard let home = home, let origin = URLComponents(url: home, resolvingAgainstBaseURL: false),
          origin.scheme == "https", let host = origin.host, !host.isEmpty,
          origin.user == nil, origin.password == nil, origin.port == nil || origin.port == 443,
          let candidate = URLComponents(url: url, resolvingAgainstBaseURL: false),
          candidate.scheme == "https", candidate.host?.lowercased() == host.lowercased(),
          candidate.user == nil, candidate.password == nil, candidate.port == nil || candidate.port == 443,
          candidate.percentEncodedPath == "/auth/google", candidate.query == nil, candidate.fragment == nil else { return nil }
    var result = URLComponents()
    result.scheme = "https"
    result.host = host.lowercased()
    result.path = "/auth/google"
    return result.string
  }

  mutating func update(_ values: [String]) {
    entries = Set(values.compactMap { URL(string: $0).flatMap { canonical($0) } })
  }

  func registeredEntry(for url: URL) -> String? {
    guard let entry = canonical(url), entries.contains(entry) else { return nil }
    return entry
  }
}

/// App routing applies to top-level destinations. Existing subframes also
/// create local documents; WebKit must apply their normal origin/CSP rules.
/// This policy never evaluates those documents or changes browser security.
struct VideoSiteNavigationPolicy {
  let host: String

  private func aboutDocument(for url: URL) -> String? {
    guard url.scheme?.lowercased() == "about" else { return nil }
    // WKNavigationAction supplies an Objective-C-backed URL. Its opaque
    // about:blank URL can have an empty `path`, unlike URL(string:) in Swift.
    // Compare only the exact opaque document name, never decode or log it.
    let raw = url.absoluteString
    guard let colon = raw.firstIndex(of: ":") else { return nil }
    let document = raw[raw.index(after: colon)...].prefix { $0 != "?" && $0 != "#" }
    return document == "blank" || document == "srcdoc" ? String(document) : nil
  }

  func rejectionReason(for url: URL, main: Bool) -> String? {
    let scheme = url.scheme?.lowercased() ?? ""
    if !main {
      if scheme == "about" {
        return aboutDocument(for: url) == nil ? "about-document" : nil
      }
    }
    guard scheme == "https" else { return "scheme" }
    guard url.user == nil, url.password == nil else { return "credentials" }
    guard url.port == nil || url.port == 443 else { return "port" }
    guard !main || url.host?.lowercased() == host.lowercased() else { return "top-level-host" }
    return nil
  }

  /// Fixed categories only: no embedded document, script, URL, ID or token.
  func classification(for url: URL) -> [String: String] {
    let rawScheme = url.scheme?.lowercased() ?? ""
    let scheme = ["https", "http", "about", "data", "blob", "javascript", "file"].contains(rawScheme)
      ? rawScheme : "other"
    let targetHost = url.host?.lowercased() ?? ""
    let destination = targetHost.isEmpty ? "none" : targetHost == host.lowercased() ? "site"
      : targetHost == "challenges.cloudflare.com" || targetHost.hasSuffix(".challenges.cloudflare.com") ? "provider" : "other"
    let document = aboutDocument(for: url) ?? "other"
    let pathForm = scheme != "about" ? "not-about" : url.path.isEmpty ? "empty"
      : ["blank", "srcdoc"].contains(url.path) ? url.path : "other"
    return ["scheme": scheme, "destination": destination, "aboutDocument": document,
      "aboutPathForm": pathForm]
  }
}

/// Standard WebKit browser for video sources. No user scripts, JS bridge,
/// console wrappers, custom UA, cookie import or TLS exceptions are installed.
final class VideoSiteBrowserFactory: NSObject, FlutterPlatformViewFactory {
  private static let browsers = NSMapTable<WKWebView, VideoSiteBrowserView>(keyOptions: .weakMemory, valueOptions: .weakMemory)
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    let browser = VideoSiteBrowserView(frame: frame, id: viewId, args: args, messenger: messenger)
    Self.browsers.setObject(browser, forKey: browser.view() as? WKWebView)
    return browser
  }
  static func metadata(for web: WKWebView) -> [String: Any] {
    browsers.object(forKey: web)?.metadata() ?? ["implementation": "other-webkit"]
  }
  static func registeredBrowsers(for host: String) -> [WKWebView] {
    browsers.keyEnumerator().allObjects.compactMap { value in
      guard let web = value as? WKWebView,
            browsers.object(forKey: web)?.isForHost(host) == true else { return nil }
      return web
    }
  }
}

/// A bounded comparison using a plain UIKit WKWebView and the same WebKit
/// store. No bridge, page probes, custom UA or navigation delegate is attached.
private final class VideoVerificationPauseDelegate: NSObject, WKNavigationDelegate {
  private var completion: ((Bool) -> Void)?
  private var deadline: Timer?
  var expectedNavigation: WKNavigation?
  init(completion: @escaping (Bool) -> Void) {
    self.completion = completion
    super.init()
    deadline = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in self?.finish(false) }
  }
  private func finish(_ committed: Bool) {
    deadline?.invalidate()
    deadline = nil
    let callback = completion
    completion = nil
    callback?(committed)
  }
  func failedToStart() { finish(false) }
  func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
    if navigation != nil && navigation === expectedNavigation { finish(true) }
  }
  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    if navigation != nil && navigation === expectedNavigation { finish(false) }
  }
  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    if navigation != nil && navigation === expectedNavigation { finish(false) }
  }
  func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { finish(false) }
  deinit { deadline?.invalidate(); completion?(false) }
}

private final class VideoVerificationWindowController: UIViewController {
  private let browser: WKWebView
  private let destination: URL
  private let returnTitle: String
  private let hint: String
  private var completion: ((String) -> Void)?

  init(url: URL, title: String, returnTitle: String, hint: String,
       completion: @escaping (String) -> Void) {
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .default()
    browser = WKWebView(frame: .zero, configuration: configuration)
    destination = url
    self.returnTitle = returnTitle
    self.hint = hint
    self.completion = completion
    super.init(nibName: nil, bundle: nil)
    self.title = title
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    navigationItem.prompt = hint
    browser.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(browser)
    NSLayoutConstraint.activate([
      browser.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      browser.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      browser.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      browser.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])
    navigationItem.leftBarButtonItem = UIBarButtonItem(title: returnTitle,
      style: .done, target: self, action: #selector(retryAfterWindow))
    browser.load(URLRequest(url: destination))
  }

  @objc private func retryAfterWindow() { finish("retry") }

  private func finish(_ value: String) {
    guard let completed = completion else { return }
    completion = nil
    browser.stopLoading()
    (navigationController ?? self).dismiss(animated: !UIAccessibility.isReduceMotionEnabled) {
      completed(value)
    }
  }

  deinit {
    browser.stopLoading()
    completion?("cancelled")
  }
}

private final class VideoSiteBrowserView: NSObject, FlutterPlatformView, WKNavigationDelegate, WKUIDelegate, WKHTTPCookieStoreObserver {
  private let web: WKWebView
  private let channel: FlutterMethodChannel
  private let host: String
  private let dialogConfirm: String
  private let dialogCancel: String
  private let verificationWindowTitle: String
  private let verificationWindowReturn: String
  private let verificationWindowHint: String
  private var verificationWindow: UINavigationController?
  private var verificationPause: VideoVerificationPauseDelegate?
  private var externalAuthentication: VideoSiteExternalAuthenticationPolicy
  private var dismissSiteDialog: (() -> Void)?
  private var urlObserver: NSKeyValueObservation?
  private let created = ProcessInfo.processInfo.systemUptime
  private let initialOverride: String
  private var overrideChanged = false
  private var documentAgent: String?
  private var documentAgentChanged = false
  private var documentGeneration = 0
  private var provisionalStatus: Int?
  private var committedStatus: Int?
  private var pendingURL: URL?
  private var lastFailure: [String: Any]?
  private var requestAgents: [String: String] = [:]
  private var counters: [String: Int] = [:]
  private var events: [[String: Any]] = []
  private var navigationDecisions: [[String: Any]] = []

  init(frame: CGRect, id: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    let arguments = args as? [String: Any] ?? [:]
    let raw = arguments["home"] as? String ?? ""
    host = URL(string: raw)?.host ?? ""
    externalAuthentication = VideoSiteExternalAuthenticationPolicy(
      home: URL(string: raw), entries: arguments["externalAuthenticationEntries"] as? [String] ?? [])
    dialogConfirm = arguments["dialogConfirm"] as? String ?? "OK"
    dialogCancel = arguments["dialogCancel"] as? String ?? "Cancel"
    verificationWindowTitle = arguments["verificationWindowTitle"] as? String ?? "Site verification"
    verificationWindowReturn = arguments["verificationWindowReturn"] as? String ?? "Return and retry"
    verificationWindowHint = arguments["verificationWindowHint"] as? String ?? "Verify manually using this session."
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .default()
    configuration.allowsInlineMediaPlayback = true
    web = WKWebView(frame: frame, configuration: configuration)
    // WebKit may return "" instead of nil even before any navigation. Neither
    // means an override is configured. Never assign an invented Safari UA.
    initialOverride = web.customUserAgent ?? ""
    channel = FlutterMethodChannel(name: "breeze.video.browser.\(id)", binaryMessenger: messenger)
    super.init()
    web.navigationDelegate = self
    web.uiDelegate = self
    web.configuration.websiteDataStore.httpCookieStore.add(self)
    record("created")
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "externalAuthenticationEntries":
        self.externalAuthentication.update(args["entries"] as? [String] ?? [])
        result(nil)
      case "load":
        guard let raw = args["url"] as? String, let url = URL(string: raw),
              self.allowed(url, main: true) else {
          result(FlutterError(code: "URL_REJECTED", message: "Invalid video site URL", details: nil)); return
        }
        self.record("command-load")
        self.pendingURL = url
        self.web.load(URLRequest(url: url)); result(nil)
      case "stop": self.record("command-stop"); self.web.stopLoading(); result(nil)
      case "url": result(self.web.url?.absoluteString)
      case "canGoBack": result(self.web.canGoBack)
      case "goBack": self.web.goBack(); result(nil)
      case "verificationWindow":
        guard let raw = args["url"] as? String, let url = URL(string: raw),
              self.allowed(url, main: true) else {
          result(FlutterError(code: "URL_REJECTED", message: "Invalid video site URL", details: nil)); return
        }
        self.presentVerificationWindow(url: url, result: result)
      case "inspectable":
        guard let enabled = args["enabled"] as? Bool else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected inspection preference", details: nil)); return
        }
        if #available(iOS 16.4, *) {
          self.web.isInspectable = enabled
          self.record(enabled ? "inspection-enabled" : "inspection-disabled")
          result(enabled)
        } else {
          result(FlutterError(code: "UNAVAILABLE", message: "Requires iOS 16.4", details: nil))
        }
      case "evaluateAsync":
        guard let source = args["source"] as? String else { result(nil); return }
        // evaluateJavaScript does not resolve a returned Promise. Keep this
        // explicit async path separate from synchronous player/document reads.
        self.web.callAsyncJavaScript("return await eval(source);", arguments: ["source": source],
          in: nil, in: .page) { outcome in
          switch outcome {
          case .success(let value): result(value is NSNull ? nil : value)
          case .failure(let error):
            result(FlutterError(code: "WK_EVALUATE_ASYNC", message: "WebKit code \((error as NSError).code)", details: nil))
          }
        }
      case "evaluate":
        guard let source = args["source"] as? String else { result(nil); return }
        self.web.evaluateJavaScript(source) { value, error in
          if let error = error as NSError? {
            // WebKit error descriptions can contain URLs or page contents.
            result(FlutterError(code: "WK_EVALUATE", message: "WebKit code \(error.code)", details: nil))
          } else { result(value is NSNull ? nil : value) }
        }
      default: result(FlutterMethodNotImplemented)
      }
    }
    urlObserver = web.observe(\.url, options: [.new]) { [weak self] _, _ in self?.emit("history") }
  }

  func view() -> UIView { web }
  func isForHost(_ value: String) -> Bool { host == value }

  deinit {
    dismissSiteDialog?()
    verificationWindow?.dismiss(animated: false)
    verificationWindow = nil
    urlObserver?.invalidate()
    web.stopLoading()
    web.navigationDelegate = nil
    web.uiDelegate = nil
    web.configuration.websiteDataStore.httpCookieStore.remove(self)
    channel.setMethodCallHandler(nil)
  }

  private func record(_ event: String) {
    let current = web.customUserAgent ?? ""
    overrideChanged = overrideChanged || current != initialOverride
    if counters[event] != nil || counters.count < 64 {
      counters[event] = min((counters[event] ?? 0) + 1, 999)
    }
    if events.count >= 40 { events.removeFirst() }
    events.append(["ms": Int((ProcessInfo.processInfo.systemUptime - created) * 1000), "event": event])
  }

  func metadata() -> [String: Any] {
    let current = web.customUserAgent ?? ""
    overrideChanged = overrideChanged || current != initialOverride
    var data: [String: Any] = [
      "implementation": "system-webkit", "uaOverrideAtCreation": !initialOverride.isEmpty,
      "uaPropertyState": web.customUserAgent == nil ? "nil" : current.isEmpty ? "empty" : "nonempty",
      "uaOverrideLength": current.count, "uaOverrideChanged": overrideChanged,
      "documentUaObserved": documentAgent != nil, "documentUaChanged": documentAgentChanged,
      "requestUaObserved": !requestAgents.isEmpty,
      "documentGeneration": documentGeneration,
      "documentLocation": web.url == nil ? "unavailable" : web.url?.absoluteString == "about:blank" ? "blank" : web.url?.host == host ? "site" : "other",
      "events": counters, "timeline": events, "navigationDecisions": navigationDecisions,
    ]
    if let status = committedStatus { data["committedMainStatus"] = status }
    if let status = provisionalStatus { data["provisionalMainStatus"] = status }
    if let failure = lastFailure { data["lastFailure"] = failure }
    if #available(iOS 16.4, *) { data["inspectionEnabled"] = web.isInspectable }
    return data
  }

  func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
    // This notification is for the shared store, NOT proof that clearance was
    // issued or accepted. No cookie values (or names) are read here.
    record("shared-cookie-store-changed")
  }

  private func presentVerificationWindow(url: URL, result: @escaping FlutterResult) {
    guard verificationWindow == nil, verificationPause == nil,
          web.window != nil, dismissSiteDialog == nil else {
      result(FlutterError(code: "UNAVAILABLE", message: "Verification window unavailable", details: nil)); return
    }
    var responder: UIResponder? = web
    while responder != nil && !(responder is UIViewController) { responder = responder?.next }
    guard var controller = responder as? UIViewController else {
      result(FlutterError(code: "UNAVAILABLE", message: "Verification window unavailable", details: nil)); return
    }
    while let presented = controller.presentedViewController { controller = presented }
    guard !controller.isBeingDismissed, !controller.isBeingPresented,
          !(controller is UIAlertController) else {
      result(FlutterError(code: "BUSY", message: "Wait for the current presentation", details: nil)); return
    }
    // Commit a local empty document first, so the old challenge cannot keep
    // running JavaScript or updating the shared store behind the comparison.
    // The visible return button explicitly requests one normal site reload.
    let pause = VideoVerificationPauseDelegate { [weak self, weak controller] committed in
      guard let self = self else { result("cancelled"); return }
      self.verificationPause = nil
      self.web.navigationDelegate = nil
      guard committed, let controller = controller, self.web.window != nil else {
        self.web.navigationDelegate = self
        self.web.uiDelegate = self
        self.record("verification-window-unavailable")
        self.pendingURL = url
        self.web.load(URLRequest(url: url))
        result(FlutterError(code: "UNAVAILABLE", message: "Verification window unavailable", details: nil))
        return
      }
      self.record("verification-window-source-paused")
      let content = VideoVerificationWindowController(url: url, title: self.verificationWindowTitle,
        returnTitle: self.verificationWindowReturn, hint: self.verificationWindowHint) { [weak self] value in
          self?.verificationWindow = nil
          self?.web.navigationDelegate = self
          self?.web.uiDelegate = self
          self?.record("verification-window-closed")
          result(value)
        }
      let navigation = UINavigationController(rootViewController: content)
      navigation.modalPresentationStyle = .fullScreen
      self.verificationWindow = navigation
      self.record("verification-window-opened")
      controller.present(navigation, animated: !UIAccessibility.isReduceMotionEnabled)
    }
    verificationPause = pause
    web.navigationDelegate = nil
    web.stopLoading()
    web.navigationDelegate = pause
    web.uiDelegate = nil
    pause.expectedNavigation = web.loadHTMLString("<!doctype html><title></title>", baseURL: nil)
    if pause.expectedNavigation == nil { pause.failedToStart() }
  }

  private func allowed(_ url: URL, main: Bool) -> Bool {
    VideoSiteNavigationPolicy(host: host).rejectionReason(for: url, main: main) == nil
  }

  private func recordNavigation(_ action: WKNavigationAction, url: URL, main: Bool) {
    let policy = VideoSiteNavigationPolicy(host: host)
    var decision: [String: Any] = policy.classification(for: url)
    decision["main"] = main
    decision["targetFrameExists"] = action.targetFrame != nil
    decision["reason"] = policy.rejectionReason(for: url, main: main) ?? "allowed"
    let origin = action.sourceFrame.securityOrigin
    let sourceHost = origin.host.lowercased()
    decision["source"] = sourceHost.isEmpty ? "opaque" : sourceHost == host.lowercased() ? "site"
      : sourceHost == "challenges.cloudflare.com" || sourceHost.hasSuffix(".challenges.cloudflare.com") ? "provider" : "other"
    decision["type"] = action.navigationType == .linkActivated ? "link"
      : action.navigationType == .formSubmitted || action.navigationType == .formResubmitted ? "form"
      : action.navigationType == .backForward ? "history" : action.navigationType == .reload ? "reload" : "other"
    decision["ms"] = Int((ProcessInfo.processInfo.systemUptime - created) * 1000)
    if navigationDecisions.count >= 24 { navigationDecisions.removeFirst() }
    navigationDecisions.append(decision)
  }

  private func emit(_ method: String, extra: [String: Any] = [:]) {
    var data = extra
    if data["url"] == nil { data["url"] = web.url?.absoluteString ?? "" }
    channel.invokeMethod(method, arguments: data)
  }

  private func offerExternalAuthentication(_ url: URL) -> Bool {
    guard let entry = externalAuthentication.registeredEntry(for: url) else { return false }
    record("external-auth-offered")
    // Only the clean registered website entry crosses this bridge. Dart shows
    // an explicit continuation decision, including for programmatic navigation.
    channel.invokeMethod("externalAuth", arguments: ["url": entry])
    return true
  }

  func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
               decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    guard let url = action.request.url else { decisionHandler(.cancel); return }
    let main = action.targetFrame?.isMainFrame ?? true
    if main, externalAuthentication.registeredEntry(for: url) != nil {
      decisionHandler(.cancel)
      _ = offerExternalAuthentication(url)
      return
    }
    let permitted = allowed(url, main: main)
    recordNavigation(action, url: url, main: main)
    if permitted && main { pendingURL = url }
    let destination = url.host == host ? "site" : url.host == "challenges.cloudflare.com" ? "provider" : "other"
    record("\(main ? "main" : "frame")-\(destination)-\(permitted ? "allowed" : "blocked")")
    if let agent = action.request.value(forHTTPHeaderField: "User-Agent"), !agent.isEmpty {
      let scope = main ? "main" : "frame"
      if let previous = requestAgents[scope], previous != agent { record("\(scope)-request-ua-changed") }
      requestAgents[scope] = agent
    }
    // Report the decision without awaiting Dart: verification and navigation
    // must not depend on the responsiveness of another runtime.
    channel.invokeMethod("navigation", arguments: ["url": url.absoluteString, "main": main])
    decisionHandler(permitted ? .allow : .cancel)
  }

  func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
    dismissSiteDialog?()
    documentGeneration += 1
    provisionalStatus = nil
    record("load-start"); emit("start")
  }
  func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
    record("server-redirect")
  }
  func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
    committedStatus = provisionalStatus
    record("document-committed"); emit("commit")
  }
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    record("load-stop"); emit("stop")
    // Read the effective main-document UA, without installing scripts, replacing
    // console functions or touching cross-origin verification frames.
    let generation = documentGeneration
    webView.evaluateJavaScript("String(navigator.userAgent || '').slice(0, 300)") { [weak self] value, _ in
      guard let self = self, self.documentGeneration == generation, let agent = value as? String else { return }
      if let previous = self.documentAgent, previous != agent { self.documentAgentChanged = true }
      self.documentAgent = agent
    }
  }

  func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse,
               decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
    if let http = response.response as? HTTPURLResponse {
      let source = response.isForMainFrame ? "main" : http.url?.host == "challenges.cloudflare.com" ? "provider-frame" : "other-frame"
      record("\(source)-http-\(http.statusCode)")
    }
    if let http = response.response as? HTTPURLResponse,
       response.isForMainFrame || http.statusCode >= 400 {
      var headers: [String: String] = [:]
      for (key, value) in http.allHeaderFields {
        let name = String(describing: key).lowercased()
        if ["cf-ray", "cf-mitigated"].contains(name) { headers[name] = String(describing: value) }
      }
      if response.isForMainFrame { provisionalStatus = http.statusCode }
      channel.invokeMethod(response.isForMainFrame ? "response" : "http", arguments: [
        "url": http.url?.absoluteString ?? "", "status": http.statusCode,
        "main": response.isForMainFrame, "headers": headers,
      ])
    }
    decisionHandler(.allow)
  }

  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    reportFailure(error, stage: "provisional")
  }
  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    reportFailure(error, stage: "committed")
  }
  private func reportFailure(_ error: Error, stage: String) {
    let error = error as NSError
    let domain = error.domain == NSURLErrorDomain ? "url" : error.domain == WKErrorDomain ? "webkit" : "other"
    var failure: [String: Any] = ["domain": domain, "code": error.code, "stage": stage]
    var underlying: [[String: Any]] = []
    var cause = error.userInfo[NSUnderlyingErrorKey] as? NSError
    for _ in 0..<3 {
      guard let current = cause else { break }
      let category = current.domain == NSURLErrorDomain ? "url" : current.domain == "kCFErrorDomainCFNetwork" ? "cfnetwork" : current.domain == NSOSStatusErrorDomain ? "osstatus" : current.domain == NSPOSIXErrorDomain ? "posix" : "other"
      underlying.append(["domain": category, "code": current.code])
      cause = current.userInfo[NSUnderlyingErrorKey] as? NSError
    }
    failure["underlying"] = underlying
    lastFailure = failure
    record("error-\(stage)-\(domain)-\(error.code)")
    // A provisional failure often leaves web.url nil/about:blank. Route the
    // failure using its actual failed request, never that empty document.
    let failedURL = error.userInfo[NSURLErrorFailingURLErrorKey] as? URL ??
      (error.userInfo[NSURLErrorFailingURLStringErrorKey] as? String).flatMap { URL(string: $0) } ?? pendingURL
    failure["url"] = failedURL?.absoluteString ?? ""
    emit("error", extra: failure)
  }
  func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    reportFailure(NSError(domain: WKErrorDomain, code: 2), stage: "process")
  }

  func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
               for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
    guard action.targetFrame == nil, let url = action.request.url else { return nil }
    if offerExternalAuthentication(url) { return nil }
    if allowed(url, main: true) {
      record("popup-reused-in-browser")
      webView.load(action.request)
    }
    return nil
  }

  // Ordinary site alert/confirm/prompt flows must remain usable in website
  // fallback. Message/input values stay in UIKit/WebKit and are never logged.
  private func presentSiteDialog(message: String, frame: WKFrameInfo,
                                 cancellable: Bool, asksText: Bool = false, defaultText: String? = nil,
                                 completion: @escaping (String?) -> Void) {
    guard dismissSiteDialog == nil, web.window != nil,
          frame.securityOrigin.protocol == "https", frame.securityOrigin.host == host else {
      completion(nil); return
    }
    var responder: UIResponder? = web
    while responder != nil && !(responder is UIViewController) { responder = responder?.next }
    guard var controller = responder as? UIViewController else { completion(nil); return }
    while let presented = controller.presentedViewController { controller = presented }
    guard !controller.isBeingDismissed, !(controller is UIAlertController) else { completion(nil); return }
    let alert = UIAlertController(title: host, message: message, preferredStyle: .alert)
    if asksText { alert.addTextField { $0.text = defaultText } }
    var finished = false
    let finish: (String?) -> Void = { [weak self] value in
      guard !finished else { return }
      finished = true
      self?.dismissSiteDialog = nil
      completion(value)
    }
    if cancellable {
      alert.addAction(UIAlertAction(title: dialogCancel, style: .cancel) { _ in finish(nil) })
    }
    alert.addAction(UIAlertAction(title: dialogConfirm, style: .default) { [weak alert] _ in
      finish(asksText ? (alert?.textFields?.first?.text ?? "") : "ok")
    })
    dismissSiteDialog = { [weak alert] in
      alert?.dismiss(animated: false)
      finish(nil)
    }
    controller.present(alert, animated: !UIAccessibility.isReduceMotionEnabled)
  }

  func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
               initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
    presentSiteDialog(message: message, frame: frame, cancellable: false) { _ in completionHandler() }
  }

  func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
               initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
    presentSiteDialog(message: message, frame: frame, cancellable: true) { completionHandler($0 != nil) }
  }

  func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
               defaultText: String?, initiatedByFrame frame: WKFrameInfo,
               completionHandler: @escaping (String?) -> Void) {
    presentSiteDialog(message: prompt, frame: frame, cancellable: true,
                      asksText: true, defaultText: defaultText, completion: completionHandler)
  }
}
