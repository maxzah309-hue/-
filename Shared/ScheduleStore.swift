import Foundation
import ScheduleKit

/// Файл с расписанием в общей папке App Group — его читает и приложение, и виджет.
enum ScheduleStore {
    static var appGroupID: String? {
        // AltStore и SideStore при установке переименовывают группу и кладут настоящее имя сюда.
        if let groups = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String], let group = groups.first {
            return group
        }
        return Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String
    }

    static var fileURL: URL {
        let directory = appGroupID.flatMap { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) }
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent("schedule.json")
    }

    static func load() -> Schedule {
        guard let data = try? Data(contentsOf: fileURL), let schedule = try? ScheduleCoding.decode(data) else {
            return Schedule()
        }
        return schedule
    }

    static func save(_ schedule: Schedule) throws {
        try ScheduleCoding.encode(schedule).write(to: fileURL, options: .atomic)
    }
}
