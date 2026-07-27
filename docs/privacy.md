# Privacy Policy

Last updated: July 26, 2026

TimeAnnouncer is a macOS menu bar app that announces the current time aloud.

## Data Collection

Time Announcer has no analytics, no telemetry, and no servers of its own. Nothing about you is collected, sold, or shared with anyone by this app or its developer.

The app stores preferences locally on your Mac, including whether announcements are enabled, the selected interval, timing mode, volume, voice provider, and launch-at-login preference.

The one exception is entirely your choice: if you enable the optional ElevenLabs voice, the phrase being spoken is sent to ElevenLabs using your own API key. See Speech Providers below. The two other voices never leave your Mac.

## Speech Providers

TimeAnnouncer supports three speech providers:

- **System Voice**: uses the speech engine built into macOS. Spoken text stays on your Mac.
- **Kokoro 82M**: uses a local Python-based speech environment installed under your user account. Spoken time phrases are synthesized locally and cached as audio files on your Mac.
- **ElevenLabs**: optional cloud speech. If you choose ElevenLabs and save an API key, TimeAnnouncer sends the phrase being spoken, such as "It's ten thirty", to ElevenLabs to generate audio.

## API Keys

If you use ElevenLabs, your API key is stored in the macOS Keychain. TimeAnnouncer does not transmit your API key anywhere except to ElevenLabs when requesting speech audio.

## Local Files

Kokoro uses:

- `~/Library/Application Support/TimeAnnouncer/Kokoro` for the local speech environment.
- `~/Library/Caches/TimeAnnouncer/Kokoro` for generated audio cache files.

You can remove these folders to delete Kokoro local data.

## Contact

For support or privacy questions, email **support@initiatorworks.com**.

Time Announcer is published by INITIATOR LLC.
