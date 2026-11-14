"""Exercise the production iOS public share-page policy using Foundation."""
from pathlib import Path
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[2]
class SharePagePolicyTests(unittest.TestCase):
    def test_all_public_page_families_and_private_query_rejection(self):
        source=(ROOT/'ios/Runner/AppDelegate.swift').read_text()
        begin=source.index('  private func isPublicVideoPage(')
        end=source.index('  private func share(',begin)
        policy=source[begin:end].replace('private func','func',1)
        program='import Foundation\nstruct Policy {\n'+policy+'}\n'+'''
let policy = Policy()
let valid = ["/watch?v=42", "/voddetail/7.html", "/index.php/vod/detail/id/7.html", "/vod/7/", "/anime/023c74a87da31be14245e313.html", "/videos/QC-BT-123"]
for path in valid { assert(policy.isPublicVideoPage(URL(string: "https://source.example"+path)!), path) }
let invalid = ["/videos/", "/videos/has/slash", "/videos/id?token=private", "/watch?v=42&token=private", "/watch?v=abc", "/user/42", "/login", "/voddetail/0.html"]
for path in invalid { assert(!policy.isPublicVideoPage(URL(string: "https://source.example"+path)!), path) }
'''
        with tempfile.TemporaryDirectory(prefix='breeze-share-policy-') as temp:
            file=Path(temp)/'main.swift';file.write_text(program);binary=Path(temp)/'check'
            subprocess.run(['xcrun','swiftc',str(file),'-o',str(binary)],check=True,capture_output=True)
            result=subprocess.run([str(binary)],capture_output=True)
            self.assertEqual(result.returncode,0,result.stderr.decode(errors='replace')[:1600])
if __name__=='__main__':unittest.main()
