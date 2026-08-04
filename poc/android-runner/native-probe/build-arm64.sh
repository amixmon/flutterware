#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "$script_dir/.." && pwd)"
ndk_root="${ANDROID_NDK_ROOT:-${ANDROID_NDK_HOME:-}}"

if [[ -z "$ndk_root" ]]; then
  echo "Set ANDROID_NDK_ROOT to an installed Android NDK." >&2
  exit 2
fi

compiler="$ndk_root/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android26-clang"
output_dir="$project_dir/app/src/main/assets/native"
output="$output_dir/fluttware-probe-arm64-v8a"

if [[ ! -x "$compiler" ]]; then
  echo "Android ARM64 compiler not found: $compiler" >&2
  exit 3
fi

mkdir -p "$output_dir"
"$compiler" \
  -O2 \
  -fPIE \
  -pie \
  -Wl,--build-id=sha1 \
  -o "$output" \
  "$script_dir/fluttware_probe.c"

chmod 0644 "$output"
file "$output"
sha256sum "$output"
