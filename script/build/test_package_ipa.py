import plistlib
from pathlib import Path
import tempfile
import unittest
import zipfile

from package_ipa import package, verify


class IpaPackagingTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.app = self.root / 'Runner.app'
        self.app.mkdir()
        (self.app / 'Info.plist').write_bytes(plistlib.dumps({
            'CFBundleIdentifier': 'com.example.test',
            'CFBundleShortVersionString': '1.0',
            'CFBundleVersion': '1',
            'CFBundleExecutable': 'Runner',
        }))
        self.executable = self.app / 'Runner'
        self.executable.write_bytes(b'test executable')
        self.executable.chmod(0o755)
        self.ipa = self.root / 'test.ipa'

    def test_source_sidecars_never_enter_archive_and_permissions_survive(self):
        (self.app / '._Runner').write_bytes(b'AppleDouble')
        (self.app / '.DS_Store').write_bytes(b'Finder')
        (self.app / '__MACOSX').mkdir()
        (self.app / '__MACOSX' / 'extra').write_bytes(b'Finder')
        package(self.app, self.ipa)
        result = verify(self.ipa)
        self.assertEqual(result['app_bundles'], 1)
        self.assertEqual(result['macos_metadata'], 0)
        self.assertEqual(result['executable_permissions'], 'passed')
        with zipfile.ZipFile(self.ipa) as archive:
            self.assertEqual(archive.read('Payload/Runner.app/Runner'),
                             self.executable.read_bytes())

    def test_appledouble_pseudo_app_reproducing_install_failure_is_rejected(self):
        package(self.app, self.ipa)
        with zipfile.ZipFile(self.ipa, 'a') as archive:
            archive.writestr('Payload/._Runner.app', b'\x00\x05\x16\x07')
        with self.assertRaisesRegex(ValueError, 'macOS metadata'):
            verify(self.ipa)

    def test_second_app_is_rejected(self):
        package(self.app, self.ipa)
        with zipfile.ZipFile(self.ipa, 'a') as archive:
            archive.writestr('Payload/Other.app/', b'')
        with self.assertRaisesRegex(ValueError, 'exactly one app'):
            verify(self.ipa)

    def test_invalid_executable_does_not_replace_existing_output(self):
        package(self.app, self.ipa)
        previous = self.ipa.read_bytes()
        self.executable.chmod(0o644)
        with self.assertRaisesRegex(ValueError, 'execute permissions'):
            package(self.app, self.ipa)
        self.assertEqual(self.ipa.read_bytes(), previous)
        self.assertFalse(self.ipa.with_name('test.ipa.tmp').exists())


if __name__ == '__main__':
    unittest.main()
