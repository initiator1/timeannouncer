# Privacy Policy

Last updated: October 2, 2026

Time Announcer is a macOS menu bar app that speaks the current time.
This policy describes the 1.0.2 candidate. See the
[release record](release-checklist.md) for its publication status.

## Local preferences and diagnostics

The app has no analytics or telemetry and no backend of its own.
It stores your announcement setting, interval, timing mode, volume, selected
voice, and launch-at-login preference in its own local UserDefaults.

The candidate includes `PrivacyInfo.xcprivacy`. It declares app-only UserDefaults
access with Apple reason `CA92.1`, no tracking, and no collected data types.
This manifest describes the app's declared behavior. It does not cover the
separate websites or speech services you choose to use.

**Copy Support Diagnostics** places the app version, macOS version, settings,
and voice setup indicators on your clipboard. It includes whether an ElevenLabs
key is saved, but excludes the key itself. The app does not send this report.
You choose whether to share it by email or in a public GitHub issue.

## Speech providers

- **System Voice:** The built-in macOS speech engine speaks the time locally.
- **Kokoro:** A local Python environment synthesizes time phrases and caches audio
  on your Mac. Setup downloads packages and model files from third-party hosts.
  Missing model files can require further downloads. Those download requests
  use your internet connection; local synthesis does not require a developer backend.
- **ElevenLabs:** When selected, this optional provider receives the phrase being
  spoken, such as "It's ten thirty", and your API key to generate audio.
  Requests use your own ElevenLabs account and may consume paid credits.
  That provider's terms and privacy policy apply to those requests.

Choose System Voice to stop new ElevenLabs speech requests. Pausing stops scheduled
announcements. A manual preview can still request speech from the selected provider.

## API keys

The ElevenLabs key is stored in macOS Keychain under service `com.timeannouncer.app`
and item `elevenlabs_api_key`. Speech requests transmit it to ElevenLabs.
Updating the app does not require replacing or exporting the key.

## Local files and removal

Kokoro uses these app folders:

- `~/Library/Application Support/TimeAnnouncer/Kokoro` for its Python environment and setup audio.
- `~/Library/Caches/TimeAnnouncer/Kokoro` for generated audio.

Its dependencies may also cache downloaded models under their own user cache
folders, such as `~/.cache/huggingface`. Do not delete a shared model cache without
checking whether another app uses it.

Quit Time Announcer before removing its local speech folders. Removing the app
bundle alone leaves preferences, Keychain data, and downloaded speech files intact.
Ask support for help if you want to remove those records as well.

## External links and support

**Check for Updates…** opens GitHub. **Buy Me a Coffee…** opens Ko-fi with the
`app=timeannouncer` tag, which identifies the referring app. Your browser makes
those website requests. The websites' privacy policies apply.

Email **support@initiatorworks.com** for help or privacy questions.
Support messages contain the information you choose to send.
Time Announcer is published by INITIATOR LLC.
