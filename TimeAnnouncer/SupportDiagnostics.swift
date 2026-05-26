import Foundation

struct SupportDiagnosticsEnvironment {
    let appName: String
    let appVersion: String
    let buildNumber: String
    let operatingSystem: String
    let generatedAt: Date
    let kokoroInstalled: Bool

    static func live(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo,
        generatedAt: Date = Date(),
        kokoroInstalled: Bool = KokoroClient.isInstalled
    ) -> SupportDiagnosticsEnvironment {
        SupportDiagnosticsEnvironment(
            appName: bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "TimeAnnouncer",
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown",
            buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown",
            operatingSystem: processInfo.operatingSystemVersionString,
            generatedAt: generatedAt,
            kokoroInstalled: kokoroInstalled
        )
    }
}

enum SupportDiagnostics {
    static func make(
        settingsManager: SettingsManager,
        environment: SupportDiagnosticsEnvironment = .live(),
        hasElevenLabsApiKey: Bool? = nil
    ) -> String {
        let apiKeySaved = hasElevenLabsApiKey ?? settingsManager.hasElevenLabsApiKey
        let formatter = ISO8601DateFormatter()

        return [
            "\(environment.appName) Support Diagnostics",
            "Generated: \(formatter.string(from: environment.generatedAt))",
            "App Version: \(environment.appVersion) (\(environment.buildNumber))",
            "macOS: \(environment.operatingSystem)",
            "Announcements Enabled: \(yesNo(settingsManager.isEnabled))",
            "Interval: \(settingsManager.intervalMinutes) minutes",
            "Timing Mode: \(timingModeTitle(settingsManager.timingMode))",
            "Voice Provider: \(voiceProviderTitle(settingsManager.voiceProvider))",
            "Voice Readiness: \(voiceReadiness(settingsManager: settingsManager, kokoroInstalled: environment.kokoroInstalled, hasElevenLabsApiKey: apiKeySaved))",
            "Volume: \(Int(round(settingsManager.volume * 100)))%",
            "Launch at Login: \(yesNo(settingsManager.launchAtLogin))",
            "Kokoro Installed: \(yesNo(environment.kokoroInstalled))",
            "ElevenLabs API Key Saved: \(yesNo(apiKeySaved))"
        ].joined(separator: "\n")
    }

    private static func yesNo(_ value: Bool) -> String {
        value ? "Yes" : "No"
    }

    private static func timingModeTitle(_ timingMode: SettingsManager.TimingMode) -> String {
        switch timingMode {
        case .clockAligned:
            return "Clock-Aligned"
        case .fixedInterval:
            return "Fixed Interval"
        }
    }

    private static func voiceProviderTitle(_ voiceProvider: SettingsManager.VoiceProvider) -> String {
        switch voiceProvider {
        case .system:
            return "System Voice"
        case .kokoro:
            return "Kokoro 82M"
        case .elevenlabs:
            return "ElevenLabs"
        }
    }

    private static func voiceReadiness(
        settingsManager: SettingsManager,
        kokoroInstalled: Bool,
        hasElevenLabsApiKey: Bool
    ) -> String {
        switch settingsManager.voiceProvider {
        case .system:
            return "Ready"
        case .kokoro:
            return kokoroInstalled ? "Ready" : "Needs Kokoro Install"
        case .elevenlabs:
            return hasElevenLabsApiKey ? "Ready" : "Needs ElevenLabs API Key"
        }
    }
}
