# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Project Overview

TimeAnnouncer is a macOS menu bar application that announces the current time aloud at configurable intervals. It supports three voice options: Kokoro 82M local TTS (default), macOS system voice, or ElevenLabs AI voice (Zara).

## Build & Run

Native Swift/Xcode project with no external package dependencies (no SPM, no CocoaPods).

- **Open**: `open TimeAnnouncer.xcodeproj`
- **Build (CLI)**: `xcodebuild -project TimeAnnouncer.xcodeproj -scheme TimeAnnouncer -configuration Debug build`
- **Test (CLI)**: `xcodebuild test -project TimeAnnouncer.xcodeproj -scheme TimeAnnouncer -destination 'platform=macOS,arch=arm64'`
- **Build (Xcode)**: Cmd+B
- **Run (Xcode)**: Cmd+R
- **Tests** live in `TimeAnnouncerTests/`

## Architecture

Small native project, with app sources in `TimeAnnouncer/` and tests in `TimeAnnouncerTests/`:

| File | Role |
|------|------|
| `TimeAnnouncerApp.swift` | App entry point, AppDelegate, menu bar UI (NSStatusBar + NSMenu) |
| `TimeAnnouncer.swift` | Core timer orchestration, time formatting to natural language, speech output |
| `TimeAnnouncementSchedule.swift` | Clock-aligned interval policy and boundary calculations |
| `SettingsManager.swift` | UserDefaults wrapper for preferences |
| `KeychainHelper.swift` | macOS Security framework wrapper for API key storage |
| `ElevenLabsClient.swift` | Async HTTP client for ElevenLabs TTS API |
| `KokoroClient.swift` | Local Kokoro TTS bridge, cache, and warmed Python worker |
| `KokoroSynth.py` | Bundled Python Kokoro synthesis helper and worker protocol |

### Data Flow

`AppDelegate` owns both `SettingsManager` and `TimeAnnouncer`. User interactions in the menu modify `SettingsManager`, then `AppDelegate` calls `TimeAnnouncer.start()/stop()/updateInterval()` to apply changes. `TimeAnnouncer` reads settings from `SettingsManager` and calls `KokoroClient`, `ElevenLabsClient`, or `NSSpeechSynthesizer` to produce audio.

### Key Design Decisions

1. **Timing modes** - Two scheduling strategies: **Clock-aligned** (default) snaps to natural boundaries (:00/:15/:30/:45) via `calculateDelayToNextBoundary()`. **Fixed interval** announces immediately then repeats at exact interval. Configurable via `SettingsManager.timingMode`.

2. **Graceful degradation** - Kokoro and ElevenLabs errors silently fall back to `NSSpeechSynthesizer`. Audio playback uses `AVAudioPlayer` for Kokoro/ElevenLabs, `NSSpeechSynthesizer` for system voice.

3. **Anti-double-fire guard** - `minimumAnnouncementGap` (2s) prevents rapid announcements at clock boundaries. Clock-aligned timer callbacks also re-check the actual wall clock before speaking and only announce inside a short post-boundary grace window, preventing early/stale timers from speaking non-boundary minutes like `:59`.

4. **Menu bar only** - `LSUIElement=true` in Info.plist + `NSApp.setActivationPolicy(.accessory)` hides dock icon.

5. **Launch at login** - Uses `SMAppService` (macOS 13+) via ServiceManagement framework.

### Gotchas

- **Volume** defaults to `0.1`, configurable via menu (10%/25%/50%/75%/100%). Stored in `SettingsManager.volume`, read at announcement time — no timer restart needed.
- **Keychain key name**: `elevenlabs_api_key` (service: `com.timeannouncer.app`). Referenced in both `SettingsManager` and `ElevenLabsClient`.
- **ElevenLabs voice/model are hardcoded**: Voice ID `jqcCZkN6Knx8BJ5TBdYR` (Zara), Model `eleven_flash_v2_5`.
- **Kokoro voice/cache are hardcoded**: Voice `af_heart`, venv `~/Library/Application Support/TimeAnnouncer/Kokoro/venv`, generated WAV cache `~/Library/Caches/TimeAnnouncer/Kokoro`. When Kokoro is selected, the app warms a long-lived local Python worker so manual announcements do not reload the model for each click.
- **Clock-aligned custom intervals** must divide evenly into an hour. Fixed interval mode accepts arbitrary positive minute values.
- **UserDefaults defaults**: `isEnabled` defaults to `true` (not standard UserDefaults false), `intervalMinutes` defaults to `60`, `voiceProvider` defaults to `kokoro`, `timingMode` defaults to `clockAligned`, `volume` defaults to `0.1`.
- **Menu rebuilds entirely** on every state change via `setupMenu()` — no incremental updates.
- **Support link is hardcoded**: `AppDelegate.supportPageURL` = `https://ko-fi.com/initiatorworks?app=timeannouncer`, opened by the **Buy Me a Coffee…** menu item. One Ko-fi page serves several apps, so the `app` parameter identifies which one sent the visitor. Keep the same value in the README link. A sibling app once shipped a wrong slug as a dead link — verify the page loads before changing this.
- **Time speech format**: Hours are words ("three"), minutes use "oh" prefix for single digits ("three oh five"). AM/PM only spoken on the hour.

## Requirements

- macOS 13.0+ (for SMAppService)
- Xcode 15.0+
- Local Kokoro setup: `./scripts/setup-kokoro.sh`
- Optional: ElevenLabs API key for premium voice
