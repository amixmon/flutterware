#!/usr/bin/env bash
# Control experiment for this repository's Linux x64 host. This does not claim
# Android verification; it proves the probe sequence and preserves local errors.
set -uo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
evidence_root="${repository_root}/evidence/host"
temporary_root="$(mktemp -d /tmp/fluttware-host-control.XXXXXX)"
control_home="${temporary_root}/home"
project_root="${temporary_root}/control_app"
flutter_entry="$(command -v flutter || true)"
dart_entry="$(command -v dart || true)"

mkdir -p "${evidence_root}" "${control_home}"
printf 'Temporary control workspace: %s\n' "${temporary_root}"

run_step() {
  local name="$1"
  shift
  local log_file="${evidence_root}/${name}.log"
  {
    printf '$'
    printf ' %q' "$@"
    printf '\n'
    "$@"
    printf '\n[exit_code=%s]\n' "$?"
  } > >(tee "${log_file}") 2>&1
  return 0
}

if [[ -z "${flutter_entry}" || -z "${dart_entry}" ]]; then
  printf 'flutter and dart must be on PATH for the host control.\n' >&2
  exit 69
fi

flutter_root="$(cd "$(dirname "${flutter_entry}")/.." && pwd -P)"
flutter_dart="${flutter_root}/bin/cache/dart-sdk/bin/dart"
flutter_snapshot="${flutter_root}/bin/cache/flutter_tools.snapshot"
flutter_packages="${flutter_root}/packages/flutter_tools/.dart_tool/package_config.json"

flutter_control() {
  HOME="${control_home}" \
  PUB_CACHE="${control_home}/.pub-cache" \
  FLUTTER_ROOT="${flutter_root}" \
  FLUTTER_ALREADY_LOCKED=true \
  "${flutter_dart}" \
    --packages="${flutter_packages}" \
    "${flutter_snapshot}" \
    --suppress-analytics \
    "$@"
}

dart_control() {
  HOME="${control_home}" \
  "${flutter_dart}" --suppress-analytics "$@"
}

run_step 00_environment bash -c \
  'uname -a; uname -m; java -version; df -h .; free -h; command -v flutter dart java adb aapt2 zipalign apksigner || true'
run_step 01_stock_binaries bash -c \
  "file '${flutter_dart}'; find '${flutter_root}/bin/cache/artifacts/engine' -type f -name gen_snapshot -print -exec file {} \\; | head -80"
run_step 02_dart_version "${flutter_dart}" --version

printf '%s\n' "void main() => print('host-dart-compile-ok');" >"${temporary_root}/hello.dart"
run_step 03_dart_compile_kernel dart_control compile kernel \
  "${temporary_root}/hello.dart" -o "${temporary_root}/hello.dill"
run_step 04_dart_compile_exe dart_control compile exe \
  "${temporary_root}/hello.dart" -o "${temporary_root}/hello"
if [[ -x "${temporary_root}/hello" ]]; then
  run_step 05_dart_compiled_exe "${temporary_root}/hello"
fi

run_step 10_flutter_version flutter_control --version
run_step 11_flutter_doctor flutter_control doctor -v
run_step 12_flutter_create flutter_control create \
  --no-pub \
  --platforms=android \
  --org dev.fluttware.control \
  --project-name control_app \
  "${project_root}"
if [[ -f "${project_root}/pubspec.yaml" ]]; then
  run_step 13_flutter_pub_get timeout 20s bash -c \
    "cd '${project_root}' && HOME='${control_home}' PUB_CACHE='${control_home}/.pub-cache' FLUTTER_ROOT='${flutter_root}' FLUTTER_ALREADY_LOCKED=true '${flutter_dart}' --packages='${flutter_packages}' '${flutter_snapshot}' --suppress-analytics pub get --verbose"
  run_step 14_flutter_pub_get_offline bash -c \
    "cd '${project_root}' && HOME='${control_home}' PUB_CACHE='${control_home}/.pub-cache' FLUTTER_ROOT='${flutter_root}' FLUTTER_ALREADY_LOCKED=true '${flutter_dart}' --packages='${flutter_packages}' '${flutter_snapshot}' --suppress-analytics pub get --offline --verbose"
  run_step 20_flutter_build_apk bash -c \
    "cd '${project_root}' && HOME='${control_home}' PUB_CACHE='${control_home}/.pub-cache' FLUTTER_ROOT='${flutter_root}' FLUTTER_ALREADY_LOCKED=true '${flutter_dart}' --packages='${flutter_packages}' '${flutter_snapshot}' --suppress-analytics build apk --debug --target-platform android-arm64 --no-pub --verbose"
fi

printf 'Control logs written to %s\n' "${evidence_root}"
