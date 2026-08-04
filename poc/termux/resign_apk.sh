#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  printf 'Usage: %s INPUT.apk OUTPUT.apk [KEYSTORE.jks]\n' "$0" >&2
  exit 64
fi

input_apk="$1"
output_apk="$2"
keystore="${3:-${output_apk%.*}.jks}"
alias_name="fluttware-local"
store_password="${FLUTTWARE_KEYSTORE_PASSWORD:-android}"
aligned_apk="${output_apk%.*}.aligned.apk"

for tool in keytool zipalign apksigner; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    printf 'Missing required tool: %s\n' "${tool}" >&2
    exit 69
  fi
done

if [[ ! -f "${keystore}" ]]; then
  keytool -genkeypair -noprompt \
    -keystore "${keystore}" \
    -storepass "${store_password}" \
    -keypass "${store_password}" \
    -alias "${alias_name}" \
    -keyalg RSA -keysize 3072 -validity 3650 \
    -dname 'CN=Fluttware Local Build,OU=Development,O=Local,L=Local,C=ET'
fi

zipalign -f -p 4 "${input_apk}" "${aligned_apk}"
apksigner sign \
  --ks "${keystore}" \
  --ks-key-alias "${alias_name}" \
  --ks-pass "pass:${store_password}" \
  --key-pass "pass:${store_password}" \
  --out "${output_apk}" \
  "${aligned_apk}"
apksigner verify --verbose --print-certs "${output_apk}"

printf 'Signed APK: %s\n' "${output_apk}"
