import Foundation
import AppKit
import AVFoundation

class TimeAnnouncer {
    private var timer: Timer?
    private let synthesizer = NSSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private let settingsManager: SettingsManager

    // Fix 1: Prevent double-firing at clock boundaries
    private var lastAnnouncementTime: Date?
    private let minimumAnnouncementGap: TimeInterval = 2.0

    // Fix 3: Track in-flight ElevenLabs tasks for cancellation
    private var currentAnnouncementTask: Task<Void, Never>?

    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
    }

    func start() {
        stop() // Clear any existing timer
        scheduleNextAnnouncement()
    }

    /// Calculates the delay until the next clock-aligned announcement time
    private func calculateDelayToNextBoundary() -> TimeInterval {
        let now = Date()
        let calendar = Calendar.current
        let minutes = calendar.component(.minute, from: now)
        let seconds = calendar.component(.second, from: now)
        let nanoseconds = calendar.component(.nanosecond, from: now)

        // Include sub-second precision to hit exact boundaries
        let fractionalSeconds = Double(nanoseconds) / 1_000_000_000.0
        let totalCurrentSeconds = Double(seconds) + fractionalSeconds

        let intervalMinutes = settingsManager.intervalMinutes

        if intervalMinutes >= 60 {
            // For hourly, align to the top of the hour (:00)
            let minutesUntilNextHour = (60 - minutes) % 60
            if minutesUntilNextHour == 0 && totalCurrentSeconds < 1.0 {
                // We're within 1 second of the hour, announce now
                return 0
            }
            let actualMinutesUntil = minutesUntilNextHour == 0 ? 60 : minutesUntilNextHour
            return TimeInterval(actualMinutesUntil * 60) - totalCurrentSeconds
        } else {
            // For sub-hourly intervals, align to clock boundaries
            // e.g., 30-min -> :00 and :30, 15-min -> :00, :15, :30, :45
            let currentIntervalPosition = minutes % intervalMinutes
            let minutesUntilNext = (intervalMinutes - currentIntervalPosition) % intervalMinutes

            if minutesUntilNext == 0 && totalCurrentSeconds < 1.0 {
                // We're within 1 second of a boundary, announce now
                return 0
            }
            let actualMinutesUntil = minutesUntilNext == 0 ? intervalMinutes : minutesUntilNext
            return TimeInterval(actualMinutesUntil * 60) - totalCurrentSeconds
        }
    }

    /// Schedules the next announcement based on the current timing mode
    private func scheduleNextAnnouncement() {
        switch settingsManager.timingMode {
        case .clockAligned:
            scheduleClockAligned()
        case .fixedInterval:
            scheduleFixedInterval()
        }
    }

    /// Schedules announcements aligned to clock boundaries (:00, :15, :30, :45)
    private func scheduleClockAligned() {
        let delay = calculateDelayToNextBoundary()

        if delay == 0 {
            // At a boundary on startup — announce and reschedule past the boundary window
            announceCurrentTime()
            rescheduleAfterBoundary()
        } else {
            scheduleTimer(after: delay) { [weak self] in
                self?.announceCurrentTime()
                self?.rescheduleAfterBoundary()
            }
        }
    }

    /// Waits 1.5s so calculateDelayToNextBoundary() sees totalCurrentSeconds >= 1.0
    /// and correctly computes the delay to the NEXT boundary, not the current one.
    private func rescheduleAfterBoundary() {
        scheduleTimer(after: 1.5) { [weak self] in
            self?.scheduleClockAligned()
        }
    }

    /// Creates a one-shot timer added to .common run loop mode so it fires even
    /// while NSMenu is open (.eventTracking mode).
    private func scheduleTimer(after interval: TimeInterval, block: @escaping () -> Void) {
        let t = Timer(timeInterval: interval, repeats: false) { _ in block() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Schedules announcements at a fixed interval from now
    private func scheduleFixedInterval() {
        announceCurrentTime()
        let interval = TimeInterval(settingsManager.intervalMinutes * 60)
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.announceCurrentTime()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func updateInterval(minutes: Int) {
        if settingsManager.isEnabled {
            start() // Restart with new interval
        }
    }

    // Fix 1: Guard against rapid-fire announcements
    private func shouldAnnounce() -> Bool {
        guard let last = lastAnnouncementTime else { return true }
        return Date().timeIntervalSince(last) >= minimumAnnouncementGap
    }

    // Fix 2: Clean audio state before new playback
    private func stopAllAudio() {
        currentAnnouncementTask?.cancel()
        currentAnnouncementTask = nil
        audioPlayer?.stop()
        audioPlayer = nil
        synthesizer.stopSpeaking()
    }

    func announceCurrentTime() {
        guard shouldAnnounce() else { return }
        lastAnnouncementTime = Date()

        let timeString = formatTimeForSpeech()

        switch settingsManager.voiceProvider {
        case .elevenlabs:
            announceWithElevenLabs(timeString)
        case .system:
            announceWithSystemVoice(timeString)
        }
    }

    private func announceWithSystemVoice(_ text: String) {
        stopAllAudio()
        synthesizer.volume = settingsManager.volume
        synthesizer.startSpeaking(text)
    }

    private func announceWithElevenLabs(_ text: String) {
        currentAnnouncementTask?.cancel()
        currentAnnouncementTask = Task {
            guard !Task.isCancelled else { return }
            do {
                let audioData = try await ElevenLabsClient.fetchSpeech(text: text)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    playAudio(data: audioData)
                }
            } catch {
                guard !Task.isCancelled else { return }
                print("ElevenLabs error: \(error), falling back to system voice")
                await MainActor.run {
                    announceWithSystemVoice(text)
                }
            }
        }
    }

    private func playAudio(data: Data) {
        // Stop any existing audio before new playback
        audioPlayer?.stop()
        audioPlayer = nil
        synthesizer.stopSpeaking()

        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.volume = settingsManager.volume
            audioPlayer?.play()
        } catch {
            print("Audio playback error: \(error)")
            announceWithSystemVoice(formatTimeForSpeech())
        }
    }

    private func formatTimeForSpeech() -> String {
        let now = Date()
        let calendar = Calendar.current

        var hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)

        // Determine AM/PM
        let isPM = hour >= 12
        let period = isPM ? "P.M." : "A.M."

        // Convert to 12-hour format
        if hour == 0 {
            hour = 12
        } else if hour > 12 {
            hour -= 12
        }

        let hourWord = numberToWord(hour)

        // Format the spoken time
        if minute == 0 {
            // On the hour: "It's three A.M." or "It's three P.M."
            return "It's \(hourWord) \(period)"
        } else {
            // Off the hour - spell out for natural flow
            let minuteWord = minuteToWord(minute)
            return "It's \(hourWord) \(minuteWord)"
        }
    }

    private func numberToWord(_ n: Int) -> String {
        let words = ["", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve"]
        return n <= 12 ? words[n] : "\(n)"
    }

    private func minuteToWord(_ minute: Int) -> String {
        let ones = ["", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
        let teens = ["ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"]
        let tens = ["", "", "twenty", "thirty", "forty", "fifty"]

        if minute < 10 {
            return "oh \(ones[minute])"
        } else if minute < 20 {
            return teens[minute - 10]
        } else {
            let t = minute / 10
            let o = minute % 10
            if o == 0 {
                return tens[t]
            } else {
                return "\(tens[t]) \(ones[o])"
            }
        }
    }
}
