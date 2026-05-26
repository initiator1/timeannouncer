import XCTest
@testable import TimeAnnouncer

final class SupportDiagnosticsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "SupportDiagnosticsTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDiagnosticsIncludeLaunchSupportStateWithoutSecrets() {
        let settings = SettingsManager(defaults: defaults)
        settings.isEnabled = true
        settings.intervalMinutes = 15
        settings.timingMode = .clockAligned
        settings.voiceProvider = .elevenlabs
        settings.volume = 0.5
        settings.launchAtLogin = true

        let diagnostics = SupportDiagnostics.make(
            settingsManager: settings,
            environment: SupportDiagnosticsEnvironment(
                appName: "TimeAnnouncer",
                appVersion: "1.0",
                buildNumber: "7",
                operatingSystem: "macOS 26.5",
                generatedAt: Date(timeIntervalSince1970: 0),
                kokoroInstalled: false
            ),
            hasElevenLabsApiKey: true
        )

        XCTAssertTrue(diagnostics.contains("TimeAnnouncer Support Diagnostics"))
        XCTAssertTrue(diagnostics.contains("App Version: 1.0 (7)"))
        XCTAssertTrue(diagnostics.contains("Announcements Enabled: Yes"))
        XCTAssertTrue(diagnostics.contains("Interval: 15 minutes"))
        XCTAssertTrue(diagnostics.contains("Timing Mode: Clock-Aligned"))
        XCTAssertTrue(diagnostics.contains("Voice Provider: ElevenLabs"))
        XCTAssertTrue(diagnostics.contains("Voice Readiness: Ready"))
        XCTAssertTrue(diagnostics.contains("Volume: 50%"))
        XCTAssertTrue(diagnostics.contains("Launch at Login: Yes"))
        XCTAssertTrue(diagnostics.contains("Kokoro Installed: No"))
        XCTAssertTrue(diagnostics.contains("ElevenLabs API Key Saved: Yes"))
        XCTAssertFalse(diagnostics.contains("xi-"))
    }

    func testDiagnosticsShowMissingSelectedVoiceRequirement() {
        let settings = SettingsManager(defaults: defaults)
        settings.voiceProvider = .kokoro

        let diagnostics = SupportDiagnostics.make(
            settingsManager: settings,
            environment: SupportDiagnosticsEnvironment(
                appName: "TimeAnnouncer",
                appVersion: "1.0",
                buildNumber: "7",
                operatingSystem: "macOS 26.5",
                generatedAt: Date(timeIntervalSince1970: 0),
                kokoroInstalled: false
            ),
            hasElevenLabsApiKey: false
        )

        XCTAssertTrue(diagnostics.contains("Voice Provider: Kokoro 82M"))
        XCTAssertTrue(diagnostics.contains("Voice Readiness: Needs Kokoro Install"))
    }
}
