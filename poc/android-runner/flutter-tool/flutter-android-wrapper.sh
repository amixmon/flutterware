#!/system/bin/sh
set -eu

flutter_bin="${0%/*}"
flutter_root="$(cd "$flutter_bin/.." && pwd)"
exec "$flutter_root/bin/cache/dart-sdk/bin/dart" \
  "$flutter_root/bin/cache/flutter_tools.dill" "$@"
