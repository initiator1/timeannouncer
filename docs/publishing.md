# Maintain and publish Time Announcer

Version 1.0.2, build 3 is the current candidate. Its tested surfaces, remaining
release gates, and publication state belong in [the release record](release-checklist.md).
A successful build or technical audit does not establish user acceptance.

## Ownership and permissions

INITIATOR LLC publishes the app. The human owner approves external publication,
account changes, new credentials, paid services, and spending. Existing explicit
authorization for a step remains valid. An agent owns routine engineering,
local builds, reversible installation, verification, and recovery within the task.

Use the existing Developer ID identity and `notarytool-profile` when authorized.
Do not create keys or switch accounts because a local check fails.
Notarization submits the app to Apple. A GitHub draft also uploads files externally.
Neither action is implied by a local preparation verdict.

The distribution path is the existing
[GitHub repository](https://github.com/initiator1/timeannouncer).
The app is free; an optional Ko-fi tip unlocks nothing. Support uses
`support@initiatorworks.com` and GitHub issues. No purchase or entitlement system
is part of this release.

## Local setup and checks

Use Xcode with its command-line tools selected. The app has no Swift package
installation step. Python 3 is required for release metadata checks.
The app targets macOS 13. The test target requires macOS 14 or later.

Run from the repository root:

```sh
xcodebuild -project TimeAnnouncer.xcodeproj -scheme TimeAnnouncer -configuration Debug build
xcodebuild test -project TimeAnnouncer.xcodeproj -scheme TimeAnnouncer -destination 'platform=macOS,arch=arm64'
```

The test destination above is for Apple silicon. Select an available destination
on an Intel test Mac. Do not treat compiling both architectures as runtime coverage.

For release script changes, use these narrow checks:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s scripts -p 'test_release_metadata.py'
./scripts/check-signing-defaults.sh
./scripts/check-privacyinfo-release.sh --selftest
./scripts/publish-github-release.sh --selftest
```

For app changes, select the relevant existing tests in `TimeAnnouncerTests`.
Name the real failure risk before adding a test. Build and test results need the
candidate commit, toolchain, destination, and outcome in the release record.

## Build the candidate

Update both app configurations' version and build number together. Add release
notes at `docs/release-notes/v<version>.md`. Never overwrite the published 1.0.1
with the changed privacy manifest.

Build locally without submitting to Apple:

```sh
NOTARYTOOL_PROFILE= ./scripts/build-release.sh
./scripts/smoke-release.sh
```

The builder uses the configured INITIATOR LLC Developer ID, hardened runtime,
and a secure timestamp. It produces a universal app, ZIP, DMG, checksums, and
`build/release/source.json`. The receipt ties the candidate to app source inputs,
version, and build. Source changes require another build.

Only after notarization is authorized:

```sh
NOTARYTOOL_PROFILE=notarytool-profile ./scripts/build-release.sh
REQUIRE_NOTARIZATION=1 ./scripts/smoke-release.sh
```

The strict smoke checks the built, unzipped, and DMG app copies. It checks their
identity, architecture, resources, signature, notarization, and Gatekeeper result.
These package checks inspect bundles without launching them.

Record any sandbox or macOS permission failure accurately. Use the task's approved
local tool access where available. Do not disable Gatekeeper or remove quarantine
to make a release check pass.

## Install and accept

Save the installed app before replacement. Quit its running process through the
app menu. Install the candidate from the DMG into Applications, then launch that
copy. Confirm its version through diagnostics and confirm the running path.
Calling `open` while an older instance runs can leave the older code active.

After installation, check fresh preferences on that installed candidate:

```sh
REQUIRE_NOTARIZATION=1 RUN_APP=1 ./scripts/smoke-release.sh
```

The runtime probe requires `/Applications/TimeAnnouncer.app` to match the candidate's
version, build, executable hash, and signature. It launches that durable path with
isolated preferences. It quits its probe process and deletes only the temporary
preferences suite. Relaunch the installed app normally afterward.

Do not launch an unzipped, mounted, DerivedData, or temporary copy for first-use
testing. macOS can retarget an existing login registration to another bundle with
the same identifier merely when it runs. Deleting that temporary bundle can leave
a broken login path. After runtime checks, verify the registered app path as well
as the enabled state. Preserve any existing registration choice.

Keep the real preferences, Keychain items, and Kokoro folders. Exercise the real
jobs in the release record: first use, audible preview, scheduling, pause/resume,
voice failures, settings persistence, and login behavior. A registration check
does not prove launch after a real login. Record unavailable devices or OS versions
as untested. Check the support and download links before publication.

## Interactive preview with isolated preferences

Use the verified installed candidate for a longer first-use preview:

```sh
preview_suite="com.timeannouncer.preview.$(uuidgen)"
TIMEANNOUNCER_DEFAULTS_SUITE="$preview_suite" /Applications/TimeAnnouncer.app/Contents/MacOS/TimeAnnouncer
```

Use System Voice for this probe. Quit the preview before cleaning up its suite:

```sh
defaults delete "$preview_suite"
```

This isolates preferences only. Keychain, audio output, Kokoro storage, and macOS
login registration remain shared. Do not change those through a preview unless
the task authorizes it. Launch only the installed path. Relaunch it normally when
finished. The preview starts paused; choose a manual preview to hear speech.

## Recover safely

The builder preserves `build/release` until a new build finishes. On success it
moves the prior complete release to `build/release-history/<UTC timestamp>-<pid>`.
A failed build leaves the previous release in place and prints its staging path.
Inspect that failure before retrying. Do not delete the last usable release.

A lock at `build/.release-build-lock` prevents concurrent builds. Remove it only
after checking that its owning build is no longer running. Do not run a second
build over an active one.

This preparation also preserves the original installed app at:

```text
build/release-audit-2026-10-02/original-installed/TimeAnnouncer.app
```

That snapshot is the former local 1.0 build 1, ad-hoc signed. It is a local recovery
copy, not the signed public release. Prefer a verified previous release from
`release-history` when one is available and appropriate.

To restore an app, quit the failed copy, move it aside for diagnosis, and copy the
chosen previous bundle into Applications. Verify that copy's signature and launch.
Keep current preferences during app rollback. The audit's `original-preferences.plist`
is available for confirmed accidental settings loss; export current settings before
restoring it. Do not export, delete, or overwrite the ElevenLabs Keychain item.

## Prepare the publication decision

Review and commit the candidate, preserving unrelated work. Then run:

```sh
./scripts/launch-audit.sh
DRY_RUN=1 ./scripts/publish-github-release.sh
```

The technical audit must report `Technical release checks: PASS`.
The dry run performs checks and prints the upload command. It does not create a
release. Present the candidate version, completed acceptance, remaining limits,
and recovery path for the publication decision.

The script derives the version, title, and release notes from the project.
It verifies the known origin, pins `github.com/initiator1/timeannouncer`, and rejects
a conflicting `GH_REPO`. Package checks remain mandatory even when
`SKIP_LAUNCH_AUDIT=1` omits account checks during a rehearsal.

## Publish only with authorization

After acceptance and authorization, tag the accepted commit and push that exact
tag to the verified origin. The script checks that the local and remote tag both
resolve to the candidate commit. It will not create or repair a tag automatically.

Create an authorized draft upload:

```sh
./scripts/publish-github-release.sh
```

Or create an authorized public release directly:

```sh
DRAFT_RELEASE=0 ./scripts/publish-github-release.sh
```

The script uploads only the DMG and its checksum. It refuses an existing release,
so publishing an existing draft requires a separate authorized GitHub action.
It never treats draft creation as public release. Verify the public download,
release notes, and downloaded artifact after publication. Update the release
record with the actual result.
