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
