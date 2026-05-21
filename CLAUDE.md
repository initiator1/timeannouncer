# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TimeAnnouncer is a macOS menu bar application that announces the current time aloud at configurable intervals. It supports three voice options: Kokoro 82M local TTS (default), macOS system voice, or ElevenLabs AI voice (Zara).

## Build & Run

Native Swift/Xcode project with no external package dependencies (no SPM, no CocoaPods).

- **Open**: `open TimeAnnouncer.xcodeproj`
- **Build (CLI)**: `xcodebuild -project TimeAnnouncer.xcodeproj -scheme TimeAnnouncer -configuration Debug build`
- **Build (Xcode)**: Cmd+B
- **Run (Xcode)**: Cmd+R
- **No tests exist** in this project

## Architecture

5-file project, all in `TimeAnnouncer/`:

| File | Role |
|------|------|
| `TimeAnnouncerApp.swift` | App entry point, AppDelegate, menu bar UI (NSStatusBar + NSMenu) |
| `TimeAnnouncer.swift` | Core timer logic, time formatting to natural language, speech output |
| `SettingsManager.swift` | UserDefaults wrapper for preferences |
| `KeychainHelper.swift` | macOS Security framework wrapper for API key storage |
| `ElevenLabsClient.swift` | Async HTTP client for ElevenLabs TTS API |
| `KokoroClient.swift` | Local Kokoro TTS bridge, cache, and Python process runner |
| `KokoroSynth.py` | Bundled Python Kokoro synthesis helper |

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
- **Kokoro voice/cache are hardcoded**: Voice `af_heart`, venv `~/Library/Application Support/TimeAnnouncer/Kokoro/venv`, generated WAV cache `~/Library/Caches/TimeAnnouncer/Kokoro`.
- **UserDefaults defaults**: `isEnabled` defaults to `true` (not standard UserDefaults false), `intervalMinutes` defaults to `60`, `voiceProvider` defaults to `kokoro`, `timingMode` defaults to `clockAligned`, `volume` defaults to `0.1`.
- **Menu rebuilds entirely** on every state change via `setupMenu()` — no incremental updates.
- **Time speech format**: Hours are words ("three"), minutes use "oh" prefix for single digits ("three oh five"). AM/PM only spoken on the hour.

## Requirements

- macOS 13.0+ (for SMAppService)
- Xcode 15.0+
- Local Kokoro setup: `./scripts/setup-kokoro.sh`
- Optional: ElevenLabs API key for premium voice
