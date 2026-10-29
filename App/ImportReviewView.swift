import ScheduleKit
import SwiftUI

/// Показывает, что нашлось в файле, и спрашивает, заменить расписание или дополнить.
struct ImportReviewView: View {
    @Environment(ScheduleModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let result: ImportResult

    var body: some View {
        NavigationStack {
            List {
                if result.lessons.isEmpty {
                    Section {
                        Text("Не нашёл ни одной пары.")
                    } footer: {
                        Text(ScheduleImporter.formatHint)
                    }
                } else {
                    Section {
                        Button(replaceTitle) {
                            model.replaceLessons(result.lessons)
                            dismiss()
                        }
                        if !model.schedule.lessons.isEmpty {
                            Button("Добавить к текущему") {
                                model.appendLessons(result.lessons)
                                dismiss()
                            }
                        }
                    } header: {
                        Text("Найдено пар: \(result.lessons.count)")
                    }
                }

                if !result.errors.isEmpty {
                    Section("Не удалось разобрать") {
                        ForEach(Array(result.errors.enumerated()), id: \.offset) { item in
                            Text(item.element)
                                .font(.footnote)
                        }
                    }
                }

                if !result.lessons.isEmpty {
                    Section("Что загрузится") {
                        ForEach(result.lessons) { lesson in
                            HStack(alignment: .firstTextBaseline) {
                                Text(lesson.weekdayShort)
                                    .font(.subheadline.weight(.semibold))
                                    .frame(width: 28, alignment: .leading)
                                LessonRow(lesson: lesson)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Импорт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }

    private var replaceTitle: String {
        model.schedule.lessons.isEmpty ? "Загрузить" : "Заменить текущее расписание"
    }
}
