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

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var timeAnnouncer: TimeAnnouncer?
    var settingsManager = AppDelegate.makeSettingsManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon - we're a menu bar only app
        NSApp.setActivationPolicy(.accessory)

        let shouldShowWelcome = settingsManager.applyFirstLaunchDefaultsIfNeeded()

        // Initialize the time announcer
        timeAnnouncer = TimeAnnouncer(settingsManager: settingsManager)

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

    func setupMenu() {
        let menu = NSMenu()

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

        let clockAlignedItem = NSMenuItem(title: "Clock-Aligned (:00, :15, :30, :45)", action: #selector(selectClockAligned), keyEquivalent: "")
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
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state = settingsManager.launchAtLogin ? .on : .off
        menu.addItem(launchItem)

        let diagnosticsItem = NSMenuItem(title: "Copy Support Diagnostics", action: #selector(copySupportDiagnostics), keyEquivalent: "")
        diagnosticsItem.target = self
        menu.addItem(diagnosticsItem)

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
        inputField.stringValue = "\(settingsManager.intervalMinutes)"
        alert.accessoryView = inputField

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
        settingsManager.voiceProvider = .system
        setupMenu()
    }

    @objc func selectKokoroVoice() {
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
            settingsManager.voiceProvider = .elevenlabs
            setupMenu()
        }
    }

    @objc func showKokoroSetupDialog() {
        let alert = NSAlert()
        alert.messageText = KokoroClient.isInstalled ? "Kokoro is installed" : "Install Kokoro"
        alert.informativeText = KokoroClient.isInstalled
            ? "Kokoro is available locally. To rebuild the environment, run \(KokoroClient.installCommand) from the project directory."
            : "Kokoro needs a local Python environment before it can speak. Run \(KokoroClient.installCommand) from the project directory, then choose Kokoro again."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc func showApiKeyDialog() {
        let alert = NSAlert()
        alert.messageText = "ElevenLabs API Key"
        alert.informativeText = "Enter your ElevenLabs API key to use premium voices:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let inputField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        inputField.placeholderString = "xi-xxxxxxxxxxxxxxxxxxxxxxxx"
        alert.accessoryView = inputField

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
        switch settingsManager.voiceProvider {
        case .system:
            return "Voice: System Voice"
        case .kokoro:
            return KokoroClient.isInstalled ? "Voice: Kokoro Ready" : "Voice: Kokoro Needs Install"
        case .elevenlabs:
            return settingsManager.hasElevenLabsApiKey ? "Voice: ElevenLabs Ready" : "Voice: ElevenLabs Needs API Key"
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
        settingsManager.launchAtLogin.toggle()

        if #available(macOS 13.0, *) {
            do {
                if settingsManager.launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update login item: \(error)")
                // Revert the setting if it failed
                settingsManager.launchAtLogin.toggle()
            }
        }

        setupMenu()
    }

    @objc func copySupportDiagnostics() {
        let diagnostics = SupportDiagnostics.make(settingsManager: settingsManager)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(diagnostics, forType: .string)

        showAlert(title: "Diagnostics Copied", message: "Support diagnostics were copied to the clipboard. They include app settings and voice readiness, but not API keys.")
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
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
