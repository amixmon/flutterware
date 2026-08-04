#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "$script_dir/.." && pwd)"

if [[ "$#" -ne 10 ]]; then
  echo "Usage: $0 ANDROID_SDK AAPT2.deb ABSEIL.deb PROTOBUF.deb FMT.deb LIBCXX.deb EXPAT.deb PNG.deb ZOPFLI.deb ZLIB.deb" >&2
  exit 2
fi

android_sdk="$1"
aapt2_deb="$2"
abseil_deb="$3"
protobuf_deb="$4"
fmt_deb="$5"
libcxx_deb="$6"
expat_deb="$7"
png_deb="$8"
zopfli_deb="$9"
zlib_deb="${10}"

check_hash() {
  local file="$1"
  local expected="$2"
  local actual
  actual="$(sha256sum "$file" | cut -d ' ' -f 1)"
  if [[ "$actual" != "$expected" ]]; then
    echo "SHA-256 mismatch for $file" >&2
    echo "expected=$expected" >&2
    echo "actual=$actual" >&2
    exit 3
  fi
}

platform="$android_sdk/platforms/android-36"
build_tools="$android_sdk/build-tools/36.0.0"
check_hash "$platform/android.jar" d9eb9da824d9e247a352f570f01e1169e725b2954bca9e283a71786c59b59f9a
check_hash "$platform/core-for-system-modules.jar" 4afd3df39082ca1ca32a1effeaff7971d878e75bd01a68a4205c105deec4c559
check_hash "$platform/source.properties" 72291ff6611dbfc46fdfb6de2821c4a62c87befa5200713847eda426e3a501c2
check_hash "$build_tools/lib/d8.jar" 4097ff9c46c185c6e7214da7fe9b1befb5adeea5cc9ca349270e0249904f9240
check_hash "$build_tools/lib/apksigner.jar" 3716d9311e55d2b0918a2fd9d54ba9e406c5f6abeea700b287f11259bc163dec
check_hash "$build_tools/source.properties" 7dee6632e9ad6cb111da2bb99d747211e27927061b1276d040bb1d71fded5ebb

check_hash "$aapt2_deb" d35298f13ec26eee362d4e84f534b29b8e5f288b86c89d803ba4fb8ccb9784aa
check_hash "$abseil_deb" e489fac652cddc39d9436141e627285f1034a545a06fbb19c420514a419ad877
check_hash "$protobuf_deb" a1ba7c7f0e5903a2134662653d3e7b9ffceaa78bdd00e07ac985e2d313ebc738
check_hash "$fmt_deb" 0377ac55cc99e409a5a2ba55a7cacf86fc1f79f330c2998801e293e95cac1996
check_hash "$libcxx_deb" bb9f12113c137aa0e8513bb51cc49fe77a5ce3ca39ab9e92c57d228ecdf00222
check_hash "$expat_deb" 6f5eb2fd14b6fe4d7bb79bf7f0f3d7fc838fea07402477a172b147304366b372
check_hash "$png_deb" e47937405c72734867513cf0c63d27f36400d462666b65dfada984667d7228c4
check_hash "$zopfli_deb" 95cd7cb2209fbafb25825f5fcd4f86f021512175608e038b1c3d8d3fa0a4fe40
check_hash "$zlib_deb" 75e7d0af17fcc3b40004309fdc00a1ddb9ae08346dce5e269902c34ac3966ac9

build_root="$(mktemp -d /tmp/fluttware-android-sdk.XXXXXX)"
trap 'rm -rf "$build_root"' EXIT
dependency_root="$build_root/dependencies"
bundle_sdk="$build_root/bundle/android-sdk"
bundle_tools="$bundle_sdk/build-tools/36.0.0"
mkdir -p "$dependency_root" "$bundle_sdk/platforms" "$bundle_tools/lib" "$bundle_tools/lib64"

for package in \
  "$aapt2_deb" "$abseil_deb" "$protobuf_deb" "$fmt_deb" \
  "$libcxx_deb" "$expat_deb" "$png_deb" "$zopfli_deb" "$zlib_deb"; do
  dpkg-deb -x "$package" "$dependency_root"
done

# Keep the complete API 36 platform. Besides android.jar, AGP and tooling read
# platform metadata, framework AIDL, optional libraries, and API/resource data.
cp -a "$platform" "$bundle_sdk/platforms/android-36"

# D8 and APK signing are Java tools. Native desktop build-tool executables are
# intentionally not copied; AAPT2 below is the Android/Bionic ARM64 build.
cp "$build_tools/lib/d8.jar" "$bundle_tools/lib/d8.jar"
cp "$build_tools/lib/apksigner.jar" "$bundle_tools/lib/apksigner.jar"
cp "$build_tools/core-lambda-stubs.jar" "$bundle_tools/core-lambda-stubs.jar"
cp "$build_tools/source.properties" "$bundle_tools/source.properties"
cp "$build_tools/runtime.properties" "$bundle_tools/runtime.properties"
cp "$build_tools/package.xml" "$bundle_tools/package.xml"

termux_prefix="$dependency_root/data/data/com.termux/files/usr"
cp "$termux_prefix/bin/aapt2" "$bundle_tools/aapt2"
while IFS= read -r -d '' library; do
  cp -L "$library" "$bundle_tools/lib64/$(basename "$library")"
done < <(find "$termux_prefix/lib" -maxdepth 1 \( -type f -o -type l \) -name '*.so*' -print0)

output_dir="$project_dir/app/src/main/assets/android-sdk"
output="$output_dir/android-sdk-36-arm64.zip"
mkdir -p "$output_dir"
(
  cd "$build_root/bundle"
  zip -9 -q -r "$output" android-sdk
)

unzip -tqq "$output"
file "$bundle_tools/aapt2"
du -sh "$bundle_sdk"
ls -lh "$output"
sha256sum "$output"
