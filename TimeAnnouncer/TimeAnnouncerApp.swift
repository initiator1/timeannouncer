import SwiftUI
import ServiceManagement

@main
struct TimeAnnouncerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var timeAnnouncer: TimeAnnouncer?
    var settingsManager = AppDelegate.makeSettingsManager()

    static let supportPageURL = "https://ko-fi.com/initiatorworks?app=timeannouncer"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon - we're a menu bar only app
        NSApp.setActivationPolicy(.accessory)

        let shouldShowWelcome = settingsManager.applyFirstLaunchDefaultsIfNeeded()

        // Initialize the time announcer
        timeAnnouncer = TimeAnnouncer(settingsManager: settingsManager)
        timeAnnouncer?.onSpeechStatusChange = { [weak self] in self?.setupMenu() }

        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "clock.fill", accessibilityDescription: "Time Announcer")
        }

        // Create the menu
        setupMenu()

        if settingsManager.voiceProvider == .kokoro {
            KokoroClient.prepareForSpeech()
        }

        // Start announcing if enabled
        if settingsManager.isEnabled {
            timeAnnouncer?.start()
        }

        if shouldShowWelcome || settingsManager.shouldShowFirstLaunchWelcome {
            DispatchQueue.main.async { [weak self] in
                self?.showFirstLaunchWelcome()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Applications and Spotlight remain a way back to the controls when
        // the clock icon is hidden among other menu-bar items.
        sender.activate(ignoringOtherApps: true)
        if !flag {
            DispatchQueue.main.async { [weak self] in
                self?.statusItem?.button?.performClick(nil)
            }
        }
        return false
    }

    func setupMenu() {
        let menu = NSMenu()
        menu.delegate = self

        // Status header
        let statusItem = NSMenuItem(title: settingsManager.isEnabled ? "✓ Announcing" : "Paused", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        // Current interval display
        let intervalItem = NSMenuItem(title: "Every \(settingsManager.intervalMinutes) min", action: nil, keyEquivalent: "")
        intervalItem.isEnabled = false
        menu.addItem(intervalItem)

        let voiceStatusItem = NSMenuItem(title: voiceStatusTitle, action: nil, keyEquivalent: "")
        voiceStatusItem.isEnabled = false
        menu.addItem(voiceStatusItem)

        menu.addItem(NSMenuItem.separator())

        // Toggle on/off
        let toggleItem = NSMenuItem(
            title: settingsManager.isEnabled ? "Pause Announcements" : "Resume Announcements",
            action: #selector(toggleEnabled),
            keyEquivalent: "t"
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        // Announce now
        let announceNowItem = NSMenuItem(title: "Announce Time Now", action: #selector(announceNow), keyEquivalent: "a")
        announceNowItem.target = self
        menu.addItem(announceNowItem)

        let previewVoiceItem = NSMenuItem(title: "Preview Voice", action: #selector(previewVoice), keyEquivalent: "")
        previewVoiceItem.target = self
        menu.addItem(previewVoiceItem)

        menu.addItem(NSMenuItem.separator())

        // Interval presets submenu
        let presetsMenu = NSMenu()
        let presets = [("Every hour", 60), ("Every 30 min", 30), ("Every 15 min", 15), ("Every 5 min", 5)]

        for (title, minutes) in presets {
            let item = NSMenuItem(title: title, action: #selector(setPresetInterval(_:)), keyEquivalent: "")
            item.target = self
            item.tag = minutes
            if minutes == settingsManager.intervalMinutes {
                item.state = .on
            }
            presetsMenu.addItem(item)
        }

        presetsMenu.addItem(NSMenuItem.separator())

        let customItem = NSMenuItem(title: "Custom...", action: #selector(showCustomInterval), keyEquivalent: "")
        customItem.target = self
        presetsMenu.addItem(customItem)

        let presetsMenuItem = NSMenuItem(title: "Interval", action: nil, keyEquivalent: "")
        presetsMenuItem.submenu = presetsMenu
        menu.addItem(presetsMenuItem)

        // Timing Mode submenu
        let timingMenu = NSMenu()

        let clockAlignedItem = NSMenuItem(title: "Clock-Aligned", action: #selector(selectClockAligned), keyEquivalent: "")
        clockAlignedItem.target = self
        clockAlignedItem.state = settingsManager.timingMode == .clockAligned ? .on : .off
        timingMenu.addItem(clockAlignedItem)

        let fixedIntervalItem = NSMenuItem(title: "Fixed Interval", action: #selector(selectFixedInterval), keyEquivalent: "")
        fixedIntervalItem.target = self
        fixedIntervalItem.state = settingsManager.timingMode == .fixedInterval ? .on : .off
        timingMenu.addItem(fixedIntervalItem)

        let timingMenuItem = NSMenuItem(title: "Timing Mode", action: nil, keyEquivalent: "")
        timingMenuItem.submenu = timingMenu
        menu.addItem(timingMenuItem)

        // Voice submenu
        let voiceMenu = NSMenu()

        let systemVoiceItem = NSMenuItem(title: "System Voice (macOS)", action: #selector(selectSystemVoice), keyEquivalent: "")
        systemVoiceItem.target = self
        systemVoiceItem.state = settingsManager.voiceProvider == .system ? .on : .off
        voiceMenu.addItem(systemVoiceItem)

        let kokoroItem = NSMenuItem(title: "Kokoro 82M - af_heart", action: #selector(selectKokoroVoice), keyEquivalent: "")
        kokoroItem.target = self
        kokoroItem.state = settingsManager.voiceProvider == .kokoro ? .on : .off
        voiceMenu.addItem(kokoroItem)

        let elevenLabsItem = NSMenuItem(title: "ElevenLabs - Zara", action: #selector(selectElevenLabsVoice), keyEquivalent: "")
        elevenLabsItem.target = self
        elevenLabsItem.state = settingsManager.voiceProvider == .elevenlabs ? .on : .off
        voiceMenu.addItem(elevenLabsItem)

        voiceMenu.addItem(NSMenuItem.separator())

        let kokoroSetupItem = NSMenuItem(title: KokoroClient.isInstalled ? "Repair Kokoro Install..." : "Install Kokoro...", action: #selector(showKokoroSetupDialog), keyEquivalent: "")
        kokoroSetupItem.target = self
        voiceMenu.addItem(kokoroSetupItem)

        let apiKeyItem = NSMenuItem(title: "Set ElevenLabs API Key...", action: #selector(showApiKeyDialog), keyEquivalent: "")
        apiKeyItem.target = self
        voiceMenu.addItem(apiKeyItem)

        let voiceMenuItem = NSMenuItem(title: "Voice", action: nil, keyEquivalent: "")
        voiceMenuItem.submenu = voiceMenu
        menu.addItem(voiceMenuItem)

        // Volume submenu
        let volumeMenu = NSMenu()
        let volumePresets: [(String, Int)] = [("10%", 10), ("25%", 25), ("50%", 50), ("75%", 75), ("100%", 100)]
        let currentVolumeTag = Int(round(settingsManager.volume * 100))

        for (title, tag) in volumePresets {
            let item = NSMenuItem(title: title, action: #selector(setVolume(_:)), keyEquivalent: "")
            item.target = self
            item.tag = tag
            item.state = tag == currentVolumeTag ? .on : .off
            volumeMenu.addItem(item)
        }

        let volumeMenuItem = NSMenuItem(title: "Volume", action: nil, keyEquivalent: "")
        volumeMenuItem.submenu = volumeMenu
        menu.addItem(volumeMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Launch at login
        let launchItem = NSMenuItem(
            title: loginItemTitle,
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state = loginItemState
        menu.addItem(launchItem)

        let diagnosticsItem = NSMenuItem(title: "Copy Support Diagnostics", action: #selector(copySupportDiagnostics), keyEquivalent: "")
        diagnosticsItem.target = self
        menu.addItem(diagnosticsItem)

        // Without ANY update path, every 1.0.0 user is frozen on 1.0.0 forever
        // — including the ones who downloaded a build where the Kokoro voice
        // could not work. This is the cheapest honest fix: it opens the
        // releases page rather than pretending to auto-update. A real Sparkle
        // feed is the v1.1 answer; shipping nothing is not.
        let updatesItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        updatesItem.target = self
        menu.addItem(updatesItem)

        let supportItem = NSMenuItem(title: "Buy Me a Coffee…", action: #selector(openSupportPage), keyEquivalent: "")
        supportItem.target = self
        menu.addItem(supportItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit Time Announcer", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem?.menu = menu
    }

    @objc func toggleEnabled() {
        settingsManager.isEnabled.toggle()
        if settingsManager.isEnabled {
            timeAnnouncer?.start()
        } else {
            timeAnnouncer?.stop()
        }
        setupMenu()
    }

    @objc func announceNow() {
        timeAnnouncer?.announceCurrentTime(force: true)
    }

    @objc func previewVoice() {
        timeAnnouncer?.previewSelectedVoice()
    }

    @objc func setPresetInterval(_ sender: NSMenuItem) {
        settingsManager.intervalMinutes = sender.tag
        timeAnnouncer?.updateInterval(minutes: sender.tag)
        setupMenu()
    }

    @objc func showCustomInterval() {
        let alert = NSAlert()
        alert.messageText = "Set Custom Interval"
        alert.informativeText = settingsManager.timingMode == .clockAligned
            ? "Clock-aligned intervals must divide evenly into an hour, such as 5, 10, 15, 20, 30, or 60."
            : "Enter the number of minutes between announcements:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        inputField.setAccessibilityLabel("Interval in minutes")
        inputField.stringValue = "\(settingsManager.intervalMinutes)"
        alert.accessoryView = inputField
        alert.window.initialFirstResponder = inputField

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let minutes = Int(inputField.stringValue), minutes > 0 {
                guard settingsManager.timingMode != .clockAligned ||
                        TimeAnnouncementSchedule.isClockAlignedCompatibleInterval(minutes) else {
                    showAlert(
                        title: "Invalid Clock-Aligned Interval",
                        message: "Use an interval that divides evenly into an hour: 5, 10, 15, 20, 30, or 60 minutes. Switch to Fixed Interval for arbitrary values."
                    )
                    return
                }

                settingsManager.intervalMinutes = minutes
                timeAnnouncer?.updateInterval(minutes: minutes)
                setupMenu()
            } else {
                showAlert(title: "Invalid Interval", message: "Enter a whole number of minutes greater than zero.")
            }
        }
    }

    @objc func selectClockAligned() {
        settingsManager.timingMode = .clockAligned
        if !TimeAnnouncementSchedule.isClockAlignedCompatibleInterval(settingsManager.intervalMinutes) {
            settingsManager.intervalMinutes = TimeAnnouncementSchedule.defaultClockAlignedIntervalMinutes
            showAlert(
                title: "Interval Reset",
                message: "Clock-aligned mode only supports intervals that divide evenly into an hour. The interval was reset to 60 minutes."
            )
        }
        if settingsManager.isEnabled {
            timeAnnouncer?.start()
        }
        setupMenu()
    }

    @objc func selectFixedInterval() {
        settingsManager.timingMode = .fixedInterval
        if settingsManager.isEnabled {
            timeAnnouncer?.start()
        }
        setupMenu()
    }

    @objc func setVolume(_ sender: NSMenuItem) {
        settingsManager.volume = Float(sender.tag) / 100.0
        setupMenu()
    }

    @objc func selectSystemVoice() {
        timeAnnouncer?.cancelCurrentSpeech()
        settingsManager.voiceProvider = .system
        setupMenu()
    }

    @objc func selectKokoroVoice() {
        timeAnnouncer?.cancelCurrentSpeech()
        settingsManager.voiceProvider = .kokoro
        if !KokoroClient.isInstalled {
            showKokoroSetupDialog()
        } else {
            KokoroClient.prepareForSpeech()
        }
        setupMenu()
    }

    @objc func selectElevenLabsVoice() {
        if !settingsManager.hasElevenLabsApiKey {
            showApiKeyDialog()
        }
        if settingsManager.hasElevenLabsApiKey {
            timeAnnouncer?.cancelCurrentSpeech()
            settingsManager.voiceProvider = .elevenlabs
            setupMenu()
        }
    }

    @objc func openSupportPage() {
        // The app is free and MIT-licensed. This is the only place that asks
        // for anything, and one Ko-fi page collects for all of these tools.
        guard let url = URL(string: AppDelegate.supportPageURL) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc func checkForUpdates() {
        // Shows the installed version so a user can tell at a glance whether
        // the releases page has anything newer, then opens that page.
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let alert = NSAlert()
        alert.messageText = "Time Announcer \(version)"
        alert.informativeText = "Open the releases page to see whether a newer version is available."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Releases")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "https://github.com/initiator1/timeannouncer/releases/latest") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func showKokoroSetupDialog() {
        // 2026-07-26: this dialog previously told users to run
        // "./scripts/setup-kokoro.sh from the project directory". The shipped
        // DMG has no scripts/ directory and a downloader has no project — so
        // for every real user, two of the three advertised voices were a dead
        // end. The command now points at the script bundled in the app, the
        // real costs (Homebrew, ~2 GB, several minutes) are stated up front
        // rather than discovered halfway through, and the command is one click
        // from the clipboard because nobody retypes a path by hand.
        let command = KokoroClient.installCommand
        let alert = NSAlert()
        alert.messageText = KokoroClient.isInstalled ? "Kokoro is installed" : "Install Kokoro"
        alert.informativeText = KokoroClient.isInstalled
            ? "Kokoro is ready. To rebuild the environment, paste this into Terminal:\n\n\(command)"
            : "Kokoro is an optional higher-quality voice that runs entirely on your Mac. "
              + "Setup needs Homebrew, downloads about 2 GB, and takes a few minutes.\n\n"
              + "Paste this into Terminal, then choose Kokoro again:\n\n\(command)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Copy Command")
        alert.addButton(withTitle: "OK")

        if alert.runModal() == .alertFirstButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command, forType: .string)
        }
    }

    @objc func showApiKeyDialog() {
        let alert = NSAlert()
        alert.messageText = "ElevenLabs API Key"
        alert.informativeText = "Time phrases and your API key are sent to ElevenLabs to generate speech and may use paid credits. The key is stored in macOS Keychain. Choose System Voice to stop cloud requests."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let inputField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        inputField.placeholderString = "xi-xxxxxxxxxxxxxxxxxxxxxxxx"
        inputField.setAccessibilityLabel("ElevenLabs API key")
        alert.accessoryView = inputField
        alert.window.initialFirstResponder = inputField

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let key = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {
                do {
                    try settingsManager.setElevenLabsApiKey(key)
                    setupMenu()
                } catch {
                    showAlert(title: "Could Not Save API Key", message: error.localizedDescription)
                }
            } else {
                showAlert(title: "API Key Required", message: "Enter a key, or choose Cancel to keep using your current voice.")
            }
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private var voiceStatusTitle: String {
        if let status = timeAnnouncer?.speechStatus { return status }
        switch settingsManager.voiceProvider {
        case .system:
            return "Voice: System Voice"
        case .kokoro:
            return KokoroClient.isInstalled ? "Voice: Kokoro Selected" : "Voice: Kokoro Needs Install"
        case .elevenlabs:
            return settingsManager.hasElevenLabsApiKey ? "Voice: ElevenLabs Selected" : "Voice: ElevenLabs Needs API Key"
        }
    }

    private func showFirstLaunchWelcome() {
        settingsManager.markFirstLaunchWelcomeShown()

        let alert = NSAlert()
        alert.messageText = "Time Announcer is Ready"
        alert.informativeText = "Time Announcer starts paused and uses the built-in macOS voice so setup is optional. Preview the voice now, or use the menu bar clock to resume announcements when you are ready."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Preview Voice")
        alert.addButton(withTitle: "Not Now")

        if alert.runModal() == .alertFirstButtonReturn {
            timeAnnouncer?.previewSelectedVoice()
        }
    }

    @objc func toggleLaunchAtLogin() {
        if SMAppService.mainApp.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
            return
        }
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            settingsManager.launchAtLogin = SMAppService.mainApp.status == .enabled
            if SMAppService.mainApp.status == .requiresApproval {
                showAlert(title: "Login Approval Needed", message: "Allow Time Announcer in System Settings > General > Login Items. Choose Launch at Login again to open those settings.")
            }
        } catch {
            showAlert(title: "Could Not Change Launch at Login", message: "macOS reports: \(error.localizedDescription) Open System Settings > General > Login Items to check access.")
        }

        setupMenu()
    }

    private var loginItemTitle: String {
        SMAppService.mainApp.status == .requiresApproval ? "Launch at Login: Approval Needed…" : "Launch at Login"
    }

    private var loginItemState: NSControl.StateValue {
        switch SMAppService.mainApp.status {
        case .enabled: return .on
        case .requiresApproval: return .mixed
        default: return .off
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        if let item = menu.items.first(where: { $0.action == #selector(toggleLaunchAtLogin) }) {
            item.title = loginItemTitle
            item.state = loginItemState
        }
    }

    @objc func copySupportDiagnostics() {
        let loginStatus = SMAppService.mainApp.status == .requiresApproval
            ? "Approval needed"
            : (SMAppService.mainApp.status == .enabled ? "Yes" : "No")
        let diagnostics = SupportDiagnostics.make(settingsManager: settingsManager, loginStatus: loginStatus)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(diagnostics, forType: .string)

        showAlert(title: "Diagnostics Copied", message: "Support diagnostics were copied to the clipboard. They include app settings and voice readiness, but not API keys.")
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        timeAnnouncer?.stop()
        KokoroClient.shutdown()
    }

    private static func makeSettingsManager() -> SettingsManager {
        guard let suiteName = ProcessInfo.processInfo.environment["TIMEANNOUNCER_DEFAULTS_SUITE"],
              !suiteName.isEmpty,
              let defaults = UserDefaults(suiteName: suiteName) else {
            return SettingsManager()
        }

        return SettingsManager(defaults: defaults)
    }
}
