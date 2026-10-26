"""Execute the real Foundation-only WK navigation policy, without networking.

These are navigation-boundary and diagnostic-privacy checks. Passing them does
not prove that a Cloudflare challenge succeeds on a website or a real device.
"""

import json
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]


@unittest.skipUnless(sys.platform == "darwin" and shutil.which("xcrun"), "Apple Swift SDK required")
class VideoNavigationPolicyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = (ROOT / "ios/Runner/VideoSiteBrowser.swift").read_text()
        marker = "struct VideoSiteNavigationPolicy {"
        if marker not in source:
            raise AssertionError("Actual VideoSiteNavigationPolicy is missing from the iOS bridge")
        policy = source[source.index(marker):source.index("/// Standard WebKit browser for video sources.")]
        cls.directory = tempfile.TemporaryDirectory(prefix="breeze-video-navigation-policy-")
        cls.addClassCleanup(cls.directory.cleanup)
        path = pathlib.Path(cls.directory.name) / "policy_test.swift"
        cls.binary = pathlib.Path(cls.directory.name) / "policy_test"
        path.write_text(r'''
import Foundation

__POLICY__

let policy = VideoSiteNavigationPolicy(host: "hanime1.me")
let input = FileHandle.standardInput.readDataToEndOfFile()
let rows = try JSONSerialization.jsonObject(with: input) as! [[String: Any]]
let output: [[String: Any]] = rows.map { row in
  let raw = row["url"] as! String
  let url: URL
  switch row["construction"] as? String {
  case "bridged": url = NSURL(string: raw)! as URL
  case "request": url = URLRequest(url: NSURL(string: raw)! as URL).url!
  default: url = URL(string: raw)!
  }
  let reason = policy.rejectionReason(for: url, main: row["main"] as! Bool)
  return ["reason": reason as Any? ?? NSNull(), "classification": policy.classification(for: url)]
}
let data = try JSONSerialization.data(withJSONObject: output, options: [.sortedKeys])
FileHandle.standardOutput.write(data)
'''.replace("__POLICY__", policy))
        result = subprocess.run(
            ["xcrun", "swiftc", str(path), "-o", str(cls.binary)],
            capture_output=True, text=True, timeout=90,
        )
        if result.returncode:
            raise AssertionError(result.stderr)

    def evaluate(self, cases):
        result = subprocess.run(
            [str(self.binary)], input=json.dumps(cases),
            capture_output=True, text=True, timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_existing_frame_about_documents_allow_but_top_level_stays_restricted(self):
        local = [
            "about:blank", "about:srcdoc", "about:blank#fixture",
        ]
        rows = [{"url": url, "main": main} for url in local for main in (False, True)]
        for row, result in zip(rows, self.evaluate(rows)):
            with self.subTest(url=row["url"], main=row["main"]):
                if row["main"]:
                    self.assertIsNotNone(result["reason"])
                else:
                    self.assertIsNone(result["reason"])

    def test_bridged_webkit_about_documents_do_not_depend_on_foundation_path(self):
        cases = [
            ("about:blank", "blank"), ("about:srcdoc", "srcdoc"),
            ("about:blank#fixture", "blank"), ("about:srcdoc?fixture=1", "srcdoc"),
        ]
        rows = [{"url": url, "main": False, "construction": mode}
                for url, _ in cases for mode in ("bridged", "request")]
        for row, result in zip(rows, self.evaluate(rows)):
            with self.subTest(url=row["url"], construction=row["construction"]):
                self.assertIsNone(result["reason"])
                expected = "blank" if row["url"].startswith("about:blank") else "srcdoc"
                self.assertEqual(result["classification"]["aboutDocument"], expected)

    def test_https_frames_and_top_level_host_credentials_port_rules(self):
        cases = [
            ("https://hanime1.me/watch?v=1", True, None),
            ("https://HANIME1.ME/", True, None),
            ("https://hanime1.me:443/", True, None),
            ("https://example.com/frame", False, None),
            ("https://challenges.cloudflare.com/frame", False, None),
            ("https://challenges.cloudflare.com/frame", True, "top-level-host"),
            ("https://hanime1.me.evil.example/", True, "top-level-host"),
            ("https://user:pass@hanime1.me/", True, "credentials"),
            ("https://user@challenges.cloudflare.com/", False, "credentials"),
            ("https://@hanime1.me/", False, "credentials"),
            ("https://hanime1.me:444/", True, "port"),
            ("https://challenges.cloudflare.com:8443/", False, "port"),
        ]
        rows = [{"url": url, "main": main} for url, main, _ in cases]
        for case, result in zip(cases, self.evaluate(rows)):
            with self.subTest(url=case[0], main=case[1]):
                self.assertEqual(result["reason"], case[2])

    def test_file_http_custom_and_other_about_documents_remain_blocked(self):
        blocked = [
            "file:///private/fixture.txt", "http://hanime1.me/", "custom:fixture",
            "tel:123", "ftp://hanime1.me/file", "about:settings", "about:config",
            "data:text/html,<p>fixture</p>", "blob:https://challenges.cloudflare.com/fixture-id",
            "javascript:void(0)", "about://blank", "about:blank/", "about:%62lank",
            "about:blank.evil", "about:blank@evil",
        ]
        rows = [{"url": url, "main": main} for url in blocked for main in (False, True)]
        reasons = {"scheme", "credentials", "port", "top-level-host", "about-document"}
        for row, result in zip(rows, self.evaluate(rows)):
            with self.subTest(url=row["url"], main=row["main"]):
                self.assertIn(result["reason"], reasons)

    def test_classification_uses_only_fixed_enums_without_address_or_document_data(self):
        samples = [
            "https://hanime1.me/private-account?token=fixture-token#fixture-fragment",
            "https://challenges.cloudflare.com/turnstile/private-id?token=fixture-token",
            "https://child.challenges.cloudflare.com/private-id",
            "https://challenges.cloudflare.com.evil.example/private-id",
            "http://unlisted-fixture.example/private-id",
            "about:blank#fixture-fragment", "about:srcdoc?token=fixture-token", "about:settings",
            "data:text/html,<script>fixture-secret-body</script>",
            "blob:https://hanime1.me/fixture-private-blob-id",
            "javascript:console.log('fixture-secret-script')",
            "file:///private/fixture-file", "custom:fixture-secret",
        ]
        rows = [{"url": url, "main": False} for url in samples]
        enums = {
            "scheme": {"https", "http", "about", "data", "blob", "javascript", "file", "other"},
            "destination": {"site", "provider", "other", "none"},
            "aboutDocument": {"blank", "srcdoc", "other"},
            "aboutPathForm": {"not-about", "empty", "blank", "srcdoc", "other"},
        }
        output = self.evaluate(rows)
        for row, result in zip(rows, output):
            with self.subTest(url=row["url"]):
                classification = result["classification"]
                self.assertEqual(set(classification), set(enums))
                for key, value in classification.items():
                    self.assertIn(value, enums[key])
        serialized = json.dumps(output)
        for secret in ("fixture-", "private-account", "unlisted-fixture", "console.log", "<script>", "?token"):
            self.assertNotIn(secret, serialized)
        self.assertEqual(output[0]["classification"]["destination"], "site")
        self.assertEqual(output[1]["classification"]["destination"], "provider")
        self.assertEqual(output[2]["classification"]["destination"], "provider")
        self.assertEqual(output[3]["classification"]["destination"], "other")


if __name__ == "__main__":
    unittest.main()
