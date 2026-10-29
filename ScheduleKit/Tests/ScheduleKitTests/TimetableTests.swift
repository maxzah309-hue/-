import XCTest
@testable import ScheduleKit

final class TimetableTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
        return calendar
    }()

    private func date(_ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private func time(_ hour: Int, _ minute: Int) -> TimeOfDay { TimeOfDay(hour: hour, minute: minute) }

    // 1 сентября 2026 — вторник, значит первая неделя — 31 августа … 6 сентября.
    private func makeTimetable(swapParity: Bool = false) -> Timetable {
        let lessons = [
            Lesson(title: "Матан", room: "305", weekday: 1, start: time(9, 0), end: time(10, 30)),
            Lesson(title: "Физика", weekday: 1, start: time(10, 40), end: time(12, 10), weeks: .odd),
            Lesson(title: "Химия", weekday: 1, start: time(10, 40), end: time(12, 10), weeks: .even),
            Lesson(title: "История", weekday: 3, start: time(13, 0), end: time(14, 30)),
        ]
        let schedule = Schedule(lessons: lessons, semesterStart: date(9, 1), swapParity: swapParity)
        return Timetable(schedule: schedule, calendar: calendar)
    }

    func testWeekday() {
        let timetable = makeTimetable()
        XCTAssertEqual(timetable.weekday(of: date(9, 7)), 1)
        XCTAssertEqual(timetable.weekday(of: date(9, 1)), 2)
        XCTAssertEqual(timetable.weekday(of: date(9, 6)), 7)
    }

    func testWeekNumberAndParity() {
        let timetable = makeTimetable()
        XCTAssertEqual(timetable.weekNumber(of: date(8, 31)), 1)
        XCTAssertEqual(timetable.weekNumber(of: date(9, 6, 23, 59)), 1)
        XCTAssertEqual(timetable.weekNumber(of: date(9, 7)), 2)
        XCTAssertEqual(timetable.weekNumber(of: date(10, 29)), 9)
        XCTAssertEqual(timetable.weekNumber(of: date(8, 30)), 0)
        XCTAssertEqual(timetable.parity(of: date(9, 1)), .odd)
        XCTAssertEqual(timetable.parity(of: date(9, 7)), .even)
        XCTAssertEqual(timetable.parity(of: date(8, 30)), .even)
        XCTAssertEqual(makeTimetable(swapParity: true).parity(of: date(9, 1)), .even)
    }

    func testLessonsRespectParity() {
        let timetable = makeTimetable()
        XCTAssertEqual(timetable.lessons(on: date(9, 7)).map(\.lesson.title), ["Матан", "Химия"])
        XCTAssertEqual(timetable.lessons(on: date(9, 14)).map(\.lesson.title), ["Матан", "Физика"])
        XCTAssertEqual(timetable.lessons(on: date(9, 8)).map(\.lesson.title), [])
    }

    func testCurrentAndNext() {
        let timetable = makeTimetable()

        let during = timetable.status(at: date(9, 7, 9, 30))
        XCTAssertEqual(during.current?.lesson.title, "Матан")
        XCTAssertEqual(during.next?.lesson.title, "Химия")
        XCTAssertEqual(during.next?.start, date(9, 7, 10, 40))

        let breakTime = timetable.status(at: date(9, 7, 10, 35))
        XCTAssertNil(breakTime.current)
        XCTAssertEqual(breakTime.next?.lesson.title, "Химия")

        // Ровно в момент начала пара уже идёт, а следующей становится другая.
        let atStart = timetable.status(at: date(9, 7, 10, 40))
        XCTAssertEqual(atStart.current?.lesson.title, "Химия")
        XCTAssertEqual(atStart.next?.lesson.title, "История")

        XCTAssertEqual(timetable.next(after: date(9, 7, 12, 30))?.start, date(9, 9, 13, 0))
        // После среды — через выходные на понедельник нечётной недели.
        let afterWeekend = timetable.next(after: date(9, 9, 15, 0))
        XCTAssertEqual(afterWeekend?.lesson.title, "Матан")
        XCTAssertEqual(afterWeekend?.start, date(9, 14, 9, 0))
    }

    func testEmptySchedule() {
        let timetable = Timetable(schedule: Schedule(semesterStart: date(9, 1)), calendar: calendar)
        XCTAssertNil(timetable.next(after: date(9, 7)))
        XCTAssertNil(timetable.current(at: date(9, 7)))
        XCTAssertEqual(timetable.changeDates(after: date(9, 7, 8, 0), days: 2), [date(9, 8), date(9, 9)])
    }

    func testChangeDates() {
        let timetable = makeTimetable()
        XCTAssertEqual(
            timetable.changeDates(after: date(9, 7, 9, 30), days: 1),
            [date(9, 7, 10, 30), date(9, 7, 10, 40), date(9, 7, 12, 10), date(9, 8)]
        )
    }

    func testCodingRoundTrip() throws {
        let schedule = makeTimetable().schedule
        let decoded = try ScheduleCoding.decode(ScheduleCoding.encode(schedule))
        XCTAssertEqual(decoded, schedule)
    }

    func testTimeOfDay() {
        XCTAssertEqual(TimeOfDay(parsing: "9:05"), time(9, 5))
        XCTAssertEqual(TimeOfDay(parsing: " 09.05 "), time(9, 5))
        XCTAssertNil(TimeOfDay(parsing: "24:00"))
        XCTAssertNil(TimeOfDay(parsing: "9"))
        XCTAssertEqual(time(9, 5).text, "09:05")
        XCTAssertEqual(time(23, 30).adding(minutes: 90), time(23, 59))
    }
}
