import SwiftData
import SwiftUI

@main
struct KomaApp: App {
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
