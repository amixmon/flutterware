#!/system/bin/sh
set -eu

kernel_script="$1"
apk_script="$2"
files="$3"
flutter_root="$4"
debug_tools="$5"
jdk="$6"
sdk="$7"
workspace="$8"

echo FLUTTWARE_DIRECT_FLUTTER_PIPELINE_KERNEL
/system/bin/sh "$kernel_script" "$files" "$flutter_root" "$debug_tools"

echo FLUTTWARE_DIRECT_FLUTTER_PIPELINE_APK
/system/bin/sh "$apk_script" "$jdk" "$sdk" "$workspace" "$debug_tools"

echo FLUTTWARE_DIRECT_FLUTTER_PIPELINE_OK
