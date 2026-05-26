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
- `codesign --verify --deep --strict` succeeds.
- `build/release/TimeAnnouncer.zip` is produced for notarization.

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
- `xcrun stapler validate` succeeds.
- Gatekeeper accepts the app with `spctl --assess --type execute`.

## Launch Gate

Before public distribution:

- Install the stapled app from the release artifact, not from DerivedData.
- Verify a fresh profile starts paused on System Voice.
- Verify an existing profile with Kokoro preferences keeps Kokoro selected.
- Verify `Preview Voice`, `Announce Time Now`, pause/resume, interval changes, volume changes, and launch-at-login behavior.
- Replace any stale `/Applications/TimeAnnouncer.app` proof with the current signed/stapled artifact.

## Remaining Product Gates

- App icon.
- Public download page or GitHub release.
- Short privacy policy covering local speech, optional Kokoro, and optional ElevenLabs cloud speech.
- Public support/contact path.
