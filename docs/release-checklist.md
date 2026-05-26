# Release Checklist

This checklist tracks the direct-download macOS launch path for TimeAnnouncer.

## Build Gate

Run:

```sh
./scripts/build-release.sh
```

The script must prove:

- Developer ID Application signing succeeds.
- Hardened runtime is enabled.
- `get-task-allow` is absent from the release signature.
- `KokoroSynth.py` is present in the app bundle.
- The compiled asset catalog is present in the app bundle.
- `codesign --verify --deep --strict` succeeds.
- `build/release/TimeAnnouncer.zip` is produced for notarization.
- `build/release/TimeAnnouncer.dmg` is produced for public distribution.
- The DMG contains `TimeAnnouncer.app` and an `Applications` shortcut.

## Smoke Gate

Run after a release build:

```sh
./scripts/smoke-release.sh
```

For a short first-run smoke using an isolated preferences suite:

```sh
RUN_APP=1 ./scripts/smoke-release.sh
```

The smoke script must prove:

- The zip expands into `TimeAnnouncer.app`.
- The DMG verifies, mounts, and contains the expected install layout.
- The built app, unzipped app, and DMG app have valid signatures.
- The app bundle has the expected bundle identifier, version, menu-bar-only setting, Kokoro helper, and asset catalog.
- Hardened runtime is enabled and `get-task-allow` is absent.
- With `RUN_APP=1`, a fresh first run starts paused on System Voice at a 60-minute interval without touching the real user preferences.

## Notarization Gate

Configure a notarytool keychain profile once:

```sh
xcrun notarytool store-credentials timeannouncer-notary
```

Then run:

```sh
NOTARYTOOL_PROFILE=timeannouncer-notary ./scripts/build-release.sh
```

The script must prove:

- Apple notarization succeeds.
- The notarization ticket is stapled to `TimeAnnouncer.app`.
- The installer DMG is notarized and stapled.
- `xcrun stapler validate` succeeds.
- Gatekeeper accepts the app with `spctl --assess --type execute`.

## Launch Gate

Before public distribution:

- Install the stapled app from the release artifact, not from DerivedData.
- Use `build/release/TimeAnnouncer.dmg` as the public download artifact.
- Verify a fresh profile starts paused on System Voice.
- Verify an existing profile with Kokoro preferences keeps Kokoro selected.
- Verify `Preview Voice`, `Announce Time Now`, pause/resume, interval changes, volume changes, and launch-at-login behavior.
- Replace any stale `/Applications/TimeAnnouncer.app` proof with the current signed/stapled artifact.

## Remaining Product Gates

- Notarytool credential profile.
- Stapled release artifact.
- Public download page or GitHub release.
- Public support/contact path replacing the placeholder in `docs/support.md`.
