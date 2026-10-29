import Foundation

public struct ImportResult: Sendable {
    public var lessons: [Lesson]
    /// Строки, которые не получилось разобрать, с объяснением.
    public var errors: [String]

    public init(lessons: [Lesson] = [], errors: [String] = []) {
        self.lessons = lessons
        self.errors = errors
    }
}

/// Читает расписание из CSV (Excel, Google Таблицы, Numbers) или JSON.
public enum ScheduleImporter {
    public static let formatHint = """
        Каждая строка — одна пара: день;начало;конец;предмет;тип;аудитория;преподаватель;неделя. \
        Обязательны день, время и предмет. Неделя: пусто — каждую, «нечёт»/«числитель» или «чёт»/«знаменатель». \
        Разделитель — точка с запятой, запятая или табуляция; первая строка может быть заголовком.
        """

    public static func importData(_ data: Data) -> ImportResult {
        guard let text = decodeText(data) else {
            return ImportResult(errors: ["Не удалось прочитать файл: неизвестная кодировка."])
        }
        return importText(text)
    }

    public static func importText(_ text: String) -> ImportResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
            return importJSON(Data(trimmed.utf8))
        }
        return importCSV(trimmed)
    }

    // MARK: - JSON

    private static func importJSON(_ data: Data) -> ImportResult {
        let decoder = ScheduleCoding.decoder
        do {
            // Подходит и резервная копия целиком, и просто массив пар.
            let lessons = data.first == UInt8(ascii: "[")
                ? try decoder.decode([Lesson].self, from: data)
                : try decoder.decode(Schedule.self, from: data).lessons
            return ImportResult(lessons: lessons)
        } catch {
            return ImportResult(errors: ["Не удалось прочитать JSON: \(error.localizedDescription)"])
        }
    }

    // MARK: - CSV

    private enum Column: CaseIterable {
        case day, start, end, title, kind, room, teacher, weeks

        var aliases: [String] {
            switch self {
            case .day: ["день", "день недели", "day", "weekday"]
            case .start: ["начало", "с", "время", "время начала", "start", "time"]
            case .end: ["конец", "до", "окончание", "время окончания", "end"]
            case .title: ["предмет", "дисциплина", "название", "занятие", "subject", "title"]
            case .kind: ["тип", "вид", "тип занятия", "вид занятия", "kind", "type"]
            case .room: ["аудитория", "ауд", "кабинет", "место", "room"]
            case .teacher: ["преподаватель", "препод", "преподаватели", "teacher"]
            case .weeks: ["неделя", "недели", "четность", "week", "weeks"]
            }
        }
    }

    private static let defaultColumns: [Column] = [.day, .start, .end, .title, .kind, .room, .teacher, .weeks]

    private static func importCSV(_ text: String) -> ImportResult {
        var rows = parseRows(text)
        var columns = Dictionary(uniqueKeysWithValues: defaultColumns.enumerated().map { ($1, $0) })
        var firstLine = 1
        if let header = rows.first, let mapping = headerMapping(header) {
            columns = mapping
            rows.removeFirst()
            firstLine = 2
        }

        var result = ImportResult()
        var lastWeekday: Int?
        for (index, row) in rows.enumerated() {
            let line = index + firstLine
            let cells = row.map { $0.trimmingCharacters(in: .whitespaces) }
            if cells.allSatisfy(\.isEmpty) { continue }

            func value(_ column: Column) -> String {
                guard let position = columns[column], position < cells.count else { return "" }
                return cells[position]
            }

            let dayText = value(.day)
            if !dayText.isEmpty {
                guard let weekday = parseWeekday(dayText) else {
                    result.errors.append("Строка \(line): не понял день недели «\(dayText)».")
                    continue
                }
                lastWeekday = weekday
            }
            // Строка-заголовок дня вроде «Понедельник;;;» — запоминаем день и идём дальше.
            if Column.allCases.filter({ $0 != .day }).allSatisfy({ value($0).isEmpty }) { continue }
            guard let weekday = lastWeekday else {
                result.errors.append("Строка \(line): не указан день недели.")
                continue
            }

            var startText = value(.start)
            var endText = value(.end)
            if endText.isEmpty, let range = splitTimeRange(startText) {
                (startText, endText) = range
            }
            guard let start = TimeOfDay(parsing: startText), let end = TimeOfDay(parsing: endText) else {
                let time = [startText, endText].filter { !$0.isEmpty }.joined(separator: "–")
                result.errors.append("Строка \(line): не понял время «\(time)».")
                continue
            }
            guard end > start else {
                result.errors.append("Строка \(line): пара заканчивается раньше, чем начинается.")
                continue
            }
            let title = value(.title)
            guard !title.isEmpty else {
                result.errors.append("Строка \(line): не указан предмет.")
                continue
            }
            let weeksText = value(.weeks)
            guard let weeks = parseWeeks(weeksText) else {
                result.errors.append("Строка \(line): не понял неделю «\(weeksText)». Пишите «нечёт», «чёт» или оставьте пустым.")
                continue
            }

            result.lessons.append(Lesson(
                title: title,
                kind: value(.kind),
                room: value(.room),
                teacher: value(.teacher),
                weekday: weekday,
                start: start,
                end: end,
                weeks: weeks
            ))
        }
        return result
    }

    /// Если строка похожа на заголовок — возвращает номера столбцов.
    private static func headerMapping(_ row: [String]) -> [Column: Int]? {
        guard let first = row.first, parseWeekday(first) == nil else { return nil }
        var mapping: [Column: Int] = [:]
        for (index, cell) in row.enumerated() {
            let name = normalize(cell).trimmingCharacters(in: CharacterSet(charactersIn: ".:"))
            if let column = Column.allCases.first(where: { $0.aliases.contains(name) }), mapping[column] == nil {
                mapping[column] = index
            }
        }
        guard mapping[.title] != nil, mapping[.day] != nil || mapping[.start] != nil else { return nil }
        return mapping
    }

    static func parseRows(_ text: String) -> [[String]] {
        let delimiter = detectDelimiter(text)
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        let characters = Array(text)
        var index = 0
        while index < characters.count {
            let character = characters[index]
            if inQuotes {
                if character == "\"" {
                    if index + 1 < characters.count, characters[index + 1] == "\"" {
                        field.append("\"")
                        index += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else if character == "\"" {
                inQuotes = true
            } else if character == delimiter {
                row.append(field)
                field = ""
            } else if character.isNewline {
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else {
                field.append(character)
            }
            index += 1
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }

    private static func detectDelimiter(_ text: String) -> Character {
        let firstLine = text.split(whereSeparator: \.isNewline).first ?? ""
        let candidates: [Character] = [";", "\t", ","]
        return candidates.max { a, b in firstLine.filter { $0 == a }.count < firstLine.filter { $0 == b }.count } ?? ";"
    }

    // MARK: - Значения

    static func parseWeekday(_ text: String) -> Int? {
        let value = normalize(text).trimmingCharacters(in: CharacterSet(charactersIn: "."))
        if let number = Int(value), (1...7).contains(number) { return number }
        let prefixes: [(String, Int)] = [
            ("пн", 1), ("пон", 1), ("mon", 1),
            ("вт", 2), ("tue", 2),
            ("ср", 3), ("wed", 3),
            ("чт", 4), ("чет", 4), ("thu", 4),
            ("пт", 5), ("пят", 5), ("fri", 5),
            ("сб", 6), ("суб", 6), ("sat", 6),
            ("вс", 7), ("вос", 7), ("sun", 7),
        ]
        return prefixes.first { value.hasPrefix($0.0) }?.1
    }

    static func parseWeeks(_ text: String) -> WeekParity? {
        let value = normalize(text)
        if value.isEmpty { return .every }
        // «нечёт» проверяем раньше «чёт», потому что содержит его.
        func mentions(_ parts: [String]) -> Bool { parts.contains { value.contains($0) } }
        if mentions(["неч", "числ", "верх", "odd"]) || value.hasPrefix("1") { return .odd }
        if mentions(["чет", "знам", "ниж", "even"]) || value.hasPrefix("2") { return .even }
        if ["все", "кажд", "еженед", "every", "all", "-", "—"].contains(where: { value.hasPrefix($0) }) { return .every }
        return nil
    }

    /// «9:00-10:30» → («9:00», «10:30»)
    private static func splitTimeRange(_ text: String) -> (String, String)? {
        let parts = text.split(whereSeparator: { "-–—".contains($0) }).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2, TimeOfDay(parsing: parts[0]) != nil, TimeOfDay(parsing: parts[1]) != nil else { return nil }
        return (parts[0], parts[1])
    }

    private static func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespaces)
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
    }

    private static func decodeText(_ data: Data) -> String? {
        var bytes = data
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) { bytes.removeFirst(3) }
        // Excel на Windows часто сохраняет CSV в Windows-1251.
        return String(data: bytes, encoding: .utf8) ?? String(data: bytes, encoding: .windowsCP1251)
    }
}

/// CSV в том же формате, который понимает импорт, — для резервной копии и правки в таблицах.
public enum ScheduleExporter {
    public static func csv(_ lessons: [Lesson]) -> String {
        let header = "день;начало;конец;предмет;тип;аудитория;преподаватель;неделя"
        let rows = lessons
            .sorted { ($0.weekday, $0.start, $0.title) < ($1.weekday, $1.start, $1.title) }
            .map { lesson in
                [
                    WeekdayNames.short[(lesson.weekday - 1 + 7) % 7],
                    lesson.start.text,
                    lesson.end.text,
                    lesson.title,
                    lesson.kind,
                    lesson.room,
                    lesson.teacher,
                    lesson.weeks.shortTitle,
                ]
                .map(escape)
                .joined(separator: ";")
            }
        return ([header] + rows).joined(separator: "\n") + "\n"
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == ";" || $0 == "\"" || $0.isNewline }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
