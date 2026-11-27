import CryptoKit
import Foundation

struct MP4RetryBudget {
  private var used = 0

  static func transient(_ error: NSError) -> Bool {
    error.domain == NSURLErrorDomain && [
      NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost, NSURLErrorNotConnectedToInternet,
      NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed,
      NSURLErrorDataNotAllowed, NSURLErrorInternationalRoamingOff, NSURLErrorCallIsActive,
    ].contains(error.code)
  }

  static func transientHTTP(_ status: Int) -> Bool {
    [408, 500, 502, 503, 504].contains(status)
  }

  mutating func nextDelay() -> TimeInterval? {
    let delays: [TimeInterval] = [1, 3, 7]
    guard used < delays.count else { return nil }
    defer { used += 1 }
    return delays[used]
  }
}

/// A strong ETag is scoped to the effective HTTPS resource. Exclude the
/// signature query from the comparison and keep only a digest of origin/path.
struct MP4ResumeValidator {
  let total: Int64
  private let resource: SHA256.Digest
  private let etag: String

  init?(_ response: HTTPURLResponse) {
    guard response.statusCode == 200, Self.identityEncoding(response),
          let resource = Self.resourceKey(response.url),
          let size = Self.length(response), size > 12,
          let etag = response.value(forHTTPHeaderField: "ETag"), etag.utf8.count <= 256,
          etag.utf8.first == 0x22, etag.utf8.last == 0x22, etag.utf8.count >= 2,
          etag.utf8.dropFirst().dropLast().allSatisfy({ $0 == 0x21 || (0x23...0x7E).contains($0) || $0 >= 0x80 }) else { return nil }
    self.total = size
    self.resource = resource
    self.etag = etag
  }

  private static func resourceKey(_ url: URL?) -> SHA256.Digest? {
    guard let url, let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
          parts.scheme == "https", let host = parts.host?.lowercased(), !host.isEmpty,
          parts.port == nil || parts.port == 443, parts.user == nil, parts.password == nil else { return nil }
    return SHA256.hash(data: Data("\(host)\n\(parts.percentEncodedPath)".utf8))
  }

  private static func length(_ response: HTTPURLResponse) -> Int64? {
    guard let value = response.value(forHTTPHeaderField: "Content-Length"),
          !value.isEmpty, value.utf8.allSatisfy({ (0x30...0x39).contains($0) }) else { return nil }
    return Int64(value)
  }

  static func identityEncoding(_ response: HTTPURLResponse) -> Bool {
    guard let encoding = response.value(forHTTPHeaderField: "Content-Encoding") else { return true }
    return encoding.lowercased() == "identity"
  }

  func applyRange(to request: inout URLRequest, from offset: Int64) {
    let matches = Self.resourceKey(request.url) == resource
    request.setValue(matches ? "bytes=\(offset)-" : nil, forHTTPHeaderField: "Range")
    request.setValue(matches ? etag : nil, forHTTPHeaderField: "If-Range")
  }

  func accepts(_ response: HTTPURLResponse, from offset: Int64) -> Bool {
    guard offset > 12, offset < total, response.statusCode == 206,
          Self.resourceKey(response.url) == resource, Self.identityEncoding(response),
          response.value(forHTTPHeaderField: "ETag")?.utf8.elementsEqual(etag.utf8) == true,
          response.value(forHTTPHeaderField: "Content-Range") == "bytes \(offset)-\(total - 1)/\(total)" else { return false }
    // A chunked response can omit Content-Length. The caller still checks the
    // final length against the complete representation before publishing it.
    return response.value(forHTTPHeaderField: "Content-Length") == nil || Self.length(response) == total - offset
  }
}

enum MP4ResumeResponse {
  case append, fresh, restart

  init(_ response: HTTPURLResponse?, spool: MP4DownloadSpool?, rangeRequested: Bool) {
    guard let response, let spool else { self = .fresh; return }
    switch response.statusCode {
    case 206:
      if rangeRequested, let validator = spool.validator,
         validator.accepts(response, from: spool.size), spool.canResume { self = .append }
      else { self = .restart }
    case 416: self = .restart
    default: self = .fresh
    }
  }
}

/// Owns a private temporary file and removes its directory when the transfer
/// or in-process cache releases it. The app never writes resume metadata.
final class MP4DownloadSpool {
  static let directoryPrefix = "breeze-video-partial-"
  private let directory: URL
  let file: URL
  private var writer: FileHandle?
  private(set) var size: Int64 = 0
  var validator: MP4ResumeValidator?

  init(temporaryDirectory: URL = FileManager.default.temporaryDirectory) throws {
    directory = temporaryDirectory.appendingPathComponent(Self.directoryPrefix + UUID().uuidString, isDirectory: true)
    file = directory.appendingPathComponent("video.mp4")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
      attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
    do {
      try Data().write(to: file)
    } catch {
      try? FileManager.default.removeItem(at: directory)
      throw error
    }
  }

  func append(_ data: Data) throws {
    if writer == nil {
      let handle = try FileHandle(forWritingTo: file)
      guard try handle.seekToEnd() == UInt64(size) else { throw CocoaError(.fileWriteUnknown) }
      writer = handle
    }
    try writer?.write(contentsOf: data)
    size += Int64(data.count)
  }

  func close() throws {
    let handle = writer
    writer = nil
    try handle?.close()
  }

  var canResume: Bool {
    guard let validator, size > 12, size < validator.total,
          let info = try? file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey]),
          info.isRegularFile == true, info.isSymbolicLink != true, info.fileSize.map(Int64.init) == size,
          let handle = try? FileHandle(forReadingFrom: file) else { return false }
    defer { try? handle.close() }
    guard let header = try? handle.read(upToCount: 12), header.count == 12 else { return false }
    return String(data: header[4..<8], encoding: .ascii) == "ftyp"
  }

  deinit {
    try? close()
    try? FileManager.default.removeItem(at: directory)
  }
}

/// Retains a few stopped transfers within this process. Only a matching
/// resource and account/route scope can retrieve a partial for resumption.
final class MP4PartialCache {
  private struct Entry {
    let id: String
    let scope: String
    let spool: MP4DownloadSpool
    let token = UUID()
    let expiry: DispatchTime = .now() + 30 * 60
  }

  private var entries: [Entry] = []

  func retain(_ spool: MP4DownloadSpool, id: String, scope: String) {
    discard(id)
    let entry = Entry(id: id, scope: scope, spool: spool)
    entries.append(entry)
    if entries.count > 3 { entries.removeFirst() }
    let token = entry.token
    DispatchQueue.main.asyncAfter(deadline: entry.expiry) { [weak self] in
      self?.entries.removeAll { $0.token == token }
    }
  }

  func take(id: String, scope: String) -> MP4DownloadSpool? {
    guard let index = entries.firstIndex(where: { $0.id == id }) else { return nil }
    let entry = entries.remove(at: index)
    guard entry.scope == scope, entry.expiry > .now(), entry.spool.canResume else { return nil }
    return entry.spool
  }

  func discard(_ id: String) {
    entries.removeAll { $0.id == id }
  }
}
