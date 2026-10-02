#!/usr/bin/env bash
# Prove the privacy manifest declares app-only UserDefaults and no tracking.
# Pass a .xcprivacy path, or an .app bundle to check the shipped copy.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_MANIFEST="${ROOT_DIR}/TimeAnnouncer/PrivacyInfo.xcprivacy"

fail() {
  echo "error: $*" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required"
}

manifest_from_arg() {
  local target="${1:-}"
  if [[ -z "${target}" ]]; then
    printf '%s\n' "${SOURCE_MANIFEST}"
    return
  fi
  if [[ -d "${target}" ]]; then
    printf '%s\n' "${target}/Contents/Resources/PrivacyInfo.xcprivacy"
    return
  fi
  printf '%s\n' "${target}"
}

check_manifest() {
  local manifest="$1"
  test -f "${manifest}" || fail "missing privacy manifest ${manifest}"
  plutil -lint "${manifest}" >/dev/null || fail "${manifest} is not a valid plist"

  local tracking type reason collected_count accessed_count
  tracking="$(plutil -extract NSPrivacyTracking raw "${manifest}")"
  [[ "${tracking}" == "false" ]] || fail "${manifest} must declare NSPrivacyTracking false"

  collected_count="$(/usr/libexec/PlistBuddy -c 'Print :NSPrivacyCollectedDataTypes' "${manifest}" | grep -c 'Dict' || true)"
  [[ "${collected_count}" == "0" ]] || fail "${manifest} must collect no data types"

  if /usr/libexec/PlistBuddy -c 'Print :NSPrivacyTrackingDomains:0' "${manifest}" >/dev/null 2>&1; then
    fail "${manifest} must declare no tracking domains"
  fi

  accessed_count="$(/usr/libexec/PlistBuddy -c 'Print :NSPrivacyAccessedAPITypes' "${manifest}" | grep -c 'Dict' || true)"
  [[ "${accessed_count}" == "1" ]] || fail "${manifest} must declare exactly one accessed API type"

  type="$(plutil -extract NSPrivacyAccessedAPITypes.0.NSPrivacyAccessedAPIType raw "${manifest}")"
  [[ "${type}" == "NSPrivacyAccessedAPICategoryUserDefaults" ]] || fail "${manifest} must declare UserDefaults access"

  reason="$(plutil -extract NSPrivacyAccessedAPITypes.0.NSPrivacyAccessedAPITypeReasons.0 raw "${manifest}")"
  [[ "${reason}" == "CA92.1" ]] || fail "${manifest} must use reason CA92.1"
}

require_tool plutil
require_tool /usr/libexec/PlistBuddy

MANIFEST="$(manifest_from_arg "${1:-}")"
check_manifest "${MANIFEST}"
echo "PrivacyInfo ok: ${MANIFEST}"
