import ScheduleKit
import SwiftUI

struct LessonRow: View {
    let lesson: Lesson

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(lesson.start.text)
                    .font(.body.monospacedDigit().weight(.semibold))
                Text(lesson.end.text)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.title.isEmpty ? "Без названия" : lesson.title)
                    .font(.body.weight(.medium))
                if !lesson.details.isEmpty {
                    Text(lesson.details)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !lesson.teacher.isEmpty {
                    Text(lesson.teacher)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if lesson.weeks != .every {
                Text(lesson.weeks.shortTitle)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.tint.opacity(0.15), in: Capsule())
            }
        }
        .padding(.vertical, 2)
    }
}

struct NextLessonCard: View {
    @Environment(ScheduleModel.self) private var model

    var body: some View {
        TimelineView(.everyMinute) { context in
            card(status: model.timetable.status(at: context.date), now: context.date)
        }
    }

    private func card(status: TimetableStatus, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let current = status.current {
                Label("Сейчас: \(current.lesson.title), до \(current.lesson.end.text)", systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let next = status.next {
                Text("Следующая пара")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(next.lesson.title)
                    .font(.title3.weight(.semibold))
                Text("\(next.dayLabel(relativeTo: now).capitalized), \(next.lesson.timeRange)")
                    .font(.headline)
                    .foregroundStyle(.tint)
                if !next.lesson.details.isEmpty {
                    Text(next.lesson.details)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Ближайших пар нет")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
