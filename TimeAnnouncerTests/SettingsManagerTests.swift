import XCTest
@testable import TimeAnnouncer

final class SettingsManagerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "TimeAnnouncerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testFirstLaunchDefaultsStartPausedWithSystemVoice() {
        let settings = SettingsManager(defaults: defaults)

        XCTAssertTrue(settings.applyFirstLaunchDefaultsIfNeeded())

        XCTAssertFalse(settings.isEnabled)
        XCTAssertEqual(settings.intervalMinutes, 60)
        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertEqual(settings.voiceProvider, .system)
        XCTAssertEqual(settings.timingMode, .clockAligned)
        XCTAssertEqual(settings.volume, 0.25, accuracy: 0.001)
        XCTAssertTrue(settings.shouldShowFirstLaunchWelcome)
    }

    func testExistingConfiguredInstallKeepsLegacyEnabledKokoroBehavior() {
        defaults.set(30, forKey: "intervalMinutes")
        defaults.set("kokoro", forKey: "voiceProvider")

        let settings = SettingsManager(defaults: defaults)

        XCTAssertFalse(settings.applyFirstLaunchDefaultsIfNeeded())
        XCTAssertTrue(settings.isEnabled)
        XCTAssertEqual(settings.intervalMinutes, 30)
        XCTAssertEqual(settings.voiceProvider, .kokoro)
        XCTAssertFalse(settings.shouldShowFirstLaunchWelcome)
    }

    func testFirstLaunchWelcomeCanBeDismissed() {
        let settings = SettingsManager(defaults: defaults)
        settings.applyFirstLaunchDefaultsIfNeeded()

        XCTAssertTrue(settings.shouldShowFirstLaunchWelcome)

        settings.markFirstLaunchWelcomeShown()

        XCTAssertFalse(settings.shouldShowFirstLaunchWelcome)
    }
}
