#!/usr/bin/env python3
"""Restore the unchanged native component used by the 3.0.38 compatibility build."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--apk', type=Path, required=True, help='Published v3.0.37 b2263 arm64 APK')
args = parser.parse_args()
record = json.loads((root / 'docs/releases/3.0.38-android-source.json').read_text())
raw = args.apk.read_bytes()
if hashlib.sha256(raw).hexdigest() != record['publishedBaseline']['apkSha256']:
    raise SystemExit('APK differs from the verified published baseline; nothing changed')
component = record['preservedNativeBinary']
with zipfile.ZipFile(args.apk) as archive:
    binary = archive.read(component['member'])
if hashlib.sha256(binary).hexdigest() != component['sha256']:
    raise SystemExit('Native component checksum mismatch; nothing changed')
destination = root / 'android/app/src/main/jniLibs/arm64-v8a/libwaifu2x_cli.so'
destination.parent.mkdir(parents=True, exist_ok=True)
if not destination.exists() or destination.read_bytes() != binary:
    destination.write_bytes(binary)
print('Verified published native component is ready')
