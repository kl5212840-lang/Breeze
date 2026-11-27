#!/usr/bin/env bash
set -euo pipefail

CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."

# Keep the C library in sync with objectbox_flutter_libs in pubspec.lock.
version=5.3.2
platform=$(uname -s)
case "$platform" in
  Darwin)
    library=libobjectbox.dylib
    archive=objectbox-macos-universal.zip
    checksum=(shasum -a 256)
    sha256=680c598573ede04b9762565d48d4e161ad286f786f159abb8da89353bfa1d0bc
    ;;
  Linux)
    library=libobjectbox.so
    archive=objectbox-linux-x64.tar.gz
    checksum=(sha256sum)
    sha256=6dbb5450c36dd11ee9074f16ecc61e79b45ff43c2082934601f3166b39c8a613
    ;;
  *)
    echo "ObjectBox test setup supports macOS and Linux x86_64. This host uses $platform." >&2
    exit 1
    ;;
esac

# ObjectBox first looks for this file in the current repository.
local_library="lib/$library"
if [[ -f "$local_library" ]]; then
  exit 0
fi
if [[ "$platform" == Linux && "$(uname -m)" != x86_64 ]]; then
  echo "Provide a compatible ObjectBox library at $local_library to run the regressions on Linux $(uname -m)." >&2
  exit 1
fi

cache="build/mobile-regressions/objectbox/$version/$platform"
if [[ ! -s "$cache/$library" ]]; then
  mkdir -p "$cache"
  scratch=$(mktemp -d "$cache/.download.XXXXXX")
  cleanup() {
    if [[ -e "$scratch/$archive" ]]; then unlink "$scratch/$archive"; fi
    if [[ -e "$scratch/$library" ]]; then unlink "$scratch/$library"; fi
    rmdir "$scratch"
  }
  trap cleanup EXIT

  echo "Downloading ObjectBox $version for $platform" >&2
  curl --fail --silent --show-error --location \
    --retry 2 --retry-max-time 60 --connect-timeout 15 --max-time 60 \
    --output "$scratch/$archive" \
    "https://github.com/objectbox/objectbox-c/releases/download/v$version/$archive"
  actual=$("${checksum[@]}" "$scratch/$archive")
  if [[ "${actual%% *}" != "$sha256" ]]; then
    echo "ObjectBox archive checksum mismatch for $archive." >&2
    exit 1
  fi

  if [[ "$platform" == Darwin ]]; then
    unzip -p "$scratch/$archive" "lib/$library" > "$scratch/$library"
  else
    tar -xOzf "$scratch/$archive" "lib/$library" > "$scratch/$library"
  fi
  if [[ ! -s "$scratch/$library" ]]; then
    echo "ObjectBox archive contained an empty $library." >&2
    exit 1
  fi
  mv "$scratch/$library" "$cache/$library"
fi

if [[ "$platform" == Darwin ]]; then
  # SIP can strip DYLD_LIBRARY_PATH before Flutter starts its test process.
  if [[ -e "$local_library" || -L "$local_library" ]]; then
    if [[ ! -f "$local_library" ]]; then
      echo "Unable to use $local_library. Provide a usable library or remove the invalid path." >&2
      exit 1
    fi
  else
    ln -s "../$cache/$library" "$local_library" || [[ -f "$local_library" ]]
  fi
else
  # Return only the library directory for the runner's environment.
  printf '%s/%s\n' "$PWD" "$cache"
fi
