#if DEBUG
import Flutter
import UIKit
import QuartzCore

/// Opt-in geometry only. No view descriptions, labels, image data or WebKit
/// contents are inspected. There is no timer until Dart explicitly requests it.
final class NativeCompositionDiagnostics {
  private let channel: FlutterMethodChannel
  private let logQueue = DispatchQueue(label: "breeze.native-composition.log")
  private var requests = 0
  private var serial = 0
  private static let prefix = "BREEZE_NATIVE_UI_LAYER "
  private static let offsets = [0, 100, 250, 500]

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "breeze.native-composition.capture", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "capture" else { result(FlutterMethodNotImplemented); return }
      guard let self = self, let args = call.arguments as? [String: Any],
            let event = args["event"] as? String,
            ["route-added", "native-scene-audit"].contains(event) else {
        result(nil); return
      }
      let metadata = self.metadata(args, event: event)
      DispatchQueue.main.async { [weak self] in self?.schedule(metadata) }
      result(nil)
    }
  }

  deinit { channel.setMethodCallHandler(nil) }

  private func metadata(_ args: [String: Any], event: String) -> [String: Any] {
    var safe: [String: Any] = ["trigger": event]
    for key in ["request", "routeEpoch"] {
      if let value = args[key] as? Int, value >= 0 { safe[key] = value }
    }
    if let phase = args["phase"] as? String, phase.utf8.count <= 160,
       phase.range(of: "^(completed|dismissed|forward|reverse|none)(\\|(completed|dismissed|forward|reverse|none))*$", options: .regularExpression) != nil {
      safe["phase"] = phase
    }
    return safe
  }

  private func schedule(_ metadata: [String: Any]) {
    guard requests < 32 else { return }
    requests += 1
    let request = requests
    for offset in Self.offsets {
      DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(offset)) { [weak self] in
        self?.capture(metadata, request: request, offset: offset)
      }
    }
  }

  private func type(_ object: NSObject) -> String {
    String(NSStringFromClass(Swift.type(of: object)).prefix(96))
  }

  private func number(_ value: CGFloat) -> Any {
    if !value.isFinite { return NSNull() }
    return (Double(value) * 1000).rounded() / 1000
  }

  private func rect(_ value: CGRect) -> [Any] {
    [number(value.origin.x), number(value.origin.y), number(value.width), number(value.height)]
  }

  private func engineID(_ view: UIView) -> String? {
    guard let id = view.accessibilityIdentifier, id.utf8.count <= 100,
          id.range(of: "^platform_view\\[[0-9]+\\](\\.(overlay|overlay_view)\\[[0-9]+\\])?$", options: .regularExpression) != nil else { return nil }
    return id
  }

  private func isWebContent(_ view: UIView) -> Bool {
    let name = type(view)
    return name.hasPrefix("WK") || name.hasPrefix("_WK") || name.contains("WebKit")
  }

  private func flutterRoot() -> (UIView?, Int) {
    let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      .filter { $0.activationState == .foregroundActive }
      .flatMap { $0.windows }.filter { !$0.isHidden }
      .sorted { $0.isKeyWindow && !$1.isKeyWindow }
    var queue: [(UIView, Int)] = windows.prefix(4).map { ($0, 0) }
    var index = 0
    while index < queue.count && index < 128 {
      let (view, depth) = queue[index]; index += 1
      if type(view) == "FlutterView" { return (view, index) }
      if depth < 24 && !isWebContent(view) {
        for child in view.subviews where queue.count < 128 { queue.append((child, depth + 1)) }
      }
    }
    return (nil, index)
  }

  private func capture(_ metadata: [String: Any], request: Int, offset: Int) {
    serial += 1
    let capture = serial
    var records = [[String: Any]]()
    let (root, searched) = flutterRoot()
    var begin = metadata
    begin.merge(["event": "capture", "id": capture, "batch": request,
                 "offsetMs": offset, "uptimeMs": ProcessInfo.processInfo.systemUptime * 1000,
                 "rootFound": root != nil, "searched": searched]) { _, new in new }
    records.append(begin)
    guard let root = root else { publish(records); return }
    var queue: [(UIView, Int, Int, Int)] = [(root, -1, 0, 0)]
    var index = 0
    var truncated = false
    while index < queue.count && index < 128 {
      let (view, parent, sibling, depth) = queue[index]
      let node = index
      index += 1
      let layer = view.layer
      var geometry: [String: Any] = ["event": "view", "id": capture, "node": node,
        "parent": parent, "sibling": sibling, "depth": depth, "type": type(view),
        "frame": rect(view.frame), "bounds": rect(view.bounds),
        "global": rect(view.convert(view.bounds, to: root)), "hidden": view.isHidden,
        "alpha": number(view.alpha), "clips": view.clipsToBounds]
      if let id = engineID(view) { geometry["engine"] = id }
      records.append(geometry)
      if let presentation = layer.presentation() {
        records.append(["event": "presentation", "id": capture, "node": node,
          "frame": rect(presentation.frame), "bounds": rect(presentation.bounds),
          "global": rect(presentation.convert(presentation.bounds, to: root.layer.presentation() ?? root.layer)),
          "hidden": presentation.isHidden, "opacity": presentation.opacity,
          "z": number(presentation.zPosition)])
      }
      var backing: [String: Any] = ["event": "layer", "id": capture, "node": node,
        "type": type(layer), "frame": rect(layer.frame), "bounds": rect(layer.bounds),
        "hidden": layer.isHidden, "opacity": layer.opacity,
        "z": number(layer.zPosition), "contents": layer.contents != nil,
        "masksToBounds": layer.masksToBounds, "sublayers": layer.sublayers?.count ?? 0]
      if let metal = layer as? CAMetalLayer {
        backing["drawableSize"] = [number(metal.drawableSize.width), number(metal.drawableSize.height)]
      }
      records.append(backing)
      if let mask = view.mask {
        records.append(maskRecord(mask.layer, viewType: type(mask), capture: capture, node: node))
      } else if let mask = layer.mask {
        records.append(maskRecord(mask, viewType: nil, capture: capture, node: node))
      }
      let stopped = isWebContent(view)
      if stopped { records.append(["event": "web-root-stop", "id": capture, "node": node]) }
      if !stopped && depth < 24 {
        for (position, child) in view.subviews.enumerated() {
          guard queue.count < 128 else { truncated = true; break }
          queue.append((child, node, position, depth + 1))
        }
      } else if !stopped && !view.subviews.isEmpty { truncated = true }
    }
    records.append(["event": "capture-end", "id": capture, "nodes": index,
                    "truncated": truncated, "durationMs": ProcessInfo.processInfo.systemUptime * 1000 - (begin["uptimeMs"] as? Double ?? 0)])
    publish(records)
  }

  private func maskRecord(_ layer: CALayer, viewType: String?, capture: Int, node: Int) -> [String: Any] {
    let path = (layer as? CAShapeLayer)?.path
    var record: [String: Any] = ["event": "mask", "id": capture, "node": node,
      "type": type(layer), "frame": rect(layer.frame), "bounds": rect(layer.bounds),
      "contents": layer.contents != nil, "pathAvailable": path != nil]
    if let viewType = viewType { record["viewType"] = viewType }
    if let path = path { record["pathBounds"] = rect(path.boundingBoxOfPath) }
    return record
  }

  private func publish(_ records: [[String: Any]]) {
    logQueue.async {
      for record in records {
        guard JSONSerialization.isValidJSONObject(record),
              let data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else { continue }
        // One scalar record per line avoids unified-log truncation. Never
        // truncate JSON: an oversize record yields a safe bounded sentinel.
        if Self.prefix.utf8.count + data.count < 900 {
          NSLog("%@%@", Self.prefix, json)
        } else {
          let fallback: [String: Any] = ["event": "record-too-large", "id": record["id"] ?? 0,
                                         "node": record["node"] ?? -1]
          if let bytes = try? JSONSerialization.data(withJSONObject: fallback, options: [.sortedKeys]),
             let text = String(data: bytes, encoding: .utf8) { NSLog("%@%@", Self.prefix, text) }
        }
      }
    }
  }
}
#endif
