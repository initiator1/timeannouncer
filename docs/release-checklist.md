# Time Announcer release record

## Candidate and decision, 2026-10-02

Candidate: **1.0.2, build 3**. Branch: `codex/dependable-release-1.0.2`.
Status: **Hold public release. Local engineering preparation is complete;
interactive acceptance and external approvals remain open.**

The signed candidate is installed and running from `/Applications/TimeAnnouncer.app`.
Original preferences are unchanged. The source receipt identifies the package with
SHA-256 `b5e97502b0b3b416bdf5d1777cac7481add55bbddc673ce4529ba1a33892ec72`.
The final local commit is recorded in the audit folder's `candidate-git.txt`.

The latest public GitHub release remains 1.0.1, checked on 2026-10-02.
Version 1.0.0 shipped on 2026-05-26. This record must never describe that
historical release as an unshipped product. The 1.0.2 work has not been uploaded
or published. Its signed local package is not notarized.

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
| Install and start | DMG installs the stated version; first use is quiet and understandable | Signed universal DMG mounts; installed executable matches candidate; isolated fresh-default smoke passes |
| Hear a preview | Preview uses the chosen voice at the chosen app volume | First-use Preview action exercised; actual audible output is not independently verified |
| Run a schedule | Choose interval/mode, resume, hear a correctly timed announcement, then pause | Boundary policy tests pass; actual scheduled speaker output remains unverified |
| Control settings | Invalid input explains recovery; preferences survive restart | Code and persistence fixtures inspected; full menu interaction awaits supported automation |
| Recover from voice failure | Stalled, cancelled, or malformed voice output cannot hang future speech | Five real subprocess fixtures pass; physical fallback audio remains unverified |
| Return after login | Registration points to Applications; macOS approval state is truthful | macOS records enabled and allowed at `/Applications/TimeAnnouncer.app`; real logout/login remains untested |
| Update and get help | Correct installed version, useful diagnostics, working links, no key disclosure | Diagnostic fixtures pass; current public release and GitHub issues render; Ko-fi tip form renders |
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
- `build-release-final.log`: final local Release build, signing, DMG generation, and checksum result.
- `smoke-final-installed.log`: final package identity, resources, architecture, signature,
  and fresh defaults using the repaired installed-only runtime probe.
- `install-final.log`: actual installation from the final candidate DMG.
- `01-first-use.png`: first-use dialog inspection during this preparation.
- `02-reopened-menu.png`: installed candidate menu before the final API-key copy correction.
  The menu layout is unchanged.
- `original-preferences.plist`: recovery snapshot; original preference values remain unchanged.
- `restored-preferences.plist`, `restored-login-registration.txt`, and
  `final-runtime-readback.log`: final readback, installed identity, and helper comparison.
- `offline-kokoro-probe.json`: the installed helper generates a 1.725-second,
  non-silent 24 kHz mono WAV in 6.20 seconds with offline flags and the existing model.
  The helper is byte-identical in the final installed build. This does not prove
  speaker output or warm-worker latency.
- `restoration-rehearsal.log`: backup extraction and macOS security verification.

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
keyboard focus. Native semantics are present, but complete keyboard navigation,
VoiceOver, compact laptop placement, and high-contrast settings are unverified.
No accessibility compliance claim is made. There is no web layout to test.

Desktop inspection can read the welcome alert but returns `noWindowsAvailable`
or times out for the menu-only app. An app-scoped screenshot verifies the menu
visually. A separate accessibility automation method awaits explicit permission.
A full Finder screenshot was rejected by automatic approval review because it
could expose unrelated private content. All saved images are app-only captures.

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
but no new cache-eviction mechanism is added.

ElevenLabs uses HTTPS and the user's own key. Requests have bounded timeouts and
an ephemeral session. One in-flight app task is retained; newer requests cancel
older work. Cancellation cannot refund a request already received by the service.
No paid live request or billing change was made. Actual authentication, quota,
and provider/voice availability remain untested. The UI discloses possible credit use.

Timers run only while the app and Mac are awake. Policy tests cover clock-boundary
behavior. Actual sleep/wake, clock changes, output-device changes, and scheduled
speaker delivery remain untested. Console errors and copied diagnostics support
local troubleshooting. There is no remote monitoring or telemetry.

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

1. Finish actual menu, audio, scheduled delivery, persistence, and failure recovery
   acceptance on this candidate. Supported menu automation is unresolved.
2. Obtain authorization to send this concrete candidate to Apple for notarization.
   Automatic approval review rejected that external upload. Gatekeeper currently
   reports `Unnotarized Developer ID`; no security protection was bypassed.
3. After notarization and acceptance, obtain separate publication approval. No
   GitHub draft, public release, tag push, or outreach has occurred.

## Important follow-ups

- Execute the current candidate on Intel and macOS 13 before presenting those
  systems as tested. Keep the runtime coverage statement visible.
- Test fresh Kokoro setup in an isolated environment and pin the proven dependency
  set. Keep System Voice usable when setup fails.
- Verify paid ElevenLabs behavior only with account/purpose/spend authorization.
- Exercise real sleep/wake and login after normal use permits it.
- Check reopening while a modal alert is present. The ordinary reopen path is
  visually verified; an alert may need a separate guard if it overlaps the menu.
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
