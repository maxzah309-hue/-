import Foundation

/// Время суток с точностью до минуты, например 09:00.
public struct TimeOfDay: Hashable, Comparable, Sendable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    /// Понимает «9:00», «09:00» и «9.00».
    public init?(parsing text: String) {
        let parts = text.trimmingCharacters(in: .whitespaces).split(whereSeparator: { $0 == ":" || $0 == "." })
        guard parts.count == 2,
              let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0..<24).contains(hour), (0..<60).contains(minute)
        else { return nil }
        self.init(hour: hour, minute: minute)
    }

    public var minutesSinceMidnight: Int { hour * 60 + minute }

    /// «09:00»
    public var text: String { String(format: "%02d:%02d", hour, minute) }

    public func adding(minutes: Int) -> TimeOfDay {
        let total = min(max(minutesSinceMidnight + minutes, 0), 23 * 60 + 59)
        return TimeOfDay(hour: total / 60, minute: total % 60)
    }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }
}

extension TimeOfDay: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let value = TimeOfDay(parsing: text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Неверное время: \(text)")
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(text)
    }
}

/// По каким неделям идёт пара (числитель/знаменатель).
public enum WeekParity: String, Codable, CaseIterable, Sendable {
    case every, odd, even

    public var title: String {
        switch self {
        case .every: "Каждую неделю"
        case .odd: "По нечётным"
        case .even: "По чётным"
        }
    }

    public var shortTitle: String {
        switch self {
        case .every: ""
        case .odd: "нечёт"
        case .even: "чёт"
        }
    }
}

public enum WeekdayNames {
    /// Индекс 0 — понедельник.
    public static let short = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
    public static let full = ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"]
}

public struct Lesson: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    /// Лекция, практика, лабораторная — что угодно.
    public var kind: String
    public var room: String
    public var teacher: String
    /// День недели: 1 — понедельник … 7 — воскресенье.
    public var weekday: Int
    public var start: TimeOfDay
    public var end: TimeOfDay
    public var weeks: WeekParity

    public init(
        id: UUID = UUID(),
        title: String,
        kind: String = "",
        room: String = "",
        teacher: String = "",
        weekday: Int,
        start: TimeOfDay,
        end: TimeOfDay,
        weeks: WeekParity = .every
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.room = room
        self.teacher = teacher
        self.weekday = weekday
        self.start = start
        self.end = end
        self.weeks = weeks
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, kind, room, teacher, weekday, start, end, weeks
    }

    // Необязательные поля можно не указывать, если JSON пишется руками.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        kind = try container.decodeIfPresent(String.self, forKey: .kind) ?? ""
        room = try container.decodeIfPresent(String.self, forKey: .room) ?? ""
        teacher = try container.decodeIfPresent(String.self, forKey: .teacher) ?? ""
        weekday = try container.decode(Int.self, forKey: .weekday)
        start = try container.decode(TimeOfDay.self, forKey: .start)
        end = try container.decode(TimeOfDay.self, forKey: .end)
        weeks = try container.decodeIfPresent(WeekParity.self, forKey: .weeks) ?? .every
    }
}

public struct Schedule: Codable, Hashable, Sendable {
    public var lessons: [Lesson]
    /// Любой день первой недели семестра. Первая неделя считается нечётной.
    public var semesterStart: Date
    /// Поменять местами чётные и нечётные недели.
    public var swapParity: Bool

    public init(lessons: [Lesson] = [], semesterStart: Date = Schedule.defaultSemesterStart(), swapParity: Bool = false) {
        self.lessons = lessons
        self.semesterStart = semesterStart
        self.swapParity = swapParity
    }

    /// 1 сентября текущего учебного года.
    public static func defaultSemesterStart(now: Date = Date(), calendar: Calendar = .current) -> Date {
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        let startYear = month >= 8 ? year : year - 1
        return calendar.date(from: DateComponents(year: startYear, month: 9, day: 1)) ?? now
    }

    public func lessons(onWeekday weekday: Int) -> [Lesson] {
        lessons
            .filter { $0.weekday == weekday }
            .sorted { ($0.start, $0.title) < ($1.start, $1.title) }
    }

    private enum CodingKeys: String, CodingKey {
        case lessons, semesterStart, swapParity
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lessons = try container.decodeIfPresent([Lesson].self, forKey: .lessons) ?? []
        semesterStart = try container.decodeIfPresent(Date.self, forKey: .semesterStart) ?? Schedule.defaultSemesterStart()
        swapParity = try container.decodeIfPresent(Bool.self, forKey: .swapParity) ?? false
    }
}

public enum ScheduleCoding {
    public static func encode(_ schedule: Schedule) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(schedule)
    }

    public static func decode(_ data: Data) throws -> Schedule {
        try decoder.decode(Schedule.self, from: data)
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
