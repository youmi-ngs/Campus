import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case timetable
    case tasks
    case courses
    case settings
}

/// タブバーで4つの役割を分ける。HIG の「主要な機能を同じ階層に並べる」構成に合わせている。
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \Semester.startDate, order: .reverse) private var semesters: [Semester]
    @Query(filter: #Predicate<TaskItem> { $0.isDone == false }) private var openTasks: [TaskItem]

    @State private var selection: AppTab = .timetable

    /// タブバーのバッジは、To-Do タブに並ぶ件数と同じにする。
    private var todoCount: Int {
        TaskBoard.groups(from: openTasks).count
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Timetable", systemImage: "square.grid.3x3", value: AppTab.timetable) {
                TimetableView()
            }

            Tab("To-Do", systemImage: "checklist", value: AppTab.tasks) {
                TaskListView()
            }
            .badge(todoCount)

            Tab("Courses", systemImage: "books.vertical", value: AppTab.courses) {
                CourseListView()
            }

            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
        .task {
            NotificationManager.shared.bootstrap()
            await NotificationManager.shared.refreshAuthorizationStatus()
            await TaskSyncCoordinator.shared.sync(context: context)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await TaskSyncCoordinator.shared.sync(context: context) }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(PreviewData.container)
}
