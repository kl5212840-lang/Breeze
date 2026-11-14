import BackgroundTasks
import Flutter
import UIKit

/// A user-initiated continued processing request. Transfer and queue ownership
/// stay with their existing writers; this bridge only holds the system activity.
final class ContinuedDownloadActivity {
  private static let suffix = ".download.continued."
  private static let scopes: Set<String> = ["comics", "video"]
  private let scheduler = BGTaskScheduler.shared
  private var prefix: String?
  private var channel: FlutterMethodChannel?
  private var entries: [String: Entry] = [:]

  private final class Entry {
    let scope: String
    let token: String
    let identifier: String
    var progress: Report
    var state = "submitting"
    var task: BGTask?
    var beginReplies: [FlutterResult] = []

    init(scope: String, token: String, identifier: String, progress: Report) {
      self.scope = scope
      self.token = token
      self.identifier = identifier
      self.progress = progress
    }
  }

  private struct Report {
    let title: String
    let subtitle: String
    let completed: Int64
    let total: Int64

    init?(_ args: [String: Any]) {
      guard let title = args["title"] as? String, Self.safeText(title, limit: 80),
        let subtitle = args["subtitle"] as? String, Self.safeText(subtitle, limit: 120),
        let completed = args["completed"] as? Int64, let total = args["total"] as? Int64,
        completed >= 0, total >= 1, completed <= total else { return nil }
      self.title = title
      self.subtitle = subtitle
      self.completed = completed
      self.total = total
    }

    private static func safeText(_ value: String, limit: Int) -> Bool {
      !value.trimmingCharacters(in: .whitespaces).isEmpty &&
        value.count <= limit && !value.contains("://") &&
        value.rangeOfCharacter(from: .controlCharacters) == nil
    }
  }

  func register() {
    guard #available(iOS 26.0, *), let bundle = Bundle.main.bundleIdentifier else { return }
    let prefix = bundle + Self.suffix
    let permitted = Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String]
    if permitted?.contains(prefix + "*") == true { self.prefix = prefix }
  }

  func attach(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "breeze.download.continued", binaryMessenger: messenger)
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(FlutterMethodNotImplemented); return }
      self.handle(call, result)
    }
  }

  private func status(_ state: String, supported: Bool = true, accepted: Bool = false) -> [String: Any] {
    ["supported": supported, "accepted": accepted, "state": state]
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    if call.method == "snapshot" {
      let scopes = entries.mapValues { entry -> [String: Any] in
        ["state": entry.state, "completed": entry.progress.completed, "total": entry.progress.total]
      }
      result(["supported": ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26, "scopes": scopes])
      return
    }
    guard #available(iOS 26.0, *) else {
      result(call.method == "begin" ? status("unsupported", supported: false) as Any : false)
      return
    }
    let args = call.arguments as? [String: Any] ?? [:]
    guard let scope = args["scope"] as? String, Self.scopes.contains(scope),
      let token = args["token"] as? String, !token.isEmpty, token.utf8.count <= 256 else {
      result(call.method == "begin" ? status("invalid") as Any : false)
      return
    }
    switch call.method {
    case "begin":
      guard let report = Report(args) else { result(status("invalid")); return }
      begin(scope: scope, token: token, report: report, reply: result)
    case "update":
      guard let entry = entries[scope], entry.token == token, entry.state != "stopping",
        let report = Report(args) else { result(false); return }
      entry.progress = report
      applyProgress(entry)
      result(true)
    case "end":
      guard let entry = entries[scope], entry.token == token, let success = args["success"] as? Bool else {
        result(false); return
      }
      finish(entry, success: success && entry.state != "stopping")
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @available(iOS 26.0, *)
  private func begin(scope: String, token: String, report: Report, reply: @escaping FlutterResult) {
    if let previous = entries[scope], previous.token == token {
      if previous.state == "submitting" {
        previous.beginReplies.append(reply)
      } else {
        reply(status(previous.state, accepted: true))
      }
      return
    }
    guard let prefix, UIApplication.shared.applicationState == .active else {
      reply(status("unavailable"))
      return
    }
    if let previous = entries[scope] { finish(previous, success: false) }
    // A system identifier is unique per generation and never contains a Dart
    // token, source, title, URL or other potentially sensitive data.
    let identifier = prefix + UUID().uuidString.lowercased()
    guard scheduler.register(forTaskWithIdentifier: identifier, using: .main, launchHandler: { [weak self] task in
      guard let self else { task.setTaskCompleted(success: false); return }
      self.launched(task)
    }) else {
      reply(status("rejected"))
      return
    }
    let entry = Entry(scope: scope, token: token, identifier: identifier, progress: report)
    entry.beginReplies.append(reply)
    entries[scope] = entry
    let request = BGContinuedProcessingTaskRequest(identifier: identifier, title: report.title, subtitle: report.subtitle)
    request.strategy = .queue
    if #available(iOS 27.0, *) {
      DispatchQueue.global(qos: .utility).async {
        self.scheduler.submitTaskRequest(request) { error in
          DispatchQueue.main.async { self.submitted(entry, succeeded: error == nil) }
        }
      }
    } else {
      do {
        try scheduler.submit(request)
        submitted(entry, succeeded: true)
      } catch {
        submitted(entry, succeeded: false)
      }
    }
  }

  private func submitted(_ entry: Entry, succeeded: Bool) {
    guard entries[entry.scope] === entry else {
      // Cancellation can beat asynchronous submission; re-cancel only this
      // retired request if it was registered after the first cancellation.
      if succeeded { scheduler.cancel(taskRequestWithIdentifier: entry.identifier) }
      return
    }
    if entry.state != "submitting" { return }
    if succeeded {
      entry.state = "queued"
      resolveBegin(entry, accepted: true)
    } else {
      entries.removeValue(forKey: entry.scope)
      entry.state = "rejected"
      resolveBegin(entry, accepted: false)
    }
  }

  private func resolveBegin(_ entry: Entry, accepted: Bool) {
    let replies = entry.beginReplies
    entry.beginReplies.removeAll()
    let response = status(entry.state, accepted: accepted)
    replies.forEach { $0(response) }
  }

  @available(iOS 26.0, *)
  private func launched(_ raw: BGTask) {
    guard let task = raw as? BGContinuedProcessingTask,
      let entry = entries.values.first(where: { $0.identifier == task.identifier }) else {
      raw.setTaskCompleted(success: false)
      return
    }
    if let active = entry.task {
      if active !== task { task.setTaskCompleted(success: false) }
      return
    }
    entry.task = task
    entry.state = "running"
    task.expirationHandler = { [weak self, weak entry] in
      DispatchQueue.main.async {
        guard let self, let entry else { return }
        self.expired(entry)
      }
    }
    applyProgress(entry)
    resolveBegin(entry, accepted: true)
  }

  @available(iOS 26.0, *)
  private func applyProgress(_ entry: Entry) {
    guard let task = entry.task as? BGContinuedProcessingTask else { return }
    let report = entry.progress
    task.progress.totalUnitCount = report.total
    task.progress.completedUnitCount = report.completed
    if task.title != report.title || task.subtitle != report.subtitle {
      task.updateTitle(report.title, subtitle: report.subtitle)
    }
  }

  private func expired(_ entry: Entry) {
    guard entries[entry.scope] === entry, entry.state == "running" else { return }
    entry.state = "stopping"
    guard let channel else { finish(entry, success: false); return }
    channel.invokeMethod("expired", arguments: ["scope": entry.scope, "token": entry.token]) { [weak self, weak entry] _ in
      DispatchQueue.main.async {
        guard let self, let entry else { return }
        self.finish(entry, success: false)
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self, weak entry] in
      guard let self, let entry else { return }
      self.finish(entry, success: false)
    }
  }

  private func finish(_ entry: Entry, success: Bool) {
    guard entries[entry.scope] === entry else { return }
    entries.removeValue(forKey: entry.scope)
    entry.state = "ended"
    resolveBegin(entry, accepted: false)
    if let task = entry.task {
      entry.task = nil
      task.expirationHandler = nil
      task.setTaskCompleted(success: success)
    } else {
      scheduler.cancel(taskRequestWithIdentifier: entry.identifier)
    }
  }
}
