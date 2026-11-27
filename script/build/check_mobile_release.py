#!/usr/bin/env python3
"""Check Breeze mobile release inputs and readback files without publishing."""

import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import subprocess
import zipfile

import package_ipa


APP_ID = 'com.zephyr.breeze'
ABI = 'arm64-v8a'
# Flutter adds 2000 to the source build number for this split APK.
ARM64_BUILD_OFFSET = 2000
VERSION = r'(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)'
SHA256 = r'[0-9a-fA-F]{64}'


def require_equal(label, actual, expected):
    if actual != expected:
        raise ValueError(f'{label}: expected {expected!r}, got {actual!r}')


def run(*command):
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode:
        detail = result.stderr.strip() or result.stdout.strip()
        raise ValueError(f'{Path(command[0]).name} exited {result.returncode}: {detail}')
    return result.stdout.strip()


def resolve_commit(repo, ref):
    return run('git', '-C', repo, 'rev-parse', '--verify', '--end-of-options', ref + '^{commit}')


def read_source(repo, ref):
    commit = resolve_commit(repo, ref)
    pubspec = run('git', '-C', repo, 'show', f'{commit}:pubspec.yaml')
    versions = re.findall(r'^version:[^\S\r\n]*(.*?)$', pubspec, re.MULTILINE)
    if len(versions) != 1:
        raise ValueError('Source pubspec.yaml must have one top-level version')
    value = versions[0].partition('#')[0].strip()
    if len(value) >= 2 and value[0] in '\"\'' and value[-1] == value[0]:
        value = value[1:-1]
    match = re.fullmatch(rf'({VERSION})\+([1-9][0-9]*)', value)
    if not match:
        raise ValueError(f'Source pubspec.yaml version must be MAJOR.MINOR.PATCH+BUILD: {value!r}')
    version, build = match.groups()
    return {
        'commit': commit,
        'tree': run('git', '-C', repo, 'rev-parse', f'{commit}^{{tree}}'),
        'version': version,
        'build': int(build),
    }


def read_release(path):
    release = json.loads(path.read_text(encoding='utf-8'))
    if not isinstance(release, dict):
        raise ValueError(f'{path}: expected a GitHub REST release object')
    if (release.get('draft') is not False or release.get('prerelease') is not False
            or not release.get('published_at')):
        raise ValueError(f'{path}: expected a published stable GitHub release')
    tag = release.get('tag_name')
    if not isinstance(tag, str) or not re.fullmatch(rf'v{VERSION}', tag):
        raise ValueError(f'{path}: unexpected release tag {tag!r}')
    return release


def apk_name(version):
    return f'Breeze-Android-v{version}-{ABI}.apk'


def ipa_name(version):
    return f'Breeze-iOS-v{version}.ipa'


def fingerprint(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return {'bytes': path.stat().st_size, 'sha256': digest.hexdigest()}


def check_release_asset(release, name, file_info):
    assets = release.get('assets')
    if not isinstance(assets, list) or any(not isinstance(asset, dict) for asset in assets):
        raise ValueError('Expected GitHub REST release assets')
    matches = [asset for asset in assets if asset.get('name') == name]
    require_equal(f'{name} matching GitHub assets', len(matches), 1)
    asset = matches[0]
    require_equal(f'{name} GitHub asset state', asset.get('state'), 'uploaded')
    require_equal(f'{name} GitHub asset size', asset.get('size'), file_info['bytes'])
    require_equal(f'{name} GitHub asset digest', asset.get('digest'), 'sha256:' + file_info['sha256'])


def check_remote_tag(repo, remote, tag, expected_commit, *, required):
    ref = f'refs/tags/{tag}'
    peeled = ref + '^{}'
    output = run('git', '-C', repo, 'ls-remote', '--tags', '--', remote, ref, peeled)
    refs = {}
    for line in output.splitlines():
        sha, separator, name = line.partition('\t')
        if not separator or name not in (ref, peeled):
            raise ValueError(f'Unexpected remote tag response for {tag}: {line!r}')
        refs[name] = sha
    actual = refs.get(peeled) or refs.get(ref)
    if actual is None:
        if required:
            raise ValueError(f'Remote tag {tag} is missing on {remote}')
    else:
        require_equal(f'Remote tag {tag} on {remote}', actual, expected_commit)
    return actual


def parse_apk_badging(badging):
    package = re.search(r'^package: (.*)$', badging, re.MULTILINE)
    native = re.search(r'^native-code: (.*)$', badging, re.MULTILINE)
    fields = dict(re.findall(r"(\w+)='([^']*)'", package[1])) if package else {}
    if not {'name', 'versionName', 'versionCode'} <= fields.keys():
        raise ValueError('APK is missing aapt package metadata')
    abis = re.findall(r"'([^']+)'", native[1]) if native else []
    require_equal('APK native ABIs', abis, [ABI])
    if not re.fullmatch(r'[1-9][0-9]*', fields['versionCode']):
        raise ValueError('APK versionCode must be a positive integer')
    return {
        'package_id': fields['name'],
        'version': fields['versionName'],
        'version_code': int(fields['versionCode']),
        'abi': ABI,
    }


def parse_apk_signer(signature):
    signers = re.findall(
        rf'^Signer #[0-9]+ certificate SHA-256 digest: ({SHA256})$',
        signature, re.MULTILINE,
    )
    require_equal('APK signer count', len(signers), 1)
    return signers[0].lower()


def inspect_apk(path, tools):
    aapt = tools / 'aapt' if tools else 'aapt'
    apksigner = tools / 'apksigner' if tools else 'apksigner'
    result = parse_apk_badging(run(aapt, 'dump', 'badging', path.resolve(strict=True)))
    signature = run(apksigner, 'verify', '--print-certs', path.resolve(strict=True))
    return {**result, 'signer_sha256': parse_apk_signer(signature), **fingerprint(path)}


def check_ipa_metadata(ipa, source):
    require_equal('IPA bundle identifier', ipa['bundle_id'], APP_ID)
    require_equal('IPA marketing version', ipa['version'], source['version'])
    require_equal('IPA build number', ipa['build'], str(source['build']))
    require_equal('IPA supported platforms', ipa['supported_platforms'], ['iPhoneOS'])


def check_apk_metadata(apk, version, build=None):
    require_equal('APK package identifier', apk['package_id'], APP_ID)
    require_equal('APK marketing version', apk['version'], version)
    if build is not None:
        require_equal('ARM64 APK versionCode', apk['version_code'], build + ARM64_BUILD_OFFSET)


def check_checksums(path, expected):
    checksums = {}
    for line in path.read_text(encoding='utf-8').splitlines():
        match = re.fullmatch(rf'({SHA256}) [ *](.+)', line)
        if not match or match[2] in checksums:
            raise ValueError(f'{path}: invalid or duplicate checksum entry {line!r}')
        checksums[match[2]] = match[1].lower()
    require_equal('Checksum file entries', checksums, expected)


def compare_readback(label, path, expected):
    actual = fingerprint(path)
    for field in ('bytes', 'sha256'):
        require_equal(f'{label} readback {field}', actual[field], expected[field])
    return actual


def verify_release(args):
    source = read_source(args.repo, args.source_ref)
    previous = read_release(args.previous_release)
    previous_version = previous['tag_name'][1:]
    version = source['version']
    if tuple(map(int, version.split('.'))) <= tuple(map(int, previous_version.split('.'))):
        raise ValueError(f'Source version {version} must advance past {previous_version}')
    result = {
        'source': source,
        'previous_release_tag': previous['tag_name'],
        'release_tag': f'v{version}',
        'source_attestation': 'not checked',
    }
    if args.merged_ref:
        commit = resolve_commit(args.repo, args.merged_ref)
        tree = run('git', '-C', args.repo, 'rev-parse', f'{commit}^{{tree}}')
        require_equal('Merged source tree', tree, source['tree'])
        result['merged_source'] = {'commit': commit, 'tree': tree}
    if args.remote:
        expected_commit = result.get('merged_source', source)['commit']
        result['remote_tag'] = {
            'remote': args.remote,
            'commit': check_remote_tag(
                args.repo, args.remote, result['release_tag'], expected_commit,
                required=args.published_release is not None,
            ),
        }

    ipa = package_ipa.verify(args.ipa)
    check_ipa_metadata(ipa, source)
    apk = inspect_apk(args.apk, args.android_build_tools)
    check_apk_metadata(apk, version, source['build'])

    if args.previous_apk:
        previous_apk = inspect_apk(args.previous_apk, args.android_build_tools)
        check_release_asset(previous, apk_name(previous_version), previous_apk)
        check_apk_metadata(previous_apk, previous_version)
        previous_build = previous_apk['version_code'] - ARM64_BUILD_OFFSET
        if not 0 < previous_build < source['build']:
            raise ValueError(
                f'Source build {source["build"]} must advance past a positive previous build ({previous_build})'
            )
        signer = previous_apk['signer_sha256']
        result['previous_signer_evidence'] = 'APK matches supplied previous GitHub Release asset metadata'
        result['previous_build'] = previous_build
    else:
        signer = args.previous_signer_sha256.lower()
        if not re.fullmatch(SHA256, signer):
            raise ValueError('Previous signer SHA-256 must have 64 hexadecimal digits')
        result['previous_signer_evidence'] = 'caller-supplied certificate fingerprint'
    require_equal('APK signer SHA-256', apk['signer_sha256'], signer)
    result['ipa'] = ipa
    result['apk'] = apk

    files = {ipa_name(version): ipa, apk_name(version): apk}
    if args.checksums:
        check_checksums(args.checksums, {name: info['sha256'] for name, info in files.items()})
        files['SHA256SUMS.txt'] = fingerprint(args.checksums)
        result['checksum_file'] = files['SHA256SUMS.txt']

    if args.published_release:
        published = read_release(args.published_release)
        require_equal('Published release tag', published['tag_name'], result['release_tag'])
        for name, info in files.items():
            check_release_asset(published, name, info)
        result['published_release_metadata'] = {'matched_assets': list(files)}

    if args.icloud_ipa:
        upload_status = 'not checked'
        if args.check_icloud_upload:
            status_script = Path(__file__).with_name('check_icloud_upload.swift')
            run('swift', status_script, args.icloud_ipa, args.icloud_apk)
            upload_status = 'uploaded'
        result['icloud_readback'] = {
            'ipa': compare_readback('iCloud IPA', args.icloud_ipa, ipa),
            'apk': compare_readback('iCloud APK', args.icloud_apk, apk),
            'upload_status': upload_status,
        }
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--source-ref', required=True, help='Git candidate commit or ref')
    parser.add_argument('--merged-ref', help='Git merge commit or local tag to compare by tree')
    parser.add_argument('--remote', help='Git remote to check for a conflicting release tag')
    parser.add_argument('--previous-release', type=Path, required=True, help='Previous GitHub REST release JSON')
    parser.add_argument('--ipa', type=Path, required=True)
    parser.add_argument('--apk', type=Path, required=True)
    signer = parser.add_mutually_exclusive_group(required=True)
    signer.add_argument('--previous-apk', type=Path, help='Previous APK with matching release asset digest')
    signer.add_argument('--previous-signer-sha256', help='Trusted previous APK signer certificate SHA-256')
    parser.add_argument('--android-build-tools', type=Path, help='Directory containing aapt and apksigner (otherwise use PATH)')
    parser.add_argument('--published-release', type=Path, help='Current GitHub REST release JSON')
    parser.add_argument('--checksums', type=Path, help='Release SHA256SUMS.txt')
    parser.add_argument('--icloud-ipa', type=Path)
    parser.add_argument('--icloud-apk', type=Path)
    parser.add_argument(
        '--check-icloud-upload', action='store_true',
        help='Require macOS to report both iCloud files uploaded',
    )
    args = parser.parse_args()
    if bool(args.icloud_ipa) != bool(args.icloud_apk):
        parser.error('--icloud-ipa and --icloud-apk must be supplied together')
    if args.check_icloud_upload and not args.icloud_ipa:
        parser.error('--check-icloud-upload requires both iCloud paths')
    if args.android_build_tools:
        args.android_build_tools = args.android_build_tools.resolve()
    try:
        result = verify_release(args)
    except (OSError, ValueError, KeyError, plistlib.InvalidFileException, zipfile.BadZipFile) as error:
        parser.exit(1, f'Mobile release rejected: {error}\n')
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
