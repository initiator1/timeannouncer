import Foundation

enum TimeAnnouncementSchedule {
    static let defaultClockAlignedIntervalMinutes = 60

    static func isClockAlignedCompatibleInterval(_ minutes: Int) -> Bool {
        minutes > 0 && minutes <= 60 && 60 % minutes == 0
    }

    static func clockAlignedIntervalOrDefault(_ minutes: Int) -> Int {
        isClockAlignedCompatibleInterval(minutes) ? minutes : defaultClockAlignedIntervalMinutes
    }

    static func delayToNextClockAlignedBoundary(
        from date: Date = Date(),
        intervalMinutes requestedIntervalMinutes: Int,
        calendar: Calendar = .current
    ) -> TimeInterval {
        let intervalMinutes = clockAlignedIntervalOrDefault(requestedIntervalMinutes)
        let minute = calendar.component(.minute, from: date)
        let second = calendar.component(.second, from: date)
        let nanosecond = calendar.component(.nanosecond, from: date)

        let totalCurrentSeconds = Double(second) + Double(nanosecond) / 1_000_000_000.0
        let minutesUntilNext = (intervalMinutes - (minute % intervalMinutes)) % intervalMinutes

        if minutesUntilNext == 0 && totalCurrentSeconds < 1.0 {
            return 0
        }

        let actualMinutesUntil = minutesUntilNext == 0 ? intervalMinutes : minutesUntilNext
        return TimeInterval(actualMinutesUntil * 60) - totalCurrentSeconds
    }

    static func isClockAlignedAnnouncementTime(
        at date: Date = Date(),
        intervalMinutes requestedIntervalMinutes: Int,
        gracePeriod: TimeInterval,
        calendar: Calendar = .current
    ) -> Bool {
        let second = calendar.component(.second, from: date)
        let nanosecond = calendar.component(.nanosecond, from: date)
        let secondsAfterMinute = Double(second) + Double(nanosecond) / 1_000_000_000.0

        guard secondsAfterMinute < gracePeriod else {
            return false
        }

        let minute = calendar.component(.minute, from: date)
        let intervalMinutes = clockAlignedIntervalOrDefault(requestedIntervalMinutes)
        return minute % intervalMinutes == 0
    }
}
