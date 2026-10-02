#!/usr/bin/env bash
# Refuse a signed reprint of public 1.0.1 that now includes PrivacyInfo.
# Public v1.0.1 has no privacy manifest. This tree added one. Owner chooses
# the next version; this script does not bump it.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBLIC_WITHOUT_PRIVACYINFO="${PUBLIC_WITHOUT_PRIVACYINFO:-1.0.1}"
SOURCE_MANIFEST="${ROOT_DIR}/TimeAnnouncer/PrivacyInfo.xcprivacy"
PROJECT="${ROOT_DIR}/TimeAnnouncer.xcodeproj/project.pbxproj"

fail() {
  echo "error: $*" >&2
  exit 1
}

marketing_version() {
  if [[ -n "${TA_MARKETING_VERSION:-}" ]]; then
    printf '%s\n' "${TA_MARKETING_VERSION}"
    return
  fi
  local version
  version="$(
    /usr/bin/grep -E 'MARKETING_VERSION = [^;]+;' "${PROJECT}" \
      | /usr/bin/head -1 \
      | /usr/bin/sed -E 's/.*= ([^;]+);/\1/' \
      | /usr/bin/tr -d '[:space:]'
  )"
  [[ -n "${version}" ]] || fail "could not read MARKETING_VERSION from project.pbxproj"
  printf '%s\n' "${version}"
}

check_tree() {
  test -f "${SOURCE_MANIFEST}" || fail "missing ${SOURCE_MANIFEST}"
  local version
  version="$(marketing_version)"
  if [[ "${version}" == "${PUBLIC_WITHOUT_PRIVACYINFO}" ]]; then
    fail "public ${PUBLIC_WITHOUT_PRIVACYINFO} has no PrivacyInfo; bump MARKETING_VERSION before a signed build"
  fi
  echo "PrivacyInfo release version ${version} is not a reprint of public ${PUBLIC_WITHOUT_PRIVACYINFO}."
}

selftest() {
  local out
  if out="$(TA_MARKETING_VERSION="${PUBLIC_WITHOUT_PRIVACYINFO}" "$0" 2>&1)"; then
    fail "selftest: public ${PUBLIC_WITHOUT_PRIVACYINFO} must fail"
  fi
  printf '%s\n' "${out}" | /usr/bin/grep -Fq "public ${PUBLIC_WITHOUT_PRIVACYINFO} has no PrivacyInfo" \
    || fail "selftest: missing public-version refusal"
  TA_MARKETING_VERSION="1.0.2" "$0" >/dev/null
  echo "PrivacyInfo release reuse check ok."
}

if [[ "${1:-}" == "--selftest" ]]; then
  selftest
  exit 0
fi

check_tree
