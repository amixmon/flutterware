#!/usr/bin/env bash
# Non-destructive, repeatable Flutter-on-Android smoke test. It creates only an
# isolated project and logs beneath FLUTTWARE_WORKSPACE.
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=env.sh
source "${script_dir}/env.sh"

run_id="$(date -u +%Y%m%dT%H%M%SZ)"
probe_root="${FLUTTWARE_WORKSPACE}/probe-${run_id}"
log_root="${probe_root}/logs"
project_root="${probe_root}/probe_app"
summary_file="${probe_root}/summary.tsv"
install_requested=false
if [[ "${1:-}" == "--install" ]]; then
  install_requested=true
elif [[ $# -gt 0 ]]; then
  printf 'Usage: %s [--install]\n' "$0" >&2
  exit 64
fi

mkdir -p "${log_root}"
printf 'step\texit_code\tduration_seconds\tlog\n' >"${summary_file}"

run_step() {
  local step="$1"
  shift
  local log_file="${log_root}/${step}.log"
  local started finished exit_code
  started="$(date +%s)"
  {
    printf '$'
    printf ' %q' "$@"
    printf '\n'
    "$@"
  } > >(tee "${log_file}") 2>&1
  exit_code=${PIPESTATUS[0]}
  finished="$(date +%s)"
  printf '%s\t%s\t%s\t%s\n' \
    "${step}" "${exit_code}" "$((finished - started))" "${log_file}" \
    >>"${summary_file}"
  return 0
}

run_shell_step() {
  local step="$1"
  shift
  run_step "${step}" /system/bin/sh -c "$*"
}

write_test_sources() {
  mkdir -p "${probe_root}/dart_compile"
  cat >"${probe_root}/dart_compile/hello.dart" <<'DART'
void main() => print('dart-compile-ok');
DART
}

configure_android_build() {
  local properties_file="${project_root}/android/gradle.properties"
  if command -v aapt2 >/dev/null 2>&1; then
    printf '\nandroid.aapt2FromMavenOverride=%s\n' "$(command -v aapt2)" >>"${properties_file}"
  fi
  printf 'android.enableResourceOptimizations=false\n' >>"${properties_file}"
}

inventory='set -u
printf "date="; date -u +%FT%TZ
printf "uname="; uname -a
printf "abi="; getprop ro.product.cpu.abi 2>/dev/null || true
printf "sdk="; getprop ro.build.version.sdk 2>/dev/null || true
printf "release="; getprop ro.build.version.release 2>/dev/null || true
printf "model="; getprop ro.product.model 2>/dev/null || true
printf "kernel_exec_mounts\\n"; mount 2>/dev/null | grep -E "(/data|/storage|/sdcard)" || true
printf "memory\\n"; cat /proc/meminfo | head -5
printf "disk\\n"; df -h "${FLUTTWARE_WORKSPACE}"
for tool in bash sh git curl unzip tar xz java javac keytool gradle dart flutter aapt2 d8 r8 zipalign apksigner adb sdkmanager; do
  resolved=$(command -v "${tool}" 2>/dev/null || true)
  printf "tool\\t%s\\t%s\\n" "${tool}" "${resolved:-MISSING}"
  if [ -n "${resolved}" ] && command -v file >/dev/null 2>&1; then file "${resolved}" 2>/dev/null || true; fi
done'
run_shell_step 00_inventory "${inventory}"

write_test_sources
run_step 01_dart_version dart --version
run_step 02_dart_host dart "${script_dir}/check_android_host.dart"
run_step 03_dart_compile_kernel dart compile kernel \
  "${probe_root}/dart_compile/hello.dart" \
  -o "${probe_root}/dart_compile/hello.dill"
run_step 04_dart_compile_exe dart compile exe \
  "${probe_root}/dart_compile/hello.dart" \
  -o "${probe_root}/dart_compile/hello"
if [[ -x "${probe_root}/dart_compile/hello" ]]; then
  run_step 05_dart_compiled_exe "${probe_root}/dart_compile/hello"
else
  run_shell_step 05_dart_compiled_exe \
    "printf 'SKIP: dart compile exe produced no executable\\n'; exit 125"
fi

run_step 10_flutter_version flutter --version
run_step 11_flutter_doctor flutter doctor -v
run_step 12_flutter_create flutter create \
  --no-pub \
  --platforms=android \
  --org dev.fluttware.probe \
  --project-name probe_app \
  "${project_root}"

if [[ -f "${project_root}/pubspec.yaml" ]]; then
  configure_android_build
  run_step 13_flutter_pub_get bash -c \
    "cd \"${project_root}\" && flutter pub get --verbose"
  run_step 14_flutter_pub_get_offline bash -c \
    "cd \"${project_root}\" && flutter pub get --offline --verbose"
  run_step 20_flutter_build_debug bash -c \
    "cd \"${project_root}\" && flutter build apk --debug --target-platform android-arm64 --verbose"
  run_step 21_flutter_build_profile bash -c \
    "cd \"${project_root}\" && flutter build apk --profile --target-platform android-arm64 --no-tree-shake-icons --verbose"
  run_step 22_flutter_build_release bash -c \
    "cd \"${project_root}\" && flutter build apk --release --target-platform android-arm64 --no-tree-shake-icons --verbose"
else
  run_shell_step 13_flutter_pub_get "printf 'SKIP: flutter create failed\\n'; exit 125"
  run_shell_step 14_flutter_pub_get_offline "printf 'SKIP: flutter create failed\\n'; exit 125"
  run_shell_step 20_flutter_build_debug "printf 'SKIP: flutter create failed\\n'; exit 125"
  run_shell_step 21_flutter_build_profile "printf 'SKIP: flutter create failed\\n'; exit 125"
  run_shell_step 22_flutter_build_release "printf 'SKIP: flutter create failed\\n'; exit 125"
fi

apk_path=''
for candidate in \
  "${project_root}/build/app/outputs/flutter-apk/app-release.apk" \
  "${project_root}/build/app/outputs/flutter-apk/app-debug.apk"; do
  if [[ -f "${candidate}" ]]; then
    apk_path="${candidate}"
    break
  fi
done

if [[ -n "${apk_path}" ]] && command -v apksigner >/dev/null 2>&1; then
  run_step 30_apksigner_verify apksigner verify --verbose --print-certs "${apk_path}"
else
  run_shell_step 30_apksigner_verify "printf 'SKIP: no APK or apksigner\\n'; exit 125"
fi

resigned_apk="${probe_root}/probe-app-resigned.apk"
if [[ -n "${apk_path}" ]] \
    && command -v keytool >/dev/null 2>&1 \
    && command -v zipalign >/dev/null 2>&1 \
    && command -v apksigner >/dev/null 2>&1; then
  run_step 31_resign_apk \
    "${script_dir}/resign_apk.sh" \
    "${apk_path}" \
    "${resigned_apk}" \
    "${probe_root}/probe-keystore.jks"
  if [[ -f "${resigned_apk}" ]]; then
    apk_path="${resigned_apk}"
  fi
else
  run_shell_step 31_resign_apk \
    "printf 'SKIP: no APK, keytool, zipalign, or apksigner\\n'; exit 125"
fi

if [[ "${install_requested}" == true && -n "${apk_path}" ]]; then
  if command -v termux-open >/dev/null 2>&1; then
    run_step 40_install_intent termux-open "${apk_path}"
  elif command -v adb >/dev/null 2>&1; then
    run_step 40_install_adb adb install -r "${apk_path}"
  else
    run_shell_step 40_install "printf 'SKIP: no user-mediated installer or adb\\n'; exit 125"
  fi
fi

printf '\nProbe complete. Summary: %s\n' "${summary_file}"
printf 'Logs: %s\n' "${log_root}"
