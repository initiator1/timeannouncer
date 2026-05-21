import XCTest
@testable import TimeAnnouncer

final class TimeAnnouncementScheduleTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testClockAlignedCompatibilityOnlyAllowsHourDivisors() {
        XCTAssertTrue(TimeAnnouncementSchedule.isClockAlignedCompatibleInterval(5))
        XCTAssertTrue(TimeAnnouncementSchedule.isClockAlignedCompatibleInterval(15))
        XCTAssertTrue(TimeAnnouncementSchedule.isClockAlignedCompatibleInterval(30))
        XCTAssertTrue(TimeAnnouncementSchedule.isClockAlignedCompatibleInterval(60))

        XCTAssertFalse(TimeAnnouncementSchedule.isClockAlignedCompatibleInterval(0))
        XCTAssertFalse(TimeAnnouncementSchedule.isClockAlignedCompatibleInterval(7))
        XCTAssertFalse(TimeAnnouncementSchedule.isClockAlignedCompatibleInterval(90))
    }

    func testThirtyMinuteClockAlignedBoundaries() {
        XCTAssertTrue(TimeAnnouncementSchedule.isClockAlignedAnnouncementTime(
            at: date(hour: 10, minute: 0, second: 0),
            intervalMinutes: 30,
            gracePeriod: 2,
            calendar: calendar
        ))
        XCTAssertTrue(TimeAnnouncementSchedule.isClockAlignedAnnouncementTime(
            at: date(hour: 10, minute: 30, second: 1),
            intervalMinutes: 30,
            gracePeriod: 2,
            calendar: calendar
        ))
        XCTAssertFalse(TimeAnnouncementSchedule.isClockAlignedAnnouncementTime(
            at: date(hour: 10, minute: 59, second: 0),
            intervalMinutes: 30,
            gracePeriod: 2,
            calendar: calendar
        ))
    }

    func testDelayUsesNextThirtyMinuteBoundary() {
        let delay = TimeAnnouncementSchedule.delayToNextClockAlignedBoundary(
            from: date(hour: 10, minute: 29, second: 30),
            intervalMinutes: 30,
            calendar: calendar
        )

        XCTAssertEqual(delay, 30, accuracy: 0.001)
    }

    private func date(hour: Int, minute: Int, second: Int) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 5,
            day: 21,
            hour: hour,
            minute: minute,
            second: second
        ).date!
    }
}
