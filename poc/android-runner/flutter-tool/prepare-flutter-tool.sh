#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "$script_dir/.." && pwd)"
flutter_sdk="${1:-}"
expected_flutter="3.44.8"
expected_dart="3.12.2"

if [[ -z "$flutter_sdk" || ! -d "$flutter_sdk/packages/flutter_tools" ]]; then
  echo "Usage: $0 /path/to/flutter-sdk" >&2
  exit 2
fi

version_json="$flutter_sdk/bin/cache/flutter.version.json"
actual_flutter="$(jq -r .flutterVersion "$version_json")"
actual_dart="$(jq -r .dartSdkVersion "$version_json")"
if [[ "$actual_flutter" != "$expected_flutter" || "$actual_dart" != "$expected_dart" ]]; then
  echo "Expected Flutter $expected_flutter / Dart $expected_dart, got Flutter $actual_flutter / Dart $actual_dart" >&2
  exit 3
fi

build_root="$(mktemp -d /tmp/fluttware-flutter-tool.XXXXXX)"
trap 'rm -rf "$build_root"' EXIT
mkdir -p "$build_root/source/packages" "$build_root/home" "$build_root/bundle/flutter/bin/cache"
cp -a "$flutter_sdk/packages/flutter_tools" "$build_root/source/packages/flutter_tools"
patch -d "$build_root/source" -p1 < "$script_dir/android-host.patch"

dart="$flutter_sdk/bin/cache/dart-sdk/bin/dart"
kernel="$build_root/bundle/flutter/bin/cache/flutter_tools.dill"
HOME="$build_root/home" DART_SUPPRESS_ANALYTICS=true "$dart" compile kernel \
  --packages="$build_root/source/packages/flutter_tools/.dart_tool/package_config.json" \
  "$build_root/source/packages/flutter_tools/bin/flutter_tools.dart" \
  -o "$kernel"

bundle="$build_root/bundle/flutter"
mkdir -p \
  "$bundle/bin" \
  "$bundle/bin/cache/artifacts" \
  "$bundle/bin/cache/pkg" \
  "$bundle/packages/flutter_tools/.dart_tool" \
  "$bundle/packages/flutter_template_images" \
  "$bundle/packages/flutter" \
  "$bundle/packages/flutter_test" \
  "$bundle/packages/flutter_driver" \
  "$bundle/packages/flutter_localizations"

cp "$flutter_sdk/LICENSE" "$bundle/LICENSE"
cp "$flutter_sdk/pubspec.lock" "$bundle/pubspec.lock"
cp "$script_dir/flutter-android-wrapper.sh" "$bundle/bin/flutter"
cp "$version_json" "$bundle/bin/cache/flutter.version.json"
cp "$flutter_sdk/bin/cache/engine.stamp" "$bundle/bin/cache/engine.stamp"
cp "$flutter_sdk/bin/cache/engine.realm" "$bundle/bin/cache/engine.realm"
cp "$flutter_sdk/bin/cache/engine_stamp.stamp" "$bundle/bin/cache/engine_stamp.stamp"
cp "$flutter_sdk/bin/cache/engine_stamp.json" "$bundle/bin/cache/engine_stamp.json"
cp -R "$flutter_sdk/bin/cache/artifacts/gradle_wrapper" \
  "$bundle/bin/cache/artifacts/gradle_wrapper"
cp -R "$flutter_sdk/bin/cache/pkg/sky_engine" "$bundle/bin/cache/pkg/sky_engine"
cp -R "$flutter_sdk/bin/cache/pkg/flutter_gpu" "$bundle/bin/cache/pkg/flutter_gpu"
cp -R "$flutter_sdk/packages/flutter_tools/templates" "$bundle/packages/flutter_tools/templates"
cp -R "$flutter_sdk/packages/flutter_tools/gradle" "$bundle/packages/flutter_tools/gradle"
cp "$script_dir/package_config.android.json" \
  "$bundle/packages/flutter_tools/.dart_tool/package_config.json"
cp -R "$HOME/.pub-cache/hosted/pub.dev/flutter_template_images-5.0.0/templates" \
  "$bundle/packages/flutter_template_images/templates"
cp "$flutter_sdk/packages/flutter/pubspec.yaml" "$bundle/packages/flutter/pubspec.yaml"
cp -R "$flutter_sdk/packages/flutter/lib" "$bundle/packages/flutter/lib"
cp "$flutter_sdk/packages/flutter_test/pubspec.yaml" "$bundle/packages/flutter_test/pubspec.yaml"
cp "$flutter_sdk/packages/flutter_driver/pubspec.yaml" "$bundle/packages/flutter_driver/pubspec.yaml"
cp "$flutter_sdk/packages/flutter_localizations/pubspec.yaml" \
  "$bundle/packages/flutter_localizations/pubspec.yaml"
cp "$script_dir/android-host.patch" "$bundle/FLUTTWARE_ANDROID_HOST.patch"
mkdir -p "$build_root/bundle/flutter-compat-bin"
cp "$script_dir/git-unavailable-shim.sh" "$build_root/bundle/flutter-compat-bin/git"

output_dir="$project_dir/app/src/main/assets/flutter"
output="$output_dir/flutter-tool-3.44.8-android-arm64.zip"
mkdir -p "$output_dir"
(
  cd "$build_root/bundle"
  zip -9 -q -r "$output" flutter flutter-compat-bin
)

unzip -tqq "$output"
ls -lh "$kernel" "$output"
sha256sum "$kernel" "$output"
