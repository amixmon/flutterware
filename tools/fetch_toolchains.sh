#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd "$script_dir/.." && pwd)"
asset_root="$repository_root/apps/fluttware_flutter/android/app/src/main/assets"
release="toolchain-3.44.8-android-arm64-v1"
base_url="https://github.com/amixmon/flutterware/releases/download/$release"
download_root="$(mktemp -d /tmp/flutterware-toolchains.XXXXXX)"
trap 'rm -rf "$download_root"' EXIT

fetch() {
  local directory="$1"
  local filename="$2"
  local expected_sha256="$3"
  local downloaded="$download_root/$filename"
  local destination="$asset_root/$directory/$filename"

  if [[ -f "$destination" ]] &&
      printf '%s  %s\n' "$expected_sha256" "$destination" |
        sha256sum --check --status; then
    echo "Reusing verified $destination"
    return
  fi

  echo "Downloading $filename"
  curl --fail --location --retry 3 --output "$downloaded" \
    "$base_url/$filename"
  printf '%s  %s\n' "$expected_sha256" "$downloaded" | sha256sum --check --status
  mkdir -p "$(dirname "$destination")"
  install -m 0644 "$downloaded" "$destination"
  echo "Installed $destination"
}

fetch android-sdk android-sdk-36-arm64.zip \
  9dd61cc3e347891132e2040c88bd05171c57613af4cc27ecef0c276f158e4107
fetch dart dart-sdk-3.12.2-android-arm64.zip \
  56ff79e303240379c029ebad06dcba9adac3875879d4c88a4bb3d09600aa2c54
fetch flutter-debug flutter-debug-3.44.8-android-arm64.zip \
  95030e9f4e1e4611da656f4dc0374e4aa73e6e7670ad1d7eaa6e51991a918d75
fetch flutter flutter-tool-3.44.8-android-arm64.zip \
  ec1d0108927c9071ad42f1180dd8b6b226b6142806bf9e45f33c4c7866edf883
fetch jdk openjdk-21.0.12-android-arm64.zip \
  d8e689d6c70b53510a112f60759b0a9461371c8418a755019041d98b9f4d77db

echo "Flutterware Android ARM64 toolchains are ready."
