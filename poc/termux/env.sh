#!/usr/bin/env bash
# Source this file from Termux before running the probes.

if [[ -z "${HOME:-}" ]]; then
  printf 'HOME is not set; refusing to guess an app-private directory.\n' >&2
  return 2 2>/dev/null || exit 2
fi

export FLUTTWARE_ROOT="${FLUTTWARE_ROOT:-${HOME}/.local/share/fluttware}"
export FLUTTWARE_WORKSPACE="${FLUTTWARE_WORKSPACE:-${FLUTTWARE_ROOT}/workspace}"
export FLUTTER_ROOT="${FLUTTER_ROOT:-${PREFIX:-/data/data/com.termux/files/usr}/share/flutter}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${PREFIX:-/data/data/com.termux/files/usr}/share/android-sdk}"
export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT}}"
export PUB_CACHE="${PUB_CACHE:-${FLUTTWARE_ROOT}/cache/pub}"
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-${FLUTTWARE_ROOT}/cache/gradle}"
export TMPDIR="${TMPDIR:-${FLUTTWARE_ROOT}/tmp}"

if [[ -z "${JAVA_HOME:-}" ]] && command -v java >/dev/null 2>&1; then
  java_executable="$(command -v java)"
  java_executable="$(readlink -f "${java_executable}" 2>/dev/null || printf '%s' "${java_executable}")"
  export JAVA_HOME="${java_executable%/bin/java}"
  unset java_executable
fi

path_parts=(
  "${FLUTTER_ROOT}/bin"
  "${ANDROID_SDK_ROOT}/platform-tools"
)
if [[ -n "${JAVA_HOME:-}" ]]; then
  path_parts+=("${JAVA_HOME}/bin")
fi
for path_part in "${path_parts[@]}"; do
  if [[ -d "${path_part}" && ":${PATH}:" != *":${path_part}:"* ]]; then
    PATH="${path_part}:${PATH}"
  fi
done
export PATH
unset path_part path_parts

export PUB_ENVIRONMENT="${PUB_ENVIRONMENT:+${PUB_ENVIRONMENT}:}fluttware_android"
export GRADLE_OPTS="${GRADLE_OPTS:--Dorg.gradle.daemon=false -Dorg.gradle.jvmargs=-Xmx2048m}"

mkdir -p \
  "${FLUTTWARE_WORKSPACE}" \
  "${PUB_CACHE}" \
  "${GRADLE_USER_HOME}" \
  "${TMPDIR}"
