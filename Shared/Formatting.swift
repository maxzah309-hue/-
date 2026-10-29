import Foundation
import ScheduleKit

extension Lesson {
    /// «10:40–12:10»
    var timeRange: String { "\(start.text)–\(end.text)" }

    /// «ауд. 305 · лекция»
    var details: String {
        [room, kind].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var weekdayShort: String { WeekdayNames.short[(weekday - 1 + 7) % 7] }
    var weekdayFull: String { WeekdayNames.full[(weekday - 1 + 7) % 7] }
}

extension LessonOccurrence {
    /// «сегодня», «завтра» или «пн».
    func dayLabel(relativeTo now: Date, calendar: Calendar = .current) -> String {
        if calendar.isDate(start, inSameDayAs: now) { return "сегодня" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(start, inSameDayAs: tomorrow) {
            return "завтра"
        }
        return lesson.weekdayShort.lowercased()
    }

    func isToday(relativeTo now: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(start, inSameDayAs: now)
    }
}
