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
    var settingsManager = SettingsManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon - we're a menu bar only app
        NSApp.setActivationPolicy(.accessory)

        // Initialize the time announcer
        timeAnnouncer = TimeAnnouncer(settingsManager: settingsManager)

        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "clock.fill", accessibilityDescription: "Time Announcer")
        }

        // Create the menu
        setupMenu()

        // Start announcing if enabled
        if settingsManager.isEnabled {
            timeAnnouncer?.start()
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
        timeAnnouncer?.announceCurrentTime()
    }

    @objc func setPresetInterval(_ sender: NSMenuItem) {
        settingsManager.intervalMinutes = sender.tag
        timeAnnouncer?.updateInterval(minutes: sender.tag)
        setupMenu()
    }

    @objc func showCustomInterval() {
        let alert = NSAlert()
        alert.messageText = "Set Custom Interval"
        alert.informativeText = "Enter the number of minutes between announcements:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        inputField.stringValue = "\(settingsManager.intervalMinutes)"
        alert.accessoryView = inputField

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let minutes = Int(inputField.stringValue), minutes > 0 {
                settingsManager.intervalMinutes = minutes
                timeAnnouncer?.updateInterval(minutes: minutes)
                setupMenu()
            }
        }
    }

    @objc func selectClockAligned() {
        settingsManager.timingMode = .clockAligned
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
                settingsManager.setElevenLabsApiKey(key)
                setupMenu()
            }
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

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
