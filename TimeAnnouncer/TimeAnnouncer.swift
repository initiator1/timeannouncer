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
    private let clockBoundaryGracePeriod: TimeInterval = 2.0
    private var audioGeneration = 0

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
        TimeAnnouncementSchedule.delayToNextClockAlignedBoundary(
            intervalMinutes: settingsManager.intervalMinutes
        )
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
            handleClockAlignedTimerFire()
        } else {
            scheduleTimer(after: delay) { [weak self] in
                self?.handleClockAlignedTimerFire()
            }
        }
    }

    private func handleClockAlignedTimerFire() {
        if isClockAlignedAnnouncementTime() {
            announceCurrentTime()
            rescheduleAfterBoundary()
        } else {
            // Timer callbacks can arrive at the edge of a boundary. Re-check the
            // wall clock before speaking so a :00 timer cannot announce :59.
            let retryDelay = max(calculateDelayToNextBoundary(), 0.05)
            scheduleTimer(after: retryDelay) { [weak self] in
                self?.handleClockAlignedTimerFire()
            }
        }
    }

    private func isClockAlignedAnnouncementTime(at date: Date = Date()) -> Bool {
        TimeAnnouncementSchedule.isClockAlignedAnnouncementTime(
            at: date,
            intervalMinutes: settingsManager.intervalMinutes,
            gracePeriod: clockBoundaryGracePeriod
        )
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
        stopAllAudio()
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
    @discardableResult
    private func stopAllAudio() -> Int {
        audioGeneration += 1
        currentAnnouncementTask?.cancel()
        currentAnnouncementTask = nil
        audioPlayer?.stop()
        audioPlayer = nil
        synthesizer.stopSpeaking()
        return audioGeneration
    }

    private func isCurrentAnnouncement(_ generation: Int) -> Bool {
        audioGeneration == generation
    }

    func announceCurrentTime() {
        guard shouldAnnounce() else { return }
        lastAnnouncementTime = Date()

        let timeString = formatTimeForSpeech()

        switch settingsManager.voiceProvider {
        case .elevenlabs:
            announceWithElevenLabs(timeString)
        case .kokoro:
            announceWithKokoro(timeString)
        case .system:
            announceWithSystemVoice(timeString)
        }
    }

    private func announceWithSystemVoice(_ text: String) {
        stopAllAudio()
        speakWithSystemVoice(text)
    }

    private func speakWithSystemVoice(_ text: String) {
        synthesizer.volume = settingsManager.volume
        synthesizer.startSpeaking(text)
    }

    private func announceWithElevenLabs(_ text: String) {
        let generation = stopAllAudio()
        currentAnnouncementTask = Task { [weak self] in
            guard !Task.isCancelled else { return }
            do {
                let audioData = try await ElevenLabsClient.fetchSpeech(text: text)
                guard !Task.isCancelled else { return }
                await MainActor.run { [weak self] in
                    guard let self = self, self.isCurrentAnnouncement(generation) else { return }
                    self.currentAnnouncementTask = nil
                    self.playAudio(data: audioData)
                }
            } catch {
                guard !Task.isCancelled else { return }
                print("ElevenLabs error: \(error), falling back to system voice")
                await MainActor.run { [weak self] in
                    guard let self = self, self.isCurrentAnnouncement(generation) else { return }
                    self.currentAnnouncementTask = nil
                    self.speakWithSystemVoice(text)
                }
            }
        }
    }

    private func announceWithKokoro(_ text: String) {
        let generation = stopAllAudio()
        currentAnnouncementTask = Task { [weak self] in
            guard !Task.isCancelled else { return }
            do {
                let audioData = try await KokoroClient.fetchSpeech(text: text)
                guard !Task.isCancelled else { return }
                await MainActor.run { [weak self] in
                    guard let self = self, self.isCurrentAnnouncement(generation) else { return }
                    self.currentAnnouncementTask = nil
                    self.playAudio(data: audioData)
                }
            } catch {
                guard !Task.isCancelled else { return }
                print("Kokoro error: \(error), falling back to system voice")
                await MainActor.run { [weak self] in
                    guard let self = self, self.isCurrentAnnouncement(generation) else { return }
                    self.currentAnnouncementTask = nil
                    self.speakWithSystemVoice(text)
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
