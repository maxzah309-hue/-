import Foundation

/// Конкретная пара в конкретный день.
public struct LessonOccurrence: Hashable, Identifiable, Sendable {
    public let lesson: Lesson
    public let start: Date
    public let end: Date

    public init(lesson: Lesson, start: Date, end: Date) {
        self.lesson = lesson
        self.start = start
        self.end = end
    }

    public var id: String { "\(lesson.id)-\(start.timeIntervalSinceReferenceDate)" }
}

public struct TimetableStatus: Hashable, Sendable {
    /// Пара, которая идёт прямо сейчас.
    public let current: LessonOccurrence?
    /// Ближайшая пара, которая ещё не началась.
    public let next: LessonOccurrence?
}

/// Раскладывает недельное расписание по реальным датам с учётом чётности недель.
public struct Timetable {
    public let schedule: Schedule
    public let calendar: Calendar

    public init(schedule: Schedule, calendar: Calendar = .current) {
        var calendar = calendar
        calendar.firstWeekday = 2
        self.schedule = schedule
        self.calendar = calendar
    }

    /// 1 — понедельник … 7 — воскресенье.
    public func weekday(of date: Date) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7 + 1
    }

    /// Номер недели семестра; неделя, в которую попадает `semesterStart`, — первая.
    public func weekNumber(of date: Date) -> Int {
        let days = calendar.dateComponents([.day], from: startOfWeek(schedule.semesterStart), to: startOfWeek(date)).day ?? 0
        return Int((Double(days) / 7).rounded(.down)) + 1
    }

    public func parity(of date: Date) -> WeekParity {
        let isOdd = weekNumber(of: date) % 2 != 0
        return isOdd != schedule.swapParity ? .odd : .even
    }

    public func lessons(on date: Date) -> [LessonOccurrence] {
        let day = calendar.startOfDay(for: date)
        let dayOfWeek = weekday(of: day)
        let weekParity = parity(of: day)
        return schedule.lessons
            .filter { $0.weekday == dayOfWeek && ($0.weeks == .every || $0.weeks == weekParity) }
            .compactMap { occurrence(of: $0, on: day) }
            .sorted { ($0.start, $0.lesson.title) < ($1.start, $1.lesson.title) }
    }

    /// Пары за `days` дней, начиная с дня, в который попадает `date`.
    public func occurrences(from date: Date, days: Int) -> [LessonOccurrence] {
        let first = calendar.startOfDay(for: date)
        return (0..<max(days, 0)).flatMap { offset -> [LessonOccurrence] in
            guard let day = calendar.date(byAdding: .day, value: offset, to: first) else { return [] }
            return lessons(on: day)
        }
    }

    public func current(at date: Date) -> LessonOccurrence? {
        lessons(on: date).first { $0.start <= date && date < $0.end }
    }

    /// Ищем на две недели вперёд — этого хватает при любой чётности.
    public func next(after date: Date) -> LessonOccurrence? {
        occurrences(from: date, days: 15).first { $0.start > date }
    }

    public func status(at date: Date) -> TimetableStatus {
        TimetableStatus(current: current(at: date), next: next(after: date))
    }

    /// Моменты после `date`, когда меняется текущая или следующая пара: начала и концы пар, а также полночь
    /// (чтобы «завтра» вовремя превращалось в «сегодня»). `days` — сколько дней покрыть, считая текущий.
    public func changeDates(after date: Date, days: Int) -> [Date] {
        var dates = Set<Date>()
        for occurrence in occurrences(from: date, days: days) {
            dates.insert(occurrence.start)
            dates.insert(occurrence.end)
        }
        let today = calendar.startOfDay(for: date)
        for offset in 1...max(days, 1) {
            if let midnight = calendar.date(byAdding: .day, value: offset, to: today) {
                dates.insert(midnight)
            }
        }
        return dates.filter { $0 > date }.sorted()
    }

    private func startOfWeek(_ date: Date) -> Date {
        let day = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1 - weekday(of: day), to: day) ?? day
    }

    private func occurrence(of lesson: Lesson, on day: Date) -> LessonOccurrence? {
        guard let start = calendar.date(bySettingHour: lesson.start.hour, minute: lesson.start.minute, second: 0, of: day),
              let end = calendar.date(bySettingHour: lesson.end.hour, minute: lesson.end.minute, second: 0, of: day)
        else { return nil }
        return LessonOccurrence(lesson: lesson, start: start, end: max(start, end))
    }
}
