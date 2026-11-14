import Foundation
import CoreFoundation

/// Registration leases are distinct from the lifetime of their browser view.
/// Old close/callbacks cannot revoke a later lease, while view disposal is final.
struct VideoSiteAccountCookieAccess {
  let viewToken = UUID().uuidString.lowercased()
  private(set) var token = UUID().uuidString.lowercased()
  private(set) var generation = 0
  private var closed = true
  private var disposed = false
  mutating func open() throws -> String {
    guard !disposed else { throw VideoSiteAccountCookiePolicy.Failure.unavailable }
    token = UUID().uuidString.lowercased(); generation += 1; closed = false
    return token
  }
  mutating func close(_ token: String) {
    guard self.token == token else { return }
    closed = true; generation += 1
  }
  mutating func dispose(_ viewToken: String) -> Bool {
    guard self.viewToken == viewToken else { return false }
    disposed = true; closed = true; generation += 1
    return true
  }
  func live(_ token: String, generation: Int) -> Bool {
    !disposed && !closed && self.token == token && self.generation == generation
  }
}

/// Pure boundary for a view's exact source/origin. This never reads a default
/// cookie jar, broadens a domain, or includes verification-provider cookies.
struct VideoSiteAccountCookiePolicy {
  enum Failure: Error { case unavailable, rejected, quota }
  let source: String
  let host: String
  let origin: String

  init(home: URL?, source: String?) throws {
    guard let source, !source.isEmpty, source.count <= 200,
      let home, let parts = URLComponents(url: home, resolvingAgainstBaseURL: false),
      parts.scheme?.lowercased() == "https", let host = parts.host?.lowercased(), !host.isEmpty,
      parts.user == nil, parts.password == nil, parts.port == nil || parts.port == 443 else { throw Failure.unavailable }
    var canonical = URLComponents()
    canonical.scheme = "https"; canonical.host = host
    guard let origin = canonical.string else { throw Failure.unavailable }
    self.source = source; self.host = host; self.origin = origin
  }

  func accepts(_ url: URL) -> Bool {
    guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
    return parts.scheme?.lowercased() == "https" && parts.host?.lowercased() == host &&
      parts.user == nil && parts.password == nil && (parts.port == nil || parts.port == 443) &&
      (parts.path.isEmpty || parts.path == "/") && parts.query == nil && parts.fragment == nil
  }

  private func domain(_ value: String) -> String {
    String(value.hasPrefix(".") ? value.dropFirst() : value[...]).lowercased()
  }
  private func accountName(_ value: String) -> Bool {
    value.range(of: "^[!#$%&'*+.^_`|~0-9A-Za-z-]{1,120}$", options: .regularExpression) != nil &&
      value.range(of: "^(?:__cf|cf_|_cf|xsrf|csrf|_ga|_gid|_fbp)|challenge|turnstile|captcha",
        options: [.regularExpression, .caseInsensitive]) == nil
  }
  private var declaredOmoOrigin: Bool {
    source == "ccc2fe17-c0a8-4fd8-a596-835772686404" &&
      ["www.omofuna.com", "omofuna.com"].contains(host)
  }
  private func declaredOmoAccount(_ name: String) -> Bool {
    declaredOmoOrigin && ["user_id", "user_name", "user_check"].contains(name)
  }
  private func acceptsDomain(_ value: String, name: String) -> Bool {
    domain(value) == host || declaredOmoAccount(name) && host == "www.omofuna.com" && domain(value) == "omofuna.com"
  }
  func key(_ cookie: HTTPCookie) -> String {
    cookie.name + "\u{0}" + domain(cookie.domain) + "\u{0}" + cookie.path
  }
  func wire(_ cookie: HTTPCookie, now: Date = Date()) -> [String: Any]? {
    guard accountName(cookie.name), !declaredOmoOrigin || declaredOmoAccount(cookie.name),
      !cookie.value.isEmpty, cookie.value.utf16.count <= 4096,
      cookie.value.rangeOfCharacter(from: .controlCharacters) == nil,
      acceptsDomain(cookie.domain, name: cookie.name),
      declaredOmoAccount(cookie.name) || cookie.isHTTPOnly && cookie.isSecure,
      cookie.path.hasPrefix("/"), cookie.path.utf16.count <= 256,
      cookie.path.rangeOfCharacter(from: .controlCharacters) == nil,
      cookie.expiresDate == nil || cookie.expiresDate! > now else { return nil }
    return ["name": cookie.name, "value": cookie.value, "domain": cookie.domain, "path": cookie.path,
      "httpOnly": cookie.isHTTPOnly, "secure": cookie.isSecure,
      "expires": cookie.expiresDate.map { Int64($0.timeIntervalSince1970 * 1000) as Any } ?? NSNull()]
  }
  func export(_ cookies: [HTTPCookie], now: Date = Date()) throws -> [[String: Any]] {
    let allowed = cookies.filter { wire($0, now: now) != nil }
    guard allowed.count <= 32, Set(allowed.map(key)).count == allowed.count,
      allowed.reduce(0, { $0 + $1.value.utf16.count }) <= 24000 else { throw Failure.quota }
    return allowed.compactMap { wire($0, now: now) }
  }
  func cookie(_ raw: [String: Any], origin: URL, existingDomain: String? = nil,
              now: Date = Date()) throws -> HTTPCookie {
    guard accepts(origin), let name = raw["name"] as? String, accountName(name),
      !declaredOmoOrigin || declaredOmoAccount(name),
      let value = raw["value"] as? String, !value.isEmpty, value.utf16.count <= 4096,
      value.rangeOfCharacter(from: .controlCharacters) == nil,
      let rawDomain = raw["domain"] as? String, acceptsDomain(rawDomain, name: name),
      let httpOnly = raw["httpOnly"] as? Bool, let secure = raw["secure"] as? Bool,
      declaredOmoAccount(name) || httpOnly && secure,
      let path = raw["path"] as? String, path.hasPrefix("/"), path.utf16.count <= 256,
      path.rangeOfCharacter(from: .controlCharacters) == nil,
      existingDomain == nil || domain(existingDomain!) == domain(rawDomain) else { throw Failure.rejected }
    var properties: [HTTPCookiePropertyKey: Any] = [.name: name, .value: value,
      .domain: existingDomain ?? rawDomain, .path: path]
    if secure { properties[.secure] = "TRUE" }
    if httpOnly { properties[HTTPCookiePropertyKey(rawValue: "HttpOnly")] = "TRUE" }
    if let rawExpiry = raw["expires"], !(rawExpiry is NSNull) {
      guard let number = rawExpiry as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
        number.doubleValue.isFinite, number.doubleValue.rounded(.towardZero) == number.doubleValue,
        number.doubleValue > now.timeIntervalSince1970 * 1000,
        number.doubleValue < Double(Int64.max) else { throw Failure.rejected }
      properties[.expires] = Date(timeIntervalSince1970: number.doubleValue / 1000)
    } else { properties[.discard] = "TRUE" }
    guard let cookie = HTTPCookie(properties: properties), wire(cookie, now: now) != nil else { throw Failure.rejected }
    return cookie
  }
  func same(_ a: HTTPCookie, _ b: HTTPCookie) -> Bool {
    guard key(a) == key(b), a.value == b.value, a.isHTTPOnly == b.isHTTPOnly,
      a.isSecure == b.isSecure else { return false }
    switch (a.expiresDate, b.expiresDate) {
    case (nil, nil): return true
    case let (a?, b?): return abs(a.timeIntervalSince(b)) < 1
    default: return false
    }
  }
  func canCompensate(current: [HTTPCookie], applied: HTTPCookie, deleting: Bool) -> Bool {
    let matching = current.filter { key($0) == key(applied) }
    return deleting ? matching.isEmpty : matching.count == 1 && same(matching[0], applied)
  }
}
