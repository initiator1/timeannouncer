#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="${ROOT_DIR}/build/release"
ZIP_PATH="${BUILD_ROOT}/TimeAnnouncer.zip"
ZIP_SHA256_PATH="${ZIP_PATH}.sha256"
DMG_PATH="${BUILD_ROOT}/TimeAnnouncer.dmg"
DMG_SHA256_PATH="${DMG_PATH}.sha256"
APP_PATH="${BUILD_ROOT}/DerivedData/Build/Products/Release/TimeAnnouncer.app"
TEAM_ID="${TEAM_ID:-MDWFZC6396}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: Douglas Baker (${TEAM_ID})}"
RUN_APP="${RUN_APP:-0}"

fail() {
  echo "error: $*" >&2
  exit 1
}

require_file() {
  test -e "$1" || fail "missing $1"
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required"
}

require_file "${ZIP_PATH}"
require_file "${ZIP_SHA256_PATH}"
require_file "${DMG_PATH}"
require_file "${DMG_SHA256_PATH}"
require_file "${APP_PATH}"
require_tool codesign
require_tool ditto
require_tool hdiutil
require_tool shasum
require_tool spctl

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/timeannouncer-smoke.XXXXXX")"
cleanup() {
  if [[ -n "${SMOKE_PID:-}" ]] && kill -0 "${SMOKE_PID}" 2>/dev/null; then
    kill "${SMOKE_PID}" 2>/dev/null || true
    wait "${SMOKE_PID}" 2>/dev/null || true
  fi
  if [[ -n "${SMOKE_DEFAULTS_SUITE:-}" ]]; then
    defaults delete "${SMOKE_DEFAULTS_SUITE}" >/dev/null 2>&1 || true
  fi
  if [[ -n "${DMG_MOUNTED:-}" ]]; then
    hdiutil detach "${MOUNT_DIR}" -quiet >/dev/null 2>&1 || true
  fi
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

(cd "${BUILD_ROOT}" && shasum -a 256 -c "$(basename "${ZIP_SHA256_PATH}")")
(cd "${BUILD_ROOT}" && shasum -a 256 -c "$(basename "${DMG_SHA256_PATH}")")

ditto -x -k "${ZIP_PATH}" "${TMP_DIR}/unzipped"
UNZIPPED_APP="${TMP_DIR}/unzipped/TimeAnnouncer.app"
require_file "${UNZIPPED_APP}"

hdiutil verify "${DMG_PATH}"
codesign --verify --verbose=2 "${DMG_PATH}"
MOUNT_DIR="${TMP_DIR}/dmg"
mkdir -p "${MOUNT_DIR}"
hdiutil attach "${DMG_PATH}" -mountpoint "${MOUNT_DIR}" -nobrowse -readonly -quiet
DMG_MOUNTED=1
DMG_APP="${MOUNT_DIR}/TimeAnnouncer.app"
require_file "${DMG_APP}"
require_file "${MOUNT_DIR}/Applications"

for candidate in "${APP_PATH}" "${UNZIPPED_APP}" "${DMG_APP}"; do
  require_file "${candidate}/Contents/MacOS/TimeAnnouncer"
  require_file "${candidate}/Contents/Resources/KokoroSynth.py"
  require_file "${candidate}/Contents/Resources/Assets.car"

  /usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${candidate}/Contents/Info.plist" | grep -Fxq "com.timeannouncer.app"
  /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${candidate}/Contents/Info.plist" | grep -Fxq "1.0"
  /usr/libexec/PlistBuddy -c "Print :LSUIElement" "${candidate}/Contents/Info.plist" | grep -Fxq "true"

  codesign --verify --deep --strict --verbose=2 "${candidate}"
  SIGNATURE_DETAILS="$(codesign -dv --verbose=4 "${candidate}" 2>&1)"
  echo "${SIGNATURE_DETAILS}" | grep -Fq "Authority=${SIGNING_IDENTITY}" || fail "${candidate} is not signed with ${SIGNING_IDENTITY}"
  echo "${SIGNATURE_DETAILS}" | grep -Fq "TeamIdentifier=${TEAM_ID}" || fail "${candidate} is not signed with team ${TEAM_ID}"
  echo "${SIGNATURE_DETAILS}" | grep -Fq "flags=0x10000(runtime)" || fail "${candidate} does not have hardened runtime"

  if codesign -d --entitlements :- "${candidate}" 2>/dev/null | grep -Fq "get-task-allow"; then
    fail "${candidate} contains get-task-allow"
  fi
done

if [[ "${RUN_APP}" == "1" ]]; then
  SMOKE_DEFAULTS_SUITE="com.timeannouncer.smoke.$(uuidgen | tr '[:upper:]' '[:lower:]')"

  TIMEANNOUNCER_DEFAULTS_SUITE="${SMOKE_DEFAULTS_SUITE}" "${UNZIPPED_APP}/Contents/MacOS/TimeAnnouncer" >/tmp/timeannouncer-smoke-app.log 2>&1 &
  SMOKE_PID=$!
  sleep 3

  if ! kill -0 "${SMOKE_PID}" 2>/dev/null; then
    fail "release app exited during smoke launch"
  fi

  defaults read "${SMOKE_DEFAULTS_SUITE}" isEnabled | grep -Fxq "0"
  defaults read "${SMOKE_DEFAULTS_SUITE}" voiceProvider | grep -Fxq "system"
  defaults read "${SMOKE_DEFAULTS_SUITE}" intervalMinutes | grep -Fxq "60"
  defaults delete "${SMOKE_DEFAULTS_SUITE}" >/dev/null 2>&1 || true
fi

if spctl --assess --type execute --verbose=4 "${UNZIPPED_APP}"; then
  echo "Gatekeeper accepted unzipped release app."
else
  echo "Gatekeeper did not accept the release app. Expected until notarization is complete."
fi

echo "Release smoke checks passed."
