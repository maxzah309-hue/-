import Foundation
import Observation
import ScheduleKit
import WidgetKit

@Observable
final class ScheduleModel {
    private(set) var schedule: Schedule
    var errorMessage: String?

    init() {
        schedule = ScheduleStore.load()
    }

    var timetable: Timetable { Timetable(schedule: schedule) }

    /// Любое изменение сразу сохраняется и обновляет виджеты.
    func update(_ change: (inout Schedule) -> Void) {
        change(&schedule)
        do {
            try ScheduleStore.save(schedule)
        } catch {
            errorMessage = "Не удалось сохранить расписание: \(error.localizedDescription)"
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    func save(_ lesson: Lesson) {
        update { schedule in
            if let index = schedule.lessons.firstIndex(where: { $0.id == lesson.id }) {
                schedule.lessons[index] = lesson
            } else {
                schedule.lessons.append(lesson)
            }
        }
    }

    func delete(_ ids: Set<UUID>) {
        update { schedule in schedule.lessons.removeAll { ids.contains($0.id) } }
    }

    func replaceLessons(_ lessons: [Lesson]) {
        update { schedule in schedule.lessons = lessons }
    }

    func appendLessons(_ lessons: [Lesson]) {
        update { schedule in schedule.lessons += lessons }
    }
}
