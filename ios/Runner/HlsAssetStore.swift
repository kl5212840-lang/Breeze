import Foundation
import CoreFoundation

/// Foundation-only ownership/transaction boundary. The presenter calls every
/// method on one serial IO queue. Apple-managed packages stay at Apple's URL.
final class HlsAssetStore {
  enum StoreError: Error { case invalidIndex, invalidMetadata, invalidPath, staleBinding, busy, missingPackage }
  private enum Phase: String, Codable { case staged, ready, retired }
  private enum RemovalPhase: String, Codable { case staged, rolledBack, committed }
  private struct Binding: Codable, Hashable {
    let assetID: String
    let generation: String
    let resourceID: String
  }
  private struct Metadata: Codable, Equatable {
    let source: String
    let url: String
    let title: String
    let quality: String
    let taskKey: String
    var showTask: Bool
    let at: Int64
    let cover: String?
    let durationMs: Int64?
    let sourceDuration: String?
    var publicFields: [String: Any] {
      var row: [String: Any] = ["source": source, "url": url, "title": title,
        "quality": quality, "taskKey": taskKey, "showTask": showTask, "at": at]
      if let cover { row["cover"] = cover }
      if let durationMs { row["durationMs"] = durationMs }
      if let sourceDuration { row["sourceDuration"] = sourceDuration }
      return row
    }
  }
  private struct Asset: Codable {
    let binding: Binding
    let relativePath: String
    var phase: Phase
    let metadata: Metadata
    let bytes: Int64
  }
  private struct Removal: Codable {
    let token: String
    let source: String
    let bindings: [Binding]
    var phase: RemovalPhase
  }
  private struct Index: Codable {
    var format = "breeze-hls-assets"
    var version = 1
    var assets: [Asset] = []
    var removals: [Removal] = []
  }
  private struct Recovery: Codable {
    let id: String
    let binding: Binding
    let metadata: Metadata
    let attempt: Int
    let scope: String
    let expected: String
    let wifiOnly: Bool
    let referer: String
    let origin: String?
    let userAgent: String?
    var cancellationRequested: Bool = false
    var status: String = "running"
    var reason: String?
    var relativePath: String?

    var fields: [String: Any] {
      var row = metadata.publicFields
      row["id"] = id
      row["assetId"] = binding.assetID
      row["generation"] = binding.generation
      row["resourceId"] = binding.resourceID
      row["attempt"] = attempt
      row["recoveryScope"] = scope
      row["wifiOnly"] = wifiOnly
      row["status"] = status
      row["reason"] = reason
      return row
    }
  }

  private let fm = FileManager.default
  private let home: URL
  private let indexRoot: URL
  private let indexURL: URL
  private let recoveryURL: URL
  private var state: Index
  private var recovery: [String: Recovery] = [:]
  private var recoveryReadable = true
  private var readers: [Binding: Int] = [:]
  private static let maximumIndexBytes = 16 * 1024 * 1024

  init(home: URL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true), indexRoot: URL? = nil) throws {
    guard home.isFileURL else { throw StoreError.invalidPath }
    self.home = home.standardizedFileURL
    self.indexRoot = (indexRoot ?? home.appendingPathComponent("Library/Application Support/BreezeHlsAssets", isDirectory: true)).standardizedFileURL
    self.indexURL = self.indexRoot.appendingPathComponent("index.json")
    self.recoveryURL = self.indexRoot.appendingPathComponent("recovery-v1.json")
    self.state = Index()
    try validateIndexLocation()
    if fm.fileExists(atPath: indexURL.path) {
      let data = try Data(contentsOf: indexURL)
      guard data.count <= Self.maximumIndexBytes,
        let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any],
        Set(raw.keys) == Set(["format", "version", "assets", "removals"]) else { throw StoreError.invalidIndex }
      state = try JSONDecoder().decode(Index.self, from: data)
    }
    try validateState()
    if let attributes = try? fm.attributesOfItem(atPath: recoveryURL.path),
      attributes[.type] as? FileAttributeType != .typeRegular {
      recoveryReadable = false
    } else if fm.fileExists(atPath: recoveryURL.path) {
      do {
        let data = try Data(contentsOf: recoveryURL)
        guard data.count <= Self.maximumIndexBytes,
          let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          raw.count <= 2048 else { throw StoreError.invalidIndex }
        let decoder = JSONDecoder()
        for (identifier, value) in raw {
          guard let data = try? JSONSerialization.data(withJSONObject: value),
            let entry = try? decoder.decode(Recovery.self, from: data),
            (try? validateRecovery(identifier, entry)) != nil else { continue }
          recovery[identifier] = entry
        }
      } catch {
        // Existing offline assets have a separate authority. Preserve the
        // corrupt journal verbatim and do not attach any unproven transfer.
        recoveryReadable = false
      }
    }
    var recovered = state
    var changed = false
    for i in recovered.assets.indices where recovered.assets[i].phase == .staged {
      let asset = recovered.assets[i]
      if recovery.values.contains(where: {
        $0.binding == asset.binding && $0.status == "running" &&
          !$0.cancellationRequested && $0.metadata.taskKey == asset.metadata.taskKey
      }) { continue }
      recovered.assets[i].phase = .retired
      changed = true
    }
    for i in recovered.removals.indices where recovered.removals[i].phase == .staged {
      // Expose retained packages again, but keep a replayable receipt. Dart's
      // outer recovery journal may prove its DB commit and replay this token.
      recovered.removals[i].phase = .rolledBack
      changed = true
    }
    if changed { try publish(recovered) }
    try? cleanupRetired()
  }

  /// Validate before creating an OS task description. `url` is the canonical
  /// public authority; `video` is an identical compatibility alias for the
  /// presenter's job payload, never the ephemeral media request URL.
  func normalizedMetadata(_ raw: [String: Any]) throws -> [String: Any] {
    var fields = try Self.cleanMetadata(raw).publicFields
    fields["video"] = fields["url"]
    return fields
  }

  /// Actual bytes currently present in Apple's package, not network throughput
  /// or an estimate of its final size. This read neither stages nor publishes it.
  func downloadedPackageBytes(at url: URL) throws -> Int64? {
    try packageBytes(packageURL(relativePackagePath(url)))
  }

  /// Record only the original OS task's public identity and reconstructable
  /// policy before resume. The system owns the actual request.
  func registerRecovery(
    identifier: String, id: String, assetID: String, generation: String,
    resourceID: String, metadata: [String: Any], attempt: Int, scope: String,
    expected: String, wifiOnly: Bool, referer: String, origin: String?, userAgent: String?
  ) throws {
    let binding = try makeBinding(assetID: assetID, generation: generation, resourceID: resourceID)
    let entry = Recovery(id: id, binding: binding, metadata: try Self.cleanMetadata(metadata),
      attempt: attempt, scope: scope, expected: expected, wifiOnly: wifiOnly,
      referer: referer, origin: origin, userAgent: userAgent)
    try validateRecovery(identifier, entry)
    guard recoveryReadable, recovery.count < 2048, recovery[identifier] == nil else { throw StoreError.busy }
    try requireNoRecoverableWriter(resourceID: resourceID)
    var next = recovery
    next[identifier] = entry
    try publishRecovery(next)
  }

  func requireNoRecoverableWriter(resourceID: String) throws {
    guard !recovery.values.contains(where: { previous in
      previous.binding.resourceID == resourceID && previous.status == "running" &&
        !state.assets.contains(where: { $0.binding == previous.binding && $0.phase == .ready })
    }) else { throw StoreError.busy }
  }

  func recoveryIdentifiers() -> [String] { Array(recovery.keys) }

  func recoveryDescriptor(_ identifier: String) -> [String: Any]? {
    guard let entry = recovery[identifier] else { return nil }
    var fields = entry.fields
    fields["expected"] = entry.expected
    fields["referer"] = entry.referer
    fields["origin"] = entry.origin
    fields["userAgent"] = entry.userAgent
    fields["cancellationRequested"] = entry.cancellationRequested
    let hasAsset = state.assets.contains(where: { $0.binding == entry.binding && $0.phase != .retired })
    fields["hasAsset"] = hasAsset
    fields["canReattach"] = entry.status == "running" &&
      !entry.cancellationRequested &&
      !hasAsset
    if let relative = entry.relativePath, let location = try? packageURL(relative) {
      fields["location"] = location
    }
    return fields
  }

  func rememberRecoveryLocation(_ identifier: String, url: URL) throws {
    guard let entry = recovery[identifier], entry.status == "running",
      !entry.cancellationRequested else { return }
    let relative = try relativePackagePath(url)
    if entry.relativePath == relative { return }
    guard entry.relativePath == nil else { throw StoreError.staleBinding }
    var next = recovery
    next[identifier]?.relativePath = relative
    try publishRecovery(next)
  }

  func recoverySnapshot(excluding live: Set<String>) throws -> [[String: Any]] {
    var next = recovery
    var failedStages = [Binding]()
    let rows: [[String: Any]] = recovery.compactMap { identifier, entry in
      guard !live.contains(identifier) else { return nil }
      var row = entry.fields
      if !entry.cancellationRequested && entry.status == "running",
        let asset = state.assets.first(where: { $0.binding == entry.binding && $0.phase != .retired }) {
        // A read error (for example, a temporarily inaccessible directory)
        // cannot establish that an owned package was lost.
        let publicFields: [String: Any]
        do {
          publicFields = try publicRow(asset)
        } catch StoreError.invalidPath {
          // A confirmed invalid structure cannot be published or traversed.
          publicFields = [:]
        } catch {
          return row
        }
        for (key, value) in publicFields { row[key] = value }
        if (row["bytes"] as? Int64 ?? 0) > 0 {
          row["status"] = "staged"
        } else {
          row["status"] = "failed"
          if asset.phase == .staged {
            next[identifier]?.status = "failed"
            failedStages.append(asset.binding)
          }
        }
      }
      return row
    }
    if !failedStages.isEmpty {
      // Release these exact writers durably before attempting file cleanup.
      // A restart between the two writes will retire their staged entries.
      try publishRecovery(next)
      for binding in failedStages {
        _ = try? discard(assetID: binding.assetID, generation: binding.generation)
      }
    }
    return rows
  }

  func cancelRecovery(assetID: String, generation: String, resourceID: String) throws -> Bool {
    let binding = try makeBinding(assetID: assetID, generation: generation, resourceID: resourceID)
    guard let (identifier, entry) = recovery.first(where: { $0.value.binding == binding }),
      !state.assets.contains(where: { $0.binding == binding && $0.phase == .ready }) else { return false }
    if !entry.cancellationRequested {
      var next = recovery
      next[identifier]?.cancellationRequested = true
      try publishRecovery(next)
    }
    return true
  }

  func finishRecovery(_ identifier: String, status: String, reason: String? = nil) throws {
    guard let entry = recovery[identifier], entry.status == "running",
      !state.assets.contains(where: { $0.binding == entry.binding && $0.phase == .ready }) else { return }
    guard status == "failed" || status == "cancelled" else { throw StoreError.invalidMetadata }
    var next = recovery
    next[identifier]?.status = entry.cancellationRequested ? "cancelled" : status
    next[identifier]?.reason = reason == "network" ? reason : nil
    try publishRecovery(next)
  }

  func finishOrphanedRecovery(_ identifier: String) throws {
    guard let entry = recovery[identifier], entry.status == "running",
      !state.assets.contains(where: { $0.binding == entry.binding && $0.phase != .retired }) else { return }
    if let relative = entry.relativePath,
      !state.assets.contains(where: { $0.relativePath == relative && $0.binding != entry.binding }) {
      let url = try packageURL(relative)
      if try packageBytes(url) != nil { try fm.removeItem(at: url) }
    }
    try finishRecovery(identifier, status: entry.cancellationRequested ? "cancelled" : "failed")
  }

  func acknowledgeRecovery(assetID: String, generation: String, resourceID: String) throws -> Bool {
    let binding = try makeBinding(assetID: assetID, generation: generation, resourceID: resourceID)
    guard let (identifier, entry) = recovery.first(where: { $0.value.binding == binding }) else { return true }
    let asset = state.assets.first { $0.binding == binding }
    guard asset?.phase == .ready || entry.status != "running" else { return false }
    var next = recovery
    next.removeValue(forKey: identifier)
    try publishRecovery(next)
    return true
  }

  func stage(url: URL, assetID: String, generation: String, resourceID: String, metadata: [String: Any]) throws -> [String: Any] {
    let binding = try makeBinding(assetID: assetID, generation: generation, resourceID: resourceID)
    let info = try Self.cleanMetadata(metadata)
    if let receipt = recovery.values.first(where: { $0.binding == binding }) {
      guard !receipt.cancellationRequested, receipt.status == "running",
        info.taskKey == receipt.metadata.taskKey, info.source == receipt.metadata.source,
        info.url == receipt.metadata.url, info.quality == receipt.metadata.quality else { throw StoreError.staleBinding }
    }
    guard !state.removals.contains(where: { $0.source == info.source && $0.phase == .staged }) else { throw StoreError.busy }
    let relative = try relativePackagePath(url)
    if let recorded = recovery.values.first(where: { $0.binding == binding })?.relativePath {
      guard relative == recorded else { throw StoreError.staleBinding }
    }
    let package = try packageURL(relative)
    guard let bytes = try packageBytes(package), bytes > 0 else { throw StoreError.missingPackage }
    if let existing = state.assets.first(where: { $0.binding == binding }) {
      guard existing.phase == .staged, existing.relativePath == relative else { throw StoreError.staleBinding }
      return try publicRow(existing)
    }
    guard !state.assets.contains(where: {
      $0.relativePath == relative || ($0.binding.assetID == assetID && $0.binding.generation == generation)
    }) else { throw StoreError.staleBinding }
    let asset = Asset(binding: binding, relativePath: relative, phase: .staged, metadata: info, bytes: bytes)
    var next = state
    next.assets.append(asset)
    try publish(next)
    return try publicRow(asset)
  }

  func commit(assetID: String, generation: String, resourceID: String) throws -> [String: Any] {
    let binding = try makeBinding(assetID: assetID, generation: generation, resourceID: resourceID)
    guard let selected = state.assets.first(where: { $0.binding == binding }), selected.phase != .retired else { throw StoreError.staleBinding }
    if let receipt = recovery.values.first(where: { $0.binding == binding }) {
      guard !receipt.cancellationRequested, receipt.status == "running" else { throw StoreError.staleBinding }
      let previous = state.assets.first { $0.binding.resourceID == resourceID && $0.phase == .ready }
      guard selected.phase == .ready || previous?.binding.generation ?? "" == receipt.expected else { throw StoreError.staleBinding }
    }
    guard !state.removals.contains(where: { $0.source == selected.metadata.source && $0.phase == .staged }) else { throw StoreError.busy }
    if selected.phase == .ready { return try publicRow(selected) }
    guard let bytes = try packageBytes(packageURL(selected.relativePath)), bytes > 0 else { throw StoreError.missingPackage }
    var next = state
    for i in next.assets.indices {
      if next.assets[i].binding == binding {
        next.assets[i].phase = .ready
      } else if next.assets[i].binding.resourceID == resourceID && next.assets[i].phase != .retired {
        next.assets[i].phase = .retired
      }
    }
    // Publish the new generation before touching the old package. An atomic
    // index failure therefore leaves the old ready generation and bytes intact.
    try publish(next)
    try? cleanupRetired()
    return try publicRow(state.assets.first(where: { $0.binding == binding })!)
  }

  @discardableResult
  func discard(assetID: String, generation: String, rejectRecovery: Bool = false) throws -> Bool {
    guard Self.token(assetID), Self.token(generation) else { throw StoreError.invalidMetadata }
    guard let i = state.assets.firstIndex(where: { $0.binding.assetID == assetID && $0.binding.generation == generation }) else { return false }
    guard state.assets[i].phase != .ready, readers[state.assets[i].binding, default: 0] == 0 else { throw StoreError.busy }
    let binding = state.assets[i].binding
    if rejectRecovery {
      // Persist rejection before retiring the package. Restart cleanup can
      // finish an interrupted rejection without treating it as a live writer.
      try finishRecovery(Self.sessionPrefix + assetID + "." + generation, status: "cancelled")
    }
    var next = state
    next.assets[i].phase = .retired
    try publish(next)
    try cleanupRetired()
    return !state.assets.contains(where: { $0.binding == binding })
  }

  func list() throws -> [[String: Any]] {
    let hidden = Set(state.removals.filter { $0.phase == .staged }.flatMap { $0.bindings })
    return try state.assets.filter { $0.phase == .ready && !hidden.contains($0.binding) }
      .sorted { $0.metadata.at > $1.metadata.at }.map(publicRow)
  }

  func hideTasks(keys: [String]) throws {
    let selected = Set(keys)
    var next = state
    for i in next.assets.indices where selected.contains(next.assets[i].metadata.taskKey) {
      // Metadata is value-typed; hide only the disposable task presentation.
      let old = next.assets[i]
      var metadata = old.metadata
      metadata.showTask = false
      next.assets[i] = Asset(binding: old.binding, relativePath: old.relativePath,
        phase: old.phase, metadata: metadata, bytes: old.bytes)
    }
    try publish(next)
  }

  @discardableResult
  func delete(resourceID: String, assetID: String, generation: String) throws -> Bool {
    let binding = try makeBinding(assetID: assetID, generation: generation, resourceID: resourceID)
    guard let i = state.assets.firstIndex(where: { $0.binding == binding }) else { return false }
    guard readers[binding, default: 0] == 0 else { throw StoreError.busy }
    guard !state.removals.contains(where: { $0.phase == .staged && $0.bindings.contains(binding) }) else { throw StoreError.busy }
    var next = state
    next.assets[i].phase = .retired
    try publish(next)
    try cleanupRetired()
    return !state.assets.contains(where: { $0.binding == binding })
  }

  func hold(resourceID: String, assetID: String, generation: String) throws -> URL {
    let binding = try makeBinding(assetID: assetID, generation: generation, resourceID: resourceID)
    guard let asset = state.assets.first(where: { $0.binding == binding && $0.phase == .ready }),
      !state.removals.contains(where: { $0.phase == .staged && $0.bindings.contains(binding) }) else { throw StoreError.staleBinding }
    let url = try packageURL(asset.relativePath)
    guard let bytes = try packageBytes(url), bytes > 0 else { throw StoreError.missingPackage }
    readers[binding, default: 0] += 1
    return url
  }

  func release(resourceID: String, assetID: String, generation: String) {
    let binding = Binding(assetID: assetID, generation: generation, resourceID: resourceID)
    guard let count = readers[binding], count > 0 else { return }
    if count == 1 { readers.removeValue(forKey: binding) } else { readers[binding] = count - 1 }
    try? cleanupRetired()
  }

  func stageRemoval(source: String, resources: [[String: Any]]) throws -> String {
    guard !source.isEmpty, source.count <= 200, !resources.isEmpty else { throw StoreError.invalidMetadata }
    let bindings = try resources.map(bindingFromRow)
    guard Set(bindings).count == bindings.count else { throw StoreError.invalidMetadata }
    if let existing = state.removals.first(where: { $0.source == source && $0.phase == .staged }) {
      guard Set(existing.bindings) == Set(bindings) else { throw StoreError.staleBinding }
      return existing.token
    }
    try checkRemoval(source: source, bindings: bindings)
    let token = UUID().uuidString
    var next = state
    next.removals.append(Removal(token: token, source: source, bindings: bindings, phase: .staged))
    try publish(next)
    return token
  }

  @discardableResult
  func commitRemoval(token: String) throws -> Bool {
    guard Self.token(token), let i = state.removals.firstIndex(where: { $0.token == token }) else { return false }
    let removal = state.removals[i]
    guard !state.removals.contains(where: {
      $0.token != token && $0.source == removal.source && $0.phase == .staged
    }) else { throw StoreError.busy }
    if removal.phase != .committed {
      try checkRemoval(source: removal.source, bindings: removal.bindings)
      var next = state
      next.removals[i].phase = .committed
      for index in next.assets.indices where removal.bindings.contains(next.assets[index].binding) {
        next.assets[index].phase = .retired
      }
      try publish(next)
    }
    try cleanupRetired()
    return !state.assets.contains(where: { removal.bindings.contains($0.binding) })
  }

  @discardableResult
  func rollbackRemoval(token: String) throws -> Bool {
    guard Self.token(token), let i = state.removals.firstIndex(where: { $0.token == token }) else { return false }
    if state.removals[i].phase == .committed { return false }
    if state.removals[i].phase == .rolledBack { return true }
    var next = state
    next.removals[i].phase = .rolledBack
    try publish(next)
    return true
  }

  private func checkRemoval(source: String, bindings: [Binding]) throws {
    let ready = state.assets.filter { $0.metadata.source == source && $0.phase == .ready }
    guard Set(ready.map { $0.binding }) == Set(bindings) else { throw StoreError.staleBinding }
    guard !state.assets.contains(where: { $0.metadata.source == source &&
      ($0.phase == .staged || readers[$0.binding, default: 0] > 0) }) else { throw StoreError.busy }
  }

  private func publicRow(_ asset: Asset) throws -> [String: Any] {
    let bytes = try packageBytes(packageURL(asset.relativePath))
    var row = asset.metadata.publicFields
    row["format"] = "hls"
    row["resourceId"] = asset.binding.resourceID
    row["assetId"] = asset.binding.assetID
    row["generation"] = asset.binding.generation
    row["bytes"] = bytes ?? 0
    row["filePresent"] = bytes != nil
    row["available"] = asset.phase == .ready && (bytes ?? 0) > 0
    return row
  }

  private func cleanupRetired() throws {
    var next = state
    var removed = Set<Binding>()
    for asset in state.assets where asset.phase == .retired && readers[asset.binding, default: 0] == 0 {
      let url = try packageURL(asset.relativePath)
      if try packageBytes(url) != nil { try fm.removeItem(at: url) }
      removed.insert(asset.binding)
    }
    if !removed.isEmpty {
      next.assets.removeAll { removed.contains($0.binding) }
      try publish(next)
    }
  }

  private func makeBinding(assetID: String, generation: String, resourceID: String) throws -> Binding {
    guard Self.token(assetID), Self.token(generation), Self.matches(resourceID, "^[a-f0-9]{64}$") else { throw StoreError.invalidMetadata }
    return Binding(assetID: assetID, generation: generation, resourceID: resourceID)
  }

  private func bindingFromRow(_ row: [String: Any]) throws -> Binding {
    guard let asset = row["assetId"] as? String, let generation = row["generation"] as? String,
      let resource = row["resourceId"] as? String else { throw StoreError.invalidMetadata }
    return try makeBinding(assetID: asset, generation: generation, resourceID: resource)
  }

  #if DEBUG
  /// Diagnostic values are deliberately booleans/counts only: no private paths,
  /// package names, transport URLs or metadata can enter the debug log.
  func debugPathBoundary(_ url: URL) -> [String: Any] {
    let candidate = url.standardizedFileURL
    let canonicalHome = home.resolvingSymlinksInPath()
    let canonicalCandidate = candidate.resolvingSymlinksInPath()
    let homeParts = home.pathComponents
    let candidateParts = candidate.pathComponents
    let decodedCandidate = candidate.path.removingPercentEncoding
    let decodedParts = decodedCandidate.map { URL(fileURLWithPath: $0).pathComponents } ?? []
    func commonCount(_ a: [String], _ b: [String]) -> Int {
      zip(a, b).prefix { $0.0 == $0.1 }.count
    }
    func containerID(_ parts: [String]) -> String? {
      guard parts.count >= 3 else { return nil }
      for i in 0..<(parts.count - 2) where parts[i] == "Data" && parts[i + 1] == "Application" {
        return parts[i + 2]
      }
      return nil
    }
    let homeContainer = containerID(homeParts)
    let candidateContainer = containerID(candidateParts)
    let decodedContainer = containerID(decodedParts)
    let parent = home.deletingLastPathComponent().path + "/"
    let roots = [home, canonicalHome]
    let matched = roots.first { candidate.path.hasPrefix($0.path + "/Library/") }
    let relative = matched.map { String(candidate.path.dropFirst($0.path.count + 1)) }
    let parts = relative?.split(separator: "/", omittingEmptySubsequences: false) ?? []
    var symlinks = 0
    var ancestorErrors = 0
    var current = home
    for part in parts {
      current.appendPathComponent(String(part))
      do {
        if try fm.attributesOfItem(atPath: current.path)[.type] as? FileAttributeType == .typeSymbolicLink { symlinks += 1 }
      } catch { ancestorErrors += 1 }
    }
    let canonicalPackage = current.resolvingSymlinksInPath().path
    let canonicalIndex = indexRoot.resolvingSymlinksInPath().path
    let rootAttributes = try? fm.attributesOfItem(atPath: current.path)
    var unsupportedEntries = 0
    var entryErrors = 0
    var entries = 0
    if relative != nil, rootAttributes?[.type] as? FileAttributeType == .typeDirectory,
      let enumeration = fm.enumerator(at: current, includingPropertiesForKeys: nil,
        options: [], errorHandler: { _, _ in entryErrors += 1; return false }) {
      for case let child as URL in enumeration {
        entries += 1
        do {
          let type = try fm.attributesOfItem(atPath: child.path)[.type] as? FileAttributeType
          if type != .typeDirectory && type != .typeRegular { unsupportedEntries += 1 }
        } catch { entryErrors += 1 }
      }
    }
    return [
      "isFileURL": url.isFileURL,
      "homeComponentCount": homeParts.count,
      "candidateComponentCount": candidateParts.count,
      "commonComponentCount": commonCount(homeParts, candidateParts),
      "decodedCommonComponentCount": commonCount(homeParts, decodedParts),
      "homeContainerIDPresent": homeContainer != nil,
      "candidateContainerIDPresent": candidateContainer != nil,
      "candidateContainerMatchesHome": homeContainer != nil && homeContainer == candidateContainer,
      "decodedContainerMatchesHome": homeContainer != nil && homeContainer == decodedContainer,
      "candidateMatchesHomeParent": candidate.path.hasPrefix(parent),
      "decodedCandidateMatchesHomeParent": decodedCandidate?.hasPrefix(parent) ?? false,
      "decodedCandidateHomePrefixMatch": decodedCandidate?.hasPrefix(home.path + "/Library/") ?? false,
      "decodedCandidateCanonicalHomePrefixMatch": decodedCandidate?.hasPrefix(canonicalHome.path + "/Library/") ?? false,
      "candidateContainsFileScheme": candidate.path.contains("file:"),
      "candidateContainsLibraryComponent": candidateParts.contains("Library"),
      "candidateContainsHomeLeaf": candidateParts.contains(home.lastPathComponent),
      "homePrefixMatch": candidate.path.hasPrefix(home.path + "/Library/"),
      "canonicalHomePrefixMatch": candidate.path.hasPrefix(canonicalHome.path + "/Library/"),
      "canonicalCandidateHomePrefixMatch": canonicalCandidate.path.hasPrefix(canonicalHome.path + "/Library/"),
      "homeAliasDiffers": home.path != canonicalHome.path,
      "candidateAliasDiffers": candidate.path != canonicalCandidate.path,
      "relativeLibrary": parts.first == "Library",
      "relativePartCount": parts.count,
      "relativeEmptyPartCount": parts.filter { $0.isEmpty }.count,
      "relativeTraversalPartCount": parts.filter { $0 == "." || $0 == ".." }.count,
      "suffixMovpkg": relative?.hasSuffix(".movpkg") ?? false,
      "rawSuffixMovpkg": url.path.hasSuffix(".movpkg"),
      "rawTrailingSlash": url.path.hasSuffix("/"),
      "standardizedTrailingSlash": candidate.path.hasSuffix("/"),
      "relativeBackslash": relative?.contains("\\") ?? false,
      "ancestorSymlinkCount": symlinks,
      "ancestorAttributeErrorCount": ancestorErrors,
      "canonicalInsideLibrary": canonicalPackage.hasPrefix(canonicalHome.appendingPathComponent("Library", isDirectory: true).path + "/"),
      "indexInsidePackage": canonicalIndex.hasPrefix(canonicalPackage + "/"),
      "indexEqualsPackage": canonicalIndex == canonicalPackage,
      "rawVsStandardizedPathDiffers": url.path != candidate.path,
      "decodedPathVsRawDiffers": url.path.removingPercentEncoding.map { $0 != url.path } ?? false,
      "packageRootDirectory": rootAttributes?[.type] as? FileAttributeType == .typeDirectory,
      "packageEntryCount": entries,
      "packageUnsupportedEntryCount": unsupportedEntries,
      "packageEntryErrorCount": entryErrors,
      "relativeBoundaryAccepted": (try? relativePackagePath(url)) != nil,
    ]
  }
  #endif

  private func relativePackagePath(_ url: URL) throws -> String {
    guard url.isFileURL else { throw StoreError.invalidPath }
    let candidate = url.standardizedFileURL
    let roots = [home, home.resolvingSymlinksInPath()]
    if let root = roots.first(where: { candidate.path.hasPrefix($0.path + "/Library/") }) {
      let relative = String(candidate.path.dropFirst(root.path.count + 1))
      _ = try packageURL(relative)
      return relative
    }
    // CoreSimulator can deliver a /System/Volumes/Data firmlink spelling of
    // the same container. Textual UUID equality is insufficient: the Library
    // parent must be the actual home directory (device + inode), not a second
    // directory with the same name. No package is moved or path persisted here.
    var ancestor = candidate.deletingLastPathComponent()
    while ancestor.path != "/" {
      if ancestor.lastPathComponent == "Library" {
        let candidateHome = ancestor.deletingLastPathComponent()
        if candidateHome.lastPathComponent == home.lastPathComponent &&
          sameDirectoryIdentity(candidateHome, home) {
          let relative = String(candidate.path.dropFirst(candidateHome.path.count + 1))
          let ownedPackage = try packageURL(relative)
          guard sameDirectoryIdentity(candidate, ownedPackage) else { throw StoreError.invalidPath }
          return relative
        }
      }
      let parent = ancestor.deletingLastPathComponent()
      if parent.path == ancestor.path { break }
      ancestor = parent
    }
    throw StoreError.invalidPath
  }

  private func sameDirectoryIdentity(_ first: URL, _ second: URL) -> Bool {
    guard let a = try? fm.attributesOfItem(atPath: first.path),
      let b = try? fm.attributesOfItem(atPath: second.path),
      a[.type] as? FileAttributeType == .typeDirectory,
      b[.type] as? FileAttributeType == .typeDirectory,
      let aDevice = a[.systemNumber] as? NSNumber,
      let bDevice = b[.systemNumber] as? NSNumber,
      let aInode = a[.systemFileNumber] as? NSNumber,
      let bInode = b[.systemFileNumber] as? NSNumber,
      aInode.uint64Value > 0, bInode.uint64Value > 0 else { return false }
    return aDevice == bDevice && aInode == bInode
  }

  private func packageURL(_ relative: String) throws -> URL {
    let parts = relative.split(separator: "/", omittingEmptySubsequences: false)
    guard parts.count >= 2, parts.first == "Library", !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }),
      relative.hasSuffix(".movpkg"), !relative.contains("\\") else { throw StoreError.invalidPath }
    var current = home
    for part in parts {
      current.appendPathComponent(String(part))
      if let attributes = try? fm.attributesOfItem(atPath: current.path),
        attributes[.type] as? FileAttributeType == .typeSymbolicLink { throw StoreError.invalidPath }
    }
    let root = home.resolvingSymlinksInPath().appendingPathComponent("Library", isDirectory: true).path
    guard current.resolvingSymlinksInPath().path.hasPrefix(root + "/"),
      !indexRoot.resolvingSymlinksInPath().path.hasPrefix(current.resolvingSymlinksInPath().path + "/") else { throw StoreError.invalidPath }
    return current
  }

  private func packageBytes(_ url: URL) throws -> Int64? {
    let rootType: FileAttributeType?
    do {
      rootType = try fm.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType
    } catch let error as CocoaError where error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile {
      return nil
    }
    guard rootType == .typeDirectory else { throw StoreError.invalidPath }
    var enumerationError: Error?
    guard let enumeration = fm.enumerator(at: url, includingPropertiesForKeys: nil,
      options: [], errorHandler: { _, error in enumerationError = error; return false }) else { throw StoreError.invalidPath }
    var bytes: Int64 = 0
    for case let child as URL in enumeration {
      let attributes = try fm.attributesOfItem(atPath: child.path)
      guard let type = attributes[.type] as? FileAttributeType,
        type == .typeDirectory || type == .typeRegular else { throw StoreError.invalidPath }
      if type == .typeRegular {
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        guard size >= 0, bytes <= Int64.max - size else { throw StoreError.invalidMetadata }
        bytes += size
      }
    }
    if let error = enumerationError { throw error }
    return bytes
  }

  private func validateIndexLocation() throws {
    if indexRoot.path.hasPrefix(home.path + "/") {
      var current = home
      let relative = String(indexRoot.path.dropFirst(home.path.count + 1))
      for part in relative.split(separator: "/") {
        current.appendPathComponent(String(part))
        if let attributes = try? fm.attributesOfItem(atPath: current.path),
          attributes[.type] as? FileAttributeType == .typeSymbolicLink {
          throw StoreError.invalidIndex
        }
      }
    }
    for url in [indexRoot, indexURL] {
      if let attributes = try? fm.attributesOfItem(atPath: url.path),
        let type = attributes[.type] as? FileAttributeType {
        guard type == (url == indexRoot ? .typeDirectory : .typeRegular) else { throw StoreError.invalidIndex }
      }
    }
  }

  private func publish(_ next: Index) throws {
    try validateIndexLocation()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(next)
    guard data.count <= Self.maximumIndexBytes else { throw StoreError.invalidIndex }
    try fm.createDirectory(at: indexRoot, withIntermediateDirectories: true)
    try writeLocal(data, to: indexURL)
    state = next
  }

  private func validateRecovery(_ identifier: String, _ entry: Recovery) throws {
    let binding = entry.binding
    _ = try makeBinding(assetID: binding.assetID, generation: binding.generation, resourceID: binding.resourceID)
    if let path = entry.relativePath { _ = try packageURL(path) }
    guard identifier == HlsAssetStore.sessionPrefix + binding.assetID + "." + binding.generation,
      Self.token(entry.id), entry.attempt > 0,
      Self.matches(entry.scope, "^[a-f0-9]{64}$"),
      entry.expected.isEmpty || Self.token(entry.expected),
      ["running", "failed", "cancelled"].contains(entry.status),
      entry.reason == nil || entry.reason == "network",
      try Self.cleanMetadata(entry.metadata.publicFields) == entry.metadata,
      let page = Self.publicHTTPS(entry.metadata.url), let referer = Self.publicHTTPS(entry.referer),
      referer.host == page.host,
      referer.absoluteString == page.absoluteString ||
        (referer.path == page.path && referer.query == nil),
      entry.origin == nil || entry.origin == "https://" + (page.host ?? "") ||
        entry.origin == "https://" + (page.host ?? "") + "/",
      entry.userAgent == nil || Self.recoverableUserAgent(entry.userAgent!) else { throw StoreError.invalidMetadata }
  }

  static let sessionPrefix = "breeze.video.hls.asset."
  static func recoverableUserAgent(_ value: String) -> Bool {
    value.count <= 512 && value.hasPrefix("Mozilla/5.0 (") &&
      matches(value, "^[a-zA-Z0-9 ().,/_:;+@-]+$")
  }

  private func publishRecovery(_ next: [String: Recovery]) throws {
    guard recoveryReadable else { throw StoreError.invalidIndex }
    try validateIndexLocation()
    if let attributes = try? fm.attributesOfItem(atPath: recoveryURL.path),
      attributes[.type] as? FileAttributeType != .typeRegular { throw StoreError.invalidIndex }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(next)
    guard data.count <= Self.maximumIndexBytes else { throw StoreError.invalidIndex }
    try fm.createDirectory(at: indexRoot, withIntermediateDirectories: true)
    try writeLocal(data, to: recoveryURL)
    recovery = next
  }

  private func writeLocal(_ data: Data, to url: URL) throws {
#if os(iOS)
    try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
#else
    try data.write(to: url, options: .atomic)
#endif
  }

  private func validateState() throws {
    guard state.format == "breeze-hls-assets", state.version == 1,
      state.assets.count <= 10000, state.removals.count <= 2048 else { throw StoreError.invalidIndex }
    var bindings = Set<Binding>(), paths = Set<String>(), ready = Set<String>(), generations = Set<String>()
    for asset in state.assets {
      _ = try makeBinding(assetID: asset.binding.assetID, generation: asset.binding.generation, resourceID: asset.binding.resourceID)
      let cleaned = try Self.cleanMetadata(asset.metadata.publicFields)
      _ = try packageURL(asset.relativePath)
      guard cleaned == asset.metadata, asset.bytes >= 0, bindings.insert(asset.binding).inserted,
        generations.insert(asset.binding.assetID + ":" + asset.binding.generation).inserted,
        paths.insert(asset.relativePath).inserted else { throw StoreError.invalidIndex }
      if asset.phase == .ready && !ready.insert(asset.binding.resourceID).inserted { throw StoreError.invalidIndex }
    }
    var tokens = Set<String>()
    for removal in state.removals {
      guard Self.token(removal.token), !removal.source.isEmpty, removal.source.count <= 200,
        !removal.bindings.isEmpty, Set(removal.bindings).count == removal.bindings.count,
        tokens.insert(removal.token).inserted else { throw StoreError.invalidIndex }
      for binding in removal.bindings {
        _ = try makeBinding(assetID: binding.assetID, generation: binding.generation, resourceID: binding.resourceID)
      }
    }
  }

  private static func token(_ value: String) -> Bool { matches(value, "^[A-Za-z0-9_-]{1,120}$") }
  private static func matches(_ value: String, _ pattern: String) -> Bool {
    value.range(of: pattern, options: .regularExpression) != nil
  }
  private static func integer(_ value: Any?) -> Int64? {
    guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
      number.doubleValue.isFinite, number.doubleValue == Double(number.int64Value) else { return nil }
    return number.int64Value
  }
  private static func publicHTTPS(_ value: String) -> URL? {
    guard value.count <= 4096, let url = URL(string: value), url.scheme == "https", url.host?.isEmpty == false,
      url.user == nil, url.password == nil, url.fragment == nil, url.port == nil || url.port == 443 else { return nil }
    return url
  }
  private static func publicPage(_ value: String) -> Bool {
    guard let url = publicHTTPS(value), let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
    let query = parts.queryItems ?? []
    if url.path == "/watch" {
      return query.count == 1 && query[0].name == "v" && matches(query[0].value ?? "", "^[0-9]+$")
    }
    let paths = ["^/voddetail/[1-9][0-9]{0,14}\\.html$", "^/index\\.php/vod/detail/id/[1-9][0-9]{0,14}\\.html$",
      "^/vod/[1-9][0-9]{0,14}/$", "^/anime/[a-f0-9]{16,64}\\.html$", "^/videos/[A-Za-z0-9_-]{1,64}$"]
    return paths.contains(where: { matches(url.path, $0) }) && query.count == 2 &&
      Set(query.map { $0.name }) == Set(["line", "episode"]) && query.allSatisfy {
        guard let value = $0.value, !value.isEmpty else { return false }
        return value.count <= ($0.name == "line" ? 160 : 300) && !matches(value, "[\\x00-\\x1f\\x7f]")
      }
  }
  private static func cleanMetadata(_ raw: [String: Any]) throws -> Metadata {
    guard let source = raw["source"] as? String, !source.isEmpty, source.count <= 200,
      let page = (raw["video"] ?? raw["url"]) as? String, publicPage(page),
      let title = raw["title"] as? String, title.count <= 300,
      let quality = raw["quality"] as? String, quality.count <= 80,
      let taskKey = raw["taskKey"] as? String, taskKey.count <= 2048 else { throw StoreError.invalidMetadata }
    if raw["at"] != nil && integer(raw["at"]) == nil { throw StoreError.invalidMetadata }
    let at = integer(raw["at"]) ?? Int64(Date().timeIntervalSince1970 * 1000)
    guard at >= 0 else { throw StoreError.invalidMetadata }
    var cover: String?
    if let value = raw["cover"] as? String, let url = publicHTTPS(value), url.query == nil { cover = value }
    let duration = integer(raw["durationMs"])
    let text = raw["sourceDuration"] as? String
    return Metadata(source: source, url: page, title: title, quality: quality, taskKey: taskKey,
      showTask: raw["showTask"] as? Bool ?? true, at: at, cover: cover,
      durationMs: duration.flatMap { $0 > 0 ? $0 : nil },
      sourceDuration: text.flatMap { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 300 ? $0 : nil })
  }
}
