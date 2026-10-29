import XCTest
@testable import ScheduleKit

final class ImporterTests: XCTestCase {
    func testCSVWithHeader() {
        let csv = """
            День;Начало;Конец;Предмет;Тип;Аудитория;Преподаватель;Неделя
            Понедельник;9:00;10:30;Математический анализ;лекция;305;Иванов И.И.;
            ;10:40;12:10;Физика;практика;212;Петров П.П.;нечёт
            Вт;9.00;10.30;Химия;лаба;Б-101;;знаменатель
            """
        let result = ScheduleImporter.importText(csv)
        XCTAssertEqual(result.errors, [])
        XCTAssertEqual(result.lessons.map(\.title), ["Математический анализ", "Физика", "Химия"])
        XCTAssertEqual(result.lessons.map(\.weekday), [1, 1, 2])
        XCTAssertEqual(result.lessons.map(\.weeks), [.every, .odd, .even])
        XCTAssertEqual(result.lessons[0].room, "305")
        XCTAssertEqual(result.lessons[0].teacher, "Иванов И.И.")
        XCTAssertEqual(result.lessons[1].start, TimeOfDay(hour: 10, minute: 40))
        XCTAssertEqual(result.lessons[2].kind, "лаба")
    }

    func testCSVWithoutHeaderCommaAndQuotes() {
        let csv = "Mon,09:00,10:30,\"Английский, группа 2\",семинар,410\r\nfri,13:00,14:30,История,,\r\n"
        let result = ScheduleImporter.importText(csv)
        XCTAssertEqual(result.errors, [])
        XCTAssertEqual(result.lessons.map(\.title), ["Английский, группа 2", "История"])
        XCTAssertEqual(result.lessons.map(\.weekday), [1, 5])
    }

    func testHeaderInOtherOrderAndTimeRange() {
        let csv = """
            предмет\tвремя\tдень
            Матан\t9:00-10:30\tсреда
            """
        let result = ScheduleImporter.importText(csv)
        XCTAssertEqual(result.errors, [])
        XCTAssertEqual(result.lessons.first?.weekday, 3)
        XCTAssertEqual(result.lessons.first?.start, TimeOfDay(hour: 9, minute: 0))
        XCTAssertEqual(result.lessons.first?.end, TimeOfDay(hour: 10, minute: 30))
    }

    func testDayHeaderRowsAndErrors() {
        let csv = """
            Четверг;;;
            ;9:00;10:30;Матан
            ;10:40;10:00;Физика
            Завтра;12:00;13:30;Химия
            Сб;12:00;13:30;
            Сб;кек;13:30;Биология
            Сб;12:00;13:30;Биология;;;;раз в месяц
            """
        let result = ScheduleImporter.importText(csv)
        XCTAssertEqual(result.lessons.map(\.title), ["Матан"])
        XCTAssertEqual(result.lessons.first?.weekday, 4)
        XCTAssertEqual(result.errors.count, 5)
        XCTAssertTrue(result.errors[0].hasPrefix("Строка 3"))
        XCTAssertTrue(result.errors[1].contains("Завтра"))
    }

    func testParsers() {
        XCTAssertEqual(ScheduleImporter.parseWeekday("ПН"), 1)
        XCTAssertEqual(ScheduleImporter.parseWeekday("четверг"), 4)
        XCTAssertEqual(ScheduleImporter.parseWeekday("Пятница"), 5)
        XCTAssertEqual(ScheduleImporter.parseWeekday("вс."), 7)
        XCTAssertEqual(ScheduleImporter.parseWeekday("6"), 6)
        XCTAssertNil(ScheduleImporter.parseWeekday("день"))

        XCTAssertEqual(ScheduleImporter.parseWeeks(""), .every)
        XCTAssertEqual(ScheduleImporter.parseWeeks("каждая"), .every)
        XCTAssertEqual(ScheduleImporter.parseWeeks("Нечётная"), .odd)
        XCTAssertEqual(ScheduleImporter.parseWeeks("числитель"), .odd)
        XCTAssertEqual(ScheduleImporter.parseWeeks("верхняя"), .odd)
        XCTAssertEqual(ScheduleImporter.parseWeeks("чётная"), .even)
        XCTAssertEqual(ScheduleImporter.parseWeeks("знаменатель"), .even)
        XCTAssertEqual(ScheduleImporter.parseWeeks("2"), .even)
        XCTAssertNil(ScheduleImporter.parseWeeks("иногда"))
    }

    func testJSON() {
        let json = """
            [{"title": "Матан", "weekday": 2, "start": "9:00", "end": "10:30", "weeks": "odd"}]
            """
        let result = ScheduleImporter.importText(json)
        XCTAssertEqual(result.errors, [])
        XCTAssertEqual(result.lessons.first?.title, "Матан")
        XCTAssertEqual(result.lessons.first?.weeks, .odd)
        XCTAssertEqual(result.lessons.first?.room, "")

        XCTAssertEqual(ScheduleImporter.importText("[{\"title\": 1}]").errors.count, 1)
    }

    func testWindows1251() {
        let data = "Пн;9:00;10:30;Матан\n".data(using: .windowsCP1251)!
        XCTAssertEqual(ScheduleImporter.importData(data).lessons.first?.title, "Матан")
    }

    func testUTF8BOM() {
        let data = Data([0xEF, 0xBB, 0xBF]) + Data("день;начало;конец;предмет\nПн;9:00;10:30;Матан".utf8)
        let result = ScheduleImporter.importData(data)
        XCTAssertEqual(result.errors, [])
        XCTAssertEqual(result.lessons.first?.title, "Матан")
    }

    func testExportRoundTrip() {
        let lessons = [
            Lesson(title: "Физика; практика", kind: "пр", room: "212", teacher: "Петров \"Пётр\"", weekday: 5,
                   start: TimeOfDay(hour: 10, minute: 40), end: TimeOfDay(hour: 12, minute: 10), weeks: .even),
            Lesson(title: "Матан", weekday: 1, start: TimeOfDay(hour: 9, minute: 0), end: TimeOfDay(hour: 10, minute: 30), weeks: .odd),
            Lesson(title: "История", weekday: 1, start: TimeOfDay(hour: 13, minute: 0), end: TimeOfDay(hour: 14, minute: 30)),
        ]
        let result = ScheduleImporter.importText(ScheduleExporter.csv(lessons))
        XCTAssertEqual(result.errors, [])

        func fields(_ lesson: Lesson) -> [String] {
            [lesson.title, lesson.kind, lesson.room, lesson.teacher, "\(lesson.weekday)", lesson.start.text, lesson.end.text, lesson.weeks.rawValue]
        }
        XCTAssertEqual(result.lessons.map(fields), [lessons[1], lessons[2], lessons[0]].map(fields))
    }
}
