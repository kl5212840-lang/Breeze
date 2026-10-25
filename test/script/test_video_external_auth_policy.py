"""Execute the actual Foundation-only policy extracted from the iOS bridge.

This checks URL allowlisting and revocation, not WK delegate/device behavior or
successful website authentication. No app is built and no network is accessed.
"""

import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]


@unittest.skipUnless(sys.platform == "darwin" and shutil.which("xcrun"), "Apple Swift SDK required")
class ExternalAuthenticationPolicyTests(unittest.TestCase):
    def test_actual_swift_policy_is_exact_opt_in_and_revocable(self):
        source = (ROOT / "ios/Runner/VideoSiteBrowser.swift").read_text()
        policy = source[
            source.index("struct VideoSiteExternalAuthenticationPolicy {"):
            source.index("/// Standard WebKit browser for video sources.")
        ]
        probe = r'''
import Foundation

__POLICY__

let origin = URL(string: "https://hanime1.me/")!
let clean = "https://hanime1.me/auth/google"
let rejected = [
  "https://accounts.google.com/auth/google",
  "https://hanime1.me.evil.example/auth/google",
  "http://hanime1.me/auth/google",
  "https://hanime1.me:444/auth/google",
  "https://user@hanime1.me/auth/google",
  "https://@hanime1.me/auth/google",
  "https://hanime1.me/auth/google?state=private",
  "https://hanime1.me/auth/google?",
  "https://hanime1.me/auth/google#code",
  "https://hanime1.me/auth/google#",
  "https://hanime1.me/auth/google/",
  "https://hanime1.me/auth/%67oogle",
  "https://hanime1.me/auth%2Fgoogle",
  "https://hanime1.me/auth/apple",
  "https://hanime1.me/watch?v=1",
  "/auth/google"
]
var policy = VideoSiteExternalAuthenticationPolicy(home: origin, entries: [])
precondition(policy.registeredEntry(for: URL(string: clean)!) == nil, "default must stay empty")
policy.update([clean] + rejected)
precondition(policy.registeredEntry(for: URL(string: clean)!) == clean)
precondition(policy.registeredEntry(for: URL(string: "https://hanime1.me:443/auth/google")!) == clean)
for raw in rejected {
  precondition(policy.registeredEntry(for: URL(string: raw)!) == nil, "rejected raw entry: \(raw)")
}
policy.update([])
precondition(policy.registeredEntry(for: URL(string: clean)!) == nil, "revoke must remove entry")
policy.update(["https://accounts.google.com/auth/google"])
precondition(policy.registeredEntry(for: URL(string: clean)!) == nil, "provider cannot opt in site")
for raw in ["http://hanime1.me/", "https://hanime1.me:444/", "https://user@hanime1.me/", "https://@hanime1.me/", "/"] {
  let invalid = VideoSiteExternalAuthenticationPolicy(home: URL(string: raw), entries: [clean])
  precondition(invalid.registeredEntry(for: URL(string: clean)!) == nil, "invalid home")
}
print("exact-entry/default-empty/update/revoke/raw-url checks passed")
'''.replace("__POLICY__", policy)
        with tempfile.TemporaryDirectory(prefix="breeze-video-auth-policy-") as directory:
            path = pathlib.Path(directory) / "policy_test.swift"
            path.write_text(probe)
            result = subprocess.run(
                ["xcrun", "swift", str(path)], capture_output=True, text=True, timeout=90
            )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("raw-url checks passed", result.stdout)


if __name__ == "__main__":
    unittest.main()
