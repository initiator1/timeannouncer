# TimeAnnouncer

TimeAnnouncer is a macOS menu bar app that speaks the current time at a chosen interval. It is designed for lightweight time awareness without opening a window.

## First Run

New installs start paused and use the built-in macOS system voice. Open the menu bar clock, choose **Preview Voice** to test audio, then choose **Resume Announcements** when you are ready.

## Voice Options

- **System Voice**: built into macOS and works without setup.
- **Kokoro 82M**: local higher-quality voice. Run `./scripts/setup-kokoro.sh` before selecting it.
- **ElevenLabs**: cloud voice that requires an ElevenLabs API key.

## Development

Build:

```sh
xcodebuild -project TimeAnnouncer.xcodeproj -scheme TimeAnnouncer -configuration Debug build
```

Test:

```sh
xcodebuild test -project TimeAnnouncer.xcodeproj -scheme TimeAnnouncer -destination 'platform=macOS,arch=arm64'
```

## Release Build

Direct-download release builds use Developer ID signing and hardened runtime:

```sh
./scripts/build-release.sh
```

This creates `build/release/TimeAnnouncer.dmg` for public distribution, `build/release/TimeAnnouncer.zip` for app notarization, and SHA-256 checksum files for both artifacts.

Smoke-check the signed DMG, zip, and app:

```sh
./scripts/smoke-release.sh
```

Audit the launch gates before publishing:

```sh
./scripts/launch-audit.sh
```

See [docs/release-checklist.md](docs/release-checklist.md) for notarization and launch gates.
See [docs/publishing.md](docs/publishing.md) for the GitHub release publishing path.

## Public Materials

- [Privacy Policy](docs/privacy.md)
- [Support](docs/support.md)
- [Publishing](docs/publishing.md)
- [Draft 1.0 Release Notes](docs/release-notes/v1.0-draft.md)
