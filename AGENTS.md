# AGENTS.md

Repository guidance for maintaining Time Announcer. Read the applicable global
instructions first. Preserve other agents' and the user's work.

## Product and release scope

Time Announcer is a free macOS menu bar app for people who want spoken time cues
without checking a screen. Its core job is to preview a voice, choose a schedule,
resume announcements, and pause them when needed.

System Voice needs no account or setup. Kokoro is an optional local voice with
separate dependency/model downloads. ElevenLabs is an optional cloud provider
using the user's own key and credits. Do not run live paid speech probes without
authorization for that account, purpose, and spending.

The current candidate is 1.0.2, build 3. It targets macOS 13 or later and packages
Apple silicon and Intel binaries. Runtime proof for each platform is separate.
Use `docs/release-checklist.md` for the current acceptance and publication state.
Do not infer readiness from a build, screenshot, or archive receipt.

## Build and test

The Swift app has no external package manager. Use Xcode and its selected tools.
The test target requires macOS 14 or later.

```sh
xcodebuild -project TimeAnnouncer.xcodeproj -scheme TimeAnnouncer -configuration Debug build
xcodebuild test -project TimeAnnouncer.xcodeproj -scheme TimeAnnouncer -destination 'platform=macOS,arch=arm64'
```

Use an available destination when testing on Intel. Existing tests live in
`TimeAnnouncerTests`. Name the failure risk and missing coverage before adding a
test. Choose narrow tests for a change. Keep persistence, cancellation, concurrency,
privacy, and permission coverage. Do not rerun the full suite only for a handoff.

Release-script fixture checks:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s scripts -p 'test_release_metadata.py'
./scripts/check-signing-defaults.sh
./scripts/check-privacyinfo-release.sh --selftest
./scripts/publish-github-release.sh --selftest
```

## Code ownership

| File | Responsibility |
|------|----------------|
| `TimeAnnouncer/TimeAnnouncerApp.swift` | App entry, AppDelegate, menu, onboarding, login registration |
| `TimeAnnouncer/TimeAnnouncer.swift` | Timer lifecycle, phrase formatting, speech tasks, fallback and status |
| `TimeAnnouncer/TimeAnnouncementSchedule.swift` | Clock-aligned interval and boundary rules |
| `TimeAnnouncer/SettingsManager.swift` | Preferences, first-use defaults, preservation of existing settings |
| `TimeAnnouncer/SupportDiagnostics.swift` | Support text without secret values |
| `TimeAnnouncer/KeychainHelper.swift` | API key storage through Security framework |
| `TimeAnnouncer/ElevenLabsClient.swift` | Optional HTTP speech request |
| `TimeAnnouncer/KokoroClient.swift` | Local worker lifecycle, deadlines, cache and audio result |
| `TimeAnnouncer/KokoroSynth.py` | Python synthesis and worker protocol |
| `scripts/setup-kokoro.sh` | Optional local dependency setup, also bundled in the app |
| `scripts/release-metadata.py` | Candidate version/build and source identity checks |

`AppDelegate` owns `SettingsManager` and `TimeAnnouncer`. Menu actions update
preferences and tell `TimeAnnouncer` to apply them. Keep scheduling policy in
`TimeAnnouncementSchedule`, speech lifecycle in `TimeAnnouncer`, and worker process
management in `KokoroClient`.

## Behavior contracts

- Fresh profiles start paused on System Voice, at 60 minutes, clock-aligned,
  25% app volume, and launch at login off. `applyFirstLaunchDefaultsIfNeeded()`
  applies this only when no user preferences exist.
- Updates preserve existing preferences. Legacy getters keep their older fallbacks,
  including 10% volume and Kokoro for a previously configured profile without a voice value.
- Clock-aligned intervals must divide 60 evenly. Fixed Interval accepts positive
  whole minutes and announces immediately when started.
- The two-second gap and wall-clock boundary check prevent early or duplicate
  automatic announcements. Manual speech still works while paused.
- Optional voice failures fall back to System Voice and expose the result in the
  menu. A saved key or installed executable is only a setup indicator.
- `LSUIElement` and accessory activation keep the app in the menu bar.
  Login state comes from `SMAppService`; approval and actual future login are separate checks.
- Menu volume presets are 10%, 25%, 50%, 75%, and 100%. Volume applies at speech time.
- Keychain service is `com.timeannouncer.app`; item is `elevenlabs_api_key`.
  Never print or export its value for diagnosis.
- Kokoro uses `af_heart`, the venv under `~/Library/Application Support/TimeAnnouncer/Kokoro`,
  and WAV cache under `~/Library/Caches/TimeAnnouncer/Kokoro`. Downloads can also use shared dependency caches.
- Provider identifiers are implementation choices in `ElevenLabsClient.swift`.
  Verify provider documentation before changing them. A key's presence does not authorize a paid probe.
- Hours are spoken as words. Single-digit minutes use "oh". AM/PM is spoken on the hour.
- The tip URL is `https://ko-fi.com/initiatorworks?app=timeannouncer` in the app,
  README, and funding file. Verify its rendered destination before changing it.

## Maintenance and release

`docs/publishing.md` owns setup, isolated preview, packaging, installation,
publication, and rollback steps. `docs/support.md` owns user recovery instructions.
`docs/privacy.md` describes local storage and optional external traffic.

Use `TIMEANNOUNCER_DEFAULTS_SUITE` for an isolated preference preview of the verified
installed `/Applications/TimeAnnouncer.app`. Never launch a temporary or DerivedData
copy for first-use checks. macOS can retarget the existing login registration to
that copy's path even without a registration action. Preference isolation does not
isolate Keychain, audio output, Kokoro storage, or login registration. Quit the preview
before deleting its suite, then relaunch the installed app normally. Never clear real
data to manufacture first use. `RUN_APP=1` requires an exactly matching installed
candidate; default package smoke does not launch an app.

Release builds retain the previous complete candidate in `build/release-history`.
The 2026-10-02 audit also preserves the former installed app and preferences under
`build/release-audit-2026-10-02`. Verify installed version and running path after
replacement. Merely opening a new bundle may activate an older running instance.

Routine local engineering and recoverable installation belong to the agent.
Honor existing authorization and review holds. Ask the human owner only for missing
product, spending, privacy, account, or external publication decisions.
A draft GitHub release is an external upload. Do not publish, message people,
charge money, or change accounts without applicable authorization.

Update only affected documentation. Record unresolved release obligations in
`OPEN-ITEMS.md` and candidate evidence in `docs/release-checklist.md`.
