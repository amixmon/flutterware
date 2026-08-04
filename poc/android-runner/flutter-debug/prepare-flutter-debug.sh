#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "$script_dir/.." && pwd)"
flutter_sdk="${1:-}"
dart_deb="${2:-}"
reference_apk="${3:-}"
expected_flutter="3.44.8"
expected_dart="3.12.2"
expected_dart_sha256="42690fbaa64a9d9efb62a0dbcaef4d055846ebacc446ecb586ec4ec8953a2161"

if [[ ! -d "$flutter_sdk/packages/flutter_tools" || ! -f "$dart_deb" || ! -f "$reference_apk" ]]; then
  echo "Usage: $0 /path/to/flutter-sdk /path/to/dart_3.12.2_aarch64.deb /path/to/reference-debug.apk" >&2
  exit 2
fi

version_json="$flutter_sdk/bin/cache/flutter.version.json"
if [[ "$(jq -r .flutterVersion "$version_json")" != "$expected_flutter" || \
      "$(jq -r .dartSdkVersion "$version_json")" != "$expected_dart" ]]; then
  echo "Expected Flutter $expected_flutter / Dart $expected_dart" >&2
  exit 3
fi

actual_dart_sha256="$(sha256sum "$dart_deb" | cut -d ' ' -f 1)"
if [[ "$actual_dart_sha256" != "$expected_dart_sha256" ]]; then
  echo "Unexpected Dart package SHA-256: $actual_dart_sha256" >&2
  exit 4
fi

build_root="$(mktemp -d /tmp/fluttware-flutter-debug.XXXXXX)"
trap 'rm -rf "$build_root"' EXIT
mkdir -p "$build_root/deb" "$build_root/bundle/flutter-debug/common/flutter_patched_sdk" \
  "$build_root/bundle/flutter-debug/apk-template"

dpkg-deb -x "$dart_deb" "$build_root/deb"
termux_sdk="$build_root/deb/data/data/com.termux/files/usr/lib/dart-sdk"
cp "$termux_sdk/bin/snapshots/frontend_server_aot.dart.snapshot" \
  "$build_root/bundle/flutter-debug/frontend_server_aot.dart.snapshot"
cp -R "$flutter_sdk/bin/cache/artifacts/engine/common/flutter_patched_sdk/." \
  "$build_root/bundle/flutter-debug/common/flutter_patched_sdk/"
cp "$flutter_sdk/bin/cache/artifacts/engine/linux-x64/vm_isolate_snapshot.bin" \
  "$build_root/bundle/flutter-debug/vm_snapshot_data"
cp "$flutter_sdk/bin/cache/artifacts/engine/linux-x64/isolate_snapshot.bin" \
  "$build_root/bundle/flutter-debug/isolate_snapshot_data"

template="$build_root/bundle/flutter-debug/apk-template"
unzip -q "$reference_apk" 'classes*.dex' 'lib/arm64-v8a/*.so' \
  'assets/flutter_assets/*' -d "$template"
rm -f "$template/assets/flutter_assets/kernel_blob.bin" \
  "$template/assets/flutter_assets/vm_snapshot_data" \
  "$template/assets/flutter_assets/isolate_snapshot_data"

required=(
  flutter-debug/frontend_server_aot.dart.snapshot
  flutter-debug/common/flutter_patched_sdk/platform_strong.dill
  flutter-debug/vm_snapshot_data
  flutter-debug/isolate_snapshot_data
  flutter-debug/apk-template/classes.dex
  flutter-debug/apk-template/lib/arm64-v8a/libflutter.so
  flutter-debug/apk-template/assets/flutter_assets/AssetManifest.bin
)
for relative_path in "${required[@]}"; do
  if [[ ! -s "$build_root/bundle/$relative_path" ]]; then
    echo "Missing Flutter debug artifact: $relative_path" >&2
    exit 5
  fi
done

output_dir="$project_dir/app/src/main/assets/flutter-debug"
output="$output_dir/flutter-debug-3.44.8-android-arm64.zip"
mkdir -p "$output_dir"
(
  cd "$build_root/bundle"
  zip -9 -q -r "$output" flutter-debug
)

unzip -tqq "$output"
ls -lh "$output"
sha256sum "$output"
