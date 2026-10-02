#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_ROOT="${ROOT_DIR}/build/release"
BUILD_ROOT="${ROOT_DIR}/build/release-staging.$$"
DERIVED_DATA="${BUILD_ROOT}/DerivedData"
APP_PATH="${DERIVED_DATA}/Build/Products/Release/TimeAnnouncer.app"
ZIP_PATH="${BUILD_ROOT}/TimeAnnouncer.zip"
ZIP_SHA256_PATH="${ZIP_PATH}.sha256"
DMG_STAGING="${BUILD_ROOT}/dmg-staging"
DMG_PATH="${BUILD_ROOT}/TimeAnnouncer.dmg"
DMG_SHA256_PATH="${DMG_PATH}.sha256"

# shellcheck source=signing-defaults.sh
source "${ROOT_DIR}/scripts/signing-defaults.sh"
NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-}"

fail() {
  echo "error: $*" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required"
}

"${ROOT_DIR}/scripts/check-signing-defaults.sh"
"${ROOT_DIR}/scripts/check-privacyinfo-release.sh"

require_tool xcodebuild
require_tool codesign
require_tool ditto
require_tool hdiutil
require_tool shasum
require_tool spctl
require_tool xcrun
require_tool python3

if ! security find-identity -v -p codesigning | grep -Fq "${SIGNING_IDENTITY}"; then
  fail "missing signing identity: ${SIGNING_IDENTITY}"
fi

mkdir -p "${ROOT_DIR}/build"
LOCK_DIR="${ROOT_DIR}/build/.release-build-lock"
mkdir "${LOCK_DIR}" 2>/dev/null || fail "another release build owns ${LOCK_DIR}; check it before removing a stale lock"
cleanup() {
  local status=$?
  rmdir "${LOCK_DIR}" 2>/dev/null || true
  if [[ "${status}" != 0 && -d "${BUILD_ROOT}" ]]; then
    echo "Build failed. Previous release remains at ${RELEASE_ROOT}; inspect ${BUILD_ROOT}." >&2
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir "${BUILD_ROOT}"
python3 "${ROOT_DIR}/scripts/release-metadata.py" write-receipt "${BUILD_ROOT}/source.json"

create_dmg() {
  rm -rf "${DMG_STAGING}" "${DMG_PATH}"
  mkdir -p "${DMG_STAGING}"
  ditto "${APP_PATH}" "${DMG_STAGING}/TimeAnnouncer.app"
  ln -s /Applications "${DMG_STAGING}/Applications"
  hdiutil create \
    -volname "TimeAnnouncer" \
    -srcfolder "${DMG_STAGING}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}"
  codesign --force --sign "${SIGNING_IDENTITY}" "${DMG_PATH}"
  codesign --verify --verbose=2 "${DMG_PATH}"
  hdiutil verify "${DMG_PATH}"
}

write_checksums() {
  (cd "${BUILD_ROOT}" && shasum -a 256 "$(basename "${ZIP_PATH}")" > "$(basename "${ZIP_SHA256_PATH}")")
  (cd "${BUILD_ROOT}" && shasum -a 256 "$(basename "${DMG_PATH}")" > "$(basename "${DMG_SHA256_PATH}")")
}

xcodebuild \
  -project "${ROOT_DIR}/TimeAnnouncer.xcodeproj" \
  -scheme TimeAnnouncer \
  -configuration Release \
  -derivedDataPath "${DERIVED_DATA}" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="${TEAM_ID}" \
  CODE_SIGN_IDENTITY="${SIGNING_IDENTITY}" \
  ENABLE_HARDENED_RUNTIME=YES \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  OTHER_CODE_SIGN_FLAGS="--timestamp" \
  ONLY_ACTIVE_ARCH=NO \
  ARCHS="arm64 x86_64" \
  build

test -d "${APP_PATH}" || fail "Release app was not built at ${APP_PATH}"
test -f "${APP_PATH}/Contents/Resources/KokoroSynth.py" || fail "KokoroSynth.py is missing from the app bundle"
# The setup script MUST ship too. Shipping KokoroSynth.py without it is what
# made the Kokoro voice unreachable for every 1.0.0 downloader (2026-07-26).
test -f "${APP_PATH}/Contents/Resources/setup-kokoro.sh" || fail "setup-kokoro.sh is missing from the app bundle — Kokoro would be a dead end for anyone installing from the DMG"
test -f "${APP_PATH}/Contents/Resources/Assets.car" || fail "compiled asset catalog is missing from the app bundle"
python3 "${ROOT_DIR}/scripts/release-metadata.py" check-app "${APP_PATH}"
python3 "${ROOT_DIR}/scripts/release-metadata.py" check-receipt "${BUILD_ROOT}/source.json"
"${ROOT_DIR}/scripts/check-privacyinfo.sh" "${APP_PATH}"

SIGNATURE_DETAILS="$(codesign -dv --verbose=4 "${APP_PATH}" 2>&1)"
echo "${SIGNATURE_DETAILS}" | grep -Fq "Authority=${SIGNING_IDENTITY}" || fail "app is not signed with ${SIGNING_IDENTITY}"
echo "${SIGNATURE_DETAILS}" | grep -Fq "TeamIdentifier=${TEAM_ID}" || fail "app is not signed with team ${TEAM_ID}"
echo "${SIGNATURE_DETAILS}" | grep -Fq "flags=0x10000(runtime)" || fail "hardened runtime is not enabled"
echo "${SIGNATURE_DETAILS}" | grep -Fq "Timestamp=" || fail "release signature does not include a secure timestamp"

if codesign -d --entitlements :- "${APP_PATH}" 2>/dev/null | grep -Fq "get-task-allow"; then
  fail "release signature contains get-task-allow"
fi

codesign --verify --deep --strict --verbose=2 "${APP_PATH}"

ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"
create_dmg
write_checksums

echo "Built signed release app: ${APP_PATH}"
echo "Created notarization zip: ${ZIP_PATH}"
echo "Created signed installer disk image: ${DMG_PATH}"
echo "Created release checksums: ${ZIP_SHA256_PATH}, ${DMG_SHA256_PATH}"

if [[ -n "${NOTARYTOOL_PROFILE}" ]]; then
  xcrun notarytool submit "${ZIP_PATH}" --keychain-profile "${NOTARYTOOL_PROFILE}" --wait
  xcrun stapler staple "${APP_PATH}"
  xcrun stapler validate "${APP_PATH}"
  ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"
  create_dmg
  xcrun notarytool submit "${DMG_PATH}" --keychain-profile "${NOTARYTOOL_PROFILE}" --wait
  xcrun stapler staple "${DMG_PATH}"
  xcrun stapler validate "${DMG_PATH}"
  write_checksums
  spctl --assess --type execute --verbose=4 "${APP_PATH}"
  echo "Notarized and stapled release app: ${APP_PATH}"
  echo "Notarized and stapled installer disk image: ${DMG_PATH}"
  echo "Updated release checksums: ${ZIP_SHA256_PATH}, ${DMG_SHA256_PATH}"
else
  echo "Notarization skipped. Set NOTARYTOOL_PROFILE to submit and staple."
  if spctl --assess --type execute --verbose=4 "${APP_PATH}"; then
    echo "Gatekeeper accepted the app."
  else
    echo "Gatekeeper did not accept the app yet. This is expected before notarization."
  fi
fi

# Keep the last complete candidate until this one has finished successfully.
python3 "${ROOT_DIR}/scripts/release-metadata.py" check-receipt "${BUILD_ROOT}/source.json"
if [[ -d "${RELEASE_ROOT}" ]]; then
  ARCHIVE_ROOT="${ROOT_DIR}/build/release-history/$(date -u +%Y%m%dT%H%M%SZ)-$$"
  mkdir -p "$(dirname "${ARCHIVE_ROOT}")"
  mv "${RELEASE_ROOT}" "${ARCHIVE_ROOT}"
  if ! mv "${BUILD_ROOT}" "${RELEASE_ROOT}"; then
    mv "${ARCHIVE_ROOT}" "${RELEASE_ROOT}"
    fail "could not promote candidate; restored previous release"
  fi
  echo "Previous release preserved: ${ARCHIVE_ROOT}"
else
  mv "${BUILD_ROOT}" "${RELEASE_ROOT}"
fi
echo "Candidate artifacts: ${RELEASE_ROOT}"
echo "Run ./scripts/smoke-release.sh, then complete installed-app acceptance in docs/release-checklist.md."
