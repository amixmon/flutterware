#!/system/bin/sh
set -eu

files="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
jdk="$files/toolchains/openjdk-21.0.12-android-arm64/jdk"
sdk="$files/toolchains/android-sdk-36-arm64/android-sdk"
flutter_base="$files/toolchains/flutter-3.44.8-android-arm64"
workspace="$files/workspace"

export HOME="$files"
export TMPDIR="$files/../cache"
export JAVA_HOME="$jdk"
export LD_LIBRARY_PATH="$sdk/build-tools/36.0.0/lib64:$jdk/lib/server:$jdk/lib"
export PATH="$jdk/bin:/system/bin:/system/xbin"

exec /system/bin/sh "$files/direct-flutter-debug-build.sh" \
  "$jdk" "$sdk" "$workspace" "$flutter_base"
