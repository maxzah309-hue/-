import SwiftUI

@main
struct RaspisanieApp: App {
    @State private var model = ScheduleModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
        }
    }
}
