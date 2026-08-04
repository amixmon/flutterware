#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "$script_dir/.." && pwd)"

if [[ "$#" -ne 6 ]]; then
  echo "Usage: $0 OPENJDK.deb LIBANDROID_SHMEM.deb LIBANDROID_SPAWN.deb LIBICONV.deb ZLIB.deb LIBCXX.deb" >&2
  exit 2
fi

openjdk_deb="$1"
shmem_deb="$2"
spawn_deb="$3"
iconv_deb="$4"
zlib_deb="$5"
libcxx_deb="$6"

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

check_hash "$openjdk_deb" 05b08dd961c30928992f87632539c3704bf082e2984aee11441c6127f9fd7884
check_hash "$shmem_deb" 0da3a24d558b93c92bcf8d611e0826a99ff96e396b148e6cdf33b47c47c57ff6
check_hash "$spawn_deb" 7988fa788ef48ab5da9660443905a2e4099ac36221739d72f5c39acc644b4d1c
check_hash "$iconv_deb" b19e6f348034bb48d2a5590b5cb242769f682c476717374d134d004cc663dc84
check_hash "$zlib_deb" 75e7d0af17fcc3b40004309fdc00a1ddb9ae08346dce5e269902c34ac3966ac9
check_hash "$libcxx_deb" bb9f12113c137aa0e8513bb51cc49fe77a5ce3ca39ab9e92c57d228ecdf00222

build_root="$(mktemp -d /tmp/fluttware-jdk.XXXXXX)"
trap 'rm -rf "$build_root"' EXIT

mkdir -p "$build_root/openjdk" "$build_root/dependencies" "$build_root/bundle/jdk/bin"
dpkg-deb -x "$openjdk_deb" "$build_root/openjdk"
dpkg-deb -x "$shmem_deb" "$build_root/dependencies"
dpkg-deb -x "$spawn_deb" "$build_root/dependencies"
dpkg-deb -x "$iconv_deb" "$build_root/dependencies"
dpkg-deb -x "$zlib_deb" "$build_root/dependencies"
dpkg-deb -x "$libcxx_deb" "$build_root/dependencies"

source_jdk="$build_root/openjdk/data/data/com.termux/files/usr/lib/jvm/java-21-openjdk"
source_lib="$build_root/dependencies/data/data/com.termux/files/usr/lib"
bundle_jdk="$build_root/bundle/jdk"

if [[ ! -x "$source_jdk/bin/java" || ! -f "$source_jdk/lib/modules" ]]; then
  echo "The OpenJDK package does not contain the expected runtime image" >&2
  exit 4
fi

# Keep the complete runtime module image. Development-only jmods, sources,
# headers, demos, and manuals are deliberately not placed in the APK.
cp -a "$source_jdk/conf" "$source_jdk/legal" "$source_jdk/lib" "$bundle_jdk/"
cp "$source_jdk/release" "$bundle_jdk/release"
for launcher in java javac jar jarsigner keytool; do
  cp "$source_jdk/bin/$launcher" "$bundle_jdk/bin/$launcher"
done

# The Termux JDK is linked against these Android compatibility libraries. Put
# real files beside the JDK libraries so ZipInputStream does not need to
# preserve package symlinks. Runtime code supplies this directory through
# LD_LIBRARY_PATH, ahead of the original Termux RUNPATH.
cp "$source_lib/libandroid-shmem.so" "$bundle_jdk/lib/libandroid-shmem.so"
cp "$source_lib/libandroid-spawn.so" "$bundle_jdk/lib/libandroid-spawn.so"
cp "$source_lib/libiconv.so" "$bundle_jdk/lib/libiconv.so"
cp "$source_lib/libcharset.so" "$bundle_jdk/lib/libcharset.so"
cp "$source_lib/libz.so.1.3.2" "$bundle_jdk/lib/libz.so.1.3.2"
cp "$source_lib/libz.so.1.3.2" "$bundle_jdk/lib/libz.so.1"
cp "$source_lib/libc++_shared.so" "$bundle_jdk/lib/libc++_shared.so"

# Termux removes the target of this development-only link. Broken links do not
# belong in the Android asset ZIP.
find "$bundle_jdk" -xtype l -delete

output_dir="$project_dir/app/src/main/assets/jdk"
output="$output_dir/openjdk-21.0.12-android-arm64.zip"
mkdir -p "$output_dir"
(
  cd "$build_root/bundle"
  zip -9 -q -r "$output" jdk
)

unzip -tqq "$output"
file "$bundle_jdk/bin/java" "$bundle_jdk/lib/server/libjvm.so"
du -sh "$bundle_jdk"
ls -lh "$output"
sha256sum "$output"
