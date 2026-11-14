import Foundation
import Flutter
import UIKit
import os

/// URLSession owns the requests. This journal owns bindings and file receipts.
final class BackgroundFileTransfer: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
  static let prefix = "breeze.download.files.v1."
  private static let log = Logger(subsystem: "breeze.download.files", category: "journal")
  private static let identifiers = [prefix + "wifi", prefix + "any"]

  private struct Binding: Codable, Equatable {
    let batchId: String
    let kind: String
    let source: String
    let scope: String
    let taskKey: String
    let attempt: Int
    let resourceId: String
    let manifestId: String
    let wifiOnly: Bool
    let expectedVersion: String?

    init?(_ input: [String: Any]) {
      guard let id = input["batchId"] as? String, Self.matches(id, "^[a-f0-9-]{24,64}$"),
        let kind = input["kind"] as? String, ["comic", "mp4"].contains(kind),
        let source = input["source"] as? String, !source.isEmpty, source.count <= 200,
        let scope = input["scope"] as? String, Self.hash(scope),
        let task = input["taskKey"] as? String, !task.isEmpty, task.utf8.count <= 4096,
        let attempt = input["attempt"] as? Int, attempt > 0,
        let resource = input["resourceId"] as? String, Self.hash(resource),
        let manifest = input["manifestId"] as? String, Self.hash(manifest),
        let wifi = input["wifiOnly"] as? Bool else { return nil }
      self.batchId = id
      self.kind = kind
      self.source = source
      self.scope = scope
      self.taskKey = task
      self.attempt = attempt
      self.resourceId = resource
      self.manifestId = manifest
      self.wifiOnly = wifi
      if let expected = input["expectedVersion"] as? String {
        guard expected.isEmpty || Self.hash(expected) else { return nil }
        self.expectedVersion = expected
      } else {
        self.expectedVersion = nil
      }
    }

    var session: String { BackgroundFileTransfer.prefix + (wifiOnly ? "wifi" : "any") }
    var fields: [String: Any] {
      var row: [String: Any] = ["batchId": batchId, "kind": kind, "source": source,
        "scope": scope, "taskKey": taskKey, "attempt": attempt, "resourceId": resourceId,
        "manifestId": manifestId, "wifiOnly": wifiOnly]
      row["expectedVersion"] = expectedVersion
      return row
    }

    static func hash(_ value: String) -> Bool { matches(value, "^[a-f0-9]{64}$") }
    static func matches(_ value: String, _ pattern: String) -> Bool {
      value.range(of: pattern, options: .regularExpression) != nil
    }
  }

  private struct Item: Codable {
    let index: Int
    let maxBytes: Int64
    var status = "queued"
    var bytes: Int64 = 0
    var reason: String?
    var httpStatus: Int?
    var terminal: Bool { ["staged", "failed", "cancelled"].contains(status) }
    var fields: [String: Any] {
      var row: [String: Any] = ["index": index, "status": status, "bytes": bytes]
      row["reason"] = reason
      row["httpStatus"] = httpStatus
      return row
    }
  }

  private struct Batch: Codable {
    let binding: Binding
    let concurrency: Int
    let created: Date
    var items: [Item]
    var cancelling = false
    var acknowledged = false
    var terminal: Bool { items.allSatisfy(\.terminal) }
    var status: String {
      if acknowledged || cancelling && terminal { return "cancelled" }
      if !terminal { return "running" }
      return items.allSatisfy { $0.status == "staged" } ? "staged" : "failed"
    }
  }

  private let fm = FileManager.default
  // The serial queue owns every session, delegate callback, and journal mutation.
  private let worker = OperationQueue()
  private let root: URL
  private let expectedRoot: URL
  private var sessions: [String: URLSession] = [:]
  private var batches: [String: Batch] = [:]
  private var tasks: [String: URLSessionDownloadTask] = [:]
  private var progress: [String: (bytes: Int64, total: Int64?)] = [:]
  private var pendingCompletions: [String: [Int: Item]] = [:]
  private var storageBlocked = Set<String>()
  private var storageRetryScheduled = false
  private var storageRetryCount = 0
  private var restored = Set<String>()
  private var completions: [String: [() -> Void]] = [:]
  private var eventsFinished = Set<String>()
  private var draining = Set<String>()
  private var deferredSubmissions: [String: [(FlutterMethodCall, FlutterResult)]] = [:]
  private var leases: [String: String] = [:]
  private var cancelWaiters: [String: [FlutterResult]] = [:]
  private var channel: FlutterMethodChannel?
  private var readable = false
  private var loaded = false
  private var lastNotification = Date.distantPast
  // Serialized alongside journal and task ownership on worker.
  private var foreground = false
  private var deferredByLifecycle = Set<String>()

  override init() {
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    root = support.appendingPathComponent("breeze-background-downloads-v1", isDirectory: true)
    expectedRoot = support.resolvingSymlinksInPath().appendingPathComponent("breeze-background-downloads-v1", isDirectory: true)
    super.init()
    worker.maxConcurrentOperationCount = 1
    worker.name = "breeze.download.files"
    worker.qualityOfService = .utility
    NotificationCenter.default.addObserver(self, selector: #selector(enteredBackground),
      name: UIApplication.didEnterBackgroundNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(enteredForeground),
      name: UIApplication.didBecomeActiveNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(enteredBackground),
      name: UIScene.didEnterBackgroundNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(enteredForeground),
      name: UIScene.didActivateNotification, object: nil)
  }

  @objc private func enteredBackground() { setForeground(false) }
  @objc private func enteredForeground() { setForeground(true) }

  private func setForeground(_ allowed: Bool) {
    worker.addOperation {
      self.foreground = allowed
      for batch in Array(self.batches.values) where !batch.terminal && !batch.cancelling {
        if allowed && batch.binding.kind == "mp4" {
          self.advance(batch.binding.batchId)
        } else {
          self.suspendRunning(batch)
        }
      }
    }
  }

  private func suspendRunning(_ batch: Batch) {
    for item in batch.items where item.status == "running" {
      let key = token(batch.binding.batchId, item.index)
      if let task = tasks[key], task.state == .running, deferredByLifecycle.insert(key).inserted {
        task.suspend()
      }
    }
  }

  deinit { NotificationCenter.default.removeObserver(self) }

  func start() {
    setForeground(UIApplication.shared.applicationState == .active)
    worker.addOperation { self.load() }
  }

  func backgroundEvents(_ identifier: String, completion: @escaping () -> Void) {
    worker.addOperation {
      self.load()
      guard Self.identifiers.contains(identifier), self.readable else {
        DispatchQueue.main.async(execute: completion)
        return
      }
      self.completions[identifier, default: []].append(completion)
      self.finishEvents(identifier)
    }
  }

  func attach(_ messenger: FlutterBinaryMessenger) {
    let bridge = FlutterMethodChannel(name: "breeze.download.files", binaryMessenger: messenger)
    channel = bridge
    bridge.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(false); return }
      self.worker.addOperation {
        self.load()
        self.handle(call, result)
      }
    }
  }

  private var journal: URL { root.appendingPathComponent("journal.json") }

  private func load() {
    guard !loaded else { return }
    loaded = true
    do {
      guard root.resolvingSymlinksInPath().path == expectedRoot.path else {
        throw CocoaError(.fileReadCorruptFile)
      }
      try fm.createDirectory(at: root, withIntermediateDirectories: true,
        attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
      var local = root
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try local.setResourceValues(values)
      if fm.fileExists(atPath: journal.path) {
        let attributes = try fm.attributesOfItem(atPath: journal.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular else {
          throw CocoaError(.fileReadCorruptFile)
        }
        let data = try Data(contentsOf: journal)
        guard data.count <= 4 * 1024 * 1024 else { throw CocoaError(.fileReadCorruptFile) }
        batches = try JSONDecoder().decode([String: Batch].self, from: data)
        guard batches.count <= 128, batches.allSatisfy({
          $0.key == $0.value.binding.batchId && Binding($0.value.binding.fields) != nil &&
            (1...8).contains($0.value.concurrency) && (1...500).contains($0.value.items.count) &&
            $0.value.items.enumerated().allSatisfy {
              $0.offset == $0.element.index && $0.element.maxBytes > 0 &&
                ["queued", "running", "staged", "failed", "cancelled"].contains($0.element.status)
            }
        }) else { throw CocoaError(.fileReadCorruptFile) }
      }
      readable = true
    } catch {
      readable = false
      loaded = false
      return
    }
    for identifier in Self.identifiers where sessions[identifier] == nil {
      openSession(identifier)
    }
  }

  private func openSession(_ identifier: String) {
    let configuration = URLSessionConfiguration.background(withIdentifier: identifier)
    configuration.allowsCellularAccess = identifier.hasSuffix(".any")
    configuration.sessionSendsLaunchEvents = true
    configuration.isDiscretionary = false
    configuration.httpCookieStorage = nil
    configuration.httpShouldSetCookies = false
    configuration.urlCredentialStorage = nil
    configuration.urlCache = nil
    configuration.timeoutIntervalForResource = 86400
    let session = URLSession(configuration: configuration, delegate: self, delegateQueue: worker)
    sessions[identifier] = session
    session.getAllTasks { all in
      self.worker.addOperation {
        guard self.sessions[identifier] === session else { return }
        self.restore(identifier, all)
      }
    }
  }

  private func write(_ next: [String: Batch]) throws {
    guard readable else { throw CocoaError(.fileWriteUnknown) }
    let data = try JSONEncoder().encode(next)
    guard data.count <= 4 * 1024 * 1024 else { throw CocoaError(.fileWriteOutOfSpace) }
    try data.write(to: journal, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    batches = next
  }

  private func update(_ batch: Batch) throws {
    var next = batches
    next[batch.binding.batchId] = batch
    try write(next)
  }

  private func reply(_ result: @escaping FlutterResult, _ value: Any?) {
    DispatchQueue.main.async { result(value) }
  }

  private func notify(force: Bool = true) {
    let now = Date()
    guard force || now.timeIntervalSince(lastNotification) >= 0.5 else { return }
    lastNotification = now
    DispatchQueue.main.async { self.channel?.invokeMethod("changed", arguments: nil) }
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard readable else { reply(result, FlutterError(code: "storage", message: nil, details: nil)); return }
    let input = call.arguments as? [String: Any] ?? [:]
    if call.method == "snapshot" {
      retryBlockedWrites()
      reply(result, batches.values.filter { !$0.acknowledged }.map { batch -> [String: Any] in
        var row = batch.binding.fields
        row["status"] = batch.status
        if storageBlocked.contains(batch.binding.batchId) { row["storageBlocked"] = true }
        row["items"] = batch.items.map { item -> [String: Any] in
          var fields = item.fields
          if !item.terminal, let count = progress[token(batch.binding.batchId, item.index)] {
            fields["bytes"] = count.bytes
            fields["total"] = count.total
          }
          return fields
        }
        return row
      })
      return
    }
    if call.method == "releaseStage", let lease = call.arguments as? String {
      leases.removeValue(forKey: lease)
      reply(result, nil)
      return
    }
    guard let binding = Binding(input) else { reply(result, false); return }
    let id = binding.batchId
    do {
      if call.method == "submit" {
        if draining.contains(binding.session) {
          deferredSubmissions[binding.session, default: []].append((call, result))
          return
        }
        reply(result, try submit(binding, input))
        return
      }
      guard var batch = batches[id] else {
        reply(result, call.method == "ack" || call.method == "cancel")
        return
      }
      guard batch.binding == binding else { reply(result, false); return }
      switch call.method {
      case "holdStage":
        guard !batch.cancelling, !batch.acknowledged, let i = input["index"] as? Int,
          batch.items.indices.contains(i), batch.items[i].status == "staged",
          let url = existingStage(id, i) else { reply(result, nil); return }
        let lease = UUID().uuidString
        leases[lease] = id
        reply(result, ["path": url.path, "lease": lease])
      case "linkVideoStage":
        guard binding.kind == "mp4", !batch.cancelling, !batch.acknowledged,
          batch.items.count == 1, batch.items[0].status == "staged",
          let source = existingStage(id, 0) else { reply(result, nil); return }
        let stageID = try linkVideoStage(source)
        reply(result, stageID)
      case "cancel":
        if leases.values.contains(id) { reply(result, false); return }
        batch.cancelling = true
        try update(batch)
        pendingCompletions.removeValue(forKey: id)
        storageBlocked.remove(id)
        cancelWaiters[id, default: []].append(result)
        for (key, task) in tasks where key.hasPrefix(id + ":") { task.cancel() }
        finishCancel(id)
      case "ack":
        guard batch.terminal, !leases.values.contains(id),
          !tasks.keys.contains(where: { $0.hasPrefix(id + ":") }) else { reply(result, false); return }
        batch.acknowledged = true
        try update(batch)
        try clear(batch)
        reply(result, true)
        notify()
      default: reply(result, FlutterMethodNotImplemented)
      }
    } catch {
      reply(result, FlutterError(code: "storage", message: nil, details: nil))
    }
  }

  private func submit(_ binding: Binding, _ input: [String: Any]) throws -> Bool {
    if let prior = batches[binding.batchId] {
      return prior.binding == binding && !prior.acknowledged
    }
    guard batches.count < 128, let session = sessions[binding.session],
      let limit = input["concurrency"] as? Int, (1...8).contains(limit),
      let rows = input["items"] as? [[String: Any]], !rows.isEmpty, rows.count <= 500,
      binding.kind != "mp4" || (rows.count == 1 && limit == 1),
      !batches.values.contains(where: {
        !$0.acknowledged && !$0.terminal &&
          $0.binding.kind == binding.kind && $0.binding.resourceId == binding.resourceId
      }) else { return false }
    var requests = [URLRequest]()
    var items = [Item]()
    for (index, row) in rows.enumerated() {
      guard row["index"] as? Int == index, let limit = row["maxBytes"] as? Int64,
        limit > 0, limit <= (binding.kind == "comic" ? 64 * 1024 * 1024 : 16 * 1024 * 1024 * 1024),
        let urlText = row["url"] as? String, urlText.count <= 8192,
        let url = URL(string: urlText), Self.publicHTTPS(url),
        url.query == nil, row["redirectPolicy"] as? String == "same-url",
        binding.kind != "mp4" || url.pathExtension.lowercased() == "mp4",
        let headers = row["headers"] as? [String: String], headers.count <= 6 else { return false }
      var request = URLRequest(url: url)
      request.allowsCellularAccess = !binding.wifiOnly
      for (key, value) in headers {
        guard Self.safeHeader(key, value) else { return false }
        request.setValue(value, forHTTPHeaderField: key)
      }
      requests.append(request)
      items.append(Item(index: index, maxBytes: limit))
    }
    var created = [URLSessionDownloadTask]()
    for (index, request) in requests.enumerated() {
      let task = session.downloadTask(with: request)
      task.taskDescription = token(binding.batchId, index)
      created.append(task)
    }
    do {
      try update(Batch(binding: binding, concurrency: limit, created: Date(), items: items))
    } catch {
      created.forEach { $0.cancel() }
      throw error
    }
    for task in created {
      if let token = task.taskDescription { tasks[token] = task }
    }
    advance(binding.batchId)
    notify()
    return true
  }

  private static func publicHTTPS(_ url: URL) -> Bool {
    guard url.scheme == "https", url.user == nil, url.password == nil, url.fragment == nil,
      url.port == nil || url.port == 443, let host = url.host?.lowercased(), host.contains("."),
      !host.hasSuffix(".local"), !host.hasSuffix(".localhost"),
      host.last?.isNumber == false else { return false }
    return Binding.matches(host, "^[a-z0-9.-]+$")
  }

  private static func safeHeader(_ key: String, _ value: String) -> Bool {
    guard value.count <= 2048,
      value.unicodeScalars.allSatisfy({ (32...126).contains($0.value) }) else { return false }
    switch key.lowercased() {
    case "accept": return value.count <= 200 && Binding.matches(value, "^[a-zA-Z0-9+*/.,;= -]+$")
    case "accept-language": return value.count <= 128 && Binding.matches(value, "^[a-zA-Z0-9*,;.= -]+$")
    case "x-requested-with": return ["XMLHttpRequest", "com.JMComic3.app"].contains(value)
    case "referer", "origin":
      guard let url = URL(string: value), publicHTTPS(url) else { return false }
      if key.lowercased() == "origin" { return url.query == nil && ["", "/"].contains(url.path) }
      if let parts = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
        return parts.allSatisfy { ["v", "line", "episode"].contains($0.name) && ($0.value?.count ?? 0) <= 300 }
      }
      return true
    case "user-agent":
      return value.count <= 512 && value.hasPrefix("Mozilla/5.0 (") &&
        Binding.matches(value, "^[a-zA-Z0-9 ().,/_:;+@-]+$")
    default: return false
    }
  }

  private func token(_ id: String, _ index: Int) -> String { id + ":" + String(index) }

  private func bindingFor(_ task: URLSessionTask, _ session: URLSession) -> (String, Int)? {
    guard let key = task.taskDescription, let separator = key.lastIndex(of: ":"),
      let index = Int(key[key.index(after: separator)...]) else { return nil }
    let id = String(key[..<separator])
    guard let batch = batches[id], !batch.acknowledged, batch.binding.session == session.configuration.identifier,
      batch.items.indices.contains(index), key == token(id, index) else { return nil }
    return (id, index)
  }

  private func acceptsCallback(_ task: URLSessionTask, key: String) -> Bool {
    // A completion may arrive before getAllTasks during background relaunch.
    // When an owner is already known, another task with its token cannot
    // retire that owner or provide bytes for it.
    guard let owner = tasks[key] else { return true }
    return owner === task
  }

  private func stage(_ id: String, _ index: Int) -> URL {
    root.appendingPathComponent(id + "-" + String(index) + ".data")
  }

  private func existingStage(_ id: String, _ index: Int) -> URL? {
    let url = stage(id, index)
    return (try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])).map {
      $0.isRegularFile == true && $0.isSymbolicLink != true ? url : nil
    } ?? nil
  }

  private func linkVideoStage(_ source: URL) throws -> String {
    let cache = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    let directory = cache.appendingPathComponent("breeze-video-staging", isDirectory: true)
    let canonical = cache.resolvingSymlinksInPath().appendingPathComponent("breeze-video-staging", isDirectory: true)
    guard directory.resolvingSymlinksInPath().path == canonical.path else {
      throw CocoaError(.fileWriteInvalidFileName)
    }
    try fm.createDirectory(at: directory, withIntermediateDirectories: true)
    let id = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    try fm.linkItem(at: source, to: directory.appendingPathComponent(id + ".mp4"))
    return id
  }

  private func stagedBytes(_ id: String, _ index: Int) -> Int64 {
    existingStage(id, index).flatMap {
      (try? fm.attributesOfItem(atPath: $0.path)[.size] as? NSNumber)?.int64Value
    } ?? 0
  }

  private func restore(_ identifier: String, _ all: [URLSessionTask]) {
    guard let session = sessions[identifier] else { return }
    for task in all {
      guard let download = task as? URLSessionDownloadTask, let (id, index) = bindingFor(task, session),
        let batch = batches[id], !batch.items[index].terminal, let key = task.taskDescription,
        tasks[key] == nil || tasks[key] === task else { task.cancel(); continue }
      tasks[key] = download
      if batch.cancelling { task.cancel() }
    }
    restored.insert(identifier)
    for batch in Array(batches.values) where batch.binding.session == identifier {
      if batch.acknowledged { try? clear(batch); continue }
      if batch.cancelling { finishCancel(batch.binding.batchId); continue }
      advance(batch.binding.batchId)
    }
    if eventsFinished.contains(identifier) { settleMissing(identifier) }
    finishEvents(identifier)
    drainIfIdle(identifier)
    notify()
  }

  private func drainIfIdle(_ identifier: String) {
    guard restored.contains(identifier), !draining.contains(identifier),
      !tasks.keys.contains(where: { key in
        guard let id = key.split(separator: ":").first else { return false }
        return batches[String(id)]?.binding.session == identifier
      }),
      batches.values.contains(where: {
        $0.binding.session == identifier && !$0.terminal && !$0.cancelling && !$0.acknowledged
      }), let session = sessions[identifier] else { return }
    draining.insert(identifier)
    // The invalidation delegate callback is ordered after all task callbacks.
    // This also supplies a barrier on ordinary foreground cold launch.
    session.finishTasksAndInvalidate()
  }

  private func settleMissing(_ identifier: String) {
    guard restored.contains(identifier) else { return }
    for original in Array(batches.values) where original.binding.session == identifier &&
      !original.cancelling && !original.acknowledged {
      guard pendingCompletions[original.binding.batchId] == nil else { continue }
      var batch = original
      let id = batch.binding.batchId
      var changed = false
      for item in batch.items where !item.terminal && tasks[token(id, item.index)] == nil {
        let bytes = stagedBytes(id, item.index)
        batch.items[item.index].bytes = bytes
        batch.items[item.index].status = bytes > 0 && bytes <= item.maxBytes ? "staged" : "failed"
        changed = true
      }
      if changed {
        do {
          try update(batch)
          advance(id)
        } catch {}
      }
    }
    notify()
  }

  private func advance(_ id: String) {
    guard pendingCompletions[id] == nil else { return }
    guard var batch = batches[id], !batch.cancelling, !batch.acknowledged else { return }
    guard foreground && batch.binding.kind == "mp4" else {
      suspendRunning(batch)
      return
    }
    var count = batch.items.filter { $0.status == "running" }.count
    var resuming = [URLSessionDownloadTask]()
    for item in batch.items where item.status == "running" {
      let key = token(id, item.index)
      if let task = tasks[key] {
        let deferred = deferredByLifecycle.remove(key) != nil
        if deferred || task.state == .suspended { task.resume() }
      }
    }
    for item in batch.items where count < batch.concurrency && item.status == "queued" {
      guard let task = tasks[token(id, item.index)] else { continue }
      count += 1
      batch.items[item.index].status = "running"
      resuming.append(task)
    }
    if !resuming.isEmpty {
      do {
        try update(batch)
        storageBlocked.remove(id)
        for task in resuming where task.state == .suspended { task.resume() }
      } catch {
        markStorageBlocked(id)
      }
    } else {
      storageBlocked.remove(id)
    }
  }

  private func markStorageBlocked(_ id: String) {
    if storageBlocked.insert(id).inserted {
      Self.log.error("Background download is waiting for a journal write")
      notify()
    }
    guard !storageRetryScheduled, storageRetryCount < 3 else { return }
    storageRetryScheduled = true
    storageRetryCount += 1
    let delay = Double(storageRetryCount)
    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) {
      self.worker.addOperation {
        self.storageRetryScheduled = false
        self.retryBlockedWrites()
      }
    }
  }

  private func retryBlockedWrites() {
    for id in Array(storageBlocked) {
      guard var batch = batches[id], !batch.cancelling, !batch.acknowledged else {
        pendingCompletions.removeValue(forKey: id)
        storageBlocked.remove(id)
        continue
      }
      if let receipts = pendingCompletions[id] {
        for (index, receipt) in receipts { batch.items[index] = receipt }
        do {
          try update(batch)
          pendingCompletions.removeValue(forKey: id)
          notify()
        } catch {
          markStorageBlocked(id)
          continue
        }
      }
      advance(id)
      drainIfIdle(batch.binding.session)
    }
    if storageBlocked.isEmpty { storageRetryCount = 0 }
  }

  private func finishCancel(_ id: String) {
    guard var batch = batches[id], batch.cancelling, restored.contains(batch.binding.session),
      !tasks.keys.contains(where: { $0.hasPrefix(id + ":") }) else { return }
    var succeeded = false
    do {
      for i in batch.items.indices {
        batch.items[i].status = "cancelled"
        batch.items[i].bytes = 0
      }
      try update(batch)
      try removeStages(batch)
      succeeded = true
    } catch {}
    for waiter in cancelWaiters.removeValue(forKey: id) ?? [] { reply(waiter, succeeded) }
    notify()
  }

  private func removeStages(_ batch: Batch) throws {
    for item in batch.items {
      let url = stage(batch.binding.batchId, item.index)
      if fm.fileExists(atPath: url.path) { try fm.removeItem(at: url) }
    }
  }

  private func clear(_ batch: Batch) throws {
    try removeStages(batch)
    var next = batches
    next.removeValue(forKey: batch.binding.batchId)
    try write(next)
  }

  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
    guard let (id, index) = bindingFor(downloadTask, session), let item = batches[id]?.items[index],
      !item.terminal, acceptsCallback(downloadTask, key: token(id, index)) else { return }
    if totalBytesWritten > item.maxBytes || totalBytesExpectedToWrite > item.maxBytes {
      downloadTask.cancel()
      return
    }
    let total = totalBytesExpectedToWrite > 0 && totalBytesExpectedToWrite >= totalBytesWritten
      ? totalBytesExpectedToWrite : nil
    progress[token(id, index)] = (totalBytesWritten, total)
    notify(force: false)
  }

  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    guard let (id, index) = bindingFor(downloadTask, session), let batch = batches[id],
      !batch.cancelling, !batch.items[index].terminal,
      acceptsCallback(downloadTask, key: token(id, index)),
      let response = downloadTask.response as? HTTPURLResponse, response.statusCode == 200,
      let url = response.url, Self.publicHTTPS(url),
      url == downloadTask.originalRequest?.url else { return }
    if batch.binding.kind == "mp4", let mime = response.mimeType?.lowercased(),
      !["video/mp4", "application/mp4", "application/octet-stream", "binary/octet-stream"].contains(mime) { return }
    let attributes = try? fm.attributesOfItem(atPath: location.path)
    guard let size = (attributes?[.size] as? NSNumber)?.int64Value,
      size > 0, size <= batch.items[index].maxBytes,
      response.expectedContentLength <= 0 || response.expectedContentLength == size else { return }
    let destination = stage(id, index)
    do {
      try fm.moveItem(at: location, to: destination)
      try fm.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
        ofItemAtPath: destination.path)
    } catch {
      // Completion checks the owned destination even if a prior callback
      // already moved the system file before process termination.
    }
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard let (id, index) = bindingFor(task, session), var batch = batches[id] else { return }
    let key = token(id, index)
    guard acceptsCallback(task, key: key), !batch.items[index].terminal,
      pendingCompletions[id]?[index] == nil else { return }
    tasks.removeValue(forKey: key)
    deferredByLifecycle.remove(key)
    progress.removeValue(forKey: key)
    if batch.cancelling {
      finishCancel(id)
      drainIfIdle(batch.binding.session)
      return
    }
    if !batch.items[index].terminal {
      let size = error == nil ? stagedBytes(id, index) : 0
      if size > 0 && size <= batch.items[index].maxBytes {
        batch.items[index].status = "staged"
        batch.items[index].bytes = size
      } else {
        batch.items[index].status = "failed"
        let response = task.response as? HTTPURLResponse
        batch.items[index].httpStatus = response?.statusCode
        let failure = error as NSError?
        if let responseURL = response?.url, responseURL != task.originalRequest?.url {
          batch.items[index].reason = "redirectRejected"
        } else if failure?.domain == NSURLErrorDomain, failure?.code == NSURLErrorTimedOut {
          batch.items[index].reason = "timeout"
        } else if failure?.domain == NSURLErrorDomain, let code = failure?.code,
          [NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost,
           NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost,
           NSURLErrorDNSLookupFailed].contains(code) {
          batch.items[index].reason = "network"
        } else if response?.statusCode == 403 {
          batch.items[index].reason = "httpForbidden"
        } else if response?.statusCode == 404 {
          batch.items[index].reason = "httpNotFound"
        } else if response?.statusCode == 200 {
          batch.items[index].reason = "mediaRejected"
        }
      }
      if pendingCompletions[id] != nil {
        pendingCompletions[id]?[index] = batch.items[index]
        retryBlockedWrites()
        return
      }
      do { try update(batch) } catch {
        pendingCompletions[id] = [index: batch.items[index]]
        markStorageBlocked(id)
        return
      }
    }
    advance(id)
    drainIfIdle(batch.binding.session)
    notify()
  }

  func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
    guard let identifier = session.configuration.identifier, sessions[identifier] === session,
      draining.contains(identifier) else { return }
    settleMissing(identifier)
    finishEvents(identifier)
    sessions.removeValue(forKey: identifier)
    draining.remove(identifier)
    restored.remove(identifier)
    openSession(identifier)
    for (call, result) in deferredSubmissions.removeValue(forKey: identifier) ?? [] {
      handle(call, result)
    }
  }

  func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    guard let identifier = session.configuration.identifier, sessions[identifier] === session else { return }
    eventsFinished.insert(identifier)
    retryBlockedWrites()
    settleMissing(identifier)
    finishEvents(identifier)
  }

  private func finishEvents(_ identifier: String) {
    guard restored.contains(identifier), eventsFinished.contains(identifier),
      let completions = completions.removeValue(forKey: identifier) else { return }
    eventsFinished.remove(identifier)
    DispatchQueue.main.async { completions.forEach { $0() } }
  }
}
