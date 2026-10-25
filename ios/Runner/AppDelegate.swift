import Flutter
import UIKit
import Darwin
import WebKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let memoryChannelName = "memory_monitor"
  private var memoryChannel: FlutterMethodChannel?
  private var videoBrowserChannel: FlutterMethodChannel?
  private var videoSharePresenter: VideoSharePresenter?
  private var videoDownloadPresenter: VideoDownloadPresenter?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    setupMemoryChannel(pluginRegistry: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "breeze_video_ui") {
      videoSharePresenter = VideoSharePresenter(messenger: registrar.messenger())
      videoDownloadPresenter = VideoDownloadPresenter(messenger: registrar.messenger())
      registrar.register(VideoControlFactory(messenger: registrar.messenger()), withId: "breeze.video.control")
      registrar.register(VideoNavigationFactory(messenger: registrar.messenger()), withId: "breeze.video.navigation")
      registrar.register(VideoSiteBrowserFactory(messenger: registrar.messenger()), withId: "breeze.video.browser.view")
      let channel = FlutterMethodChannel(name: "breeze.video.browser", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "diagnostics",
              let args = call.arguments as? [String: Any],
              let host = args["host"] as? String, !host.isEmpty, host.count <= 253 else {
          result(FlutterMethodNotImplemented)
          return
        }
        self?.collectVideoBrowserDiagnostics(host: host, result: result)
      }
      videoBrowserChannel = channel
    }
  }

  /// Local browser metadata only. Never reads cookie values, form contents,
  /// challenge tokens, full URLs or credentials; does not modify the browser.
  private func collectVideoBrowserDiagnostics(host: String, result: @escaping FlutterResult) {
    // Include owned browsers even if a provisional failure left them blank.
    var views = VideoSiteBrowserFactory.registeredBrowsers(for: host)
    var knownBrowsers = Set(views.map { ObjectIdentifier($0) })
    var seen = Set<ObjectIdentifier>()
    func visit(_ view: UIView) {
      guard seen.insert(ObjectIdentifier(view)).inserted else { return }
      if let web = view as? WKWebView, web.url?.host == host,
         knownBrowsers.insert(ObjectIdentifier(web)).inserted { views.append(web) }
      for child in view.subviews { visit(child) }
    }
    for scene in UIApplication.shared.connectedScenes {
      if let windowScene = scene as? UIWindowScene {
        for window in windowScene.windows { visit(window) }
      }
    }
    let group = DispatchGroup()
    var records: [[String: Any]] = []
    for web in views.prefix(8) {
      var ancestor: UIView? = web
      var hidden = false
      while let current = ancestor {
        hidden = hidden || current.isHidden || current.alpha < 0.01
        ancestor = current.superview
      }
      var record: [String: Any] = [
        "attached": web.window != nil, "hiddenAncestor": hidden,
        "interactive": web.isUserInteractionEnabled,
        "width": Int(web.bounds.width.rounded()), "height": Int(web.bounds.height.rounded()),
        "persistentStore": web.configuration.websiteDataStore.isPersistent,
        "customUserAgent": !(web.customUserAgent ?? "").isEmpty,
        "injectedScripts": web.configuration.userContentController.userScripts.count,
        "loading": web.isLoading,
        "session": VideoSiteBrowserFactory.metadata(for: web),
      ]
      if #available(iOS 14.0, *) {
        record["javaScript"] = web.configuration.defaultWebpagePreferences.allowsContentJavaScript
        record["appBoundDomains"] = web.configuration.limitsNavigationsToAppBoundDomains
      }
      group.enter()
      web.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
        let clearance = cookies.filter {
          let domain = $0.domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))
          return $0.name == "cf_clearance" && (host == domain || host.hasSuffix("." + domain))
        }
        record["clearancePresent"] = !clearance.isEmpty
        record["clearanceCount"] = clearance.count
        record["clearanceExpired"] = clearance.contains { ($0.expiresDate ?? .distantFuture) <= Date() }
        record["clearancePersistent"] = clearance.contains { !$0.isSessionOnly }
        let documentPath = web.url?.path ?? ""
        let path = documentPath.isEmpty ? "/" : documentPath
        record["clearanceMetadata"] = clearance.prefix(4).map { cookie -> [String: Any] in
          let cookiePath = cookie.path
          let pathMatches = path == cookiePath ||
            (path.hasPrefix(cookiePath) && (cookiePath.hasSuffix("/") || path.dropFirst(cookiePath.count).first == "/"))
          return [
            "pathScope": cookiePath == "/" ? "root" : "non-root",
            "pathMatchesDocument": pathMatches,
            "secure": cookie.isSecure, "httpOnly": cookie.isHTTPOnly,
            "sessionOnly": cookie.isSessionOnly,
            "expired": (cookie.expiresDate ?? .distantFuture) <= Date(),
          ]
        }
        records.append(record)
        group.leave()
      }
    }
    group.notify(queue: .main) {
      result([
        "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
        "os": UIDevice.current.systemVersion,
        "browserCount": views.count, "browsers": records,
      ])
    }
  }

  private func setupMemoryChannel(pluginRegistry: FlutterPluginRegistry) {
    if memoryChannel != nil {
      return
    }

    guard let registrar = pluginRegistry.registrar(forPlugin: memoryChannelName) else {
      return
    }

    let channel = FlutterMethodChannel(
      name: memoryChannelName,
      binaryMessenger: registrar.messenger()
    )

    let handler: FlutterMethodCallHandler = { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "DEALLOCATED", message: "AppDelegate deallocated", details: nil))
        return
      }

      switch call.method {
      case "getMemoryInfo":
        result(self.getMemoryInfo())
      case "getDartMemoryInfo":
        result(self.getDartMemoryInfo())
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    channel.setMethodCallHandler(handler)

    memoryChannel = channel
  }

  private func getMemoryInfo() -> [String: Any] {
    let process = getProcessMemoryUsage()
    let totalMemory = ProcessInfo.processInfo.physicalMemory
    let availableMemory = getAvailableMemory()

    return [
      "totalMemory": toInt64(totalMemory),
      "availableMemory": toInt64(availableMemory),
      "nativeHeapSize": toInt64(process.virtualSize),
      "nativeHeapAllocatedSize": toInt64(process.residentSize),
      "nativeHeapFreeSize": 0,
    ]
  }

  private func getDartMemoryInfo() -> [String: Any] {
    let process = getProcessMemoryUsage()
    let totalMemory = ProcessInfo.processInfo.physicalMemory
    let usedMemory = process.residentSize
    let freeMemory = totalMemory > usedMemory ? totalMemory - usedMemory : 0

    return [
      "dartHeapUsed": toInt64(usedMemory),
      "dartHeapCapacity": toInt64(totalMemory),
      "dartHeapCommitted": toInt64(usedMemory),
      "externalMemory": toInt64(usedMemory),
      "maxMemory": toInt64(totalMemory),
      "totalMemory": toInt64(totalMemory),
      "freeMemory": toInt64(freeMemory),
      "usedMemory": toInt64(usedMemory),
      "nativeHeapSize": toInt64(process.virtualSize),
      "nativeHeapAllocated": toInt64(process.residentSize),
      "nativeHeapFree": 0,
      "processRss": toInt64(process.residentSize),
    ]
  }

  private func getAvailableMemory() -> UInt64 {
    var pageSize: vm_size_t = 0
    host_page_size(mach_host_self(), &pageSize)

    var vmStat = vm_statistics64()
    var count = mach_msg_type_number_t(
      MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
    )

    let result: kern_return_t = withUnsafeMutablePointer(to: &vmStat) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
        host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPointer, &count)
      }
    }

    if result != KERN_SUCCESS {
      return 0
    }

    let freePages = UInt64(vmStat.free_count)
    let inactivePages = UInt64(vmStat.inactive_count)
    let speculativePages = UInt64(vmStat.speculative_count)
    return (freePages + inactivePages + speculativePages) * UInt64(pageSize)
  }

  private func getProcessMemoryUsage() -> (residentSize: UInt64, virtualSize: UInt64) {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(
      MemoryLayout<mach_task_basic_info_data_t>.size / MemoryLayout<natural_t>.size
    )

    let result: kern_return_t = withUnsafeMutablePointer(to: &info) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), reboundPointer, &count)
      }
    }

    if result != KERN_SUCCESS {
      return (0, 0)
    }

    return (
      UInt64(info.resident_size),
      UInt64(info.virtual_size)
    )
  }

  private func toInt64(_ value: UInt64) -> Int64 {
    if value > UInt64(Int64.max) {
      return Int64.max
    }
    return Int64(value)
  }
}

/// UIKit owns the menu presentation and button material. On iOS 26+ this uses
/// the system Liquid Glass configuration; older systems keep their native tint.
private final class VideoControlFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    VideoControlView(frame: frame, id: viewId, arguments: args, messenger: messenger)
  }
}

private final class VideoNavigationFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    VideoNavigationView(frame: frame, id: viewId, arguments: args, messenger: messenger)
  }
}

private final class VideoNavigationContainer: UIView {
  let bar = UITabBar()
  var preferredHeightChanged: ((CGFloat) -> Void)?
  private var lastPreferredHeight: CGFloat = 0
  override init(frame: CGRect) { super.init(frame: frame); addSubview(bar) }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  override func layoutSubviews() {
    super.layoutSubviews()
    bar.frame = bounds
    let height = bar.sizeThatFits(bounds.size).height
    if height.isFinite, height >= 49, height <= 160, abs(height - lastPreferredHeight) > 0.5 {
      lastPreferredHeight = height
      preferredHeightChanged?(height)
    }
  }
}

private final class VideoNavigationView: NSObject, FlutterPlatformView, UITabBarDelegate {
  private let container: VideoNavigationContainer
  private let channel: FlutterMethodChannel
  private var itemDefinitions: [[String:String]] = []
  init(frame: CGRect, id: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    container = VideoNavigationContainer(frame: frame)
    channel = FlutterMethodChannel(name: "breeze.video.navigation.\(id)", binaryMessenger: messenger)
    super.init()
    container.bar.delegate = self
    container.preferredHeightChanged = { [weak self] height in
      self?.channel.invokeMethod("height", arguments: height)
    }
    configure(arguments as? [String:Any] ?? [:])
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "update" else { result(FlutterMethodNotImplemented); return }
      self?.configure(call.arguments as? [String:Any] ?? [:]); result(nil)
    }
  }
  func view() -> UIView { container }
  private func configure(_ args: [String:Any]) {
    container.overrideUserInterfaceStyle = args["dark"] as? Bool == true ? .dark : .light
    container.bar.isUserInteractionEnabled = args["enabled"] as? Bool ?? true
    let definitions = args["items"] as? [[String:String]] ?? []
    if definitions != itemDefinitions {
      itemDefinitions = definitions
      container.bar.items = definitions.enumerated().map { index, value in
        let symbol = value["symbol"] ?? "circle"
        let configuration = UIImage.SymbolConfiguration(pointSize: 21, weight: .regular)
        let item = UITabBarItem(title:value["title"],
          image:UIImage(systemName:symbol, withConfiguration:configuration), tag:index)
        item.selectedImage = UIImage(systemName:symbol + ".fill", withConfiguration:configuration) ?? item.image
        return item
      }
    }
    let selected = args["selected"] as? Int ?? 0
    if let items = container.bar.items, items.indices.contains(selected) {
      container.bar.selectedItem = items[selected]
    }
  }
  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    channel.invokeMethod("select", arguments:item.tag)
  }
  deinit { channel.setMethodCallHandler(nil) }
}

private final class VideoMenuButton: UIButton {
  var menuVisibilityChanged: ((Bool, Int) -> Void)?
  private var menuGeneration = 0
  private var outsideCapture: UIControl?

  private func captureOutsideTouches() {
    outsideCapture?.removeFromSuperview()
    guard let window = window else { return }
    var host: UIView = self
    while let parent = host.superview, parent !== window { host = parent }
    guard host.superview === window else { return }
    // Capture outside touches natively, above Flutter's touch forwarding view
    // and below UIKit's menu presentation. A Flutter barrier cannot reliably
    // arbitrate these native menu touches, and dismiss alone allows tap-through.
    let capture = UIControl(frame: window.bounds)
    capture.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    capture.addAction(UIAction { [weak self] _ in self?.dismissPresentedMenu() }, for: .touchDown)
    window.insertSubview(capture, aboveSubview: host)
    outsideCapture = capture
  }

  func dismissPresentedMenu() {
    for case let interaction as UIContextMenuInteraction in interactions { interaction.dismissMenu() }
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window == nil { outsideCapture?.removeFromSuperview(); outsideCapture = nil }
  }

  deinit { outsideCapture?.removeFromSuperview() }

  override func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
    willDisplayMenuFor configuration: UIContextMenuConfiguration,
    animator: UIContextMenuInteractionAnimating?) {
    super.contextMenuInteraction(interaction, willDisplayMenuFor: configuration, animator: animator)
    menuGeneration += 1
    captureOutsideTouches()
    menuVisibilityChanged?(true, menuGeneration)
  }

  override func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
    willEndFor configuration: UIContextMenuConfiguration,
    animator: UIContextMenuInteractionAnimating?) {
    super.contextMenuInteraction(interaction, willEndFor: configuration, animator: animator)
    let closingGeneration = menuGeneration
    let finish: () -> Void = { [weak self] in
      guard let self = self, self.menuGeneration == closingGeneration else { return }
      // Keep capture until the exit animation finishes. An immediate second
      // tap must not reach the content while the menu is visibly closing.
      self.outsideCapture?.removeFromSuperview()
      self.outsideCapture = nil
      self.menuVisibilityChanged?(false, closingGeneration)
    }
    if let animator = animator { animator.addCompletion(finish) }
    else { finish() }
  }
}

private final class VideoControlView: NSObject, FlutterPlatformView {
  private let button = VideoMenuButton(type: .system)
  private let channel: FlutterMethodChannel

  init(frame: CGRect, id: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "breeze.video.control.\(id)", binaryMessenger: messenger)
    super.init()
    button.frame = frame
    button.menuVisibilityChanged = { [weak self] visible, generation in
      self?.channel.invokeMethod(visible ? "menuOpened" : "menuClosed",
        arguments: ["generation": generation])
    }
    button.addAction(UIAction { [weak self] _ in
      guard let self = self, self.button.menu == nil else { return }
      self.channel.invokeMethod("press", arguments: nil)
    }, for: .primaryActionTriggered)
    configure(arguments as? [String: Any] ?? [:])
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "update" {
        self?.configure(call.arguments as? [String: Any] ?? [:])
        result(nil)
      } else if call.method == "dismissMenu" {
        self?.dismissMenu()
        result(nil)
      } else { result(FlutterMethodNotImplemented) }
    }
  }

  func view() -> UIView { button }

  private func dismissMenu() {
    button.dismissPresentedMenu()
  }

  private func configure(_ args: [String: Any]) {
    button.overrideUserInterfaceStyle = (args["dark"] as? Bool == true) ? .dark : .light
    var config: UIButton.Configuration
    if args["bare"] as? Bool == true { config = .plain() }
    else if #available(iOS 26.0, *) { config = .glass() }
    else { config = .tinted() }
    config.title = args["label"] as? String
    let size = (args["iconSize"] as? NSNumber)?.doubleValue ?? 18
    let playerControl = args["backgroundInset"] != nil
    if let symbol = args["symbol"] as? String, !symbol.isEmpty {
      if playerControl, let image = UIImage(systemName: symbol,
          withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: .medium)) {
        // Symbol pointSize is a font metric, not a square image boundary.
        // Fit the complete symbol into a stable content canvas. Keep the
        // 44pt button and 36pt glass plate independent of the symbol's ratio.
        let extent = CGFloat(size)
        let scale = (extent - 2) / max(image.size.width, image.size.height)
        let fitted = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let opticalX: CGFloat = symbol == "play.fill" ? 0.6 : 0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: extent, height: extent))
        config.image = renderer.image { _ in
          image.draw(in: CGRect(x: (extent - fitted.width) / 2 + opticalX,
            y: (extent - fitted.height) / 2, width: fitted.width, height: fitted.height))
        }.withRenderingMode(.alwaysTemplate)
      } else {
        config.image = UIImage(systemName: symbol)
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: size, weight: .medium)
      }
    }
    config.imagePadding = playerControl ? 0 : 5
    config.contentInsets = playerControl
      ? NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
      : NSDirectionalEdgeInsets(top: 5, leading: 9, bottom: 5, trailing: 9)
    // Keep the UIButton/platform-view hit area intact. Only the visible plate
    // is inset, so a 44pt player control draws a 36pt material background.
    // Catalog menus omit this argument and retain their native appearance.
    let backgroundInset = min(4, max(0, (args["backgroundInset"] as? NSNumber)?.doubleValue ?? 0))
    config.background.backgroundInsets = NSDirectionalEdgeInsets(
      top: backgroundInset, leading: backgroundInset,
      bottom: backgroundInset, trailing: backgroundInset)
    config.cornerStyle = .capsule
    config.baseForegroundColor = (args["light"] as? Bool == true) ? .white : .label
    config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
      var attributes = incoming
      let fontSize = (args["fontSize"] as? NSNumber)?.doubleValue ?? 13
      attributes.font = .systemFont(ofSize: fontSize, weight: .semibold)
      return attributes
    }
    button.isEnabled = args["enabled"] as? Bool ?? true
    button.configuration = config
    button.accessibilityLabel = args["tooltip"] as? String
    button.accessibilityValue = args["accessibilityValue"] as? String
    let selected = args["selected"] as? String
    let options = args["options"] as? [[String: String]] ?? []
    button.showsMenuAsPrimaryAction = !options.isEmpty
    let actions = options.map { item in
      let image = item["symbol"].flatMap {
        UIImage(systemName: $0, withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .regular))
      }
      return UIAction(title: item["title"] ?? "", image: image, state: item["value"] == selected ? .on : .off) { [weak self] _ in
        self?.channel.invokeMethod("select", arguments: item["value"])
      }
    }
    if let choiceValues = args["choiceValues"] as? [String] {
      // Only renderer choices are mutually exclusive. Commands such as
      // analysis/settings must never replace the renderer's checkmark.
      let choices = Set(choiceValues)
      var children: [UIMenuElement] = []
      var addedChoices = false
      for (index, item) in options.enumerated() {
        if choices.contains(item["value"] ?? "") {
          if !addedChoices {
            let choiceActions = options.enumerated().compactMap { index, option in
              choices.contains(option["value"] ?? "") ? actions[index] : nil
            }
            children.append(UIMenu(options: [.displayInline, .singleSelection], children: choiceActions))
            addedChoices = true
          }
        } else {
          children.append(actions[index])
        }
      }
      button.menu = children.isEmpty ? nil : UIMenu(children: children)
    } else {
      button.menu = actions.isEmpty ? nil : UIMenu(options: .singleSelection, children: actions)
    }
  }

  deinit {
    dismissMenu()
    channel.setMethodCallHandler(nil)
  }
}

/// Separate from the site browser: only an explicit user share action reaches
/// this channel. No cookies, private forms or diagnostic data enter the sheet.
private final class VideoSharePresenter {
  private let channel: FlutterMethodChannel
  private weak var active: UIActivityViewController?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "breeze.video.share", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "share" else { result(FlutterMethodNotImplemented); return }
      guard let self = self else { result("unavailable"); return }
      self.share(call.arguments as? [String: Any] ?? [:], result: result)
    }
  }

  private func share(_ args: [String: Any], result: @escaping FlutterResult) {
    guard active == nil else { result("busy"); return }
    guard let raw = args["url"] as? String, raw.count <= 2000,
          let url = URL(string: raw), url.scheme == "https", url.host?.isEmpty == false,
          url.user == nil, url.password == nil, url.port == nil || url.port == 443,
          url.path == "/watch", url.fragment == nil,
          let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let queries = parts.queryItems, queries.count == 1, queries[0].name == "v",
          let id = queries[0].value, !id.isEmpty,
          id.range(of: "^[0-9]+$", options: .regularExpression) != nil else {
      result("failed"); return
    }
    let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }.flatMap { $0.windows }
    guard let window = windows.first(where: { $0.isKeyWindow }),
          let root = window.rootViewController else { result("unavailable"); return }
    var presenter = root
    while let presented = presenter.presentedViewController { presenter = presented }
    guard presenter.viewIfLoaded?.window != nil, !presenter.isBeingDismissed,
          !(presenter is UIAlertController), !(presenter is UIActivityViewController) else {
      result("busy"); return
    }
    let title = String((args["title"] as? String ?? "").prefix(300))
    let items: [Any] = title.isEmpty ? [url] : [title, url]
    let sheet = UIActivityViewController(activityItems: items, applicationActivities: nil)
    if let popover = sheet.popoverPresentationController {
      popover.sourceView = presenter.view
      let x = (args["x"] as? NSNumber)?.doubleValue ?? .nan
      let y = (args["y"] as? NSNumber)?.doubleValue ?? .nan
      let width = (args["width"] as? NSNumber)?.doubleValue ?? .nan
      let height = (args["height"] as? NSNumber)?.doubleValue ?? .nan
      var anchor = CGRect.null
      if [x, y, width, height].allSatisfy({ $0.isFinite }), width > 0, height > 0 {
        anchor = presenter.view.convert(CGRect(x: x, y: y, width: width, height: height), from: root.view)
          .intersection(presenter.view.bounds)
      }
      popover.sourceRect = anchor.isNull || anchor.isEmpty
        ? CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 1, height: 1) : anchor
    }
    var completed = false
    sheet.completionWithItemsHandler = { [weak self] _, shared, _, error in
      guard !completed else { return }
      completed = true
      self?.active = nil
      result(error != nil ? "failed" : shared ? "shared" : "cancelled")
    }
    active = sheet
    presenter.present(sheet, animated: !UIAccessibility.isReduceMotionEnabled)
  }

  deinit { channel.setMethodCallHandler(nil) }
}
