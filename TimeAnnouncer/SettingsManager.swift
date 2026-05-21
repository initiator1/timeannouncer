import Foundation

class SettingsManager {
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let isEnabled = "isEnabled"
        static let intervalMinutes = "intervalMinutes"
        static let launchAtLogin = "launchAtLogin"
        static let voiceProvider = "voiceProvider"
        static let timingMode = "timingMode"
        static let volume = "volume"
    }

    enum VoiceProvider: String {
        case system = "system"
        case elevenlabs = "elevenlabs"
        case kokoro = "kokoro"
    }

    enum TimingMode: String {
        case clockAligned = "clockAligned"
        case fixedInterval = "fixedInterval"
    }

    var isEnabled: Bool {
        get {
            // Default to true if not set
            if defaults.object(forKey: Keys.isEnabled) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.isEnabled)
        }
        set {
            defaults.set(newValue, forKey: Keys.isEnabled)
        }
    }

    var intervalMinutes: Int {
        get {
            let value = defaults.integer(forKey: Keys.intervalMinutes)
            // Default to 60 minutes (hourly) if not set or invalid
            return value > 0 ? value : 60
        }
        set {
            defaults.set(newValue, forKey: Keys.intervalMinutes)
        }
    }

    var launchAtLogin: Bool {
        get {
            return defaults.bool(forKey: Keys.launchAtLogin)
        }
        set {
            defaults.set(newValue, forKey: Keys.launchAtLogin)
        }
    }

    var voiceProvider: VoiceProvider {
        get {
            guard let rawValue = defaults.string(forKey: Keys.voiceProvider),
                  let provider = VoiceProvider(rawValue: rawValue) else {
                return .kokoro
            }
            return provider
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.voiceProvider)
        }
    }

    var timingMode: TimingMode {
        get {
            guard let rawValue = defaults.string(forKey: Keys.timingMode),
                  let mode = TimingMode(rawValue: rawValue) else {
                return .clockAligned
            }
            return mode
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.timingMode)
        }
    }

    var volume: Float {
        get {
            if defaults.object(forKey: Keys.volume) == nil {
                return 0.1
            }
            return defaults.float(forKey: Keys.volume)
        }
        set {
            defaults.set(newValue, forKey: Keys.volume)
        }
    }

    var hasElevenLabsApiKey: Bool {
        guard let key = KeychainHelper.load(forKey: "elevenlabs_api_key") else {
            return false
        }
        return !key.isEmpty
    }

    func setElevenLabsApiKey(_ key: String) throws {
        try KeychainHelper.save(key, forKey: "elevenlabs_api_key")
    }
}
