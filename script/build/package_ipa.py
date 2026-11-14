#!/usr/bin/env python3
"""Package an iOS app without macOS sidecars; verify before replacing output."""

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import plistlib
import stat
import zipfile


def is_metadata(parts):
    return any(p.startswith('._') or p in ('__MACOSX', '.DS_Store') for p in parts)


def verify(ipa):
    with zipfile.ZipFile(ipa) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise ValueError('Duplicate ZIP entries')
        for name in names:
            parts = PurePosixPath(name).parts
            if (not parts or parts[0] != 'Payload' or '..' in parts
                    or '\\' in name or is_metadata(parts)):
                raise ValueError('Unexpected or macOS metadata entry: ' + name)
        roots = {PurePosixPath(n).parts[1] for n in names
                 if len(PurePosixPath(n).parts) > 1}
        if len(roots) != 1 or not next(iter(roots)).endswith('.app'):
            raise ValueError('Payload must contain exactly one app: ' + str(roots))
        app = 'Payload/' + next(iter(roots))
        if not archive.getinfo(app + '/').is_dir():
            raise ValueError('App bundle is not a directory')
        info = plistlib.loads(archive.read(app + '/Info.plist'))
        for key in ('CFBundleIdentifier', 'CFBundleVersion',
                    'CFBundleShortVersionString', 'CFBundleExecutable'):
            if not isinstance(info.get(key), str) or not info[key]:
                raise ValueError('Missing bundle property: ' + key)
        executable = info['CFBundleExecutable']
        if PurePosixPath(executable).name != executable:
            raise ValueError('Invalid bundle executable path')
        entry = archive.getinfo(app + '/' + executable)
        mode = entry.external_attr >> 16
        if not stat.S_ISREG(mode) or not mode & 0o111 or entry.file_size == 0:
            raise ValueError('Missing regular executable with execute permissions')
        bad = archive.testzip()
        if bad:
            raise ValueError('ZIP integrity failure: ' + bad)
    return {
        'bundle_id': info['CFBundleIdentifier'],
        'version': info['CFBundleShortVersionString'],
        'build': info['CFBundleVersion'],
        'app_bundles': 1,
        'macos_metadata': 0,
        'zip_integrity': 'passed',
        'executable_permissions': 'passed',
        'bytes': ipa.stat().st_size,
        'sha256': hashlib.sha256(ipa.read_bytes()).hexdigest(),
    }


def package(app, output):
    app = app.resolve(strict=True)
    if not app.is_dir() or app.suffix != '.app':
        raise ValueError('Input must be an existing .app directory')
    if app in output.resolve().parents:
        raise ValueError('Output cannot be inside the input bundle')
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_name(output.name + '.tmp')
    try:
        with zipfile.ZipFile(temporary, 'w', zipfile.ZIP_DEFLATED,
                             compresslevel=6) as archive:
            payload = zipfile.ZipInfo('Payload/')
            payload.create_system = 3
            payload.external_attr = (stat.S_IFDIR | 0o755) << 16
            archive.writestr(payload, b'')
            for path in [app, *sorted(app.rglob('*'))]:
                relative = path.relative_to(app.parent)
                if is_metadata(relative.parts):
                    continue
                name = 'Payload/' + relative.as_posix()
                if path.is_symlink():
                    target = os.readlink(path)
                    resolved = path.resolve(strict=True)
                    if Path(target).is_absolute() or (resolved != app and app not in resolved.parents):
                        raise ValueError('Symlink leaves app bundle: ' + str(relative))
                    entry = zipfile.ZipInfo(name)
                    entry.create_system = 3
                    entry.external_attr = path.lstat().st_mode << 16
                    archive.writestr(entry, target.encode())
                else:
                    archive.write(path, name)
        result = verify(temporary)
        os.replace(temporary, output)
        return result
    finally:
        if temporary.exists():
            temporary.unlink()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    pack = commands.add_parser('pack')
    pack.add_argument('app', type=Path)
    pack.add_argument('output', type=Path)
    check = commands.add_parser('verify')
    check.add_argument('ipa', type=Path)
    args = parser.parse_args()
    try:
        result = package(args.app, args.output) if args.command == 'pack' else verify(args.ipa)
    except (OSError, ValueError, KeyError, zipfile.BadZipFile) as error:
        parser.exit(1, 'IPA rejected: ' + str(error) + '\n')
    print(json.dumps(result, ensure_ascii=False, indent=2))
