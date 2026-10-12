import SwiftData
import SwiftUI

/// 授業の予定とは別に、自分で足すやること。追試やレポートなど単発のものに使う。
struct ManualTaskEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Semester.startDate, order: .reverse) private var semesters: [Semester]

    @State private var selectedCourse: Course?
    @State private var kind: TaskKind = .assignment
    @State private var title: String = ""
    @State private var dueDate: Date = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
    @State private var memo: String = ""

    private var courses: [Course] {
        let semester = SemesterPicker.current(from: semesters)
        let list = semester?.courses ?? semesters.flatMap(\.courses)
        return list.sorted { $0.displayName < $1.displayName }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Course") {
                    Picker("Course", selection: $selectedCourse) {
                        Text("Choose a course").tag(Course?.none)
                        ForEach(courses) { course in
                            Text(course.displayName).tag(Course?.some(course))
                        }
                    }
                }

                Section("Details") {
                    Picker("Type", selection: $kind) {
                        // 出席は時間割から自動で作られるので、手では足せない。
                        ForEach(TaskKind.allCases.filter { $0 != .attendance }) { option in
                            Label(option.defaultLabel, systemImage: option.symbolName).tag(option)
                        }
                    }
                    TextField("Title", text: $title)
                }

                Section {
                    DatePicker("Remind me", selection: $dueDate)
                } footer: {
                    Text("You will be notified at this date and time.")
                }

                Section("Notes") {
                    TextField("Notes", text: $memo, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("Add To-Do")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(selectedCourse == nil || title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if selectedCourse == nil { selectedCourse = courses.first }
            }
        }
    }

    private func save() {
        guard let course = selectedCourse else { return }
        let task = TaskItem(
            kind: kind,
            classDate: .now,
            dueDate: dueDate,
            course: course,
            isManual: true,
            customTitle: title.trimmingCharacters(in: .whitespaces)
        )
        task.memo = memo
        context.insert(task)
        try? context.save()
        dismiss()

        Task {
            await NotificationManager.shared.requestAuthorizationIfNeeded()
            await TaskSyncCoordinator.shared.refreshNotifications(context: context)
        }
    }
}
