#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH}"

BUILD_ROOT="${ROOT_DIR}/build/release"
DMG_PATH="${BUILD_ROOT}/TimeAnnouncer.dmg"
DMG_SHA256_PATH="${DMG_PATH}.sha256"
RELEASE_NOTES_PATH="${RELEASE_NOTES_PATH:-${ROOT_DIR}/docs/release-notes/v1.0.md}"
VERSION="${VERSION:-1.0.0}"
TAG="${TAG:-v${VERSION}}"
TITLE="${TITLE:-TimeAnnouncer ${VERSION}}"
DRY_RUN="${DRY_RUN:-0}"
DRAFT_RELEASE="${DRAFT_RELEASE:-1}"
SKIP_LAUNCH_AUDIT="${SKIP_LAUNCH_AUDIT:-0}"
ALLOW_DRAFT_NOTES="${ALLOW_DRAFT_NOTES:-0}"

fail() {
  echo "error: $*" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required"
}

require_file() {
  test -f "$1" || fail "missing $1"
}

release_flags=()
if [[ "${DRAFT_RELEASE}" == "1" ]]; then
  release_flags+=(--draft)
else
  release_flags+=(--latest)
fi

require_tool git
require_tool shasum

require_file "${DMG_PATH}"
require_file "${DMG_SHA256_PATH}"
require_file "${RELEASE_NOTES_PATH}"

(cd "${BUILD_ROOT}" && shasum -a 256 -c "$(basename "${DMG_SHA256_PATH}")")

if [[ "${SKIP_LAUNCH_AUDIT}" != "1" ]]; then
  "${ROOT_DIR}/scripts/launch-audit.sh"
fi

if [[ "${ALLOW_DRAFT_NOTES}" != "1" ]] && grep -Fq "Draft Release Notes" "${RELEASE_NOTES_PATH}"; then
  fail "release notes are still marked draft. Finalize notes or set ALLOW_DRAFT_NOTES=1 for a draft release rehearsal."
fi

cmd=(
  gh release create "${TAG}"
  "${DMG_PATH}#TimeAnnouncer.dmg"
  "${DMG_SHA256_PATH}#TimeAnnouncer.dmg.sha256"
  --title "${TITLE}"
  --notes-file "${RELEASE_NOTES_PATH}"
  --verify-tag
  "${release_flags[@]}"
)

if [[ "${DRY_RUN}" == "1" ]]; then
  printf 'Dry run. Would run:\n'
  printf '  %q' "${cmd[@]}"
  printf '\n'
  exit 0
fi

require_tool gh
git -C "${ROOT_DIR}" remote get-url origin >/dev/null 2>&1 || fail "origin remote is not configured"
gh auth status >/dev/null

if gh release view "${TAG}" >/dev/null 2>&1; then
  fail "release ${TAG} already exists"
fi

"${cmd[@]}"

echo "Published GitHub release ${TAG}."
