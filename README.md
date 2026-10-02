# Time Announcer

**Hear the time without looking at a screen.**

A free macOS menu bar app for people who lose track of time while concentrating,
reading, or working with their hands. Choose a schedule, preview the voice, and
resume announcements. No app account is required.

[**Download for macOS**](https://github.com/initiator1/timeannouncer/releases/latest)

Target: macOS 13 or later, Apple silicon and Intel. The release package contains
both architectures. See the [release record](docs/release-checklist.md) for tested
systems, candidate status, and known limits. Version 1.0.2 is a release candidate
until that record confirms publication.

![Time Announcer menu and spoken time demo](docs/media/timeannouncer-demo.gif)

*Demo from an earlier release. Some menu details have changed.*

## What it does

- **Clock-aligned announcements.** Choose an interval that divides an hour evenly.
  Every 15 minutes speaks at `:00`, `:15`, `:30`, and `:45`.
- **Fixed intervals.** Choose a positive whole number of minutes, including values
  such as seven minutes. Resuming this mode announces immediately.
- **Voice and volume controls.** Use the built-in System Voice without setup.
  Kokoro is an optional local voice. ElevenLabs uses your own account and API key.
- **Manual speech.** Preview the selected voice or announce the current time while paused.
- **Menu bar access.** Pause, resume, change settings, or enable launch at login from one menu.

Announcements run while the app and Mac are awake. Time Announcer does not wake
or turn on the Mac. It speaks English time phrases.

## Install and start

1. [Download the latest published release](https://github.com/initiator1/timeannouncer/releases/latest).
2. Open the disk image and drag Time Announcer to Applications.
3. Launch it and find the clock in the menu bar.
4. Choose **Preview Voice** and set a comfortable **Volume**.
5. Choose an **Interval**, then **Resume Announcements**.

Open Time Announcer again from Applications or Spotlight to show its controls.

A fresh installation starts paused on System Voice, with an hourly clock-aligned
schedule and 25% app volume. Updates preserve existing preferences, including a
previous 10% volume setting. Your Mac's output volume also affects what you hear.

Public release packages use Developer ID signing and Apple notarization. Check
the release record for each candidate's result. macOS may still show a first-open
confirmation or enforce local security policy.

## Optional voices

**Kokoro:** Choose **Voice > Install Kokoro...** and copy the setup command.
Setup uses Terminal, needs an internet connection, and downloads dependencies and
model files. The dialog estimates about 2 GB. Homebrew supplies `espeak-ng`.
After setup, select Kokoro and preview it. Speech is synthesized on your Mac.

**ElevenLabs:** Choose **Voice > Set ElevenLabs API Key...**, then select ElevenLabs.
Time phrases go to ElevenLabs and may use your account's paid credits. System
Voice works without that account or an internet connection.

## Privacy

Time Announcer has no app analytics or telemetry and no backend of its own.
Preferences stay on your Mac. Optional ElevenLabs requests send spoken phrases
to that provider. Kokoro setup downloads files from third parties. Details are
in the [privacy policy](docs/privacy.md).

## Updates, support, and feedback

**Check for Updates…** opens the GitHub releases page. Download the new disk image,
quit the running app, and replace the app in Applications. Updates are manual.

Email **support@initiatorworks.com** or
[open an issue](https://github.com/initiator1/timeannouncer/issues).
Describe what you tried, what you expected, and what happened.
**Copy Support Diagnostics** supplies the app version and relevant settings.
Review the text before sharing it. The diagnostics exclude your API key.
See [troubleshooting](docs/support.md) for recovery steps.

## Support development

The app is free and MIT-licensed. There is no purchase or subscription to unlock it.
[Buy me a coffee](https://ko-fi.com/initiatorworks?app=timeannouncer) is an optional
tip. The same link appears in the app menu.

## Build and maintain

Install Xcode and select its developer tools. The Swift app has no external
package dependencies. Kokoro setup is optional and is not needed for a System
Voice build. The test target requires macOS 14 or later.

```sh
xcodebuild -project TimeAnnouncer.xcodeproj -scheme TimeAnnouncer -configuration Debug build
xcodebuild test -project TimeAnnouncer.xcodeproj -scheme TimeAnnouncer -destination 'platform=macOS,arch=arm64'
```

The test command targets an Apple silicon Mac. Use an available Intel destination
when testing on Intel. A universal build does not establish runtime compatibility
on either architecture or on macOS 13.

[AGENTS.md](AGENTS.md) maps the code and maintenance checks.
[Publishing](docs/publishing.md) covers isolated previews, packaging, signing,
installation, rollback, and the approval boundary for external publication.

## License

MIT. See [LICENSE](LICENSE).

Made by [INITIATOR LLC](https://initiatorworks.com).
