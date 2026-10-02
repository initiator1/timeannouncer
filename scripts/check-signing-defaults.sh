#!/usr/bin/env bash
# Prove release smoke and build share the INITIATOR LLC signing default.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULTS="${ROOT_DIR}/scripts/signing-defaults.sh"
BUILD="${ROOT_DIR}/scripts/build-release.sh"
SMOKE="${ROOT_DIR}/scripts/smoke-release.sh"

fail() {
  echo "error: $*" >&2
  exit 1
}

test -f "${DEFAULTS}" || fail "missing ${DEFAULTS}"
test -f "${BUILD}" || fail "missing ${BUILD}"
test -f "${SMOKE}" || fail "missing ${SMOKE}"

# A leftover personal default in either script would fail a correctly signed
# public 1.0.1 DMG and could silently revive the 1.0.0 Gatekeeper name.
if grep -E 'SIGNING_IDENTITY=.*Douglas Baker' "${BUILD}" "${SMOKE}" "${DEFAULTS}"; then
  fail "release scripts must not default signing to the personal Developer ID"
fi

grep -Fq 'scripts/signing-defaults.sh' "${BUILD}" || fail "build-release.sh must source signing-defaults.sh"
grep -Fq 'scripts/signing-defaults.sh' "${SMOKE}" || fail "smoke-release.sh must source signing-defaults.sh"

unset SIGNING_IDENTITY
TEAM_ID="MDWFZC6396"
# shellcheck disable=SC1090
source "${DEFAULTS}"
[[ "${SIGNING_IDENTITY}" == "Developer ID Application: INITIATOR LLC (MDWFZC6396)" ]] \
  || fail "default signing identity must be INITIATOR LLC, got ${SIGNING_IDENTITY}"
[[ "${SIGNING_IDENTITY}" != *'Douglas Baker'* ]] \
  || fail "default signing identity must not be the personal Developer ID"

echo "Release signing defaults use INITIATOR LLC."
