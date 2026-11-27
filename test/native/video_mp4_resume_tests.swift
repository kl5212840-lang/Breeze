import Foundation

@main
struct VideoMP4ResumeTests {
  static func check(_ condition: @autoclosure () throws -> Bool) throws {
    if try !condition() { throw URLError(.cannotDecodeContentData) }
  }

  static func response(_ status: Int, _ address: String, headers: [String: String]) -> HTTPURLResponse {
    HTTPURLResponse(url: URL(string: address)!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
  }

  static func main() throws {
    var retry = MP4RetryBudget()
    try check([retry.nextDelay(), retry.nextDelay(), retry.nextDelay()] == [1, 3, 7])
    try check(retry.nextDelay() == nil)
    try check(MP4RetryBudget.transient(URLError(.networkConnectionLost) as NSError))
    try check(MP4RetryBudget.transient(URLError(.timedOut) as NSError))
    try check(!MP4RetryBudget.transient(URLError(.serverCertificateUntrusted) as NSError))
    try check(!MP4RetryBudget.transient(URLError(.cancelled) as NSError))
    for status in [408, 502, 503, 504] { try check(MP4RetryBudget.transientHTTP(status)) }
    for status in [401, 403, 404, 429] { try check(!MP4RetryBudget.transientHTTP(status)) }
    let first = "https://cdn.example/movie.mp4?signature=old"
    let fresh = "https://cdn.example/movie.mp4?signature=fresh"
    let validator = MP4ResumeValidator(response(200, first, headers: ["Content-Length": "24", "ETag": "\"edition\""]))!
    let folder = FileManager.default.temporaryDirectory
    let prefix = Data([0, 0, 0, 24, 102, 116, 121, 112, 0, 0, 0, 0, 1, 2, 3, 4])
    let suffix = Data([5, 6, 7, 8, 9, 10, 11, 12])
    let spool = try MP4DownloadSpool(temporaryDirectory: folder)
    spool.validator = validator
    try spool.append(prefix)
    try spool.close()
    try check(spool.canResume)

    var resumed = URLRequest(url: URL(string: fresh)!)
    validator.applyRange(to: &resumed, from: spool.size)
    try check(resumed.value(forHTTPHeaderField: "Range") == "bytes=16-")
    try check(resumed.value(forHTTPHeaderField: "If-Range") == "\"edition\"")
    resumed.url = URL(string: "https://other.example/movie.mp4")
    validator.applyRange(to: &resumed, from: spool.size)
    try check(resumed.value(forHTTPHeaderField: "Range") == nil)
    try check(resumed.value(forHTTPHeaderField: "If-Range") == nil)

    let valid = ["Content-Length": "8", "Content-Range": "bytes 16-23/24", "ETag": "\"edition\""]
    try check(validator.accepts(response(206, fresh, headers: valid), from: spool.size))
    try check(MP4ResumeResponse(response(206, fresh, headers: valid), spool: spool, rangeRequested: true) == .append)
    try check(MP4ResumeResponse(response(206, fresh, headers: valid), spool: spool, rangeRequested: false) == .restart)
    try check(MP4ResumeResponse(response(200, fresh, headers: [:]), spool: spool, rangeRequested: true) == .fresh)
    try check(MP4ResumeResponse(response(416, fresh, headers: [:]), spool: spool, rangeRequested: true) == .restart)
    try check(MP4ResumeResponse(response(416, fresh, headers: [:]), spool: nil, rangeRequested: false) == .fresh)
    for (name, value) in [("Content-Range", "bytes 15-23/24"), ("Content-Range", "bytes 16-23/25"),
                          ("Content-Range", "bytes 16-22/24"), ("Content-Length", "9"),
                          ("Content-Encoding", "gzip"), ("ETag", "W/\"edition\""), ("ETag", "\"other\"")] {
      var headers = valid
      headers[name] = value
      try check(!validator.accepts(response(206, fresh, headers: headers), from: spool.size))
      try check(MP4ResumeResponse(response(206, fresh, headers: headers), spool: spool, rangeRequested: true) == .restart)
    }
    try check(!validator.accepts(response(206, "https://cdn.example/another.mp4", headers: valid), from: spool.size))
    try check(!validator.accepts(response(200, fresh, headers: valid), from: spool.size))
    try check(!validator.accepts(response(416, fresh, headers: valid), from: spool.size))
    try check(MP4ResumeValidator(response(200, first, headers: ["Content-Length": "24", "ETag": "W/\"edition\""])) == nil)

    let cache = MP4PartialCache()
    cache.retain(spool, id: "video", scope: "account-route-1")
    try check(cache.take(id: "video", scope: "account-route-2") == nil)
    try check(cache.take(id: "video", scope: "account-route-1") == nil)
    cache.retain(spool, id: "video", scope: "account-route-1")
    try check(cache.take(id: "video", scope: "account-route-1") === spool)
    cache.retain(spool, id: "video", scope: "account-route-1")
    cache.discard("video")
    try check(cache.take(id: "video", scope: "account-route-1") == nil)

    func deposit(_ id: String) throws -> URL {
      let owned = try MP4DownloadSpool(temporaryDirectory: folder)
      owned.validator = validator
      try owned.append(prefix)
      try owned.close()
      cache.retain(owned, id: id, scope: "account-route-1")
      return owned.file
    }
    let oldest = try deposit("oldest")
    let removed = try deposit("removed")
    _ = try deposit("third")
    _ = try deposit("fourth")
    try check(!FileManager.default.fileExists(atPath: oldest.path))
    try check(FileManager.default.fileExists(atPath: removed.path))
    cache.discard("removed")
    try check(!FileManager.default.fileExists(atPath: removed.path))

    try spool.append(suffix)
    try spool.close()
    try check(spool.size == 24)
    try check(!spool.canResume)
    try check(try Data(contentsOf: spool.file) == prefix + suffix)

    let invalid = try MP4DownloadSpool(temporaryDirectory: folder)
    invalid.validator = validator
    try invalid.append(Data(repeating: 0, count: 16))
    try invalid.close()
    try check(!invalid.canResume)
    print("MP4 resume request, validator and private byte spool checks passed")
  }
}
