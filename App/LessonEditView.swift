import ScheduleKit
import SwiftUI

struct LessonEditView: View {
    @Environment(ScheduleModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var lesson: Lesson
    private let isNew: Bool

    init(lesson: Lesson, isNew: Bool) {
        _lesson = State(initialValue: lesson)
        self.isNew = isNew
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Предмет", text: $lesson.title)
                    TextField("Тип: лекция, практика…", text: $lesson.kind)
                    TextField("Аудитория", text: $lesson.room)
                    TextField("Преподаватель", text: $lesson.teacher)
                }

                Section {
                    Picker("День", selection: $lesson.weekday) {
                        ForEach(1...7, id: \.self) { weekday in
                            Text(WeekdayNames.full[weekday - 1]).tag(weekday)
                        }
                    }
                    DatePicker("Начало", selection: time(\.start), displayedComponents: .hourAndMinute)
                    DatePicker("Конец", selection: time(\.end), displayedComponents: .hourAndMinute)
                    Picker("Неделя", selection: $lesson.weeks) {
                        ForEach(WeekParity.allCases, id: \.self) { parity in
                            Text(parity.title).tag(parity)
                        }
                    }
                } footer: {
                    if lesson.end <= lesson.start {
                        Text("Пара должна заканчиваться позже, чем начинается.")
                            .foregroundStyle(.red)
                    }
                }

                if !isNew {
                    Section {
                        Button("Удалить пару", role: .destructive) {
                            model.delete([lesson.id])
                            dismiss()
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isNew ? "Новая пара" : "Пара")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        lesson.title = lesson.title.trimmingCharacters(in: .whitespaces)
                        model.save(lesson)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !lesson.title.trimmingCharacters(in: .whitespaces).isEmpty && lesson.end > lesson.start
    }

    private func time(_ keyPath: WritableKeyPath<Lesson, TimeOfDay>) -> Binding<Date> {
        Binding(
            get: {
                let value = lesson[keyPath: keyPath]
                return Calendar.current.date(bySettingHour: value.hour, minute: value.minute, second: 0, of: .now) ?? .now
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                lesson[keyPath: keyPath] = TimeOfDay(hour: components.hour ?? 0, minute: components.minute ?? 0)
            }
        )
    }
}
