import SwiftData
import SwiftUI

@main
struct CampusApp: App {
    init() {
        AppContainer.seedIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(AppContainer.shared)
    }
}
