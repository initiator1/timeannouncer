# Changelog

## Unreleased

- **Buy Me a Coffee…** menu item added. It opens
  https://ko-fi.com/initiatorworks?app=timeannouncer. The app stays free and
  MIT-licensed.

## 1.0.1 — 2026-07-26

Fixes a real problem in 1.0.0: the Kokoro voice could not be set up by anyone
who installed from the disk image.

- **Kokoro setup works from the installed app.** The setup dialog previously
  pointed at a script that was not included in the download, so two of the three
  listed voices were unusable. The script now ships inside the app, and the
  dialog has a **Copy Command** button.
- **The setup dialog states the cost up front** — Homebrew, about 2 GB, a few
  minutes — instead of failing partway through.
- **Universal build.** 1.0.0 was Apple-silicon only while listing macOS 13 as the
  requirement, so Intel Macs could download an app that would not run.
- **New app icon**, redesigned after 1.0.0 was built and never included in it.
- **Check for Updates…** added. 1.0.0 had no way to learn a newer version existed.
- **Version numbers report correctly.** 1.0.0 hardcoded its version, so later
  builds would still have identified themselves as 1.0.
- **Published support email** (support@initiatorworks.com). Support previously
  routed only through GitHub issues, which requires an account.
- Signed as INITIATOR LLC rather than an individual.

## 1.0.0 — 2026-05-26

First public release.

- Menu bar app that announces the time aloud at a chosen interval.
- Clock-aligned mode announces on `:00`, `:15`, `:30`, `:45`.
- Three voices: macOS system voice, local Kokoro 82M, and ElevenLabs.
- Starts paused on first launch.
- Signed, notarized and stapled.
