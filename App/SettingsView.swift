import ScheduleKit
import SwiftUI

struct SettingsView: View {
    @Environment(ScheduleModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingClear = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Сейчас", value: "\(model.timetable.weekNumber(of: .now))-я неделя")
                    Picker("Эта неделя", selection: currentParity) {
                        Text("Нечётная").tag(WeekParity.odd)
                        Text("Чётная").tag(WeekParity.even)
                    }
                    DatePicker("Начало семестра", selection: semesterStart, displayedComponents: .date)
                } header: {
                    Text("Чётность недель")
                } footer: {
                    Text("Нужна, если какие-то пары идут через неделю (числитель и знаменатель). Если неделя определилась неправильно, просто переключите её.")
                }

                Section {
                    Text("1. На заблокированном экране нажмите и подержите палец.\n2. Нажмите «Настроить» и выберите экран блокировки.\n3. Нажмите на область под часами и добавьте виджет «Расписание». Однострочный вариант можно поставить над часами, рядом с датой.")
                        .font(.subheadline)
                } header: {
                    Text("Виджет на экране блокировки")
                }

                Section {
                    Button("Удалить всё расписание", role: .destructive) {
                        isConfirmingClear = true
                    }
                    .disabled(model.schedule.lessons.isEmpty)
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
            .confirmationDialog("Удалить все пары?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) {
                    model.replaceLessons([])
                }
            }
        }
    }

    private var currentParity: Binding<WeekParity> {
        Binding(
            get: { model.timetable.parity(of: .now) },
            set: { parity in
                if parity != model.timetable.parity(of: .now) {
                    model.update { $0.swapParity.toggle() }
                }
            }
        )
    }

    private var semesterStart: Binding<Date> {
        Binding(
            get: { model.schedule.semesterStart },
            set: { date in model.update { $0.semesterStart = date } }
        )
    }
}
