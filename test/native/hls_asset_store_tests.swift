import Foundation

/// Compile together with HlsAssetStore.swift, without Flutter/UIKit/AVFoundation.
/// Real directory fixtures prove ownership/transactions, not HLS playability.
@main
struct HlsAssetStoreTests {
  enum Failure: Error { case assertion(String) }
  static let fm = FileManager.default
  static let resource = String(repeating: "a", count: 64)
  static let secondResource = String(repeating: "b", count: 64)
  static func check(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !value() { throw Failure.assertion(message) }
  }
  static func rejects(_ action: () throws -> Void, _ message: String) throws {
    do { try action() } catch { return }
    throw Failure.assertion(message)
  }
  final class Fixture {
    let root: URL
    let home: URL
    let index: URL
    var indexFile: URL { index.appendingPathComponent("index.json") }
    init() throws {
      root = HlsAssetStoreTests.fm.temporaryDirectory.appendingPathComponent("breeze-hls-store-\(UUID().uuidString)", isDirectory: true)
      home = root.appendingPathComponent("home", isDirectory: true)
      index = root.appendingPathComponent("index", isDirectory: true)
      try HlsAssetStoreTests.fm.createDirectory(at: home.appendingPathComponent("Library/Assets"), withIntermediateDirectories: true)
    }
    deinit { try? HlsAssetStoreTests.fm.removeItem(at: root) }
    func open() throws -> HlsAssetStore { try HlsAssetStore(home: home, indexRoot: index) }
    func package(_ name: String, bytes: Int = 48) throws -> URL {
      let url = home.appendingPathComponent("Library/Assets/\(name).movpkg", isDirectory: true)
      try HlsAssetStoreTests.fm.createDirectory(at: url.appendingPathComponent("nested"), withIntermediateDirectories: true)
      try Data(repeating: 7, count: bytes / 2).write(to: url.appendingPathComponent("init.bin"))
      try Data(repeating: 8, count: bytes - bytes / 2).write(to: url.appendingPathComponent("nested/chunk.bin"))
      return url
    }
    func metadata(source: String = "source-a", task: String = "transfer-a") -> [String: Any] {
      ["source": source, "video": "https://example.invalid/watch?v=7", "title": "Saved video",
       "quality": "720p", "taskKey": task, "at": Int64(1234), "cover": "https://example.invalid/poster.png",
       "durationMs": Int64(90000), "sourceDuration": "1:30",
       "headers": ["Authorization": "secret-never-store"],
       "mediaURL": "https://cdn.invalid/stream.m3u8?secret-never-store"]
    }
    func ready(_ store: HlsAssetStore, name: String = "one", asset: String = "asset-a", generation: String = "g1", resource: String = HlsAssetStoreTests.resource, source: String = "source-a") throws -> (URL, [String: Any]) {
      let url = try package(name)
      _ = try store.stage(url: url, assetID: asset, generation: generation, resourceID: resource, metadata: metadata(source: source))
      return (url, try store.commit(assetID: asset, generation: generation, resourceID: resource))
    }
  }

  static func main() throws {
    try publishedRowsAndPaths()
    try indexFailureKeepsOldGeneration()
    try readLeasesAndStaleDelete()
    try candidatesAndRetiredRecoverAfterRestart()
    try backgroundRecoveryReplayAndCancellation()
    try discardRecoveryPublishesBeforeCleanup()
    try missingRecoveredStageReleasesTheResource()
    try sourceRemovalAndReplay()
    try removalRejectsReadersAndNewGeneration()
    try pathAndSymlinkBoundaries()
    try futureIndexIsNotRewritten()
    try partialPackageMeasurements()
    print("HlsAssetStore: 12 Foundation fixture groups passed (not a playback test)")
  }

  static func partialPackageMeasurements() throws {
    let fixture = try Fixture(), store = try fixture.open()
    let missing = fixture.home.appendingPathComponent("Library/Assets/missing.movpkg", isDirectory: true)
    try check(try store.downloadedPackageBytes(at: missing) == nil, "an absent package is unknown, not zero bytes")
    let package = try fixture.package("partial", bytes: 83)
    try check(try store.downloadedPackageBytes(at: package) == 83, "partial bytes sum actual nested regular files")
    try Data(repeating: 1, count: 29).write(to: package.appendingPathComponent("next.bin"))
    try check(try store.downloadedPackageBytes(at: package) == 112, "a later sample sees real file growth")
    try check(try store.list().isEmpty && !fm.fileExists(atPath: fixture.indexFile.path), "sampling never stages, publishes or marks an unfinished package playable")
    let outside = fixture.root.appendingPathComponent("outside.bin")
    try Data([1]).write(to: outside)
    try fm.createSymbolicLink(at: package.appendingPathComponent("escape.bin"), withDestinationURL: outside)
    try rejects({ _ = try store.downloadedPackageBytes(at: package) }, "sampling retains package symlink boundaries")
  }

  static func publishedRowsAndPaths() throws {
    let fixture = try Fixture(), store = try fixture.open()
    let url = try fixture.package("first", bytes: 79)
    let staged = try store.stage(url: url, assetID: "asset-a", generation: "g1", resourceID: resource, metadata: fixture.metadata())
    try check(staged["available"] as? Bool == false, "stage must not claim ready")
    try check(try store.list().isEmpty, "candidates must not be listed")
    let row = try store.commit(assetID: "asset-a", generation: "g1", resourceID: resource)
    try check(row["bytes"] as? Int64 == 79, "size must sum real nested package files")
    try check(row["durationMs"] as? Int64 == 90000, "known duration must survive")
    try check(row["relativePath"] == nil && row["path"] == nil && row["headers"] == nil, "public row must never expose private authority")
    let encoded = try String(contentsOf: fixture.indexFile, encoding: .utf8)
    try check(!encoded.contains("secret-never-store") && !encoded.contains(fixture.home.path), "index leaked a transport secret or absolute home")
    // JSONEncoder may escape slashes. Inspect the actual persisted value,
    // preserving the relative-path boundary instead of its text encoding.
    let persisted = try JSONSerialization.jsonObject(with: Data(contentsOf: fixture.indexFile)) as! [String: Any]
    let assets = persisted["assets"] as! [[String: Any]]
    let relative = assets.first?["relativePath"] as? String
    try check(relative == "Library/Assets/first.movpkg", "native index must retain the exact relative Library path")
    try check(relative?.hasPrefix("/") == false && relative?.split(separator: "/").contains("..") == false,
      "native path must never be absolute or traverse its Library authority")
    try store.hideTasks(keys: ["transfer-a"])
    let hiddenTask = try store.list().first!
    try check(hiddenTask["showTask"] as? Bool == false, "task hiding must retain the actual asset")
    try check(hiddenTask["durationMs"] as? Int64 == 90000, "clearing task must preserve total duration")
    let held = try store.hold(resourceID: resource, assetID: "asset-a", generation: "g1")
    try check(held == url && fm.fileExists(atPath: url.path), "Apple's package must stay at its original location")
    store.release(resourceID: resource, assetID: "asset-a", generation: "g1")
    _ = try store.commit(assetID: "asset-a", generation: "g1", resourceID: resource)
  }

  static func indexFailureKeepsOldGeneration() throws {
    let fixture = try Fixture(), store = try fixture.open()
    let (old, _) = try fixture.ready(store)
    let candidate = try fixture.package("replacement", bytes: 93)
    _ = try store.stage(url: candidate, assetID: "asset-b", generation: "g2", resourceID: resource, metadata: fixture.metadata())
    let before = try Data(contentsOf: fixture.indexFile)
    try fm.removeItem(at: fixture.indexFile)
    try fm.createDirectory(at: fixture.indexFile, withIntermediateDirectories: false)
    try rejects({ _ = try store.commit(assetID: "asset-b", generation: "g2", resourceID: resource) }, "index failure must reject commit")
    try check(fm.fileExists(atPath: old.path) && fm.fileExists(atPath: candidate.path), "failed publication must preserve both owned packages")
    try check(try store.list().first?["assetId"] as? String == "asset-a", "old ready record must survive failed atomic publication")
    try fm.removeItem(at: fixture.indexFile)
    try before.write(to: fixture.indexFile)
    _ = try store.commit(assetID: "asset-b", generation: "g2", resourceID: resource)
    try check(!fm.fileExists(atPath: old.path) && fm.fileExists(atPath: candidate.path), "publish new before retiring old")
  }

  static func readLeasesAndStaleDelete() throws {
    let fixture = try Fixture(), store = try fixture.open()
    let (old, _) = try fixture.ready(store)
    _ = try store.hold(resourceID: resource, assetID: "asset-a", generation: "g1")
    _ = try store.hold(resourceID: resource, assetID: "asset-a", generation: "g1")
    try rejects({ _ = try store.delete(resourceID: resource, assetID: "asset-a", generation: "g1") }, "a player must block physical deletion")
    let replacement = try fixture.package("replacement")
    _ = try store.stage(url: replacement, assetID: "asset-b", generation: "g2", resourceID: resource, metadata: fixture.metadata())
    _ = try store.commit(assetID: "asset-b", generation: "g2", resourceID: resource)
    try check(fm.fileExists(atPath: old.path), "a replacement must not interrupt an old active reader")
    store.release(resourceID: resource, assetID: "asset-a", generation: "g1")
    try check(fm.fileExists(atPath: old.path), "all holders must release independently")
    store.release(resourceID: resource, assetID: "asset-a", generation: "g1")
    try check(!fm.fileExists(atPath: old.path), "last release must clean the retired package")
    try check(try !store.delete(resourceID: resource, assetID: "asset-a", generation: "g1"), "late delete must reject old generation")
    try check(fm.fileExists(atPath: replacement.path), "late deletion must preserve the replacement")
    try rejects({ _ = try store.hold(resourceID: resource, assetID: "asset-a", generation: "g1") }, "old generation must not reopen")
  }

  static func candidatesAndRetiredRecoverAfterRestart() throws {
    let fixture = try Fixture()
    let oldStore = try fixture.open()
    let candidate = try fixture.package("never-committed")
    _ = try oldStore.stage(url: candidate, assetID: "candidate", generation: "g1", resourceID: resource, metadata: fixture.metadata())
    let restarted = try fixture.open()
    try check(try restarted.list().isEmpty, "restart must not publish an unfinished candidate")
    try check(!fm.fileExists(atPath: candidate.path), "restart must discard tracked unfinished package")
    let (old, _) = try fixture.ready(restarted)
    _ = try restarted.hold(resourceID: resource, assetID: "asset-a", generation: "g1")
    _ = try fixture.ready(restarted, name: "new", asset: "asset-b", generation: "g2")
    try check(fm.fileExists(atPath: old.path), "pre-restart active reader must keep old bytes")
    let recovered = try fixture.open()
    try check(try recovered.list().count == 1 && !fm.fileExists(atPath: old.path), "restart must clean retired packages without reviving old generations")
  }

  static func backgroundRecoveryReplayAndCancellation() throws {
    let fixture = try Fixture()
    let first = try fixture.open()
    func register(_ store: HlsAssetStore, _ asset: String, _ generation: String, expected: String = "") throws -> String {
      let identifier = HlsAssetStore.sessionPrefix + asset + "." + generation
      try store.registerRecovery(identifier: identifier, id: "video-file-1",
        assetID: asset, generation: generation, resourceID: resource, metadata: fixture.metadata(),
        attempt: 2, scope: String(repeating: "a", count: 64), expected: expected,
        wifiOnly: true, referer: "https://example.invalid/watch?v=7", origin: nil, userAgent: nil)
      return identifier
    }
    let identifier = try register(first, "recovery", "generation")
    try check(try first.recoverySnapshot(excluding: [identifier]).isEmpty, "live Flutter owner must not reconcile its own transfer")
    try check(try first.recoverySnapshot(excluding: []).first?["attempt"] as? Int == 2, "expose exact attempt")
    try rejects({ _ = try register(first, "second-owner", "g2") }, "one outstanding attempt per resource")
    let package = try fixture.package("recovery")
    try first.rememberRecoveryLocation(identifier, url: package)
    let reopened = try fixture.open()
    try check(reopened.recoveryDescriptor(identifier)?["location"] as? URL == package.standardizedFileURL,
      "destination survives reattachment under a validated relative path")
    _ = try reopened.stage(url: package, assetID: "recovery", generation: "generation",
      resourceID: resource, metadata: fixture.metadata())
    let staged = try fixture.open()
    try check(try staged.list().isEmpty && staged.recoverySnapshot(excluding: []).first?["status"] as? String == "staged",
      "staged native completion must survive process exit without publishing early")
    try check(try !staged.acknowledgeRecovery(assetID: "recovery", generation: "generation", resourceID: resource),
      "acknowledgement cannot erase an unconsumed package")
    _ = try staged.commit(assetID: "recovery", generation: "generation", resourceID: resource)
    let committed = try fixture.open()
    try check(try committed.recoverySnapshot(excluding: []).first?["status"] as? String == "staged",
      "Dart can replay after commit and before task acknowledgement")
    _ = try committed.commit(assetID: "recovery", generation: "generation", resourceID: resource)
    try check(try committed.acknowledgeRecovery(assetID: "recovery", generation: "generation", resourceID: resource),
      "acknowledge a ready resource")
    try check(try committed.acknowledgeRecovery(assetID: "recovery", generation: "generation", resourceID: resource),
      "repeat acknowledgement is harmless")
    let replacement = try register(committed, "replacement", "next", expected: "generation")
    let nextPackage = try fixture.package("replacement")
    try committed.rememberRecoveryLocation(replacement, url: nextPackage)
    try check(try committed.cancelRecovery(assetID: "replacement", generation: "next", resourceID: resource), "cancel owns exact attempt")
    try rejects({ _ = try committed.stage(url: nextPackage, assetID: "replacement", generation: "next",
      resourceID: resource, metadata: fixture.metadata()) }, "late completion cannot publish after cancellation")
    try committed.finishOrphanedRecovery(replacement)
    try check(try committed.recoverySnapshot(excluding: []).first?["status"] as? String == "cancelled",
      "cancellation is durable until Dart consumes it")
    try check(!fm.fileExists(atPath: nextPackage.path) && fm.fileExists(atPath: package.path),
      "cancel removes only the current partial and preserves the previous good generation")
    let journal = try String(contentsOf: fixture.index.appendingPathComponent("recovery-v1.json"), encoding: .utf8)
    try check(!journal.contains("secret-never-store") && !journal.contains(fixture.home.path),
      "journal never persists URL secrets or absolute paths")
    let journalURL = fixture.index.appendingPathComponent("recovery-v1.json")
    var rows = try JSONSerialization.jsonObject(with: Data(journal.utf8)) as! [String: Any]
    rows["broken"] = ["attempt": "invalid"]
    try JSONSerialization.data(withJSONObject: rows).write(to: journalURL)
    let malformedEntry = try fixture.open()
    try check(try malformedEntry.recoverySnapshot(excluding: []).count == 1,
      "a malformed row cannot block valid recovery rows")
    let corrupt = Data("{corrupt".utf8)
    try corrupt.write(to: journalURL)
    let malformedJournal = try fixture.open()
    try check(try malformedJournal.list().count == 1 && malformedJournal.recoverySnapshot(excluding: []).isEmpty,
      "a corrupt journal must preserve the independently committed offline library")
    try rejects({ _ = try register(malformedJournal, "new-recovery", "g3", expected: "generation") },
      "a corrupt journal must not be overwritten by registration")
    try check(try Data(contentsOf: journalURL) == corrupt, "unreadable recovery data remains intact")
  }

  static func discardRecoveryPublishesBeforeCleanup() throws {
    let fixture = try Fixture(), store = try fixture.open()
    let (previousPackage, _) = try fixture.ready(store)
    let identifier = HlsAssetStore.sessionPrefix + "rejected.g2"
    let candidate = try fixture.package("reject")
    try store.registerRecovery(identifier: identifier, id: "video-file-1",
      assetID: "rejected", generation: "g2", resourceID: resource, metadata: fixture.metadata(),
      attempt: 2, scope: String(repeating: "a", count: 64), expected: "g1",
      wifiOnly: true, referer: "https://example.invalid/watch?v=7", origin: nil, userAgent: nil)
    try store.rememberRecoveryLocation(identifier, url: candidate)
    _ = try store.stage(url: candidate, assetID: "rejected", generation: "g2",
      resourceID: resource, metadata: fixture.metadata())
    let journal = fixture.index.appendingPathComponent("recovery-v1.json")
    let backup = fixture.index.appendingPathComponent("recovery-before-rejection")
    try fm.moveItem(at: journal, to: backup)
    try fm.createDirectory(at: journal, withIntermediateDirectories: false)
    try rejects({ _ = try store.discard(assetID: "rejected", generation: "g2", rejectRecovery: true) },
      "a failed recovery journal write must abort rejection")
    try check(fm.fileExists(atPath: candidate.path), "failed journal write must keep staged bytes")
    try fm.removeItem(at: journal)
    try fm.moveItem(at: backup, to: journal)
    _ = try store.discard(assetID: "rejected", generation: "g2", rejectRecovery: true)
    try rejects({ _ = try store.discard(assetID: "asset-a", generation: "g1", rejectRecovery: true) },
      "discard cannot reject or clean an already published generation")
    // Reopen at the boundary immediately after the staged index/file write.
    let reopened = try fixture.open()
    try check(try reopened.recoverySnapshot(excluding: []).first?["status"] as? String == "cancelled",
      "rejection must survive before the separate file cleanup returns")
    try check(!fm.fileExists(atPath: candidate.path) && fm.fileExists(atPath: previousPackage.path),
      "rejection removes only the selected candidate")
  }

  static func missingRecoveredStageReleasesTheResource() throws {
    let fixture = try Fixture(), store = try fixture.open()
    let (previousPackage, _) = try fixture.ready(store)
    func register(_ owner: HlsAssetStore, asset: String, generation: String) throws -> String {
      let identifier = HlsAssetStore.sessionPrefix + asset + "." + generation
      try owner.registerRecovery(identifier: identifier, id: "video-file-1",
        assetID: asset, generation: generation, resourceID: resource, metadata: fixture.metadata(),
        attempt: 2, scope: String(repeating: "a", count: 64), expected: "g1",
        wifiOnly: true, referer: "https://example.invalid/watch?v=7", origin: nil, userAgent: nil)
      return identifier
    }
    let identifier = try register(store, asset: "missing", generation: "g2")
    let package = try fixture.package("missing")
    try store.rememberRecoveryLocation(identifier, url: package)
    _ = try store.stage(url: package, assetID: "missing", generation: "g2",
      resourceID: resource, metadata: fixture.metadata())

    let assets = package.deletingLastPathComponent()
    guard let permissions = try fm.attributesOfItem(atPath: assets.path)[.posixPermissions] else {
      throw Failure.assertion("fixture requires POSIX directory permissions")
    }
    do {
      try fm.setAttributes([.posixPermissions: 0o000], ofItemAtPath: assets.path)
      defer { try? fm.setAttributes([.posixPermissions: permissions], ofItemAtPath: assets.path) }
      if !fm.isReadableFile(atPath: package.path) {
        let temporarilyUnreadable = try fixture.open()
        try check(try temporarilyUnreadable.recoverySnapshot(excluding: []).first?["status"] as? String == "running",
          "an inaccessible stage must retain its receipt until it can be verified")
      }
    }
    let readableAgain = try fixture.open()
    try check(try readableAgain.recoverySnapshot(excluding: []).first?["status"] as? String == "staged",
      "a temporarily inaccessible stage must remain publishable")
    try fm.removeItem(at: package)

    let recovered = try fixture.open()
    try check(try recovered.recoverySnapshot(excluding: []).first?["status"] as? String == "failed",
      "a missing stage must report failure")
    let restarted = try fixture.open()
    try check(try restarted.acknowledgeRecovery(assetID: "missing", generation: "g2", resourceID: resource),
      "the failed receipt must be durable and acknowledgeable")
    let retry = try register(restarted, asset: "retry", generation: "g3")
    let invalidPackage = try fixture.package("invalid")
    try restarted.rememberRecoveryLocation(retry, url: invalidPackage)
    _ = try restarted.stage(url: invalidPackage, assetID: "retry", generation: "g3",
      resourceID: resource, metadata: fixture.metadata())
    try fm.createSymbolicLink(at: invalidPackage.appendingPathComponent("outside"), withDestinationURL: previousPackage)
    try check(try restarted.recoverySnapshot(excluding: []).first?["status"] as? String == "failed" &&
      restarted.acknowledgeRecovery(assetID: "retry", generation: "g3", resourceID: resource),
      "a package with an invalid path must release its receipt without following the path")
    _ = try register(restarted, asset: "next-retry", generation: "g4")
    try check(try restarted.list().first?["generation"] as? String == "g1" && fm.fileExists(atPath: previousPackage.path),
      "the previous ready package must survive recovery and retry")
  }

  static func sourceRemovalAndReplay() throws {
    let fixture = try Fixture(), store = try fixture.open()
    let (package, row) = try fixture.ready(store)
    let token = try store.stageRemoval(source: "source-a", resources: [row])
    try check(try store.list().isEmpty, "staged source removal must hide rows")
    try check(fm.fileExists(atPath: package.path), "staging must not move or delete Apple's package")
    try rejects({ _ = try store.hold(resourceID: resource, assetID: "asset-a", generation: "g1") }, "hidden source removal must reject new readers")
    let restarted = try fixture.open()
    try check(try restarted.list().count == 1, "restart before commit must restore ready rows")
    try check(try restarted.rollbackRemoval(token: token), "rollback replay must retain its transaction receipt")
    try check(try restarted.rollbackRemoval(token: token), "rollback must be idempotent")
    try check(try restarted.commitRemoval(token: token), "outer committed DB journal must still replay the retained native token")
    try check(!fm.fileExists(atPath: package.path), "committed source removal must delete the package")
    let again = try fixture.open()
    try check(try again.commitRemoval(token: token), "committed receipt must survive restart for idempotent replay")
    try check(try again.list().isEmpty, "committed source removal must not reappear")
  }

  static func removalRejectsReadersAndNewGeneration() throws {
    let fixture = try Fixture(), store = try fixture.open()
    let (_, row) = try fixture.ready(store)
    _ = try store.hold(resourceID: resource, assetID: "asset-a", generation: "g1")
    try rejects({ _ = try store.stageRemoval(source: "source-a", resources: [row]) }, "source removal must reject current readers")
    store.release(resourceID: resource, assetID: "asset-a", generation: "g1")
    let token = try store.stageRemoval(source: "source-a", resources: [row])
    try check(try store.rollbackRemoval(token: token), "rollback should restore the original row")
    let (replacement, _) = try fixture.ready(store, name: "new", asset: "asset-b", generation: "g2")
    try rejects({ _ = try store.commitRemoval(token: token) }, "late source commit must not delete replacement generation")
    try check(fm.fileExists(atPath: replacement.path), "stale source removal destroyed a new generation")
  }

  static func pathAndSymlinkBoundaries() throws {
    let fixture = try Fixture(), store = try fixture.open()
    #if DEBUG
    let ordinary = try fixture.package("boundary % literal")
    let normalReport = store.debugPathBoundary(ordinary)
    try check(normalReport["relativeBoundaryAccepted"] as? Bool == true &&
      normalReport["packageRootDirectory"] as? Bool == true &&
      normalReport["packageEntryCount"] as? Int == 3,
      "safe boundary diagnostic must describe a real package without rejecting literal percent/space names")
    try check(normalReport.values.allSatisfy { $0 is Bool || $0 is Int },
      "boundary report must never contain path/URL/string values")
    // A distinct root alias is not currently accepted by the lexical boundary.
    // Diagnose that exact difference without silently broadening ownership.
    let homeAlias = fixture.root.appendingPathComponent("home-alias", isDirectory: true)
    try fm.createSymbolicLink(at: homeAlias, withDestinationURL: fixture.home)
    let aliasedPackage = homeAlias.appendingPathComponent("Library/Assets/boundary % literal.movpkg", isDirectory: true)
    let aliasReport = store.debugPathBoundary(aliasedPackage)
    try check(aliasReport["homePrefixMatch"] as? Bool == false &&
      aliasReport["canonicalCandidateHomePrefixMatch"] as? Bool == true &&
      aliasReport["relativeBoundaryAccepted"] as? Bool == false,
      "root alias mismatch must be distinguished from an outside-container path")
    try rejects({ _ = try store.stage(url: aliasedPackage, assetID: "root-alias", generation: "g1", resourceID: resource, metadata: fixture.metadata()) },
      "diagnostics must not broaden the existing path authority")
    #endif
    #if os(macOS)
    // Real APFS firmlink, not a symlink stand-in: lexical root differs while
    // the exact home and package directory device/inode identities agree.
    let firmlinkPackage = try fixture.package("firmlink-identity", bytes: 83)
    // Foundation's temp URL can keep /var while its physical Data-volume
    // entry is /private/var. Do not append the volume prefix to that alias or
    // append it twice when Foundation already supplied the physical spelling.
    let volume = "/System/Volumes/Data"
    let homeAttributes = try fm.attributesOfItem(atPath: fixture.home.path)
    var physicalPaths = Set([fixture.home.path, fixture.home.resolvingSymlinksInPath().path])
    for path in Array(physicalPaths) {
      if path.hasPrefix(volume + "/") { physicalPaths.insert(String(path.dropFirst(volume.count))) }
      if path.hasPrefix("/var/") { physicalPaths.insert("/private" + path) }
    }
    let aliases = physicalPaths.map { path in
      URL(fileURLWithPath: path.hasPrefix(volume + "/") ? path : volume + path, isDirectory: true)
    }
    guard let firmlinkHome = aliases.first(where: { alias in
      guard alias.path != fixture.home.path,
        let attributes = try? fm.attributesOfItem(atPath: alias.path),
        let device = attributes[.systemNumber] as? NSNumber,
        let inode = attributes[.systemFileNumber] as? NSNumber,
        let homeDevice = homeAttributes[.systemNumber] as? NSNumber,
        let homeInode = homeAttributes[.systemFileNumber] as? NSNumber,
        inode.uint64Value > 0, homeInode.uint64Value > 0 else { return false }
      return attributes[.type] as? FileAttributeType == .typeDirectory &&
        device == homeDevice && inode == homeInode
    }) else { throw Failure.assertion("macOS fixture requires a real Data-volume firmlink with matching device/inode") }
    let firmlinkURL = firmlinkHome.appendingPathComponent("Library/Assets/firmlink-identity.movpkg", isDirectory: true)
    _ = try store.stage(url: firmlinkURL, assetID: "firmlink", generation: "f1", resourceID: resource, metadata: fixture.metadata())
    let firmlinkRow = try store.commit(assetID: "firmlink", generation: "f1", resourceID: resource)
    try check(firmlinkRow["bytes"] as? Int64 == 83 && fm.fileExists(atPath: firmlinkPackage.path),
      "same-directory filesystem alias must save without moving Apple's package")
    let heldFirmlink = try store.hold(resourceID: resource, assetID: "firmlink", generation: "f1")
    try check(heldFirmlink.path == firmlinkPackage.path, "alias must persist only the home-relative package identity")
    store.release(resourceID: resource, assetID: "firmlink", generation: "f1")
    let impostorHome = fixture.root.appendingPathComponent("other-parent", isDirectory: true).appendingPathComponent(fixture.home.lastPathComponent, isDirectory: true)
    let impostorPackage = impostorHome.appendingPathComponent("Library/Assets/impostor.movpkg", isDirectory: true)
    try fm.createDirectory(at: impostorPackage, withIntermediateDirectories: true)
    try Data([1]).write(to: impostorPackage.appendingPathComponent("chunk.bin"))
    try rejects({ _ = try store.stage(url: impostorPackage, assetID: "impostor", generation: "f2", resourceID: resource, metadata: fixture.metadata()) },
      "same home leaf name with different device/inode must never gain ownership")
    #endif
    let outside = fixture.root.appendingPathComponent("outside.movpkg", isDirectory: true)
    try fm.createDirectory(at: outside, withIntermediateDirectories: false)
    try Data([1, 2, 3]).write(to: outside.appendingPathComponent("keep.bin"))
    try rejects({ _ = try store.stage(url: outside, assetID: "outside", generation: "g1", resourceID: resource, metadata: fixture.metadata()) }, "outside Library must be rejected")
    let alias = fixture.home.appendingPathComponent("Library/Assets/linked.movpkg")
    try fm.createSymbolicLink(at: alias, withDestinationURL: outside)
    try rejects({ _ = try store.stage(url: alias, assetID: "linked", generation: "g1", resourceID: resource, metadata: fixture.metadata()) }, "symbolic package must be rejected")
    let package = try fixture.package("internal-link")
    try fm.createSymbolicLink(at: package.appendingPathComponent("escape.bin"), withDestinationURL: outside.appendingPathComponent("keep.bin"))
    try rejects({ _ = try store.stage(url: package, assetID: "inner-link", generation: "g1", resourceID: resource, metadata: fixture.metadata()) }, "package symlink entries must be rejected")
    var metadata = fixture.metadata()
    metadata["video"] = "https://cdn.invalid/file.m3u8?signature=private"
    try rejects({ _ = try store.stage(url: try fixture.package("bad-metadata"), assetID: "bad", generation: "g1", resourceID: resource, metadata: metadata) }, "media transport URL must not be accepted as public identity")
    // OS task descriptions must be normalized before starting a transfer,
    // rather than waiting for the eventual package-stage validation.
    try rejects({ _ = try store.normalizedMetadata(metadata) }, "signed media identity must be rejected before task persistence")
    var polluted = fixture.metadata()
    polluted["cover"] = "https://example.invalid/poster.png?signature=never-persist"
    polluted["unknown"] = "private-unknown-never-persist"
    let normalized = try store.normalizedMetadata(polluted)
    try check(normalized["cover"] == nil && normalized["headers"] == nil && normalized["mediaURL"] == nil && normalized["unknown"] == nil,
      "normalization must strip query poster and unknown transport metadata")
    try check(normalized["video"] as? String == "https://example.invalid/watch?v=7" && normalized["url"] as? String == normalized["video"] as? String,
      "presenter video alias must equal the single canonical public URL")
    let normalizedPackage = try fixture.package("normalized")
    _ = try store.stage(url: normalizedPackage, assetID: "normalized", generation: "n1", resourceID: secondResource, metadata: normalized)
    _ = try store.commit(assetID: "normalized", generation: "n1", resourceID: secondResource)
    let persisted = try String(contentsOf: fixture.indexFile, encoding: .utf8)
    try check(!persisted.contains("never-persist") && !persisted.contains("secret-never-store"),
      "normalized OS metadata must not leak query poster or unknown fields into native index")
    try check(fm.fileExists(atPath: outside.appendingPathComponent("keep.bin").path), "boundary failures must not touch unrelated files")
  }

  static func futureIndexIsNotRewritten() throws {
    let fixture = try Fixture(), store = try fixture.open()
    let (package, _) = try fixture.ready(store)
    var raw = try JSONSerialization.jsonObject(with: Data(contentsOf: fixture.indexFile)) as! [String: Any]
    raw["version"] = 2
    let future = try JSONSerialization.data(withJSONObject: raw, options: [.sortedKeys])
    try future.write(to: fixture.indexFile)
    try rejects({ _ = try fixture.open() }, "future index must fail closed")
    try check(try Data(contentsOf: fixture.indexFile) == future && fm.fileExists(atPath: package.path), "unsupported index must preserve its bytes and packages")
  }
}
