# Time Announcer release record

## Candidate and decision, 2026-10-02

Candidate: **1.0.2, build 3**. Branch: `codex/dependable-release-1.0.2`.
Status: **Hold public release. Notarization and installed-app checks pass;
speaker confirmation, GitHub sign-in, and publication approval remain open.**

The signed, notarized candidate runs from `/Applications/TimeAnnouncer.app`.
Original preferences are unchanged. The source receipt identifies the package with
SHA-256 `b5e97502b0b3b416bdf5d1777cac7481add55bbddc673ce4529ba1a33892ec72`.
The final local commit is recorded in the audit folder's `candidate-git.txt`.

The latest public GitHub release remains 1.0.1, checked on 2026-10-02.
Version 1.0.0 shipped on 2026-05-26. This record must never describe that
historical release as an unshipped product. Version 1.0.2 has no GitHub upload
or publication. After BOSS approved Apple submission, Apple accepted both the
app and DMG. Their stapled tickets validate, and Gatekeeper accepts the app.

Apple submission receipts:

- App: `29cb85d9-ce12-4938-b716-9e1dcf832b92`, Accepted.
- DMG: `91b0baed-7421-40a9-b588-7d5e7caf2a0a`, Accepted.
- Final DMG SHA-256: `cc2e119d11aee12d2169688a81a158fa7dd52f915238e0cc66b079b3a734459d`.

## Audience, promise, and fixed scope

The first audience is Mac users who lose track of time during focused work,
reading, or hands-busy activities. The promise is: **Hear the time without
looking at a screen.** This is a free utility, with optional tips. It is not an
alarm, a reminder service, or a health intervention.

Target: macOS 13 or later, Apple silicon and Intel. The package includes both
architectures. Runtime evidence in this record comes from Apple silicon on
macOS 27.0.1, with Xcode 27.0 (27A266a). Intel and macOS 13 execution are untested.
The test target requires macOS 14 or later.

Included in this update:

- Install from a signed DMG into Applications and open a menu bar app.
- Start paused with System Voice, hourly clock alignment, and 25% app volume.
- Preview speech, announce the current time, choose a valid interval and timing
  mode, change volume, pause, resume, quit, and keep settings after restart.
- Reopen the existing menu from Applications or Spotlight.
- Use installed Kokoro locally or optional ElevenLabs with the user's own key.
- Bound failed voice requests, fall back to System Voice, cancel obsolete speech,
  and show preparation or failure state in the menu.
- Reflect actual macOS login registration and expose approval/error recovery.
- Copy diagnostics without keys and open the existing update and support links.
- Preserve existing preferences, Keychain data, local voice files, and a previous app.

Excluded: new platforms, automatic updates, new voices, accounts, subscriptions,
a backend, analytics, new domains, notification infrastructure, and visual redesign.

## What a real user must finish

| Job | Completion condition | Current evidence |
|---|---|---|
| Install and start | DMG installs the stated version; first use is quiet and understandable | Notarized universal DMG installs; installed executable matches; strict smoke and fresh paused defaults pass |
| Hear a preview | Preview uses the chosen voice at the chosen app volume | Actual System Voice and Kokoro previews reach playback state; speaker output needs BOSS's confirmation |
| Run a schedule | Choose interval/mode, resume, hear a correctly timed announcement, then pause | Fixed interval reaches playback 60.185 seconds after resume; clock-aligned playback starts 0.437 seconds after the boundary; pause passes; speaker confirmation remains open |
| Control settings | Invalid input explains recovery; preferences survive restart | Actual menu rejects invalid input, accepts valid settings, and preserves all test preferences after menu Quit and restart |
| Recover from voice failure | Stalled, cancelled, or malformed voice output cannot hang future speech | Five subprocess fixtures pass; invalid cached WAV triggers System Voice fallback; restored valid cache allows Kokoro retry; fallback speaker output remains unverified |
| Return after login | Registration points to Applications; macOS approval state is truthful | macOS records enabled and allowed at `/Applications/TimeAnnouncer.app`; real logout/login remains untested |
| Update and get help | Correct installed version, useful diagnostics, working links, no key disclosure | Actual copied diagnostics show 1.0.2 (3), correct settings and login state, with no key; update dialog shows 1.0.2; releases, issues, and Ko-fi render |
| Roll back | A previous app can replace this app without deleting user data | Prior 1.0.1 ZIP extracted, checksum and signature verified, notarization ticket valid, Gatekeeper accepted; live replacement not rehearsed |

No build, screenshot, unit test, or registration flag alone completes the
scheduled-audio or login jobs. Keep these limits in the release decision.

## Verified repairs and evidence

- Kokoro startup and response reads have deadlines and cancellation checks.
  Failed exchanges reset their process. Quit prevents a worker restart.
- Large fixed intervals no longer overflow during conversion to seconds.
- Invalid playback preserves the requested phrase for System Voice fallback.
- Voice changes cancel pending speech. Status updates run on the main actor.
- Custom interval and empty-key errors have visible recovery copy.
- Login status comes from macOS rather than a saved Boolean.
- Optional voice setup is not labeled as verified service readiness.
- Release checks derive version/build, reject stale app copies and changed
  source, and verify resources, signatures, both architectures, and checksums.
- Builds preserve the previous complete package. Publication pins the correct
  repository and verifies both local and remote tag commits.
- Live smoke now launches only the verified installed candidate. The earlier
  temporary-bundle probe redirected login registration to a deleted folder.
  The path is repaired and rechecked after normal launch, with settings unchanged.

Evidence is stored locally in `build/release-audit-2026-10-02/`:

- `xcode-tests.log`: 13 existing and new tests pass before the last worker-shutdown fixture.
- `focused-tests.log`: seven focused tests pass after shutdown and diagnostic updates.
  Together these cover 14 distinct tests. No tests were deleted.
- `notarized-build.log` and `notarization-receipt.json`: final Release build,
  signing, Apple acceptance, stapling, and DMG checksum.
- `smoke-notarized-installed.log`: strict notarized package identity, resources,
  architectures, signatures, tickets, Gatekeeper, and installed-only runtime checks.
- `install-notarized.log`: actual installation from the notarized candidate DMG.
- `ui-acceptance.jsonl`: actual menu, dialog, preview, scheduling, failure,
  diagnostics, modal reopening, and restart outcomes using isolated preferences.
  Early probe errors come from the test harness. The final checks pass.
- `installed-support-diagnostics.txt`: actual copied diagnostics with no key contents.
- `01-first-use.png`: first-use dialog inspection during this preparation.
- `02-reopened-menu.png`: installed candidate menu before the final API-key copy correction.
  The menu layout is unchanged.
- `03-api-key-dialog.png`: final installed app's API-key dialog; its app-only
  capture shows readable disclosure, named field, and initial focus without clipping.
- `original-preferences.plist`: recovery snapshot; original preference values remain unchanged.
- `restored-preferences.plist`, `restored-login-registration.txt`, and
  `notarized-runtime-readback.log`: final readback and notarized installed identity.
  Original preference values match. The normal app and its local worker run again.
- `offline-kokoro-probe.json`: the installed helper generates a 1.725-second,
  non-silent 24 kHz mono WAV in 6.20 seconds with offline flags and the existing model.
  The helper is byte-identical in the final installed build. This does not prove
  speaker output or warm-worker latency.
- `restoration-rehearsal.log`: backup extraction and macOS security verification.
- `launch-audit-final.log`: earlier audit, before approved notarization, fails
  authentication and notarization. Use the current audit recorded below for status.
- `launch-audit-notarized.log`: current technical audit. Package notarization
  passes; GitHub sign-in remains pending.

The [candidate menu capture](media/timeannouncer-v1.0.2-candidate-menu.png) is
available for review and later release material. It shows isolated test settings.

The unit tests use isolated defaults and local shell workers. They do not call
ElevenLabs, record the microphone, or download a model. Before adding them, the
identified coverage gaps were indefinite worker hangs, cancellation poisoning a
future request, shutdown leakage, and packages mislabeled with a new version.

## UX and accessibility observations

The welcome dialog explains the paused state and has named Preview Voice and
Not Now buttons. Its app-only capture has readable text with no clipping.
The native menu is compact and exposes pause, manual speech, four setting
submenus, login, diagnostics, updates, support, and quit. The captured menu fits
the tested display without scrolling.

The custom interval and API-key fields now have accessibility labels and initial
keyboard focus. Actual checks verify those labels, focus, Return submission,
Escape cancellation, and useful recovery for invalid intervals or empty keys.
Reopening the app with an interval dialog keeps one usable dialog.
Native semantics are present, but complete keyboard navigation,
VoiceOver, compact laptop placement, and high-contrast settings are unverified.
No accessibility compliance claim is made. There is no web layout to test.

The desktop tool cannot reliably target the menu-only app. After BOSS approved
app-specific macOS accessibility scripts, that method verifies actual menu actions
and dialogs. App-only screenshots verify layout. All saved images exclude unrelated
Finder content.

## Operational review

There is no application backend, database, server migration, account system, or
remote job queue. Server authorization, tenant isolation, database backups, and
server abuse controls do not apply to this release. No infrastructure was added.

Preferences live in UserDefaults. The existing first-run migration preserves
configured installations. ElevenLabs keys remain in Keychain; replacement uses
an update before insertion and does not delete an existing key on failure.
Diagnostics contain setup state, not the key. No key was exported or changed.

System Voice uses the local OS engine. Kokoro runs a local Python worker and
writes temporary audio before moving successful output into cache. Its setup
downloads dependencies and models; the dependency range remains unpinned.
The installed helper produces audio with model downloads disabled by its offline
flags. Fresh optional-voice setup and network-level isolation remain untested.
Cache growth is limited by the small vocabulary of time phrases and voice choice,
but no new cache-eviction mechanism is added. Invalid cached audio triggers System
Voice fallback. The app does not discard that corrupt cache entry automatically.
The acceptance probe restores the original cache file before the healthy retry;
it does not prove automatic cache repair. All user cache data is restored.

ElevenLabs uses HTTPS and the user's own key. Requests have bounded timeouts and
an ephemeral session. One in-flight app task is retained; newer requests cancel
older work. Cancellation cannot refund a request already received by the service.
No paid live request or billing change was made. Actual authentication, quota,
and provider/voice availability remain untested. The actual dialog discloses key
and phrase transmission, Keychain storage, and possible paid credit use.

Timers run only while the app and Mac are awake. Actual fixed and clock-aligned
schedule checks reach playback at the expected times. Sleep/wake, clock changes,
output-device changes, and physical speaker delivery remain unverified.
Console errors and copied diagnostics support local troubleshooting.
There is no remote monitoring or telemetry.

INITIATOR LLC owns distribution and support. The human owner approves publication,
Apple submission, spending, and account changes. The engineering agent owns builds,
reversible installation, verification, and maintaining this release record.

## DX and coding-agent acceptance

A fresh reviewer located the behavior owners and found two real publication
defects without a code handoff. Root reproduced the documented Xcode workflow,
diagnosed a main-actor compile error from the build log, repaired the owning
AppDelegate, and ran the affected tests. Separate review cleared the repaired
runtime, login, and publication paths.

README and [publishing](publishing.md) now identify prerequisites, test commands,
code owners, isolated preferences, signed packaging, actionable failures, external
authorization, and recovery. Release fixture checks run without model or provider
access. A maintainer must use the installed app for live smoke because a temporary
same-bundle copy can redirect macOS login registration.

## Distribution and learning from users

Keep the current product name and existing GitHub download path. The README is
the landing page. It gives a clear five-step trial, supported capabilities,
limits, troubleshooting, and a marked earlier-release demo. Current app-only
screenshots are available as candidate evidence.

First distribution: the existing GitHub release and INITIATOR LLC product links,
after approval. No outreach or new account is needed to prepare this update.
Feedback uses GitHub issues or support email with optional diagnostics. Ask users
what they tried, what they expected, and what happened. This is a feedback path,
not evidence of demand or a verified support-response time. Email delivery was
not probed by sending a message.

The product has no paid entitlement or cancellation flow. Ko-fi is optional and
unlocks no functionality. Its form rendered during this audit, but no payment
or subscription action was taken.

## Release blockers

1. Obtain BOSS's confirmation of clear preview and scheduled speech from the Mac.
   Actual menu, playback timing, persistence, and fallback checks pass. A pending
   question asks for speaker confirmation; elapsed time does not provide evidence.
2. Complete the approved GitHub sign-in for `initiator1`, then verify the account
   and repository access. The earlier saved credential is invalid. BOSS approves
   opening the sign-in flow; it currently waits for his interactive completion.
3. After acceptance, obtain separate publication approval. No GitHub draft, public
   release, tag push, or outreach has occurred. Apple notarization is complete.

## Important follow-ups

- Execute the current candidate on Intel and macOS 13 before presenting those
  systems as tested. Keep the runtime coverage statement visible.
- Test fresh Kokoro setup in an isolated environment and pin the proven dependency
  set. Keep System Voice usable when setup fails.
- Verify paid ElevenLabs behavior only with account/purpose/spend authorization.
- Exercise real sleep/wake and login after normal use permits it.
- Discard a corrupt Kokoro cache entry after playback decode failure so a later
  request can synthesize it again. Current fallback protects speech, but does not
  repair the cached entry. Owner: engineering agent; complete with a recovery check.
- Confirm support email receipt when authorized; the GitHub issue path is live.

## Optional polish

Refresh the older demo with the accepted candidate, shorten repeated menu status
copy if needed, and consider automatic updates only in a later scoped release.
A name change, new domain, analytics, or new dashboard does not block this release.
The host emits a deprecation warning for `hdiutil attach`, but mounting still passes.
Review its replacement when updating packaging tools, preserving older macOS support.

## Recovery

The original installed bundle is at
`build/release-audit-2026-10-02/original-installed/TimeAnnouncer.app`.
The formerly running Debug bundle is at
`build/release-audit-2026-10-02/original-running/TimeAnnouncer.app`.
The prior signed 1.0.1 package is preserved under
`build/release-history/20261002T101827Z-64335/`.
Its ZIP checksum passes. Extraction preserves its executable. macOS verifies its
signature and notarization ticket, and Gatekeeper accepts the extracted app.
The rehearsal does not replace or launch that old version on the live installation.

Quit the candidate before restoring a previous bundle to Applications. Keep
UserDefaults, Keychain, Kokoro environment, and caches. Verify the restored app's
version, signature, running path, and macOS login registration. The preference
snapshot is for confirmed accidental data loss, not routine rollback.
See [publishing](publishing.md) for the maintained procedure.
