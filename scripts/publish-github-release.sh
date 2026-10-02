#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"
export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH}"

BUILD_ROOT="${ROOT_DIR}/build/release"
DMG_PATH="${BUILD_ROOT}/TimeAnnouncer.dmg"
DMG_SHA256_PATH="${DMG_PATH}.sha256"
VERSION="${VERSION:-$(python3 "${ROOT_DIR}/scripts/release-metadata.py" version)}"
RELEASE_NOTES_PATH="${RELEASE_NOTES_PATH:-${ROOT_DIR}/docs/release-notes/v${VERSION}.md}"
TAG="${TAG:-v${VERSION}}"
TITLE="${TITLE:-TimeAnnouncer ${VERSION}}"
DRY_RUN="${DRY_RUN:-0}"
DRAFT_RELEASE="${DRAFT_RELEASE:-1}"
SKIP_LAUNCH_AUDIT="${SKIP_LAUNCH_AUDIT:-0}"
ALLOW_DRAFT_NOTES="${ALLOW_DRAFT_NOTES:-0}"
PUBLIC_WITHOUT_PRIVACYINFO="${PUBLIC_WITHOUT_PRIVACYINFO:-1.0.1}"
SOURCE_MANIFEST="${ROOT_DIR}/TimeAnnouncer/PrivacyInfo.xcprivacy"

fail() {
  echo "error: $*" >&2
  exit 1
}

check_repository() {
  local origin repository
  origin="$(git -C "${ROOT_DIR}" remote get-url origin)" || fail "origin remote is not configured"
  case "${origin}" in
    https://github.com/*) repository="${origin#https://github.com/}" ;;
    git@github.com:*) repository="${origin#git@github.com:}" ;;
    *) fail "unsupported release origin; expected the TimeAnnouncer GitHub repository" ;;
  esac
  repository="${repository%.git}"
  [[ "${repository}" == "initiator1/timeannouncer" ]] || fail "origin targets ${repository}, not initiator1/timeannouncer"
  GITHUB_REPOSITORY="github.com/${repository}"
  [[ -z "${GH_REPO:-}" || "${GH_REPO}" == "${repository}" || "${GH_REPO}" == "${GITHUB_REPOSITORY}" ]] \
    || fail "GH_REPO conflicts with origin; unset it before preparing this release"
}

remote_tag_commit() {
  local refs="$1" tag="$2" sha ref direct="" peeled=""
  while read -r sha ref; do
    [[ "${ref}" != "refs/tags/${tag}" ]] || direct="${sha}"
    [[ "${ref}" != "refs/tags/${tag}^{}" ]] || peeled="${sha}"
  done <<<"${refs}"
  printf '%s\n' "${peeled:-${direct}}"
}

marketing_version() {
  if [[ -n "${TA_MARKETING_VERSION:-}" ]]; then
    printf '%s\n' "${TA_MARKETING_VERSION}"
    return
  fi
  python3 "${ROOT_DIR}/scripts/release-metadata.py" version
}

check_publish_version() {
  local marketing
  marketing="$(marketing_version)"
  if [[ -f "${SOURCE_MANIFEST}" && "${VERSION}" == "${PUBLIC_WITHOUT_PRIVACYINFO}" ]]; then
    fail "public ${PUBLIC_WITHOUT_PRIVACYINFO} has no PrivacyInfo; do not publish this tree as ${PUBLIC_WITHOUT_PRIVACYINFO}"
  fi
  if [[ "${VERSION}" != "${marketing}" ]]; then
    fail "publish VERSION ${VERSION} does not match MARKETING_VERSION ${marketing}"
  fi
  [[ "${TAG}" == "v${VERSION}" ]] || fail "TAG ${TAG} must match v${VERSION}"
}

check_release_notes() {
  local path="${1:-${RELEASE_NOTES_PATH}}"
  [[ -f "${path}" ]] || fail "missing ${path}"
  if [[ "${ALLOW_DRAFT_NOTES}" != "1" ]] && /usr/bin/grep -Fq "Draft Release Notes" "${path}"; then
    fail "release notes are still marked draft. Finalize notes or set ALLOW_DRAFT_NOTES=1 for a draft release rehearsal."
  fi
  if /usr/bin/python3 - "${path}" <<'PY'
import json
import sys

path = sys.argv[1]
try:
    payload = json.loads(open(path, encoding="utf-8").read())
except Exception:
    raise SystemExit(0)
if not isinstance(payload, dict):
    raise SystemExit(0)
if payload.get("record_type") == "authentic_draft" and payload.get("published") is not True:
    raise SystemExit(2)
raise SystemExit(0)
PY
  then
    return 0
  fi
  fail "unpublished owner words are not GitHub release notes"
}

selftest() {
  local out
  if out="$(VERSION="${PUBLIC_WITHOUT_PRIVACYINFO}" "$0" --check-version-only 2>&1)"; then
    fail "selftest: public ${PUBLIC_WITHOUT_PRIVACYINFO} must fail"
  fi
  printf '%s\n' "${out}" | /usr/bin/grep -Fq "public ${PUBLIC_WITHOUT_PRIVACYINFO} has no PrivacyInfo" \
    || fail "selftest: missing public-version refusal"
  if out="$(VERSION="1.0.0" TA_MARKETING_VERSION="${PUBLIC_WITHOUT_PRIVACYINFO}" "$0" --check-version-only 2>&1)"; then
    fail "selftest: default 1.0.0 must not publish a ${PUBLIC_WITHOUT_PRIVACYINFO} PrivacyInfo tree"
  fi
  printf '%s\n' "${out}" | /usr/bin/grep -Fq "does not match MARKETING_VERSION" \
    || fail "selftest: missing VERSION mismatch refusal"
  VERSION="1.0.2" TA_MARKETING_VERSION="1.0.2" "$0" --check-version-only >/dev/null
  local notes
  notes="$(/usr/bin/mktemp)"
  printf '%s\n' '{"record_type":"authentic_draft","published":false,"launch":false}' >"${notes}"
  if out="$(RELEASE_NOTES_PATH="${notes}" "$0" --check-notes-only 2>&1)"; then
    rm -f "${notes}"
    fail "selftest: unpublished owner words must not be release notes"
  fi
  printf '%s\n' "${out}" | /usr/bin/grep -Fq "unpublished owner words are not GitHub release notes" \
    || { rm -f "${notes}"; fail "selftest: missing unpublished-notes refusal"; }
  rm -f "${notes}"
  if out="$(GH_REPO="someone/another-product" "$0" --check-repository-only 2>&1)"; then
    fail "selftest: conflicting GH_REPO must fail"
  fi
  printf '%s\n' "${out}" | /usr/bin/grep -Fq "GH_REPO conflicts with origin" \
    || fail "selftest: missing conflicting-repository refusal"
  (cd /tmp && GH_REPO= "${ROOT_DIR}/scripts/publish-github-release.sh" --check-repository-only) \
    | /usr/bin/grep -Fxq "github.com/initiator1/timeannouncer" \
    || fail "selftest: caller directory changed the release repository"
  [[ "$(remote_tag_commit $'tag-object\trefs/tags/v1.0.2\ncommit-sha\trefs/tags/v1.0.2^{}' v1.0.2)" == "commit-sha" ]] \
    || fail "selftest: annotated remote tag must resolve to its commit"
  [[ "$(remote_tag_commit $'commit-sha\trefs/tags/v1.0.2' v1.0.2)" == "commit-sha" ]] \
    || fail "selftest: lightweight remote tag must resolve to its commit"
  [[ -z "$(remote_tag_commit '' v1.0.2)" ]] || fail "selftest: missing remote tag must stay missing"
  echo "Release publish guard checks passed."
}

if [[ "${1:-}" == "--selftest" ]]; then
  selftest
  exit 0
fi

if [[ "${1:-}" == "--check-version-only" ]]; then
  check_publish_version
  echo "publish version ${VERSION} matches MARKETING_VERSION and is not a PrivacyInfo reprint of public ${PUBLIC_WITHOUT_PRIVACYINFO}."
  exit 0
fi

if [[ "${1:-}" == "--check-notes-only" ]]; then
  check_release_notes
  echo "release notes are not unpublished owner words."
  exit 0
fi

if [[ "${1:-}" == "--check-repository-only" ]]; then
  check_repository
  printf '%s\n' "${GITHUB_REPOSITORY}"
  exit 0
fi

check_publish_version
check_repository
[[ "${DRAFT_RELEASE}" == "0" || "${DRAFT_RELEASE}" == "1" ]] || fail "DRAFT_RELEASE must be 0 or 1"
[[ "${DRAFT_RELEASE}" == "1" || "${ALLOW_DRAFT_NOTES}" != "1" ]] || fail "ALLOW_DRAFT_NOTES is only valid for a draft release"

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
  RELEASE_NOTES_PATH="${RELEASE_NOTES_PATH}" "${ROOT_DIR}/scripts/launch-audit.sh"
else
  # Rehearsal may omit account checks, but it must never upload a stale DMG.
  REQUIRE_NOTARIZATION=1 RUN_APP=0 "${ROOT_DIR}/scripts/smoke-release.sh"
fi

check_release_notes "${RELEASE_NOTES_PATH}"

cmd=(
  gh release create "${TAG}"
  --repo "${GITHUB_REPOSITORY}"
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
git -C "${ROOT_DIR}" diff --quiet && git -C "${ROOT_DIR}" diff --cached --quiet \
  || fail "review and commit the candidate before uploading; preserve unrelated work"
if git -C "${ROOT_DIR}" ls-files --others --exclude-standard -- TimeAnnouncer TimeAnnouncer.xcodeproj scripts docs/release-notes | grep -q .; then
  fail "release inputs are untracked; review and commit them before uploading"
fi
gh auth status >/dev/null

TAG_COMMIT="$(git -C "${ROOT_DIR}" rev-parse "${TAG}^{commit}")" || fail "create the candidate tag after acceptance and publication approval"
HEAD_COMMIT="$(git -C "${ROOT_DIR}" rev-parse HEAD)"
[[ "${TAG_COMMIT}" == "${HEAD_COMMIT}" ]] || fail "${TAG} does not identify the current candidate commit"
REMOTE_TAG_REFS="$(git -C "${ROOT_DIR}" ls-remote --tags origin "refs/tags/${TAG}" "refs/tags/${TAG}^{}")" \
  || fail "could not verify the destination tag; no upload attempted"
REMOTE_TAG_COMMIT="$(remote_tag_commit "${REMOTE_TAG_REFS}" "${TAG}")"
[[ "${REMOTE_TAG_COMMIT}" == "${HEAD_COMMIT}" ]] \
  || fail "destination ${TAG} is missing or points at a different commit; no upload attempted"

if gh release view "${TAG}" --repo "${GITHUB_REPOSITORY}" >/dev/null 2>&1; then
  fail "release ${TAG} already exists"
fi

"${cmd[@]}"

if [[ "${DRAFT_RELEASE}" == "1" ]]; then
  echo "Created draft GitHub release ${TAG}; it is not public."
else
  echo "Published GitHub release ${TAG}."
fi
