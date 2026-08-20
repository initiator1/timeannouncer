# Time Announcer

**Hear the time without looking at a screen.**

A small macOS menu bar app that says the time out loud on a schedule you choose.
No window, no dock icon, no account, no analytics.

[**Download for macOS →**](https://github.com/initiator1/timeannouncer/releases/latest)

macOS 13 or later · Apple silicon and Intel · Signed and notarized · Free

![Time Announcer opening its menu bar dropdown and speaking the time: "It's ten thirty"](docs/media/timeannouncer-demo.gif)

---

## Why

Time disappears when you are concentrating. A quiet voice every 15 minutes gives
back a sense of the hour without pulling your eyes to a clock — which is the
whole problem with checking the time on the screen you were trying to ignore.

It is also useful when reading a clock is difficult, or when your hands are busy.

## What it does

- **Announces the time** at whatever interval you choose.
- **Clock-aligned mode** speaks on natural boundaries — `:00`, `:15`, `:30`,
  `:45` — so announcements match how you already think about time.
- **Three voices**: the built-in macOS voice, a higher-quality voice that runs
  entirely on your Mac ([Kokoro 82M](https://huggingface.co/hexgrad/Kokoro-82M)),
  or ElevenLabs if you already have an account.
- **Stays out of the way.** It lives in the menu bar and starts paused, so it
  never surprises you on first launch.

## How it compares to macOS

macOS can already announce the time — System Settings → Control Center → Clock
Options. That version is limited to the hour, half hour or quarter hour, and uses
the system voice.

Time Announcer covers what that does not: **any interval you want**, better
voices, a preview button, and a menu you can reach without opening System
Settings.

If the built-in already works for you, use it. It is free and installed.

## Install

1. [Download the latest release](https://github.com/initiator1/timeannouncer/releases/latest).
2. Open the disk image, drag Time Announcer to Applications.
3. Launch it. It appears in the menu bar, paused.
4. Open the menu → **Preview Voice**, then **Resume Announcements**.

Signed and notarized by INITIATOR LLC, so macOS opens it without security
warnings.

## Privacy

No analytics, no telemetry, no servers. Preferences stay on your Mac.

One exception, entirely your choice: the optional ElevenLabs voice sends the
phrase being spoken to ElevenLabs using your own API key. The other two voices
never leave your machine. Full policy: [docs/privacy.md](docs/privacy.md).

## Support

Email **support@initiatorworks.com**, or
[open an issue](https://github.com/initiator1/timeannouncer/issues).

Email needs no account — use it if you would rather not post publicly, or if you
use a screen reader.

Reporting a problem? Open the menu and choose **Copy Support Diagnostics**. It
copies your app version, macOS version and settings, and never includes your
ElevenLabs API key.

## Like the app?

Time Announcer is free and MIT-licensed, and it stays that way. If it saves you
looking at a clock, you can [buy me a coffee](https://ko-fi.com/initiatorworks?app=timeannouncer).
The same link is in the app menu.

---

## Building from source

```sh
xcodebuild -project TimeAnnouncer.xcodeproj -scheme TimeAnnouncer -configuration Debug build
```

Run the tests:

```sh
xcodebuild test -project TimeAnnouncer.xcodeproj -scheme TimeAnnouncer -destination 'platform=macOS,arch=arm64'
```

Release builds are signed, notarized and checksummed by `./scripts/build-release.sh`,
smoke-checked by `./scripts/smoke-release.sh`, and gated by `./scripts/launch-audit.sh`.
See [docs/publishing.md](docs/publishing.md) and
[docs/release-checklist.md](docs/release-checklist.md).

## License

MIT — see [LICENSE](LICENSE).

Made by [INITIATOR LLC](https://initiatorworks.com).
