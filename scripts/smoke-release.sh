#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="${ROOT_DIR}/build/release"
ZIP_PATH="${BUILD_ROOT}/TimeAnnouncer.zip"
ZIP_SHA256_PATH="${ZIP_PATH}.sha256"
DMG_PATH="${BUILD_ROOT}/TimeAnnouncer.dmg"
DMG_SHA256_PATH="${DMG_PATH}.sha256"
APP_PATH="${BUILD_ROOT}/DerivedData/Build/Products/Release/TimeAnnouncer.app"
INSTALLED_APP="/Applications/TimeAnnouncer.app"
# shellcheck source=signing-defaults.sh
source "${ROOT_DIR}/scripts/signing-defaults.sh"
RUN_APP="${RUN_APP:-0}"
REQUIRE_NOTARIZATION="${REQUIRE_NOTARIZATION:-0}"

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

"${ROOT_DIR}/scripts/check-signing-defaults.sh"
"${ROOT_DIR}/scripts/check-privacyinfo-release.sh"

require_file "${ZIP_PATH}"
require_file "${ZIP_SHA256_PATH}"
require_file "${DMG_PATH}"
require_file "${DMG_SHA256_PATH}"
require_file "${APP_PATH}"
require_file "${BUILD_ROOT}/source.json"
require_tool codesign
require_tool ditto
require_tool hdiutil
require_tool shasum
require_tool spctl
require_tool python3
require_tool lipo
python3 "${ROOT_DIR}/scripts/release-metadata.py" check-receipt "${BUILD_ROOT}/source.json"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/timeannouncer-smoke.XXXXXX")"
cleanup() {
  local status=$?
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
  if [[ "${status}" != 0 && -f "${TMP_DIR}/app.log" ]]; then
    echo "Candidate launch log:" >&2
    tail -n 40 "${TMP_DIR}/app.log" >&2
  fi
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

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

CANDIDATES=("${APP_PATH}" "${UNZIPPED_APP}" "${DMG_APP}")
if [[ "${RUN_APP}" == "1" ]]; then
  [[ -d "${INSTALLED_APP}" ]] || fail "RUN_APP=1 requires ${INSTALLED_APP}. Install this candidate from the DMG first, or use RUN_APP=0 for package checks only."
  python3 "${ROOT_DIR}/scripts/release-metadata.py" check-app "${INSTALLED_APP}" \
    || fail "installed version/build differs from the candidate. Quit the app and install this candidate from the DMG before RUN_APP=1."
  codesign --verify --deep --strict --verbose=2 "${INSTALLED_APP}" \
    || fail "installed signature is invalid. Restore or install the verified candidate from the DMG before RUN_APP=1."
  INSTALLED_BINARY_HASH="$(shasum -a 256 "${INSTALLED_APP}/Contents/MacOS/TimeAnnouncer" | awk '{print $1}')"
  CANDIDATE_BINARY_HASH="$(shasum -a 256 "${DMG_APP}/Contents/MacOS/TimeAnnouncer" | awk '{print $1}')"
  [[ "${INSTALLED_BINARY_HASH}" == "${CANDIDATE_BINARY_HASH}" ]] \
    || fail "installed executable differs from the DMG candidate. Quit the app and install this candidate before RUN_APP=1."
  CANDIDATES+=("${INSTALLED_APP}")
fi

for candidate in "${CANDIDATES[@]}"; do
  require_file "${candidate}/Contents/MacOS/TimeAnnouncer"
  require_file "${candidate}/Contents/Resources/KokoroSynth.py"
  require_file "${candidate}/Contents/Resources/setup-kokoro.sh"
  require_file "${candidate}/Contents/Resources/Assets.car"
  "${ROOT_DIR}/scripts/check-privacyinfo.sh" "${candidate}"

  /usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${candidate}/Contents/Info.plist" | grep -Fxq "com.timeannouncer.app"
  python3 "${ROOT_DIR}/scripts/release-metadata.py" check-app "${candidate}"
  ARCHITECTURES=" $(lipo -archs "${candidate}/Contents/MacOS/TimeAnnouncer") "
  for architecture in arm64 x86_64; do
    [[ "${ARCHITECTURES}" == *" ${architecture} "* ]] || fail "${candidate} is missing ${architecture}"
  done
  /usr/libexec/PlistBuddy -c "Print :LSUIElement" "${candidate}/Contents/Info.plist" | grep -Fxq "true"

  codesign --verify --deep --strict --verbose=2 "${candidate}"
  SIGNATURE_DETAILS="$(codesign -dv --verbose=4 "${candidate}" 2>&1)"
  echo "${SIGNATURE_DETAILS}" | grep -Fq "Authority=${SIGNING_IDENTITY}" || fail "${candidate} is not signed with ${SIGNING_IDENTITY}"
  echo "${SIGNATURE_DETAILS}" | grep -Fq "TeamIdentifier=${TEAM_ID}" || fail "${candidate} is not signed with team ${TEAM_ID}"
  echo "${SIGNATURE_DETAILS}" | grep -Fq "flags=0x10000(runtime)" || fail "${candidate} does not have hardened runtime"
  echo "${SIGNATURE_DETAILS}" | grep -Fq "Timestamp=" || fail "${candidate} has no secure timestamp"

  if codesign -d --entitlements :- "${candidate}" 2>/dev/null | grep -Fq "get-task-allow"; then
    fail "${candidate} contains get-task-allow"
  fi
  if [[ "${REQUIRE_NOTARIZATION}" == "1" ]]; then
    xcrun stapler validate "${candidate}"
    spctl --assess --type execute --verbose=4 "${candidate}"
  fi
done

if [[ "${REQUIRE_NOTARIZATION}" == "1" ]]; then
  xcrun stapler validate "${DMG_PATH}"
  spctl --assess --type open --context context:primary-signature --verbose=4 "${DMG_PATH}"
fi

if [[ "${RUN_APP}" == "1" ]]; then
  SMOKE_DEFAULTS_SUITE="com.timeannouncer.smoke.$(uuidgen | tr '[:upper:]' '[:lower:]')"

  # A same-ID temporary bundle can retarget macOS login registration to a path
  # deleted by cleanup. Launch only the verified, durable installed location.
  TIMEANNOUNCER_DEFAULTS_SUITE="${SMOKE_DEFAULTS_SUITE}" "${INSTALLED_APP}/Contents/MacOS/TimeAnnouncer" >"${TMP_DIR}/app.log" 2>&1 &
  SMOKE_PID=$!
  sleep 3

  if ! kill -0 "${SMOKE_PID}" 2>/dev/null; then
    fail "release app exited during smoke launch"
  fi

  defaults read "${SMOKE_DEFAULTS_SUITE}" isEnabled | grep -Fxq "0"
  defaults read "${SMOKE_DEFAULTS_SUITE}" voiceProvider | grep -Fxq "system"
  defaults read "${SMOKE_DEFAULTS_SUITE}" intervalMinutes | grep -Fxq "60"
fi

if spctl --assess --type execute --verbose=4 "${UNZIPPED_APP}"; then
  echo "Gatekeeper accepted unzipped release app."
else
  [[ "${REQUIRE_NOTARIZATION}" != "1" ]] || fail "Gatekeeper rejected the candidate"
  echo "Gatekeeper did not accept the release app. Expected until notarization is complete."
fi

echo "Package smoke checks passed. Installed-app behavior still needs acceptance in docs/release-checklist.md."
