import CoreTransferable
import ScheduleKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(ScheduleModel.self) private var model
    @State private var selectedWeekday = Timetable(schedule: Schedule()).weekday(of: .now)
    @State private var editRequest: EditRequest?
    @State private var pendingImport: PendingImport?
    @State private var isImporterPresented = false
    @State private var isSettingsPresented = false

    var body: some View {
        NavigationStack {
            Group {
                if model.schedule.lessons.isEmpty {
                    emptyState
                } else {
                    scheduleList
                }
            }
            .navigationTitle("Расписание")
            .toolbar { toolbarItems }
        }
        .sheet(item: $editRequest) { request in
            LessonEditView(lesson: request.lesson, isNew: request.isNew)
                .environment(model)
        }
        .sheet(item: $pendingImport) { pending in
            ImportReviewView(result: pending.result)
                .environment(model)
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
                .environment(model)
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .json, .plainText]
        ) { result in
            importFile(result)
        }
        .alert("Ошибка", isPresented: isErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var scheduleList: some View {
        List {
            Section {
                NextLessonCard()
            }

            Section {
                Picker("День недели", selection: $selectedWeekday) {
                    ForEach(1...7, id: \.self) { weekday in
                        Text(WeekdayNames.short[weekday - 1]).tag(weekday)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: {
                if model.schedule.lessons.contains(where: { $0.weeks != .every }) {
                    let timetable = model.timetable
                    let parity = timetable.parity(of: .now) == .odd ? "нечётная" : "чётная"
                    Text("Сейчас \(timetable.weekNumber(of: .now))-я неделя, \(parity)")
                }
            }

            Section(WeekdayNames.full[selectedWeekday - 1]) {
                let lessons = model.schedule.lessons(onWeekday: selectedWeekday)
                if lessons.isEmpty {
                    Text("Пар нет")
                        .foregroundStyle(.secondary)
                }
                ForEach(lessons) { lesson in
                    Button {
                        editRequest = EditRequest(lesson: lesson, isNew: false)
                    } label: {
                        LessonRow(lesson: lesson)
                    }
                    .foregroundStyle(.primary)
                }
                .onDelete { offsets in
                    model.delete(Set(offsets.map { lessons[$0].id }))
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Расписания пока нет", systemImage: "calendar.badge.plus")
        } description: {
            Text("Загрузите файл CSV, вставьте расписание из буфера обмена или добавьте пары вручную.")
        } actions: {
            Button("Загрузить файл") { isImporterPresented = true }
                .buttonStyle(.borderedProminent)
            Button("Вставить из буфера") { importFromClipboard() }
            Button("Добавить вручную") { addLesson() }
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                isSettingsPresented = true
            } label: {
                Label("Настройки", systemImage: "gearshape")
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu {
                Button {
                    isImporterPresented = true
                } label: {
                    Label("Загрузить файл", systemImage: "doc")
                }
                Button {
                    importFromClipboard()
                } label: {
                    Label("Вставить из буфера", systemImage: "doc.on.clipboard")
                }
                if !model.schedule.lessons.isEmpty {
                    ShareLink(
                        item: CSVFile(text: ScheduleExporter.csv(model.schedule.lessons)),
                        preview: SharePreview("Расписание")
                    ) {
                        Label("Сохранить в CSV", systemImage: "square.and.arrow.up")
                    }
                }
            } label: {
                Label("Импорт и экспорт", systemImage: "square.and.arrow.down")
            }
            Button {
                addLesson()
            } label: {
                Label("Добавить пару", systemImage: "plus")
            }
        }
    }

    private var isErrorPresented: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }

    private func addLesson() {
        let start = model.schedule.lessons(onWeekday: selectedWeekday).last?.end.adding(minutes: 10)
            ?? TimeOfDay(hour: 9, minute: 0)
        let lesson = Lesson(title: "", weekday: selectedWeekday, start: start, end: start.adding(minutes: 90))
        editRequest = EditRequest(lesson: lesson, isNew: true)
    }

    private func importFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let isAccessing = url.startAccessingSecurityScopedResource()
            defer { if isAccessing { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            pendingImport = PendingImport(result: ScheduleImporter.importData(data))
        } catch {
            model.errorMessage = "Не удалось открыть файл: \(error.localizedDescription)"
        }
    }

    private func importFromClipboard() {
        guard let text = UIPasteboard.general.string,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            model.errorMessage = "В буфере обмена нет текста. Скопируйте расписание в формате CSV и попробуйте ещё раз."
            return
        }
        pendingImport = PendingImport(result: ScheduleImporter.importText(text))
    }
}

private struct EditRequest: Identifiable {
    let lesson: Lesson
    let isNew: Bool
    var id: UUID { lesson.id }
}

private struct PendingImport: Identifiable {
    let id = UUID()
    let result: ImportResult
}

private struct CSVFile: Transferable {
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        // BOM нужен, чтобы Excel открыл кириллицу без кракозябр.
        DataRepresentation(exportedContentType: .commaSeparatedText) { file in
            Data(("\u{FEFF}" + file.text).utf8)
        }
        .suggestedFileName("raspisanie.csv")
    }
}
