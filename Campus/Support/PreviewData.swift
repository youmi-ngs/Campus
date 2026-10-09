import Foundation
import SwiftData

/// Xcode プレビュー用のサンプルデータ。
@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: AppContainer.schema,
                configurations: [ModelConfiguration(schema: AppContainer.schema, isStoredInMemoryOnly: true)]
            )
        } catch {
            fatalError("プレビュー用のコンテナを作れませんでした: \(error)")
        }

        let context = container.mainContext
        let range = Semester.suggestedRange()
        let semester = Semester(
            name: Semester.suggestedName(),
            startDate: range.start,
            endDate: range.end,
            isCurrent: true
        )
        context.insert(semester)

        let samples: [(String, String, String, Int, Int, Int, Bool, Bool)] = [
            ("Information Design Studio", "Prof. Sato", "Bldg 3, Rm 402", 0, 2, 1, true, true),
            ("Linear Algebra II", "Prof. Tanaka", "Bldg 1, Rm 115", 2, 3, 2, true, false),
            ("Media Theory", "Prof. Suzuki", "Library AV Hall", 4, 4, 3, true, false),
            ("English Communication", "Prof. Lee", "Language Center 207", 1, 5, 2, false, true),
        ]

        for sample in samples {
            let course = Course(
                name: sample.0,
                teacher: sample.1,
                room: sample.2,
                colorIndex: sample.3,
                semester: semester
            )
            course.items = "Laptop\nStudent ID\nHandouts"
            course.attendanceChannels = sample.5 == 1 ? [.digiCan, .inPerson] : [.campusPortal]
            course.attendanceDetail = "Roll call in the second half"
            course.fsEnabled = sample.6
            course.assignmentEnabled = sample.7
            context.insert(course)

            let meeting = Meeting(weekday: sample.4, period: sample.5)
            meeting.course = course
            context.insert(meeting)
        }

        try? context.save()
        TaskScheduler.generateTasks(in: context)
        return container
    }()
}
