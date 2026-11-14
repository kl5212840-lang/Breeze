import Foundation

@main
enum VideoSiteAccountCookieTests {
  static func main() throws {
    let origin = URL(string: "https://fixture.test")!
    let policy = try VideoSiteAccountCookiePolicy(home: origin, source: "fixture-source")
    let expiry = Int64(Date().addingTimeInterval(3600).timeIntervalSince1970 * 1000)
    let raw: [String: Any] = ["name": "session", "value": "fixture-session", "domain": "fixture.test",
      "path": "/", "httpOnly": true, "secure": true, "expires": expiry]
    let account = try policy.cookie(raw, origin: origin)
    precondition(policy.wire(account)?["value"] as? String == "fixture-session")
    precondition(policy.wire(account)?["expires"] as? Int64 != nil)
    precondition(policy.accepts(origin))
    for invalid in ["http://fixture.test", "https://elsewhere.test", "https://fixture.test:444",
      "https://user@fixture.test", "https://fixture.test/?token=private", "https://fixture.test/path"] {
      precondition(!policy.accepts(URL(string: invalid)!))
    }
    for name in ["__cf_bm", "cf_clearance", "challenge-token", "turnstile_session", "csrf", "_ga"] {
      var invalid = raw; invalid["name"] = name
      do { _ = try policy.cookie(invalid, origin: origin); preconditionFailure("provider cookie accepted") }
      catch VideoSiteAccountCookiePolicy.Failure.rejected {}
    }
    let invalidValues: [(String, Any)] = [("domain", "elsewhere.test"), ("httpOnly", false),
      ("secure", false), ("path", "relative"), ("expires", Int64(1)), ("expires", true)]
    for (key, value) in invalidValues {
      var invalid = raw; invalid[key] = value
      do { _ = try policy.cookie(invalid, origin: origin); preconditionFailure("invalid cookie accepted") }
      catch VideoSiteAccountCookiePolicy.Failure.rejected {}
    }
    let provider = HTTPCookie(properties: [.name: "cf_clearance", .value: "provider-fixture",
      .domain: "fixture.test", .path: "/", .secure: "TRUE",
      HTTPCookiePropertyKey(rawValue: "HttpOnly"): "TRUE"])!
    let unrelated = HTTPCookie(properties: [.name: "session", .value: "other-fixture",
      .domain: "elsewhere.test", .path: "/", .secure: "TRUE",
      HTTPCookiePropertyKey(rawValue: "HttpOnly"): "TRUE"])!
    let exported = try policy.export([provider, account, unrelated])
    precondition(exported.count == 1 && exported[0]["name"] as? String == "session")
    let dotted = try policy.cookie(raw, origin: origin, existingDomain: ".fixture.test")
    precondition(policy.key(dotted) == policy.key(account))
    precondition(policy.same(dotted, account))
    do { _ = try policy.export([dotted, account]); preconditionFailure("ambiguous account identity accepted") }
    catch VideoSiteAccountCookiePolicy.Failure.quota {}
    var changed = raw; changed["value"] = "new-visit-session"
    let newer = try policy.cookie(changed, origin: origin)
    precondition(policy.canCompensate(current: [account], applied: account, deleting: false))
    precondition(!policy.canCompensate(current: [newer], applied: account, deleting: false))
    precondition(policy.canCompensate(current: [], applied: account, deleting: true))
    precondition(!policy.canCompensate(current: [newer], applied: account, deleting: true))
    var access = VideoSiteAccountCookieAccess()
    let first = try access.open(), firstGeneration = access.generation
    precondition(access.live(first, generation: firstGeneration))
    let second = try access.open(), secondGeneration = access.generation
    precondition(!access.live(first, generation: firstGeneration))
    access.close(first)
    precondition(access.live(second, generation: secondGeneration))
    access.close(second)
    precondition(!access.live(second, generation: secondGeneration))
    let resumed = try access.open(), resumedGeneration = access.generation
    precondition(!access.dispose(UUID().uuidString))
    precondition(access.live(resumed, generation: resumedGeneration))
    precondition(access.dispose(access.viewToken))
    precondition(!access.live(resumed, generation: resumedGeneration))
    do { _ = try access.open(); preconditionFailure("disposed browser reopened a lease") }
    catch VideoSiteAccountCookiePolicy.Failure.unavailable {}
    let omoOrigin = URL(string: "https://www.omofuna.com")!
    let omo = try VideoSiteAccountCookiePolicy(home: omoOrigin, source: "ccc2fe17-c0a8-4fd8-a596-835772686404")
    let omoUnknown = try VideoSiteAccountCookiePolicy(home: omoOrigin, source: "unknown-source")
    for name in ["user_id", "user_name", "user_check"] {
      let allowed: [String: Any] = ["name": name, "value": "synthetic-only", "domain": ".omofuna.com",
        "path": "/", "httpOnly": false, "secure": false, "expires": expiry]
      let cookie = try omo.cookie(allowed, origin: omoOrigin)
      let wire = omo.wire(cookie)!
      precondition(wire["httpOnly"] as? Bool == false && wire["secure"] as? Bool == false)
      precondition(wire["domain"] as? String == ".omofuna.com")
      let restored = try omo.cookie(wire, origin: omoOrigin)
      precondition(omo.same(cookie, restored))
      do { _ = try omoUnknown.cookie(allowed, origin: omoOrigin); preconditionFailure("unknown source inherited Omo policy") }
      catch VideoSiteAccountCookiePolicy.Failure.rejected {}
      for invalid in ["evil.omofuna.com", "omofuna.com.evil.test", "com"] {
        var polluted = allowed; polluted["domain"] = invalid
        do { _ = try omo.cookie(polluted, origin: omoOrigin); preconditionFailure("unrelated cookie scope accepted") }
        catch VideoSiteAccountCookiePolicy.Failure.rejected {}
      }
    }
    for name in ["user_pwd", "group_name", "cf_clearance", "csrf", "PHPSESSID"] {
      var wrongName = raw; wrongName["domain"] = "www.omofuna.com"; wrongName["name"] = name
      do { _ = try omo.cookie(wrongName, origin: omoOrigin); preconditionFailure("undeclared Omo cookie accepted") }
      catch VideoSiteAccountCookiePolicy.Failure.rejected {}
    }
    print("Video site account cookie boundary: 7 groups passed")
  }
}
