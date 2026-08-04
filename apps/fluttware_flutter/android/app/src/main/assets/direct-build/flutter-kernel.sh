#!/system/bin/sh
set -eu

files="$1"
flutter_root="$2"
debug_tools="$3"
project="$4"
output="$5"

dart_sdk="$files/toolchains/dart-3.12.2-android-arm64/dart-sdk"
runtime="$dart_sdk/bin/dartaotruntime"
compiler="$debug_tools/frontend_server_aot.dart.snapshot"
sdk_root="$debug_tools/common/flutter_patched_sdk"
packages="$project/.dart_tool/package_config.json"
main="$project/lib/main.dart"

for required in "$runtime" "$compiler" "$sdk_root/platform_strong.dill" \
  "$packages" "$main" "$flutter_root/packages/flutter/lib/widgets.dart"; do
  if [ ! -e "$required" ]; then
    echo "FLUTTWARE_KERNEL_MISSING=$required" >&2
    exit 2
  fi
done

mkdir -p "$output"
rm -f "$output/app.dill" "$output/app.dill.d"

echo "Compiling Dart kernel"
"$runtime" "$compiler" \
  --sdk-root "$sdk_root" \
  --target=flutter \
  --no-print-incremental-dependencies \
  -Ddart.vm.profile=false \
  -Ddart.vm.product=false \
  --enable-asserts \
  --track-widget-creation \
  --no-link-platform \
  --packages "$packages" \
  --output-dill "$output/app.dill" \
  --depfile "$output/app.dill.d" \
  --verbosity=error \
  "$main"

test -s "$output/app.dill"
echo "Kernel ready ($(wc -c < "$output/app.dill") bytes)"
