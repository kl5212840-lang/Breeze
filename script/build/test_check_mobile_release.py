"""Regression checks using synthetic release records and package metadata."""

import argparse
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import check_mobile_release as check


SIGNER = 'a' * 64


class MobileReleaseTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        root = Path(directory.name)
        self.ipa = root / 'candidate.ipa'
        self.apk = root / 'candidate.apk'
        self.previous = root / 'previous.apk'
        self.ipa.write_bytes(b'ipa fixture')
        self.apk.write_bytes(b'apk fixture')
        self.previous.write_bytes(b'previous apk fixture')
        self.source = {'commit': 'commit', 'tree': 'tree', 'version': '3.0.39', 'build': 2582}
        self.ipa_info = {
            'bundle_id': check.APP_ID, 'version': '3.0.39', 'build': '2582',
            'supported_platforms': ['iPhoneOS'],
            **check.fingerprint(self.ipa),
        }
        self.apk_info = {
            'package_id': check.APP_ID, 'version': '3.0.39', 'version_code': 4582,
            'abi': check.ABI, 'signer_sha256': SIGNER, **check.fingerprint(self.apk),
        }
        self.prior_info = {
            **self.apk_info, 'version': '3.0.38', 'version_code': 4497, **check.fingerprint(self.previous),
        }
        self.args = argparse.Namespace(
            repo=root, source_ref='candidate', merged_ref=None, remote=None,
            previous_release=root / 'previous.json', ipa=self.ipa, apk=self.apk,
            previous_apk=self.previous, previous_signer_sha256=None, android_build_tools=None,
            published_release=root / 'published.json', checksums=root / 'SHA256SUMS.txt',
            icloud_ipa=root / 'icloud.ipa', icloud_apk=root / 'icloud.apk',
            check_icloud_upload=False,
        )
        self.args.icloud_ipa.write_bytes(self.ipa.read_bytes())
        self.args.icloud_apk.write_bytes(self.apk.read_bytes())
        checksums = ''.join(f'{check.fingerprint(path)["sha256"]}  {name}\n' for name, path in (
            ('Breeze-iOS-v3.0.39.ipa', self.ipa),
            ('Breeze-Android-v3.0.39-arm64-v8a.apk', self.apk),
        ))
        self.args.checksums.write_text(checksums, encoding='utf-8')
        self.write_release(self.args.previous_release, 'v3.0.38', [
            self.asset('Breeze-Android-v3.0.38-arm64-v8a.apk', self.prior_info),
        ])
        self.write_release(self.args.published_release, 'v3.0.39', [
            self.asset('Breeze-iOS-v3.0.39.ipa', self.ipa_info),
            self.asset('Breeze-Android-v3.0.39-arm64-v8a.apk', self.apk_info),
            self.asset('SHA256SUMS.txt', check.fingerprint(self.args.checksums)),
        ])

    @staticmethod
    def asset(name, info):
        return {
            'name': name, 'state': 'uploaded', 'size': info['bytes'],
            'digest': 'sha256:' + info['sha256'],
        }

    @staticmethod
    def write_release(path, tag, assets):
        path.write_text(json.dumps({
            'tag_name': tag, 'draft': False, 'prerelease': False,
            'published_at': '2026-11-27T00:00:00Z', 'assets': assets,
        }), encoding='utf-8')

    def verify(self):
        packages = {self.apk: self.apk_info, self.previous: self.prior_info}
        with (
            patch.object(check, 'read_source', return_value=self.source),
            patch.object(check.package_ipa, 'verify', return_value=self.ipa_info),
            patch.object(check, 'inspect_apk', side_effect=lambda path, _: packages[path]),
        ):
            return check.verify_release(self.args)

    def test_matches_all_supplied_inputs(self):
        result = self.verify()
        self.assertEqual(result['previous_build'], 2497)
        self.assertEqual(len(result['published_release_metadata']['matched_assets']), 3)
        self.assertEqual(result['icloud_readback']['upload_status'], 'not checked')
        self.assertEqual(result['source_attestation'], 'not checked')

    def test_rejects_a_draft_previous_release(self):
        release = json.loads(self.args.previous_release.read_text(encoding='utf-8'))
        release['draft'] = True
        self.args.previous_release.write_text(json.dumps(release), encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'expected a published stable GitHub release'):
            self.verify()

    def test_rejects_a_different_merged_source_tree(self):
        self.args.merged_ref = 'merged'
        with (
            patch.object(check, 'resolve_commit', return_value='merged-commit'),
            patch.object(check, 'run', return_value='different-tree'),
            self.assertRaisesRegex(ValueError, 'Merged source tree'),
        ):
            self.verify()

    def test_rejects_source_version_that_does_not_advance(self):
        self.source['version'] = '3.0.38'
        with self.assertRaisesRegex(ValueError, 'Source version .* must advance'):
            self.verify()

    def test_rejects_source_build_that_does_not_advance(self):
        self.prior_info['version_code'] = self.apk_info['version_code']
        with self.assertRaisesRegex(ValueError, 'Source build .* must advance'):
            self.verify()

    def test_rejects_changed_ipa_metadata(self):
        for key, value, label in (
            ('bundle_id', 'different.app', 'IPA bundle identifier'),
            ('version', '3.0.38', 'IPA marketing version'),
            ('build', '2581', 'IPA build number'),
            ('supported_platforms', ['iPhoneSimulator'], 'IPA supported platforms'),
        ):
            with self.subTest(key=key), patch.dict(self.ipa_info, {key: value}):
                with self.assertRaisesRegex(ValueError, label):
                    self.verify()

    def test_rejects_changed_apk_metadata(self):
        for key, value, label in (
            ('package_id', 'different.app', 'APK package identifier'),
            ('version', '3.0.38', 'APK marketing version'),
            ('version_code', 2582, 'ARM64 APK versionCode'),
            ('signer_sha256', 'b' * 64, 'APK signer SHA-256'),
        ):
            with self.subTest(key=key), patch.dict(self.apk_info, {key: value}):
                with self.assertRaisesRegex(ValueError, label):
                    self.verify()

    def test_rejects_prior_apk_with_different_release_asset_digest(self):
        self.prior_info['sha256'] = 'b' * 64
        with self.assertRaisesRegex(ValueError, 'v3.0.38-arm64-v8a.apk GitHub asset digest'):
            self.verify()

    def test_accepts_a_trusted_prior_signer(self):
        self.args.previous_apk = None
        self.args.previous_signer_sha256 = SIGNER.upper()
        self.assertEqual(self.verify()['previous_signer_evidence'], 'caller-supplied certificate fingerprint')

    def test_rejects_published_asset_mismatch(self):
        release = json.loads(self.args.published_release.read_text(encoding='utf-8'))
        for field, value, label in (
            ('state', 'new', 'GitHub asset state'),
            ('size', 123, 'GitHub asset size'),
            ('digest', 'sha256:' + 'b' * 64, 'GitHub asset digest'),
        ):
            with self.subTest(field=field), patch.dict(release['assets'][0], {field: value}):
                self.args.published_release.write_text(json.dumps(release), encoding='utf-8')
                with self.assertRaisesRegex(ValueError, label):
                    self.verify()

    def test_rejects_mismatched_checksum_entries(self):
        self.args.checksums.write_text(f'{"0" * 64}  Breeze-iOS-v3.0.39.ipa\n', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'Checksum file entries'):
            self.verify()

    def test_rejects_same_size_icloud_readback_with_different_bytes(self):
        self.args.icloud_apk.write_bytes(b'bad fixture')
        with self.assertRaisesRegex(ValueError, 'iCloud APK readback sha256'):
            self.verify()

    def test_icloud_upload_state_is_checked_when_requested(self):
        self.args.check_icloud_upload = True
        with patch.object(check, 'run', return_value='') as status:
            self.assertEqual(self.verify()['icloud_readback']['upload_status'], 'uploaded')
            self.assertEqual(status.call_args.args[0], 'swift')
            self.assertEqual(status.call_args.args[2:], (self.args.icloud_ipa, self.args.icloud_apk))


class MetadataTest(unittest.TestCase):
    def test_remote_tag_can_be_absent_before_publication(self):
        with patch.object(check, 'run', return_value=''):
            self.assertIsNone(check.check_remote_tag('.', 'origin', 'v3.0.39', 'candidate', required=False))
            with self.assertRaisesRegex(ValueError, 'Remote tag v3.0.39 is missing'):
                check.check_remote_tag('.', 'origin', 'v3.0.39', 'candidate', required=True)

    def test_remote_tag_must_resolve_to_the_expected_commit(self):
        with patch.object(check, 'run', return_value='stale\trefs/tags/v3.0.39'):
            with self.assertRaisesRegex(ValueError, 'Remote tag v3.0.39 on origin'):
                check.check_remote_tag('.', 'origin', 'v3.0.39', 'candidate', required=False)
        annotated = 'object\trefs/tags/v3.0.39\ncandidate\trefs/tags/v3.0.39^{}'
        with patch.object(check, 'run', return_value=annotated):
            self.assertEqual(
                check.check_remote_tag('.', 'origin', 'v3.0.39', 'candidate', required=True),
                'candidate',
            )

    def test_requires_an_arm64_only_apk(self):
        package = "package: name='com.zephyr.breeze' versionCode='4582' versionName='3.0.39'\n"
        self.assertEqual(check.parse_apk_badging(package + "native-code: 'arm64-v8a'")['version_code'], 4582)
        for abis in ('', "'x86_64'", "'arm64-v8a' 'x86_64'"):
            with self.subTest(abis=abis), self.assertRaisesRegex(ValueError, 'APK native ABIs'):
                check.parse_apk_badging(package + f'native-code: {abis}')

    def test_requires_one_certificate_digest(self):
        certificate = f'Signer #1 certificate SHA-256 digest: {SIGNER}'
        public_key = f'Signer #1 public key SHA-256 digest: {"b" * 64}'
        self.assertEqual(check.parse_apk_signer(f'{certificate}\n{public_key}'), SIGNER)
        for signature in (public_key, f'{certificate}\n{certificate.replace("#1", "#2")}'):
            with self.subTest(signature=signature), self.assertRaisesRegex(ValueError, 'APK signer count'):
                check.parse_apk_signer(signature)

    def test_uses_git_source_instead_of_worktree_pubspec(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            check.run('git', '-C', root, 'init', '-q')
            pubspec = root / 'pubspec.yaml'
            pubspec.write_text("version: '3.0.39+2582' # release candidate\n", encoding='utf-8')
            check.run('git', '-C', root, 'add', 'pubspec.yaml')
            check.run('git', '-C', root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com',
                      'commit', '-qm', 'test release source')
            pubspec.write_text('version: 3.0.40+2600\n', encoding='utf-8')
            source = check.read_source(root, 'HEAD')
            self.assertEqual((source['version'], source['build']), ('3.0.39', 2582))


if __name__ == '__main__':
    unittest.main()
