#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "$script_dir/.." && pwd)"
package_path="${1:-}"
expected_sha256="42690fbaa64a9d9efb62a0dbcaef4d055846ebacc446ecb586ec4ec8953a2161"
# Source package:
# https://packages.termux.dev/apt/termux-main/pool/main/d/dart/dart_3.12.2_aarch64.deb

if [[ -z "$package_path" || ! -f "$package_path" ]]; then
  echo "Usage: $0 /path/to/dart_3.12.2_aarch64.deb" >&2
  exit 2
fi

actual_sha256="$(sha256sum "$package_path" | cut -d ' ' -f 1)"
if [[ "$actual_sha256" != "$expected_sha256" ]]; then
  echo "Unexpected Dart package SHA-256: $actual_sha256" >&2
  exit 3
fi

extract_dir="$(mktemp -d /tmp/fluttware-dart-sdk.XXXXXX)"
trap 'rm -rf "$extract_dir"' EXIT
dpkg-deb -x "$package_path" "$extract_dir"

sdk_parent="$extract_dir/data/data/com.termux/files/usr/lib"
sdk="$sdk_parent/dart-sdk"
output_dir="$project_dir/app/src/main/assets/dart"
output="$output_dir/dart-sdk-3.12.2-android-arm64.zip"

required=(
  dart-sdk/LICENSE
  dart-sdk/version
  dart-sdk/revision
  dart-sdk/bin/dart
  dart-sdk/bin/dartvm
  dart-sdk/bin/dartaotruntime
  dart-sdk/bin/snapshots/dartdev_aot.dart.snapshot
  dart-sdk/bin/snapshots/gen_kernel_aot.dart.snapshot
  dart-sdk/lib/_internal/vm_platform_product.dill
)

for relative_path in "${required[@]}"; do
  if [[ ! -f "$sdk_parent/$relative_path" ]]; then
    echo "Dart package is missing $relative_path" >&2
    exit 4
  fi
done

mkdir -p "$output_dir"
(
  cd "$sdk_parent"
  zip -9 -q "$output" "${required[@]}"
)

unzip -t "$output"
ls -lh "$output"
sha256sum "$output"
