"""Run the production presenter selection with UIKit-shaped host fixtures.

This tests host ownership and transition rejection, not WebKit or site acceptance.
The release iOS build separately compiles the helper against real UIKit.
"""
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]

class VerificationPresenterTests(unittest.TestCase):
    def test_detached_browser_uses_live_engine_host_and_rejects_stale_hosts(self):
        source = (ROOT / 'ios/Runner/VideoSiteBrowser.swift').read_text()
        start = source.index('enum VideoVerificationPresentation {')
        end = source.index('/// A bounded comparison', start)
        helper = source[start:end]
        fixtures = '''
import Foundation
final class UIWindow {}
final class UIView { var window: UIWindow?; init(_ window: UIWindow?) { self.window = window } }
class UIViewController {
 var viewIfLoaded: UIView?
 var presentedViewController: UIViewController?
 var isBeingDismissed = false
 var isBeingPresented = false
 init(_ window: UIWindow? = nil) { if let window { viewIfLoaded = UIView(window) } }
}
final class UIAlertController: UIViewController {}
'''
        checks = '''
let window = UIWindow()
let host = UIViewController(window)
let detachedBrowserHost: UIViewController? = nil
assert(VideoVerificationPresentation.presenter(from: host) === host)
assert(VideoVerificationPresentation.presenter(from: detachedBrowserHost) == nil)
assert(VideoVerificationPresentation.presenter(from: UIViewController()) == nil)
let sheet = UIViewController(window)
host.presentedViewController = sheet
assert(VideoVerificationPresentation.presenter(from: host) === sheet)
sheet.isBeingDismissed = true
assert(VideoVerificationPresentation.presenter(from: host) == nil)
sheet.isBeingDismissed = false
sheet.isBeingPresented = true
assert(VideoVerificationPresentation.presenter(from: host) == nil)
sheet.isBeingPresented = false
sheet.viewIfLoaded?.window = nil
assert(VideoVerificationPresentation.presenter(from: host) == nil)
sheet.viewIfLoaded?.window = UIWindow()
assert(VideoVerificationPresentation.presenter(from: host) == nil)
host.presentedViewController = UIAlertController(window)
assert(VideoVerificationPresentation.presenter(from: host) == nil)
host.presentedViewController = nil
host.isBeingDismissed = true
assert(VideoVerificationPresentation.presenter(from: host) == nil)
print("Presenter ownership fixtures passed")
'''
        with tempfile.TemporaryDirectory(prefix='breeze-verification-presenter-') as temp:
            path = pathlib.Path(temp) / 'main.swift'
            path.write_text(fixtures + helper + checks)
            binary = pathlib.Path(temp) / 'check'
            subprocess.run(['xcrun', 'swiftc', str(path), '-o', str(binary)], check=True, capture_output=True, text=True)
            result = subprocess.run([str(binary)], check=True, capture_output=True, text=True)
            self.assertIn('fixtures passed', result.stdout)

if __name__ == '__main__':
    unittest.main()
