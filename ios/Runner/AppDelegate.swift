import Flutter
import UIKit
import Darwin
import WebKit
import Security

/// Device-only authorization material. It is never included in app preferences,
/// backup exports, diagnostics or synchronizable Keychain items.
private final class BackupSecurityStore: NSObject, UIDocumentPickerDelegate, UIAdaptivePresentationControllerDelegate {
  private let channel: FlutterMethodChannel
  private let queue = DispatchQueue(label: "breeze.backup-security")
  private let service = (Bundle.main.bundleIdentifier ?? "com.zephyr.breeze") + ".backup-security"
  private var activeExport: (picker: UIDocumentPickerViewController, result: FlutterResult)?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "breeze/backup_security", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      if call.method == "supported" { result(true); return }
      if call.method == "exportFile" {
        self.exportFile(call.arguments as? [String: Any] ?? [:], result: result); return
      }
      guard ["readKey", "writeKey", "deleteKey"].contains(call.method) else {
        result(FlutterMethodNotImplemented); return
      }
      guard let args = call.arguments as? [String: Any],
            let id = args["archiveId"] as? String,
            id.range(of: "^[a-f0-9]{32}$", options: .regularExpression) != nil else {
        result(FlutterError(code: "invalid_arguments", message: nil, details: nil)); return
      }
      let key = (args["key"] as? FlutterStandardTypedData)?.data
      if call.method == "writeKey" && key?.count != 32 {
        result(FlutterError(code: "invalid_arguments", message: nil, details: nil)); return
      }
      self.queue.async {
        var query: [String: Any] = [
          kSecClass as String: kSecClassGenericPassword,
          kSecAttrService as String: self.service,
          kSecAttrAccount as String: id,
          kSecAttrSynchronizable as String: false,
        ]
        var status: OSStatus = errSecParam
        var response: Any?
        switch call.method {
        case "readKey":
          query[kSecReturnData as String] = true
          query[kSecMatchLimit as String] = kSecMatchLimitOne
          var item: CFTypeRef?
          status = SecItemCopyMatching(query as CFDictionary, &item)
          if status == errSecItemNotFound { status = errSecSuccess }
          else if status == errSecSuccess {
            if let data = item as? Data, data.count == 32 {
              response = FlutterStandardTypedData(bytes: data)
            } else { status = errSecDecode }
          }
        case "writeKey":
          let values: [String: Any] = [
            kSecValueData as String: key!,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
          ]
          status = SecItemUpdate(query as CFDictionary, values as CFDictionary)
          if status == errSecItemNotFound {
            query.merge(values) { _, updated in updated }
            status = SecItemAdd(query as CFDictionary, nil)
          }
        case "deleteKey":
          status = SecItemDelete(query as CFDictionary)
          if status == errSecItemNotFound { status = errSecSuccess }
        default: break
        }
        DispatchQueue.main.async {
          if status == errSecSuccess { result(response) }
          else { result(FlutterError(code: "device_storage_unavailable", message: nil, details: nil)) }
        }
      }
    }
  }

  deinit { channel.setMethodCallHandler(nil) }

  private func exportFile(_ args: [String: Any], result: @escaping FlutterResult) {
    guard activeExport == nil, let path = args["path"] as? String else { result("busy"); return }
    let url = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL
    guard ["breezerecovery", "breezebackup", "zip"].contains(url.pathExtension),
          let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
          url.path.hasPrefix(cache.resolvingSymlinksInPath().path + "/"),
          FileManager.default.fileExists(atPath: url.path) else { result("failed"); return }
    let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }.flatMap { $0.windows }
    guard let root = windows.first(where: { $0.isKeyWindow })?.rootViewController else { result("failed"); return }
    var presenter = root
    while let presented = presenter.presentedViewController { presenter = presented }
    guard presenter.viewIfLoaded?.window != nil, !presenter.isBeingDismissed,
          !(presenter is UIAlertController), !(presenter is UIDocumentPickerViewController),
          !(presenter is UIActivityViewController) else { result("busy"); return }

    let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
    picker.delegate = self
    picker.presentationController?.delegate = self
    activeExport = (picker, result)
    presenter.present(picker, animated: !UIAccessibility.isReduceMotionEnabled)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    finishExport(controller, status: urls.isEmpty ? "cancelled" : "saved")
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finishExport(controller, status: "cancelled")
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    guard let picker = presentationController.presentedViewController as? UIDocumentPickerViewController else { return }
    finishExport(picker, status: "cancelled")
  }

  private func finishExport(_ picker: UIDocumentPickerViewController, status: String) {
    guard let active = activeExport, active.picker === picker else { return }
    activeExport = nil
    active.result(status)
  }
}

/// The operating system owns this device-local preference. Preview assets are
/// high-resolution companions, not a recreation of SpringBoard tint/materials.
private final class AppIconSettings {
  private let classic = "AppIconClassic"
  private var changing = false
  private var previews: [String: Data] = [:]
#if DEBUG
  private var didRequestDirectIconProbe = false
  private var directIconProbeActiveObserver: NSObjectProtocol?
#endif

  func register(with messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "breeze.appearance.app_icon", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        guard let self else { result(nil); return }
        self.handle(call, result: result)
      }
#if DEBUG
    if ProcessInfo.processInfo.arguments.contains("--breeze-icon-direct-probe") {
      if UIApplication.shared.applicationState == .active {
        requestDirectIconProbeOnce()
      } else if directIconProbeActiveObserver == nil {
        directIconProbeActiveObserver = NotificationCenter.default.addObserver(
          forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
          guard let self else { return }
          if let observer = self.directIconProbeActiveObserver {
            NotificationCenter.default.removeObserver(observer)
            self.directIconProbeActiveObserver = nil
          }
          self.requestDirectIconProbeOnce()
        }
      }
    }
#endif
  }

#if DEBUG
  // Explicit one-shot launch diagnostic only. This path is absent from release
  // and never supplies the production preview or changes the desktop icon.
  private func requestDirectIconProbeOnce() {
    guard !didRequestDirectIconProbe,
          let ownBundle = Bundle.main.bundleIdentifier else { return }
    didRequestDirectIconProbe = true
    DispatchQueue(label: "breeze.app-icon.direct-probe", qos: .utility).async {
      let directory = FileManager.default.temporaryDirectory
      let reportURL = directory.appendingPathComponent("breeze-icon-direct-probe.json")
      func record(_ fields: [String: Any]) {
        var report = fields
        report["context"] = "application-sandbox"
        report["time"] = ISO8601DateFormatter().string(from: Date())
        if let json = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]) {
          try? json.write(to: reportURL, options: .atomic)
        }
      }
      record(["phase": "started"])
      guard let library = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY | RTLD_LOCAL),
            let symbol = dlsym(library, "SBSCopyIconImagePNGDataForDisplayIdentifier") else {
        record(["phase": "complete", "exportPresent": false, "available": false])
        return
      }
      typealias CopyIcon = @convention(c) (CFString) -> Unmanaged<CFData>?
      let copyIcon = unsafeBitCast(symbol, to: CopyIcon.self)
      guard let returned = copyIcon(ownBundle as CFString) else {
        record(["phase": "complete", "exportPresent": true, "available": false])
        return
      }
      let data = returned.takeRetainedValue() as Data
      guard let image = UIImage(data: data)?.cgImage else {
        record(["phase": "complete", "available": false, "decodeFailed": true, "bytes": data.count])
        return
      }
      let output = directory.appendingPathComponent("breeze-icon-direct-probe.png")
      var saved = false
      do { try data.write(to: output, options: .atomic); saved = true } catch {}
      record(["phase": "complete", "exportPresent": true, "available": true,
              "width": image.width, "height": image.height, "bytes": data.count, "saved": saved])
    }
  }
#endif

  // Scene traits report the system interface appearance. They are deliberately
  // not taken from a Flutter-styled control or a view with an override. UIKit
  // does not expose Home Screen's independent dark/tinted/clear icon setting.
  private func systemPreviewStyle() -> UIUserInterfaceStyle {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let scene = scenes.first { $0.activationState == .foregroundActive && $0.windows.contains { $0.isKeyWindow } }
      ?? scenes.first { $0.activationState == .foregroundActive }
      ?? scenes.first { $0.activationState == .foregroundInactive }
    return scene?.traitCollection.userInterfaceStyle == .dark ? .dark : .light
  }

  private func status(failed: Bool = false) -> [String: Any] {
    let app = UIApplication.shared
    let name = app.alternateIconName
    let style = systemPreviewStyle()
    var value: [String: Any] = [
      "supported": app.supportsAlternateIcons,
      "iconName": name ?? "",
      "previewAppearance": name == nil && style == .dark ? "dark" : "light",
      "failed": failed,
    ]
    let preview = name == nil ? "BreezeAppIconPreview"
      : name == classic ? "BreezeClassicIconPreview" : nil
    if let preview {
      // Classic has no authored dark variant: keep its original artwork.
      let previewStyle: UIUserInterfaceStyle = name == nil ? style : .light
      let cacheKey = "\(preview)|\(previewStyle.rawValue)"
      if previews[cacheKey] == nil {
        let traits = UITraitCollection(userInterfaceStyle: previewStyle)
        previews[cacheKey] = UIImage(named: preview, in: .main, compatibleWith: traits)?.pngData()
      }
      if let bytes = previews[cacheKey] {
        value["preview"] = FlutterStandardTypedData(bytes: bytes)
      }
    }
    return value
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let app = UIApplication.shared
    switch call.method {
    case "status": result(status())
    case "select":
      guard let requested = call.arguments as? String,
            requested.isEmpty || requested == classic,
            app.supportsAlternateIcons, !changing else {
        result(status(failed: true))
        return
      }
      let name: String? = requested.isEmpty ? nil : requested
      guard app.alternateIconName != name else { result(status()); return }
      changing = true
      app.setAlternateIconName(name) { [weak self] error in
        DispatchQueue.main.async {
          guard let self else { result(nil); return }
          self.changing = false
          result(self.status(failed: error != nil || app.alternateIconName != name))
        }
      }
    default: result(FlutterMethodNotImplemented)
    }
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let memoryChannelName = "memory_monitor"
  private var memoryChannel: FlutterMethodChannel?
  private var videoBrowserChannel: FlutterMethodChannel?
  private var videoSharePresenter: VideoSharePresenter?
  private var videoDownloadPresenter: VideoDownloadPresenter?
  private lazy var hlsAssetDownloadPresenter = HlsAssetDownloadPresenter()
  private lazy var backgroundFileTransfer = BackgroundFileTransfer()
  private lazy var continuedDownloadActivity = ContinuedDownloadActivity()
  private var routingConfigExporter: RoutingConfigExporter?
  private var backupSecurity: BackupSecurityStore?
  private let appIconSettings = AppIconSettings()
#if DEBUG
  private var nativeCompositionDiagnostics: NativeCompositionDiagnostics?
#endif

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    continuedDownloadActivity.register()
    backgroundFileTransfer.start()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(_ application: UIApplication,
                            handleEventsForBackgroundURLSession identifier: String,
                            completionHandler: @escaping () -> Void) {
    if identifier.hasPrefix(BackgroundFileTransfer.prefix) {
      backgroundFileTransfer.backgroundEvents(identifier, completion: completionHandler)
      return
    }
    if identifier.hasPrefix(HlsAssetDownloadPresenter.sessionPrefix) {
      hlsAssetDownloadPresenter.handleBackgroundSession(identifier, completion: completionHandler)
      return
    }
    super.application(application, handleEventsForBackgroundURLSession: identifier, completionHandler: completionHandler)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    setupMemoryChannel(pluginRegistry: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "breeze_app_icon") {
      appIconSettings.register(with: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "breeze_video_ui") {
      FlutterMethodChannel(name: "breeze.interface.symbols", binaryMessenger: registrar.messenger())
        .setMethodCallHandler { call, result in
          guard call.method == "image" else { result(FlutterMethodNotImplemented); return }
          guard let name = call.arguments as? String, name.count <= 64,
                let image = UIImage(systemName: name,
                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)),
                image.size.width > 0, image.size.height > 0 else { result(nil); return }
          let extent: CGFloat = 24
          let scale = (extent - 2) / max(image.size.width, image.size.height)
          let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
          let format = UIGraphicsImageRendererFormat()
          format.scale = 3
          let renderer = UIGraphicsImageRenderer(size: CGSize(width: extent, height: extent), format: format)
          let bytes = renderer.pngData { _ in
            image.withTintColor(.black, renderingMode: .alwaysOriginal).draw(in: CGRect(
              x: (extent - size.width) / 2, y: (extent - size.height) / 2,
              width: size.width, height: size.height))
          }
          result(FlutterStandardTypedData(bytes: bytes))
        }
      FlutterMethodChannel(name: "breeze.download.capacity", binaryMessenger: registrar.messenger())
        .setMethodCallHandler { call, result in
          guard call.method == "availableBytes" else { result(FlutterMethodNotImplemented); return }
          DispatchQueue.global(qos: .utility).async {
            let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            let attributes = directory.flatMap { try? FileManager.default.attributesOfFileSystem(forPath: $0.deletingLastPathComponent().path) }
            let available = attributes?[.systemFreeSize] as? NSNumber
            DispatchQueue.main.async { result(available) }
          }
        }
      OmoNetwork.shared.register(registrar.messenger())
      videoSharePresenter = VideoSharePresenter(messenger: registrar.messenger())
      videoDownloadPresenter = VideoDownloadPresenter(messenger: registrar.messenger())
      hlsAssetDownloadPresenter.attach(messenger: registrar.messenger())
      backgroundFileTransfer.attach(registrar.messenger())
      continuedDownloadActivity.attach(registrar.messenger())
      routingConfigExporter = RoutingConfigExporter(messenger: registrar.messenger())
      backupSecurity = BackupSecurityStore(messenger: registrar.messenger())
#if DEBUG
      nativeCompositionDiagnostics = NativeCompositionDiagnostics(messenger: registrar.messenger())
#endif
      registrar.register(VideoControlFactory(messenger: registrar.messenger()), withId: "breeze.video.control")
      registrar.register(VideoNavigationFactory(messenger: registrar.messenger()), withId: "breeze.video.navigation")
      registrar.register(SearchSurfaceFactory(), withId: "breeze.search.surface")
      registrar.register(VideoSiteBrowserFactory(registrar: registrar), withId: "breeze.video.browser.view")
#if targetEnvironment(simulator)
      if ProcessInfo.processInfo.arguments.contains("--breeze-settings-probe") {
        let messenger = registrar.messenger()
        DispatchQueue.main.async { runSettingsControlsProbe(messenger: messenger) }
      }
#endif
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
/// Flutter sends the resolved ARGB role as an integer in the platform-view arguments.
private func videoThemeColor(_ value: Any?) -> UIColor? {
  guard let number = value as? NSNumber else { return nil }
  let argb = number.uint32Value
  return UIColor(red: CGFloat((argb >> 16) & 0xff) / 255,
    green: CGFloat((argb >> 8) & 0xff) / 255,
    blue: CGFloat(argb & 0xff) / 255,
    alpha: CGFloat(argb >> 24) / 255)
}

private final class VideoControlFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger
  init(messenger: FlutterBinaryMessenger) { self.messenger = messenger }
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    switch (args as? [String: Any])?["kind"] as? String {
    case "segmented":
      return VideoSegmentedControlView(frame: frame, id: viewId, arguments: args, messenger: messenger)
    case "iconGroup":
      return VideoIconGroupView(frame: frame, id: viewId, arguments: args, messenger: messenger)
    default:
      return VideoControlView(frame: frame, id: viewId, arguments: args, messenger: messenger)
    }
  }
}

/// Uses the system selector's material and selection animation without adding
/// a separate glass background. Flutter chooses a multiline fallback if titles
/// cannot fit, and owns the scaled font and minimum 44pt layout height.
private final class VideoSegmentedControlView: NSObject, FlutterPlatformView {
  private let control = UISegmentedControl(items: [])
  private let channel: FlutterMethodChannel
  private var definitions: [[String: String]] = []

  init(frame: CGRect, id: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "breeze.video.control.\(id)", binaryMessenger: messenger)
    super.init()
    control.frame = frame
    control.isMomentary = false
    control.apportionsSegmentWidthsByContent = false
    control.addAction(UIAction { [weak self] _ in
      guard let self = self, self.control.isEnabled,
            self.definitions.indices.contains(self.control.selectedSegmentIndex) else { return }
      let value = self.definitions[self.control.selectedSegmentIndex]["value"]
      self.channel.invokeMethod("select", arguments: value)
    }, for: .valueChanged)
    configure(arguments as? [String: Any] ?? [:])
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "update" else { result(FlutterMethodNotImplemented); return }
      self?.configure(call.arguments as? [String: Any] ?? [:])
      result(nil)
    }
  }

  func view() -> UIView { control }

  private func configure(_ args: [String: Any]) {
    control.overrideUserInterfaceStyle = args["dark"] as? Bool == true ? .dark : .light
    control.selectedSegmentTintColor = videoThemeColor(args["selectedBackground"])
    control.semanticContentAttribute = args["rtl"] as? Bool == true ? .forceRightToLeft : .forceLeftToRight
    control.isEnabled = args["enabled"] as? Bool ?? true
    let options = args["options"] as? [[String: String]] ?? []
    if options != definitions {
      definitions = options
      control.removeAllSegments()
      for (index, option) in options.enumerated() {
        control.insertSegment(withTitle: option["title"] ?? "", at: index, animated: false)
      }
    }
    let requestedSize = (args["fontSize"] as? NSNumber)?.doubleValue ?? 13
    let fontSize = requestedSize.isFinite && requestedSize > 0 ? requestedSize : 13
    let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
    for state in [UIControl.State.normal, .disabled] {
      control.setTitleTextAttributes([.font: font], for: state)
    }
    var selectedAttributes: [NSAttributedString.Key: Any] = [.font: font]
    if let foreground = videoThemeColor(args["selectedForeground"]) {
      selectedAttributes[.foregroundColor] = foreground
    }
    control.setTitleTextAttributes(selectedAttributes, for: .selected)
    let selected = args["selected"] as? String
    let selectedIndex = definitions.firstIndex { $0["value"] == selected }
      ?? UISegmentedControl.noSegment
    if control.selectedSegmentIndex != selectedIndex {
      control.selectedSegmentIndex = selectedIndex
    }
    // Setting titles or selection does not send .valueChanged. Only a user
    // action above reports a selection back across the bridge.
  }

  deinit { channel.setMethodCallHandler(nil) }
}

/// A non-interactive material underneath Flutter's existing search editor.
/// Keeping text input in Flutter avoids duplicate first responders and IME state.
private final class SearchSurfaceFactory: NSObject, FlutterPlatformViewFactory {
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    SearchSurfaceView(frame: frame, arguments: args as? [String: Any] ?? [:])
  }
}

private final class SearchSurfaceView: NSObject, FlutterPlatformView {
  private let container: SearchMaterialContainer
  init(frame: CGRect, arguments: [String: Any]) {
    container = SearchMaterialContainer(frame: frame)
    super.init()
    container.overrideUserInterfaceStyle = arguments["dark"] as? Bool == true ? .dark : .light
    container.highContrast = arguments["highContrast"] as? Bool ?? false
    container.readableContent = arguments["readableContent"] as? Bool ?? false
    // Absent for search: preserve its height-derived capsule exactly.
    if let radius = arguments["panelRadius"] as? NSNumber {
      container.panelRadius = max(0, CGFloat(truncating: radius))
      container.layer.maskedCorners = arguments["topOnly"] as? Bool == true
        ? [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        : [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
    }
    container.refreshMaterial()
  }
  func view() -> UIView { container }
}

private final class SearchMaterialContainer: UIView {
  var highContrast = false
  var panelRadius: CGFloat?
  var readableContent = false
  private let material = UIVisualEffectView()
  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    clipsToBounds = true
    addSubview(material)
    NotificationCenter.default.addObserver(self, selector: #selector(refreshMaterial),
      name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
  override func layoutSubviews() {
    super.layoutSubviews()
    layer.cornerRadius = panelRadius ?? bounds.height / 2
    material.frame = bounds
  }
  @objc func refreshMaterial() {
    if UIAccessibility.isReduceTransparencyEnabled {
      material.effect = nil
      material.backgroundColor = .secondarySystemBackground
    } else if readableContent {
      // Dense task text uses the system's stronger content material; its outer
      // presentation keeps the existing glass, rather than simulated opacity.
      material.backgroundColor = .clear
      material.effect = UIBlurEffect(style: .systemThickMaterial)
    } else if #available(iOS 26.0, *) {
      material.backgroundColor = .clear
      material.effect = UIGlassEffect(style: .regular)
    } else {
      material.backgroundColor = .clear
      material.effect = UIBlurEffect(style: .systemMaterial)
    }
    layer.borderWidth = highContrast ? 1 : 0.5
    layer.borderColor = UIColor.separator.withAlphaComponent(highContrast ? 1 : 0.35)
      .resolvedColor(with: traitCollection).cgColor
  }
  deinit { NotificationCenter.default.removeObserver(self) }
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
  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .clear
    isOpaque = false
    // The adapter is transparent; UITabBar keeps UIKit's default appearance,
    // Liquid Glass and accessibility-driven behavior without an extra plate.
    addSubview(bar)
  }
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
  private var requestedSelection: Int?
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
  private func navigationImage(_ name: String) -> UIImage? {
    // The follow tab shares Flutter's exact bell silhouettes. UIKit still owns
    // tab layout, tint, selected material, accessibility and touch feedback.
    switch name {
    case "breeze.follow":
      return UIImage(named: "NavigationFollow")?.withRenderingMode(.alwaysTemplate)
        ?? UIImage(systemName: "bell")
    case "breeze.follow.selected":
      return UIImage(named: "NavigationFollowSelected")?.withRenderingMode(.alwaysTemplate)
        ?? UIImage(systemName: "bell.fill")
    default:
      return UIImage(systemName: name)
    }
  }
  private func configure(_ args: [String:Any]) {
    container.overrideUserInterfaceStyle = args["dark"] as? Bool == true ? .dark : .light
    container.bar.tintColor = videoThemeColor(args["accent"])
    container.bar.isUserInteractionEnabled = args["enabled"] as? Bool ?? true
    let definitions = args["items"] as? [[String:String]] ?? []
    let itemsChanged = definitions != itemDefinitions
    if itemsChanged {
      itemDefinitions = definitions
      container.bar.items = definitions.enumerated().map { index, value in
        let symbol = value["symbol"] ?? "circle"
        let item = UITabBarItem(title:value["title"],
          image:navigationImage(symbol), tag:index)
        let selectedImage = value["selectedSymbol"].flatMap { navigationImage($0) }
        item.selectedImage = selectedImage ?? UIImage(systemName:symbol + ".fill") ?? item.image
        return item
      }
    }
    let selected = args["selected"] as? Int ?? 0
    let selectionChanged = selected != requestedSelection
    requestedSelection = selected
    guard let items = container.bar.items else { return }
    let badges = args["badges"] as? [Any] ?? []
    for (index, item) in items.enumerated() {
      let value = badges.indices.contains(index) ? badges[index] as? String : nil
      let badge = value?.isEmpty == false ? value : nil
      if item.badgeValue != badge { item.badgeValue = badge }
    }
    if (itemsChanged || selectionChanged), items.indices.contains(selected),
       container.bar.selectedItem !== items[selected] {
      // Ignore unrelated updates while UIKit is handling a native selection.
      container.bar.selectedItem = items[selected]
    }
  }
  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    channel.invokeMethod("select", arguments:item.tag)
  }
  deinit { channel.setMethodCallHandler(nil) }
}

private final class VideoMenuButton: UIButton {
  static let listPlateEdge = UIColor { traits in
    UIColor.white.withAlphaComponent(traits.userInterfaceStyle == .dark ? 0.17 : 0.68)
  }

  var menuVisibilityChanged: ((Bool, Int) -> Void)?
  private var menuGeneration = 0
  private var outsideCapture: UIControl?
  private var choiceFeedbackEnabled = false
  private var iconFeedbackOnly = false
  private var flatIconInset: CGFloat?
  private var forwardedPressed = false
  private var lastFeedbackSize = CGSize.zero

  func configureChoiceFeedback(_ enabled: Bool, iconOnly: Bool = false, flatInset: CGFloat? = nil) {
    guard enabled != choiceFeedbackEnabled || iconOnly != iconFeedbackOnly ||
      flatInset != flatIconInset else { return }
    choiceFeedbackEnabled = enabled
    iconFeedbackOnly = iconOnly
    flatIconInset = flatInset
    if enabled {
      configurationUpdateHandler = { [weak self] _ in self?.updateChoiceFeedback() }
    } else {
      configurationUpdateHandler = nil
      forwardedPressed = false
      titleLabel?.layer.removeAllAnimations()
      imageView?.layer.removeAllAnimations()
      titleLabel?.transform = .identity
      imageView?.transform = .identity
    }
  }

  func setForwardedPressed(_ pressed: Bool) {
    guard choiceFeedbackEnabled else { return }
    let next = pressed && isEnabled
    guard next != forwardedPressed else { return }
    forwardedPressed = next
    setNeedsUpdateConfiguration()
  }

  private func updateChoiceFeedback() {
    guard choiceFeedbackEnabled, var config = configuration else { return }
    if !isEnabled { forwardedPressed = false }
    let held = isEnabled && (forwardedPressed || isHighlighted)
    let shift: CGFloat = held && !UIAccessibility.isReduceMotionEnabled ? 1 : 0
    if let inset = flatIconInset {
      // Keep the button and its hit target still while the painted plate sinks.
      config.background.backgroundInsets = NSDirectionalEdgeInsets(top: inset + shift,
        leading: inset, bottom: inset - shift, trailing: inset)
      config.baseBackgroundColor = held ? .secondarySystemFill : .tertiarySystemFill
      config.background.strokeColor = isFocused ? tintColor : Self.listPlateEdge
      config.background.strokeWidth = isFocused ? 1.5 : 0.5
      configuration = config
    } else if !iconFeedbackOnly {
      // Text choices highlight around their fitted title, not the value column.
      let fitted = sizeThatFits(CGSize(width: 10000, height: 10000))
      let spare = max(0, bounds.width - max(44, fitted.width))
      let leading = contentHorizontalAlignment == .trailing ? spare : spare / 2
      let trailing = contentHorizontalAlignment == .trailing ? 0 : spare / 2
      config.background.backgroundInsets = NSDirectionalEdgeInsets(top: 0,
        leading: leading, bottom: 0, trailing: trailing)
      config.background.backgroundColor = held ? .secondarySystemFill : .clear
      configuration = config
    }
    // Icon menus retain UIKit's glass configuration, background and plate inset.
    // Their ordinary UIButton highlight remains owned by the native control.
    // Move only visible content, never the platform-view frame or its material.
    let transform = CGAffineTransform(translationX: 0, y: shift)
    let changes: () -> Void = {
      self.titleLabel?.transform = transform
      self.imageView?.transform = transform
    }
    if window == nil || UIAccessibility.isReduceMotionEnabled { changes() }
    else {
      UIView.animate(withDuration: 0.12, delay: 0,
        options: [.beginFromCurrentState, .allowUserInteraction], animations: changes)
    }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    if choiceFeedbackEnabled, bounds.size != lastFeedbackSize {
      lastFeedbackSize = bounds.size
      setNeedsUpdateConfiguration()
    }
  }

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
    if window == nil {
      outsideCapture?.removeFromSuperview(); outsideCapture = nil
      setForwardedPressed(false)
    }
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

#if targetEnvironment(simulator)
/// Opt-in, offscreen UIKit fixture. No page navigation, account reads, app
/// installation or device-test cleanup. Only constant labels enter the file.
private func runSettingsControlsProbe(messenger: FlutterBinaryMessenger) {
  var rows = [[String: Any]]()
  var identifier: Int64 = -9000
  for dark in [false, true] {
    for selectionIndicator in [false, true] {
      for fontSize in [16.0, 24.0, 32.0] {
        for title in ["发现", "按功能返回", "Automatic"] {
          let font = UIFont.systemFont(ofSize: fontSize)
          let textSize = (title as NSString).size(withAttributes: [.font: font])
          let oldWidth = max(44, textSize.width + max(40, 21 + fontSize))
          let height = max(44, textSize.height + 16)
          let width = fontSize == 16 ? 220.0 : 248.0
          let control = VideoControlView(frame: CGRect(x: 0, y: 0, width: width, height: height),
            id: identifier, arguments: ["label": title, "fontSize": fontSize,
              "selectionIndicator": selectionIndicator, "pressFeedback": true, "bare": true,
              "dark": dark], messenger: messenger)
          identifier -= 1
          guard let button = control.view() as? VideoMenuButton else { continue }
          button.layoutIfNeeded()
          button.configurationUpdateHandler?(button)
          button.layoutIfNeeded()
          let frame = button.frame
          let labelWidth = button.titleLabel?.bounds.width ?? 0
          let labelHeight = button.titleLabel?.bounds.height ?? 0
          let nativeFont = button.titleLabel?.attributedText?.attribute(.font,
            at: 0, effectiveRange: nil) as? UIFont ?? button.titleLabel?.font ?? font
          let actualText = (title as NSString).size(withAttributes: [.font: nativeFont])
          let ideal = button.sizeThatFits(CGSize(width: 10000, height: 10000))
          let legacy = UIButton(type: .system)
          var legacyConfig = button.configuration!
          legacyConfig.titleLineBreakMode = .byWordWrapping
          legacyConfig.background.backgroundInsets = .zero
          legacy.configuration = legacyConfig
          legacy.frame = CGRect(x: 0, y: 0, width: oldWidth, height: height)
          legacy.layoutIfNeeded()
          button.setForwardedPressed(true)
          button.configurationUpdateHandler?(button)
          button.layoutIfNeeded()
          let pressedColor = button.configuration?.background.backgroundColor?
            .resolvedColor(with: button.traitCollection).cgColor.alpha ?? 0
          let pressedOffset = button.titleLabel?.transform.ty ?? 0
          let frameStable = frame == button.frame
          var contentRect = button.titleLabel?.frame ?? .zero
          if let image = button.imageView, image.image != nil {
            contentRect = contentRect.union(image.frame)
          }
          let backgroundInsets = button.configuration!.background.backgroundInsets
          let backgroundMidX = (backgroundInsets.leading + button.bounds.width - backgroundInsets.trailing) / 2
          let feedbackAligned = abs(contentRect.midX - backgroundMidX) <= 1
          button.setForwardedPressed(false)
          button.configurationUpdateHandler?(button)
          button.layoutIfNeeded()
          let releasedColor = button.configuration?.background.backgroundColor?
            .resolvedColor(with: button.traitCollection).cgColor.alpha ?? 0
          let releasedOffset = button.titleLabel?.transform.ty ?? 0
          let fits = labelWidth >= actualText.width - 0.5
          let singleLine = labelHeight <= nativeFont.lineHeight + 1
          let expectedOffset = UIAccessibility.isReduceMotionEnabled ? 0.0 : 1.0
          rows.append(["label": title, "fontSize": fontSize, "dark": dark,
            "selectionIndicator": selectionIndicator, "feedbackAligned": feedbackAligned,
            "oldEstimatedWidth": oldWidth, "nativeIdealWidth": ideal.width,
            "legacyLabelWidth": legacy.titleLabel?.bounds.width ?? 0,
            "legacyLabelHeight": legacy.titleLabel?.bounds.height ?? 0,
            "availableWidth": width, "labelWidth": labelWidth,
            "actualTextWidth": actualText.width, "singleLine": singleLine,
            "fullLabelFits": fits, "frameStable": frameStable,
            "pressedOffset": pressedOffset, "pressedFillAlpha": pressedColor,
            "releasedOffset": releasedOffset, "releasedFillAlpha": releasedColor,
            "passed": fits && singleLine && frameStable && feedbackAligned && pressedColor > 0 &&
              abs(pressedOffset - expectedOffset) < 0.01 && releasedOffset == 0 && releasedColor == 0])
        }
      }
    }
  }
  let output: [String: Any] = ["build": Bundle.main.infoDictionary?["CFBundleVersion"] ?? "",
    "kind": "offscreen UIKit fixture; not page or motion acceptance",
    "allPassed": rows.count == 36 && rows.allSatisfy { $0["passed"] as? Bool == true },
    "rows": rows]
  if let data = try? JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]) {
    try? data.write(to: URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("breeze-settings-control-probe.json"), options: .atomic)
  }
}
#endif

@discardableResult
private func configureVideoControlButton(_ button: VideoMenuButton, _ args: [String: Any]) -> UIColor? {
  button.overrideUserInterfaceStyle = (args["dark"] as? Bool == true) ? .dark : .light
  let light = args["light"] as? Bool == true
  let accent = light ? UIColor.white : videoThemeColor(args["accent"])
  button.tintColor = accent
  var config: UIButton.Configuration
  let flatSurface = args["flatSurface"] as? Bool == true
  if args["bare"] as? Bool == true { config = .plain() }
  else if flatSurface {
    // Repeated list actions use a system fill without sampling the scrolling backdrop.
    config = .filled()
    config.baseBackgroundColor = .tertiarySystemFill
    config.background.strokeColor = VideoMenuButton.listPlateEdge
    config.background.strokeWidth = 0.5
  }
  else if #available(iOS 26.0, *) { config = .glass() }
  else {
    config = .tinted()
    config.baseBackgroundColor = accent
  }
  config.title = args["label"] as? String
  let size = (args["iconSize"] as? NSNumber)?.doubleValue ?? 18
  let playerControl = args["backgroundInset"] != nil
  if let symbol = args["symbol"] as? String, !symbol.isEmpty {
    if symbol == "breeze.more.vertical" || symbol == "breeze.more.on-cover" {
      let extent = CGFloat(size)
      let onCover = symbol == "breeze.more.on-cover"
      config.image = UIGraphicsImageRenderer(
        size: CGSize(width: extent, height: extent)
      ).image { context in
        context.cgContext.scaleBy(x: extent / 16, y: extent / 16)
        for position in [3.0, 6.75, 10.5] {
          let dot = UIBezierPath(ovalIn: CGRect(
            x: onCover ? position : 6.75,
            y: onCover ? 6.75 : position,
            width: 2.5, height: 2.5
          ))
          if onCover {
            UIColor.black.withAlphaComponent(0.7).setStroke()
            dot.lineWidth = 1.2
            dot.stroke()
          }
          (onCover ? UIColor.white : UIColor.black).setFill()
          dot.fill()
        }
      }.withRenderingMode(onCover ? .alwaysOriginal : .alwaysTemplate)
    } else if playerControl, let image = UIImage(systemName: symbol,
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
  // Update the same UIButton rather than replacing its platform view while
  // account data is refreshing. UIKit owns the activity animation.
  config.showsActivityIndicator = args["busy"] as? Bool == true
  if args["pressFeedback"] as? Bool == true {
    config.titleLineBreakMode = .byTruncatingTail
  }
  let alignment: UIControl.ContentHorizontalAlignment = args["selectionIndicator"] as? Bool == true
    ? .trailing : .center
  if button.contentHorizontalAlignment != alignment { button.contentHorizontalAlignment = alignment }
  let compactTextChoice = args["compactTextChoice"] as? Bool == true
  if args["selectionIndicator"] as? Bool == true {
    config.titleLineBreakMode = .byTruncatingTail
    config.image = UIImage(systemName: "chevron.up.chevron.down")
    config.imagePlacement = .trailing
    config.imagePadding = 5
    config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
      font: .systemFont(ofSize: (args["fontSize"] as? NSNumber)?.doubleValue ?? 16))
  } else if compactTextChoice {
    config.titleLineBreakMode = .byTruncatingTail
    config.image = UIImage(systemName: "chevron.down")
    config.imagePlacement = .trailing
    config.imagePadding = 4
    config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 10, weight: .medium)
  }
  config.contentInsets = playerControl
    ? NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
    : NSDirectionalEdgeInsets(top: 5, leading: 9, bottom: 5, trailing: 9)
  // Keep the UIButton/platform-view hit area intact. Only the visible plate
  // is inset, so a 44pt player control draws a 36pt material background.
  // Icon-only menus share the same plate inset as adjacent icon buttons.
  let backgroundInset = min(4, max(0, (args["backgroundInset"] as? NSNumber)?.doubleValue ?? 0))
  config.background.backgroundInsets = NSDirectionalEdgeInsets(
    top: backgroundInset, leading: backgroundInset,
    bottom: backgroundInset, trailing: backgroundInset)
  config.cornerStyle = .capsule
  // Floating actions sit over busy posters. Keep the system glass effect but
  // give its regular material a semantic fill for readable labels; there is
  // intentionally no glass bar or second effect view behind the buttons.
  if !flatSurface && args["readableSurface"] as? Bool == true {
    config.background.backgroundColor = UIColor.secondarySystemBackground
      .withAlphaComponent(UIAccessibility.isReduceTransparencyEnabled ? 1 : 0.82)
  }
  config.baseForegroundColor = light ? .white
    : flatSurface ? .label
      : (args["selectionIndicator"] as? Bool == true || args["secondaryForeground"] as? Bool == true)
        ? .secondaryLabel : accent ?? .label
  config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
    var attributes = incoming
    let fontSize = (args["fontSize"] as? NSNumber)?.doubleValue ?? 13
    attributes.font = .systemFont(ofSize: fontSize,
      weight: args["selectionIndicator"] as? Bool == true || compactTextChoice ? .regular : .semibold)
    return attributes
  }
  let enabled = args["enabled"] as? Bool ?? true
  button.isEnabled = enabled
  button.configureChoiceFeedback(args["pressFeedback"] as? Bool == true,
    iconOnly: args["iconPressFeedback"] as? Bool == true,
    flatInset: flatSurface ? CGFloat(backgroundInset) : nil)
  button.accessibilityLabel = args["tooltip"] as? String
  button.accessibilityValue = args["accessibilityValue"] as? String
  let selectedControl = args["controlSelected"] as? Bool == true
  if selectedControl {
    if args["bare"] as? Bool == true {
      config.background.backgroundColor = .tertiarySystemFill
    } else {
      config.background.strokeColor = accent ?? .label
      config.background.strokeWidth = 1
    }
  }
  button.configuration = config
  // A stored traits override must not retain UIKit's previous disabled bit
  // when an existing platform view becomes actionable (e.g. after decoding).
  var traits = button.accessibilityTraits
  traits.remove([.selected, .notEnabled])
  if selectedControl { traits.insert(.selected) }
  if !enabled { traits.insert(.notEnabled) }
  button.accessibilityTraits = traits
  return accent
}

/// Hosts adjacent UIKit buttons in one Flutter composition layer. Their appearance,
/// hit targets and accessibility elements still belong to the individual buttons.
private final class VideoIconGroupContainer: UIView {
  var orderedButtons: [VideoMenuButton] = []
  var rightToLeft = false

  override func layoutSubviews() {
    super.layoutSubviews()
    let extent: CGFloat = 44
    for (index, button) in orderedButtons.enumerated() {
      let offset = CGFloat(index) * extent
      let x = rightToLeft ? bounds.maxX - extent - offset : bounds.minX + offset
      button.frame = CGRect(x: x, y: bounds.midY - extent / 2, width: extent, height: extent)
    }
  }
}

private final class VideoIconGroupView: NSObject, FlutterPlatformView {
  private let container: VideoIconGroupContainer
  private let channel: FlutterMethodChannel
  private var buttons: [String: VideoMenuButton] = [:]
  private var definitions: [String: [String: Any]] = [:]

  init(frame: CGRect, id: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    container = VideoIconGroupContainer(frame: frame)
    channel = FlutterMethodChannel(name: "breeze.video.control.\(id)", binaryMessenger: messenger)
    super.init()
    container.isOpaque = false
    container.backgroundColor = .clear
    container.isAccessibilityElement = false
    configure(arguments as? [String: Any] ?? [:])
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "update" {
        self?.configure(call.arguments as? [String: Any] ?? [:])
        result(nil)
      } else if call.method == "setPressed", let value = call.arguments as? [String: Any],
        let id = value["id"] as? String, let pressed = value["pressed"] as? Bool {
        self?.buttons[id]?.setForwardedPressed(pressed)
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { container }

  private func configure(_ args: [String: Any]) {
    var nextDefinitions: [String: [String: Any]] = [:]
    var ordered: [VideoMenuButton] = []
    for definition in args["buttons"] as? [[String: Any]] ?? [] {
      guard let id = definition["id"] as? String, !id.isEmpty,
        nextDefinitions[id] == nil else { continue }
      let button: VideoMenuButton
      if let existing = buttons[id] {
        button = existing
      } else {
        button = VideoMenuButton(type: .system)
        button.addAction(UIAction { [weak self, weak button] _ in
          guard let self = self, let button = button, button.isEnabled,
            self.buttons[id] === button else { return }
          self.channel.invokeMethod("select", arguments: id)
        }, for: .primaryActionTriggered)
        container.addSubview(button)
        buttons[id] = button
      }
      // The platform creation reply can repeat the initial arguments.
      let previous = definitions[id] as NSDictionary?
      if previous?.isEqual(definition as NSDictionary) != true {
        configureVideoControlButton(button, definition)
      }
      nextDefinitions[id] = definition
      ordered.append(button)
    }
    for id in definitions.keys where nextDefinitions[id] == nil {
      buttons.removeValue(forKey: id)?.removeFromSuperview()
    }
    definitions = nextDefinitions
    container.rightToLeft = args["rtl"] as? Bool == true
    container.semanticContentAttribute = container.rightToLeft ? .forceRightToLeft : .forceLeftToRight
    container.orderedButtons = ordered
    container.accessibilityElements = ordered
    container.setNeedsLayout()
  }

  deinit { channel.setMethodCallHandler(nil) }
}

private final class VideoControlView: NSObject, FlutterPlatformView {
  private let button = VideoMenuButton(type: .system)
  private let channel: FlutterMethodChannel
  private var compactArguments: [String: Any]?
  private var compactMenu: VideoCompactMenu?
  private var compactGeneration = 0

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
      if self.compactArguments != nil { self.presentCompactMenu(); return }
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
      } else if call.method == "openMenu" {
        if self?.button.isEnabled == true { self?.presentCompactMenu() }
        result(nil)
      } else if call.method == "setPressed", let pressed = call.arguments as? Bool {
        self?.button.setForwardedPressed(pressed)
        result(nil)
      } else { result(FlutterMethodNotImplemented) }
    }
  }

  func view() -> UIView { button }

  private func dismissMenu() {
    compactMenu?.dismiss()
    button.dismissPresentedMenu()
  }

  private func presentCompactMenu() {
    guard compactMenu == nil, let arguments = compactArguments,
      let window = button.window else { return }
    compactGeneration += 1
    let generation = compactGeneration
    let menu = VideoCompactMenu(button: button, window: window, arguments: arguments,
      selected: { [weak self] value in
        self?.channel.invokeMethod("select", arguments: value)
      }, closed: { [weak self] in
        guard let self = self, self.compactGeneration == generation else { return }
        self.compactMenu = nil
        self.channel.invokeMethod("menuClosed", arguments: ["generation": generation])
      })
    compactMenu = menu
    menu.present(in: window)
    channel.invokeMethod("menuOpened", arguments: ["generation": generation])
  }

  private func configure(_ args: [String: Any]) {
    let accent = configureVideoControlButton(button, args)
    let selected = args["selected"] as? String
    let options = args["options"] as? [[String: String]] ?? []
    if args["compactPopup"] as? Bool == true, !options.isEmpty {
      compactArguments = args
      compactMenu?.overrideUserInterfaceStyle = button.overrideUserInterfaceStyle
      compactMenu?.updateAccentColor(accent)
      compactMenu?.updateLayoutArguments(fontSize: args["menuFontSize"] as? NSNumber,
        bottomInset: args["menuBottomInset"] as? NSNumber)
      button.showsMenuAsPrimaryAction = false
      button.menu = nil
      return
    }
    compactArguments = nil
    compactMenu?.dismiss(animated: false)
    button.showsMenuAsPrimaryAction = !options.isEmpty
    let actions = options.map { item in
      let image = item["symbol"].flatMap {
        UIImage(systemName: $0, withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .regular))
      }
      return UIAction(title: item["title"] ?? "", image: image, state: item["value"] == selected ? .on : .off) { [weak self] _ in
        self?.channel.invokeMethod("select", arguments: item["value"])
      }
    }
    if let groups = args["groups"] as? [[String]], !groups.isEmpty {
      let grouped = groups.compactMap { group -> UIMenu? in
        let members = options.enumerated().compactMap { index, option in
          group.contains(option["value"] ?? "") ? actions[index] : nil
        }
        return members.isEmpty ? nil : UIMenu(options: .displayInline, children: members)
      }
      button.menu = grouped.isEmpty ? nil : UIMenu(children: grouped)
    } else if let choiceValues = args["choiceValues"] as? [String] {
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
    compactMenu?.dismiss(animated: false)
    dismissMenu()
    channel.setMethodCallHandler(nil)
  }
}

/// Command menus are anchored below their trigger. UIKit's stock UIMenu owns
/// its minimum width and may cover the trigger; this small native glass layer
/// retains system materials while sizing from the actual command labels.
private final class VideoCompactMenu: UIControl {
  private struct Row {
    let option: [String: String]
    let action: UIButton
    let label: UILabel
    let detail: UILabel?
    let icon: UIImageView?
    let check: UIImageView?
    let badge: UILabel?
    let badgeBackground: UIView?
    let separator: UIView?
  }

  private let panel = UIView()
  private let scroll = UIScrollView()
  private let material: UIVisualEffectView
  private weak var anchorButton: UIButton?
  private var panelSize: CGSize = .zero
  private var rows: [Row] = []
  private let textLeft: CGFloat
  private let menuRtl: Bool
  private let copyConfirmation: String
  private var copyNotice: UILabel?
  private var copyNoticeDismissal: DispatchWorkItem?
  private var menuFontSize: CGFloat = 17
  private var measuredAvailableWidth: CGFloat?
  private var needsRowMeasurement = true
  private var bottomInset: CGFloat = 0
  private let onChoose: (String) -> Void
  private let closed: () -> Void
  private let selectAfterDismissal: Set<String>
  private var closing = false
  private var selection: String?

  init(button: UIButton, window: UIWindow, arguments: [String: Any],
    selected: @escaping (String) -> Void, closed: @escaping () -> Void) {
    anchorButton = button
    self.onChoose = selected
    self.closed = closed
    selectAfterDismissal = Set(arguments["selectAfterDismissal"] as? [String] ?? [])
    menuRtl = arguments["menuRtl"] as? Bool == true
    copyConfirmation = arguments["copyConfirmation"] as? String ?? "Copied"
    let copyActionLabel = arguments["copyActionLabel"] as? String ?? "Copy"
    let options = arguments["options"] as? [[String: String]] ?? []
    let groups = arguments["groups"] as? [[String]] ?? []
    let checked = arguments["selected"] as? String
    textLeft = options.contains { !($0["symbol"] ?? "").isEmpty } ? 48 : 16
    // Standard effects follow accessibility preferences in place. A manual
    // nil-effect snapshot would stay opaque after Reduce Transparency changes.
    if #available(iOS 26.0, *) {
      material = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
    } else {
      material = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    }
    super.init(frame: window.bounds)
    updateLayoutArguments(fontSize: arguments["menuFontSize"] as? NSNumber,
      bottomInset: arguments["menuBottomInset"] as? NSNumber)
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange(_:)),
      name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange(_:)),
      name: UIResponder.keyboardWillHideNotification, object: nil)
    autoresizingMask = [.flexibleWidth, .flexibleHeight]
    overrideUserInterfaceStyle = button.overrideUserInterfaceStyle
    accessibilityViewIsModal = true
    addAction(UIAction { [weak self] _ in self?.dismiss() }, for: .touchUpInside)
    panel.layer.shadowColor = UIColor.black.cgColor
    panel.layer.shadowOpacity = 0.14
    panel.layer.shadowRadius = 14
    panel.layer.shadowOffset = CGSize(width: 0, height: 5)
    addSubview(panel)
    material.layer.cornerRadius = 24
    material.clipsToBounds = true
    material.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    panel.addSubview(material)
    scroll.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    scroll.alwaysBounceVertical = false
    material.contentView.addSubview(scroll)
    var previousGroup: Int?
    for option in options {
      let group = groups.firstIndex { $0.contains(option["value"] ?? "") }
      var separator: UIView?
      if let previousGroup = previousGroup, let group = group, previousGroup != group {
        let line = UIView()
        line.backgroundColor = .separator
        scroll.addSubview(line)
        separator = line
      }
      previousGroup = group
      let action = UIButton(type: .system)
      action.accessibilityLabel = [option["title"], option["detail"]].compactMap { $0 }.joined(separator: ", ")
      action.accessibilityIdentifier = "video-menu.\(option["value"] ?? "")"
      let label = UILabel()
      label.text = option["title"]
      label.textColor = .label
      label.numberOfLines = 0
      if menuRtl { label.textAlignment = .right }
      action.addSubview(label)
      let detail = option["detail"].map { text in
        let detail = UILabel()
        detail.text = text
        detail.textColor = .secondaryLabel
        detail.numberOfLines = 0
        action.addSubview(detail)
        return detail
      }
      var rowIcon: UIImageView?
      if let symbol = option["symbol"], !symbol.isEmpty {
        let icon = UIImageView(image: UIImage(systemName: symbol,
          withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .regular)))
        icon.contentMode = .scaleAspectFit
        icon.tintColor = .label
        action.addSubview(icon)
        rowIcon = icon
      }
      var rowCheck: UIImageView?
      if option["value"] == checked {
        action.accessibilityTraits.insert(.selected)
        let check = UIImageView(image: UIImage(systemName: "checkmark"))
        check.contentMode = .scaleAspectFit
        check.tintColor = .label
        action.addSubview(check)
        rowCheck = check
      }
      var rowBadge: UILabel?
      var rowBadgeBackground: UIView?
      if let badgeText = option["badge"], !badgeText.isEmpty {
        let badge = UILabel()
        badge.text = badgeText
        badge.textColor = .label
        badge.textAlignment = .center
        badge.numberOfLines = 0
        let background = UIView()
        background.isUserInteractionEnabled = false
        background.addSubview(badge)
        action.addSubview(background)
        action.accessibilityValue = badgeText
        rowBadge = badge
        rowBadgeBackground = background
      }
      if let copyText = option["copyText"], !copyText.isEmpty {
        let press = UILongPressGestureRecognizer(target: self, action: #selector(copyOnLongPress(_:)))
        press.cancelsTouchesInView = true
        action.addGestureRecognizer(press)
        action.accessibilityCustomActions = [
          UIAccessibilityCustomAction(name: copyActionLabel) { [weak self] _ in
            self?.copyOption(copyText) ?? false
          }
        ]
      }
      action.addAction(UIAction { [weak self] _ in
        guard let self = self, !self.closing else { return }
        self.selection = option["value"]
        self.dismiss()
      }, for: .touchUpInside)
      action.addAction(UIAction { [weak action] _ in action?.backgroundColor = .tertiarySystemFill }, for: .touchDown)
      action.addAction(UIAction { [weak action] _ in action?.backgroundColor = .clear },
        for: [.touchUpInside, .touchUpOutside, .touchCancel])
      scroll.addSubview(action)
      rows.append(Row(option: option, action: action, label: label, detail: detail,
        icon: rowIcon, check: rowCheck, badge: rowBadge,
        badgeBackground: rowBadgeBackground, separator: separator))
    }
    updateAccentColor(arguments["light"] as? Bool == true
      ? .white : videoThemeColor(arguments["accent"]))
  }

  @objc private func copyOnLongPress(_ gesture: UILongPressGestureRecognizer) {
    guard gesture.state == .began,
      let action = gesture.view as? UIButton,
      let row = rows.first(where: { $0.action === action }),
      let text = row.option["copyText"] else { return }
    action.backgroundColor = .clear
    _ = copyOption(text)
  }

  private func copyOption(_ text: String) -> Bool {
    guard !closing, window != nil, !text.isEmpty else { return false }
    UIPasteboard.general.string = text
    showCopyNotice()
    UINotificationFeedbackGenerator().notificationOccurred(.success)
    UIAccessibility.post(notification: .announcement, argument: copyConfirmation)
    return true
  }

  private func showCopyNotice() {
    copyNoticeDismissal?.cancel()
    let notice = copyNotice ?? UILabel()
    notice.text = copyConfirmation
    notice.font = UIFont.systemFont(ofSize: menuFontSize * 0.88, weight: .semibold)
    notice.textAlignment = .center
    notice.textColor = .label
    notice.backgroundColor = .secondarySystemGroupedBackground
    notice.layer.cornerRadius = 16
    notice.layer.cornerCurve = .continuous
    notice.layer.borderWidth = 1 / traitCollection.displayScale
    notice.layer.borderColor = UIColor.separator.resolvedColor(with: traitCollection).cgColor
    notice.clipsToBounds = true
    notice.isUserInteractionEnabled = false
    notice.isAccessibilityElement = false
    notice.numberOfLines = 0
    if copyNotice == nil {
      addSubview(notice)
      copyNotice = notice
    }
    setNeedsLayout()

    let dismissal = DispatchWorkItem { [weak self] in
      self?.copyNotice?.removeFromSuperview()
      self?.copyNotice = nil
      self?.copyNoticeDismissal = nil
    }
    copyNoticeDismissal = dismissal
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: dismissal)
  }

  func updateAccentColor(_ color: UIColor?) {
    for row in rows {
      row.check?.tintColor = color ?? .label
      row.badgeBackground?.backgroundColor = UIColor { traits in
        guard let color else { return UIColor.tertiarySystemFill.resolvedColor(with: traits) }
        return color.resolvedColor(with: traits).withAlphaComponent(0.16)
      }
    }
  }

  func updateLayoutArguments(fontSize: NSNumber?, bottomInset: NSNumber?) {
    let value = CGFloat(fontSize?.doubleValue ?? 17)
    let nextSize = value.isFinite ? max(12, value) : 17
    if nextSize != menuFontSize {
      menuFontSize = nextSize
      needsRowMeasurement = true
    }
    updateBottomInset(bottomInset)
  }

  private func measureRows(availableWidth: CGFloat) {
    let font = UIFont.systemFont(ofSize: menuFontSize)
    let detailFont = UIFont.monospacedDigitSystemFont(ofSize: menuFontSize * 14 / 17, weight: .regular)
    let badgeFont = UIFont.systemFont(ofSize: menuFontSize * 0.76, weight: .semibold)
    func width(of text: String, font: UIFont) -> CGFloat {
      (text as NSString).size(withAttributes: [.font: font]).width
    }
    func height(of text: String, font: UIFont, width: CGFloat) -> CGFloat {
      ceil((text as NSString).boundingRect(
        with: CGSize(width: width, height: .greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font], context: nil).height)
    }
    let measuredBadgeWidth = rows.compactMap(\.badge?.text).map { width(of: $0, font: badgeFont) }.max() ?? 0
    let badgeWidth = measuredBadgeWidth > 0
      ? min(ceil(measuredBadgeWidth + 16), availableWidth * 0.36) : 0
    let badgeHorizontalPadding = min(8, badgeWidth * 0.16)
    let badgeTextWidth = max(1, badgeWidth - badgeHorizontalPadding * 2)
    let checkWidth: CGFloat = rows.contains { $0.check != nil } ? 20 : 0
    let sharesRow = rows.contains { $0.badge != nil && $0.check != nil }
    let accessoryWidth = sharesRow ? badgeWidth + 12 + checkWidth : max(badgeWidth, checkWidth)
    let trailing: CGFloat = 16 + (accessoryWidth > 0 ? accessoryWidth + 12 : 0)
    let detailWidth = ceil(rows.compactMap(\.detail?.text).map { width(of: $0, font: detailFont) }.max() ?? 0)
    let stackDetails = detailWidth > 0 &&
      availableWidth - textLeft - trailing - detailWidth - 12 < width(of: "00000000", font: font)
    let detailSpace = detailWidth > 0 && !stackDetails ? detailWidth + 12 : 0
    let textWidth = rows.map { row in
      let titleWidth = width(of: row.label.text ?? "", font: font)
      guard let detail = row.detail?.text else { return max(0, titleWidth - detailSpace) }
      return stackDetails ? max(titleWidth, width(of: detail, font: detailFont)) : titleWidth
    }.max() ?? 0
    let width = min(availableWidth, ceil(textLeft + textWidth + trailing + detailSpace))
    let labelWidth = max(1, width - textLeft - trailing - detailSpace)
    func rowFrame(x: CGFloat, y: CGFloat, width extent: CGFloat, height: CGFloat) -> CGRect {
      CGRect(x: menuRtl ? width - x - extent : x, y: y, width: extent, height: height)
    }
    var y: CGFloat = 6
    for row in rows {
      if let line = row.separator {
        line.frame = CGRect(x: 16, y: y, width: max(0, width - 32), height: 0.5)
        y += 1
      }
      let inlineDetail = row.detail != nil && !stackDetails
      let titleWidth = inlineDetail ? labelWidth : max(1, width - textLeft - trailing)
      let titleHeight = inlineDetail ? ceil(font.lineHeight)
        : height(of: row.label.text ?? "", font: font, width: titleWidth)
      let detailHeight = row.detail?.text.map {
        height(of: $0, font: detailFont, width: inlineDetail ? detailWidth : titleWidth)
      } ?? 0
      let badgeHeight = row.badge?.text.map {
        height(of: $0, font: badgeFont, width: badgeTextWidth)
      } ?? 0
      let pillHeight = badgeHeight > 0 ? badgeHeight + 6 : 0
      let textHeight = stackDetails ? titleHeight + detailHeight : max(titleHeight, detailHeight)
      let rowHeight = max(44, max(textHeight, pillHeight) + 20)
      row.action.frame = CGRect(x: 0, y: y, width: width, height: rowHeight)
      row.label.font = font
      row.label.numberOfLines = inlineDetail ? 1 : 0
      row.label.lineBreakMode = inlineDetail ? .byTruncatingMiddle : .byWordWrapping
      let titleTop = stackDetails ? (rowHeight - textHeight) / 2 : (rowHeight - titleHeight) / 2
      row.label.frame = rowFrame(x: textLeft, y: titleTop, width: titleWidth, height: titleHeight)
      row.detail?.font = detailFont
      row.detail?.textAlignment = inlineDetail ? (menuRtl ? .left : .right) : (menuRtl ? .right : .left)
      row.detail?.frame = rowFrame(x: inlineDetail ? textLeft + titleWidth + 12 : textLeft,
        y: inlineDetail ? (rowHeight - detailHeight) / 2 : titleTop + titleHeight,
        width: inlineDetail ? detailWidth : titleWidth, height: detailHeight)
      row.icon?.frame = rowFrame(x: 16, y: (rowHeight - 22) / 2, width: 22, height: 22)
      row.check?.frame = rowFrame(x: width - 36, y: (rowHeight - 20) / 2, width: 20, height: 20)
      row.badge?.font = badgeFont
      row.badge?.frame = CGRect(x: badgeHorizontalPadding, y: 3, width: badgeTextWidth, height: max(0, pillHeight - 6))
      let badgeEnd = width - 16 - (row.check == nil ? 0 : 32)
      row.badgeBackground?.frame = rowFrame(x: badgeEnd - badgeWidth,
        y: (rowHeight - pillHeight) / 2, width: badgeWidth, height: pillHeight)
      row.badgeBackground?.layer.cornerRadius = pillHeight / 2
      y += rowHeight
    }
    panelSize = CGSize(width: width, height: y + 6)
    scroll.contentSize = panelSize
    measuredAvailableWidth = availableWidth
    needsRowMeasurement = false
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func accessibilityPerformEscape() -> Bool { dismiss(); return true }

  @objc private func keyboardWillChange(_ notification: Notification) {
    guard !closing else { return }
    if notification.name == UIResponder.keyboardWillHideNotification {
      bottomInset = 0
    } else if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
      let window = window {
      let keyboard = convert(frame, from: window.screen.coordinateSpace)
      let overlap = bounds.intersection(keyboard)
      bottomInset = !overlap.isNull && keyboard.maxY >= bounds.maxY ? overlap.height : 0
    }
    setNeedsLayout()
  }

  func updateBottomInset(_ value: NSNumber?) {
    let inset = CGFloat(value?.doubleValue ?? 0)
    bottomInset = inset.isFinite ? max(0, inset) : 0
    setNeedsLayout()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    guard let button = anchorButton, button.window === window else {
      dismiss(animated: false)
      return
    }
    let anchor = button.convert(button.bounds, to: self)
    let safe = safeAreaInsets
    let previousOffset = scroll.contentOffset
    let availableWidth = max(1, bounds.width - safe.left - safe.right - 24)
    if needsRowMeasurement || measuredAvailableWidth != availableWidth {
      measureRows(availableWidth: availableWidth)
    }
    let right = min(anchor.maxX, bounds.width - safe.right - 12)
    let safeTop = safe.top + 6
    // The full-window shield stays in place; only the panel avoids the keyboard.
    // Like the Flutter fallback, prefer below, then above when that has room.
    let safeBottom = max(safeTop, bounds.height - max(safe.bottom, bottomInset) - 12)
    let belowTop = min(safeBottom, max(safeTop, anchor.maxY + 6))
    let aboveBottom = min(safeBottom, max(safeTop, anchor.minY - 6))
    let below = safeBottom - belowTop
    let above = aboveBottom - safeTop
    let opensAbove = panelSize.height > below && above > below
    let availableHeight = opensAbove ? above : below
    let height = min(panelSize.height, availableHeight)
    let top = opensAbove ? aboveBottom - height : belowTop
    panel.frame = CGRect(x: max(safe.left + 12, right - panelSize.width), y: top,
      width: panelSize.width, height: height)
    material.frame = panel.bounds
    scroll.frame = material.contentView.bounds
    let inset = scroll.adjustedContentInset
    let minY = -inset.top
    let maxY = max(minY, scroll.contentSize.height - scroll.bounds.height + inset.bottom)
    let minX = -inset.left
    let maxX = max(minX, scroll.contentSize.width - scroll.bounds.width + inset.right)
    scroll.setContentOffset(CGPoint(x: min(maxX, max(minX, previousOffset.x)),
      y: min(maxY, max(minY, previousOffset.y))), animated: false)
    panel.layer.shadowPath = UIBezierPath(roundedRect: panel.bounds, cornerRadius: 24).cgPath
    if let notice = copyNotice {
      let size = notice.sizeThatFits(CGSize(width: max(1, availableWidth - 28), height: .greatestFiniteMagnitude))
      let width = min(availableWidth, ceil(size.width) + 28)
      let height = ceil(size.height) + 18
      let top = safe.top + 8
      let y = panel.frame.minY >= top + height + 6 ? top : max(top, safeBottom - height - 6)
      notice.frame = CGRect(x: (bounds.width - width) / 2, y: y, width: width, height: height)
    }
  }

  func present(in window: UIWindow) {
    window.addSubview(self)
    layoutIfNeeded()
    panel.alpha = 0
    UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.16,
      animations: { self.panel.alpha = 1 })
    UIAccessibility.post(notification: .screenChanged, argument: panel)
  }

  func dismiss(animated: Bool = true) {
    guard !closing else { return }
    closing = true
    copyNoticeDismissal?.cancel()
    copyNotice?.removeFromSuperview()
    let value = selection
    selection = nil
    let waitsForDismissal = value.map { selectAfterDismissal.contains($0) } ?? false
    if let value, !waitsForDismissal { onChoose(value) }
    let finish = { [self] in
      // Keep the full-window touch shield until the panel has disappeared.
      removeFromSuperview()
      closed()
      if let value, waitsForDismissal { onChoose(value) }
    }
    if animated && !UIAccessibility.isReduceMotionEnabled {
      UIView.animate(withDuration: 0.12, animations: { self.panel.alpha = 0 },
        completion: { _ in finish() })
    } else { finish() }
  }

  deinit { NotificationCenter.default.removeObserver(self) }
}

/// Separate from the site browser: only an explicit user share action reaches
/// this channel. No cookies, private forms or diagnostic data enter the sheet.
/// A local config copy goes to Files. Report actual save/cancel, then remove
/// private temporary data. Configuration text never enters logs or requests.
private final class RoutingConfigExporter: NSObject, UIDocumentPickerDelegate {
  private let channel: FlutterMethodChannel
  private var completion: FlutterResult?
  private var directory: URL?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "breeze.routing.export", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "save" else { result(FlutterMethodNotImplemented); return }
      guard let self else { result("unavailable"); return }
      self.save(call.arguments as? [String: Any] ?? [:], result: result)
    }
  }

  private func save(_ args: [String: Any], result: @escaping FlutterResult) {
    guard completion == nil else { result("busy"); return }
    guard let text = args["contents"] as? String,
          text.utf8.count <= 3 * 1024 * 1024,
          !text.contains("\0"), text.range(of: "(?im)^(?:\\x{FEFF})?[ \\t]*\\[Rule\\][ \\t]*\\r?$", options: .regularExpression) != nil else {
      result("failed"); return
    }
    let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }.flatMap { $0.windows }
    guard let root = windows.first(where: { $0.isKeyWindow })?.rootViewController else {
      result("unavailable"); return
    }
    var presenter = root
    while let next = presenter.presentedViewController { presenter = next }
    guard presenter.viewIfLoaded?.window != nil, !presenter.isBeingDismissed,
          !(presenter is UIAlertController), !(presenter is UIDocumentPickerViewController) else {
      result("busy"); return
    }
    do {
      let folder = FileManager.default.temporaryDirectory.appendingPathComponent("BreezeRoutingExport", isDirectory: true)
      try? FileManager.default.removeItem(at: folder)
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      directory = folder
      let file = folder.appendingPathComponent("Breeze-Shadowrocket.conf")
      try Data(text.utf8).write(to: file, options: [.atomic, .completeFileProtection])
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      var protectedFolder = folder
      try protectedFolder.setResourceValues(values)
      let picker = UIDocumentPickerViewController(forExporting: [file], asCopy: true)
      picker.overrideUserInterfaceStyle = (args["dark"] as? Bool == true) ? .dark : .light
      picker.delegate = self
      completion = result
      presenter.present(picker, animated: !UIAccessibility.isReduceMotionEnabled)
    } catch {
      cleanup()
      result("failed")
    }
  }

  private func cleanup() {
    if let directory { try? FileManager.default.removeItem(at: directory) }
    directory = nil
  }
  private func finish(_ status: String) {
    let result = completion
    completion = nil
    cleanup()
    result?(status)
  }
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    finish(urls.isEmpty ? "cancelled" : "saved")
  }
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { finish("cancelled") }
  deinit { cleanup(); channel.setMethodCallHandler(nil) }
}

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

  private func isPublicVideoPage(_ url: URL) -> Bool {
    guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
    let detailPatterns = [
      "^/voddetail/[1-9][0-9]{0,14}\\.html$",
      "^/index\\.php/vod/detail/id/[1-9][0-9]{0,14}\\.html$",
      "^/vod/[1-9][0-9]{0,14}/$",
      "^/videos/[A-Za-z0-9_-]{1,64}$",
      "^/anime/[a-f0-9]{16,64}\\.html$",
    ]
    if detailPatterns.contains(where: { parts.percentEncodedPath.range(of: $0, options: .regularExpression) != nil }) {
      return parts.query == nil || parts.query?.isEmpty == true
    }
    guard parts.percentEncodedPath == "/watch", let queries = parts.queryItems, queries.count == 1,
          queries[0].name == "v", let id = queries[0].value else { return false }
    return id.range(of: "^[0-9]+$", options: .regularExpression) != nil
  }

  private func share(_ args: [String: Any], result: @escaping FlutterResult) {
    guard active == nil else { result("busy"); return }
    guard let raw = args["url"] as? String, raw.count <= 2000,
          let url = URL(string: raw), url.scheme == "https", url.host?.isEmpty == false,
          url.user == nil, url.password == nil, url.port == nil || url.port == 443,
          url.fragment == nil, isPublicVideoPage(url) else {
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
