import ScheduleKit
import SwiftUI
import WidgetKit

struct LessonEntry: TimelineEntry {
    let date: Date
    let current: LessonOccurrence?
    let next: LessonOccurrence?
    let hasSchedule: Bool

    static var sample: LessonEntry {
        let now = Date()
        let lesson = Lesson(
            title: "Математический анализ",
            kind: "лекция",
            room: "ауд. 305",
            weekday: 1,
            start: TimeOfDay(hour: 10, minute: 40),
            end: TimeOfDay(hour: 12, minute: 10)
        )
        let start = Calendar.current.date(bySettingHour: 10, minute: 40, second: 0, of: now) ?? now
        let next = LessonOccurrence(lesson: lesson, start: start, end: start.addingTimeInterval(90 * 60))
        return LessonEntry(date: now, current: nil, next: next, hasSchedule: true)
    }

    /// Пусто, если пара сегодня, иначе «Завтра, » или «Пн, ».
    func dayPrefix(_ occurrence: LessonOccurrence, separator: String = ", ") -> String {
        occurrence.isToday(relativeTo: date) ? "" : occurrence.dayLabel(relativeTo: date).capitalized + separator
    }
}

struct LessonProvider: TimelineProvider {
    func placeholder(in context: Context) -> LessonEntry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping (LessonEntry) -> Void) {
        let schedule = ScheduleStore.load()
        if context.isPreview && schedule.lessons.isEmpty {
            completion(.sample)
        } else {
            completion(entry(at: Date(), timetable: Timetable(schedule: schedule)))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LessonEntry>) -> Void) {
        let timetable = Timetable(schedule: ScheduleStore.load())
        let now = Date()
        // Отдельная запись на каждое начало и конец пары — так виджет переключается минута в минуту.
        let dates = [now] + timetable.changeDates(after: now, days: 2).prefix(80)
        let entries = dates.map { entry(at: $0, timetable: timetable) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date, timetable: Timetable) -> LessonEntry {
        let status = timetable.status(at: date)
        return LessonEntry(
            date: date,
            current: status.current,
            next: status.next,
            hasSchedule: !timetable.schedule.lessons.isEmpty
        )
    }
}

struct NextLessonWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextLessonWidget", provider: LessonProvider()) { entry in
            LessonWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackground()
                }
        }
        .configurationDisplayName("Следующая пара")
        .description("Какая пара следующая, во сколько и где.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCircular, .systemSmall])
    }
}

@main
struct RaspisanieWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextLessonWidget()
    }
}

// MARK: - Views

struct LessonWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LessonEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            InlineLessonView(entry: entry)
        case .accessoryCircular:
            CircularLessonView(entry: entry)
        case .accessoryRectangular:
            RectangularLessonView(entry: entry)
        default:
            SmallLessonView(entry: entry)
        }
    }
}

private struct WidgetBackground: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline, .accessoryCircular, .accessoryRectangular:
            Color.clear
        default:
            Rectangle().fill(.background)
        }
    }
}

/// Экран блокировки, под часами.
private struct RectangularLessonView: View {
    let entry: LessonEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let next = entry.next {
                if let current = entry.current {
                    // Идёт пара: сверху когда она кончится, ниже — следующая.
                    let room = next.lesson.room.isEmpty ? "" : " · " + next.lesson.room
                    Text("Сейчас: \(current.lesson.title), до \(current.lesson.end.text)")
                        .font(.caption)
                        .lineLimit(1)
                    Text(entry.dayPrefix(next) + next.lesson.start.text + room)
                        .font(.headline)
                        .lineLimit(1)
                        .widgetAccentable()
                    Text(next.lesson.title)
                        .lineLimit(1)
                } else {
                    Text(entry.dayPrefix(next) + next.lesson.timeRange)
                        .font(.headline)
                        .lineLimit(1)
                        .widgetAccentable()
                    Text(next.lesson.title)
                        .lineLimit(1)
                    if !next.lesson.details.isEmpty {
                        Text(next.lesson.details)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Расписание")
                    .font(.headline)
                    .widgetAccentable()
                Text(entry.hasSchedule ? "Ближайших пар нет" : "Добавьте пары в приложении")
                    .font(.caption)
            }
        }
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Экран блокировки, одна строка над часами.
private struct InlineLessonView: View {
    let entry: LessonEntry

    var body: some View {
        if let next = entry.next {
            let room = next.lesson.room.isEmpty ? "" : " · " + next.lesson.room
            Text(entry.dayPrefix(next, separator: " ") + next.lesson.start.text + " " + next.lesson.title + room)
        } else {
            Text(entry.hasSchedule ? "Пар нет" : "Добавьте расписание")
        }
    }
}

/// Экран блокировки, кружок: время начала и аудитория.
private struct CircularLessonView: View {
    let entry: LessonEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let next = entry.next {
                VStack(spacing: 0) {
                    if next.isToday(relativeTo: entry.date) {
                        Image(systemName: "graduationcap.fill")
                            .font(.caption2)
                    } else {
                        Text(next.lesson.weekdayShort)
                            .font(.caption2.weight(.semibold))
                    }
                    Text(next.lesson.start.text)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .minimumScaleFactor(0.6)
                        .widgetAccentable()
                    if !next.lesson.room.isEmpty {
                        Text(next.lesson.room)
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
                .padding(4)
            } else {
                Image(systemName: "calendar")
            }
        }
    }
}

/// Домашний экран.
private struct SmallLessonView: View {
    let entry: LessonEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let next = entry.next {
                Text(entry.current == nil ? "Следующая пара" : "Далее")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(next.lesson.title)
                    .font(.headline)
                    .lineLimit(3)
                Spacer(minLength: 0)
                Text(next.lesson.timeRange)
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.tint)
                if next.isToday(relativeTo: entry.date) {
                    Text("через \(next.start, style: .relative)")
                        .font(.caption)
                } else {
                    Text(next.dayLabel(relativeTo: entry.date).capitalized)
                        .font(.caption)
                }
                if !next.lesson.room.isEmpty {
                    Text(next.lesson.room)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Расписание")
                    .font(.headline)
                Spacer(minLength: 0)
                Text(entry.hasSchedule ? "Ближайших пар нет" : "Добавьте пары в приложении")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
