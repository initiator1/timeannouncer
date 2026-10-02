#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH}"

SUPPORT_DOC="${ROOT_DIR}/docs/support.md"
VERSION="$(python3 "${ROOT_DIR}/scripts/release-metadata.py" version)" || exit 1
RELEASE_NOTES="${RELEASE_NOTES_PATH:-${ROOT_DIR}/docs/release-notes/v${VERSION}.md}"

failures=0
warnings=0

print_pass() {
  printf 'PASS: %s\n' "$1"
}

print_warn() {
  warnings=$((warnings + 1))
  printf 'WARN: %s\n' "$1"
}

print_fail() {
  failures=$((failures + 1))
  printf 'FAIL: %s\n' "$1"
  if [[ -n "${2:-}" ]]; then
    printf '      %s\n' "$2" | sed $'s/\r$//'
  fi
}

require_tool() {
  if command -v "$1" >/dev/null 2>&1; then
    print_pass "$1 is available"
  else
    print_fail "$1 is available" "Install or select the required developer toolchain."
  fi
}

check_command() {
  local label="$1"
  shift
  local output
  if output="$("$@" 2>&1)"; then
    print_pass "$label"
  else
    print_fail "$label" "$output"
  fi
}

check_contains_no_placeholder() {
  local file="$1"
  local pattern="$2"
  local label="$3"

  if [[ ! -f "$file" ]]; then
    print_fail "$label" "$file is missing."
  elif grep -Fq "$pattern" "$file"; then
    print_fail "$label" "$file still contains: $pattern"
  else
    print_pass "$label"
  fi
}

check_optional_command() {
  local label="$1"
  local tool="$2"

  if command -v "$tool" >/dev/null 2>&1; then
    print_pass "$label"
    return 0
  fi

  print_fail "$label" "$tool is required for the configured publishing path."
  return 1
}

printf 'TimeAnnouncer Technical Release Audit\n'
printf 'Repository: %s\n' "$ROOT_DIR"
printf 'Candidate: %s\n\n' "$VERSION"

require_tool codesign
require_tool git
require_tool hdiutil
require_tool shasum
require_tool spctl
require_tool xcrun

printf '\nRepository\n'
if git -C "$ROOT_DIR" diff --quiet && git -C "$ROOT_DIR" diff --cached --quiet; then
  print_pass "tracked working tree is clean"
else
  print_fail "tracked working tree is clean" "Review and commit the release changes before publishing. Preserve unrelated work."
fi

if git -C "$ROOT_DIR" ls-files --others --exclude-standard | grep -q .; then
  print_warn "untracked files are present"
  git -C "$ROOT_DIR" ls-files --others --exclude-standard | sed 's/^/      /'
else
  print_pass "no untracked files"
fi

if git -C "$ROOT_DIR" remote get-url origin >/dev/null 2>&1; then
  print_pass "git origin remote is configured"
else
  print_fail "git origin remote is configured" "No origin remote is configured for publishing a GitHub release."
fi

printf '\nPublishing Tooling\n'
if check_optional_command "GitHub CLI is available" gh; then
  check_command "GitHub CLI is authenticated" gh auth status
fi

printf '\nRelease Artifacts\n'
check_command "candidate packages match source, version, signature, and notarization" \
  env REQUIRE_NOTARIZATION=1 RUN_APP=0 "${ROOT_DIR}/scripts/smoke-release.sh"

printf '\nPublic Materials\n'
check_contains_no_placeholder "$SUPPORT_DOC" "Launch Support Placeholder" "public support path is final"
check_contains_no_placeholder "$SUPPORT_DOC" "Before public release" "support doc has no pre-release placeholder"

if [[ -f "$RELEASE_NOTES" ]]; then
  if grep -Fq "Draft Release Notes" "$RELEASE_NOTES"; then
    print_warn "release notes are still marked draft"
  else
    print_pass "release notes are no longer marked draft"
  fi
else
  print_fail "release notes exist" "$RELEASE_NOTES is missing."
fi

printf '\nSummary\n'
printf 'Failures: %d\n' "$failures"
printf 'Warnings: %d\n' "$warnings"

if [[ "$failures" -gt 0 ]]; then
  printf 'Technical release checks: FAIL\n'
  exit 1
fi

printf 'Technical release checks: PASS\n'
printf 'Installed-app acceptance and publication approval are recorded separately in docs/release-checklist.md.\n'
exit 0
