#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH}"

BUILD_ROOT="${ROOT_DIR}/build/release"
APP_PATH="${BUILD_ROOT}/DerivedData/Build/Products/Release/TimeAnnouncer.app"
ZIP_PATH="${BUILD_ROOT}/TimeAnnouncer.zip"
ZIP_SHA256_PATH="${ZIP_PATH}.sha256"
DMG_PATH="${BUILD_ROOT}/TimeAnnouncer.dmg"
DMG_SHA256_PATH="${DMG_PATH}.sha256"
SUPPORT_DOC="${ROOT_DIR}/docs/support.md"
RELEASE_NOTES="${ROOT_DIR}/docs/release-notes/v1.0.md"
NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-notarytool-profile}"

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

require_file() {
  if [[ -e "$1" ]]; then
    print_pass "$2 exists"
  else
    print_fail "$2 exists" "$1 is missing. Run ./scripts/build-release.sh first."
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

printf 'TimeAnnouncer Launch Audit\n'
printf 'Repository: %s\n' "$ROOT_DIR"
printf 'Notary profile: %s\n\n' "$NOTARYTOOL_PROFILE"

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
  print_fail "tracked working tree is clean" "Commit, stash, or revert tracked changes before publishing."
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
require_file "$APP_PATH" "release app"
require_file "$ZIP_PATH" "notarization zip"
require_file "$ZIP_SHA256_PATH" "zip SHA-256 file"
require_file "$DMG_PATH" "installer DMG"
require_file "$DMG_SHA256_PATH" "DMG SHA-256 file"

if [[ -f "$ZIP_PATH" && -f "$ZIP_SHA256_PATH" ]]; then
  check_command "zip checksum matches" bash -c 'cd "$1" && shasum -a 256 -c "$(basename "$2")"' _ "$BUILD_ROOT" "$ZIP_SHA256_PATH"
fi

if [[ -f "$DMG_PATH" && -f "$DMG_SHA256_PATH" ]]; then
  check_command "DMG checksum matches" bash -c 'cd "$1" && shasum -a 256 -c "$(basename "$2")"' _ "$BUILD_ROOT" "$DMG_SHA256_PATH"
fi

if [[ -d "$APP_PATH" ]]; then
  check_command "release app signature is valid" codesign --verify --deep --strict --verbose=2 "$APP_PATH"

  signature_details="$(codesign -dv --verbose=4 "$APP_PATH" 2>&1)"
  if printf '%s\n' "$signature_details" | grep -Fq "flags=0x10000(runtime)"; then
    print_pass "hardened runtime is enabled"
  else
    print_fail "hardened runtime is enabled" "$signature_details"
  fi

  if printf '%s\n' "$signature_details" | grep -Fq "Timestamp="; then
    print_pass "release app has a secure timestamp"
  else
    print_fail "release app has a secure timestamp" "$signature_details"
  fi

  if codesign -d --entitlements :- "$APP_PATH" 2>/dev/null | grep -Fq "get-task-allow"; then
    print_fail "release app excludes get-task-allow" "Debug entitlement found in release signature."
  else
    print_pass "release app excludes get-task-allow"
  fi
fi

if [[ -f "$DMG_PATH" ]]; then
  check_command "DMG verifies" hdiutil verify "$DMG_PATH"
  check_command "DMG signature is valid" codesign --verify --verbose=2 "$DMG_PATH"
fi

printf '\nNotarization\n'
check_command "notarytool profile is usable" xcrun notarytool history --keychain-profile "$NOTARYTOOL_PROFILE"

if [[ -d "$APP_PATH" ]]; then
  check_command "app notarization ticket validates" xcrun stapler validate "$APP_PATH"
  check_command "Gatekeeper accepts release app" spctl --assess --type execute --verbose=4 "$APP_PATH"
fi

if [[ -f "$DMG_PATH" ]]; then
  check_command "DMG notarization ticket validates" xcrun stapler validate "$DMG_PATH"
  check_command "Gatekeeper accepts installer DMG" spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"
fi

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
  printf 'Launch status: NOT READY\n'
  exit 1
fi

printf 'Launch status: READY\n'
exit 0
