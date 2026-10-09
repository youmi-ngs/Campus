import SwiftData
import SwiftUI

/// 授業タブ。登録した授業を一覧し、リマインドの設定状況をひと目で確認できる。
struct CourseListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Semester.startDate, order: .reverse) private var semesters: [Semester]

    @State private var searchText = ""
    @State private var isAddingCourse = false

    private var semester: Semester? { SemesterPicker.current(from: semesters) }

    private var courses: [Course] {
        let all = (semester?.courses ?? []).sorted {
            let left = $0.sortedMeetings.first
            let right = $1.sortedMeetings.first
            switch (left, right) {
            case let (l?, r?):
                if l.sortWeekday != r.sortWeekday { return l.sortWeekday < r.sortWeekday }
                if l.period != r.period { return l.period < r.period }
                return $0.displayName < $1.displayName
            case (nil, _?): return false
            case (_?, nil): return true
            default: return $0.displayName < $1.displayName
            }
        }

        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return all }
        return all.filter {
            $0.name.localizedStandardContains(query)
                || $0.teacher.localizedStandardContains(query)
                || $0.room.localizedStandardContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if semester == nil || (semester?.courses.isEmpty ?? true) {
                    ContentUnavailableView {
                        Label("No Courses Yet", systemImage: "books.vertical")
                    } description: {
                        Text("Add a course to see it in your timetable and get attendance, FS, and assignment reminders.")
                    } actions: {
                        Button("Add Course") { isAddingCourse = true }
                            .buttonStyle(.borderedProminent)
                            .disabled(semester == nil)
                    }
                } else if courses.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    list
                }
            }
            .navigationTitle("Courses")
            .searchable(text: $searchText, prompt: "Course, instructor, or room")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddingCourse = true
                    } label: {
                        Label("Add Course", systemImage: "plus")
                    }
                    .disabled(semester == nil)
                }
            }
            .sheet(isPresented: $isAddingCourse) {
                if let semester {
                    CourseEditView(mode: .create(semester: semester, slot: nil))
                }
            }
        }
    }

    private var list: some View {
        List {
            Section {
                ForEach(courses) { course in
                    NavigationLink {
                        CourseDetailView(course: course)
                    } label: {
                        CourseListRow(course: course)
                    }
                }
            } header: {
                Text(semester?.name ?? "")
            } footer: {
                Text(courses.count == 1 ? "1 course" : "\(courses.count) courses")
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct CourseListRow: View {
    let course: Course

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(course.color)
                .frame(width: 5)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                Text(course.displayName)
                    .font(.body.weight(.medium))

                Text(course.scheduleSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !course.room.isEmpty || !course.teacher.isEmpty {
                    HStack(spacing: 10) {
                        if !course.room.isEmpty {
                            Label(course.room, systemImage: "mappin")
                        }
                        if !course.teacher.isEmpty {
                            Label(course.teacher, systemImage: "person")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    // 最終課題は繰り返しではないので、チップには出さない。
                    ForEach(TaskKind.allCases.filter(\.isRecurring)) { kind in
                        if course.isEnabled(kind) {
                            ReminderChip(
                                text: offsetText(for: kind),
                                symbol: kind.symbolName,
                                color: course.color,
                                accessibilityText: "\(kind.shortLabel), \(offsetText(for: kind))"
                            )
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }

    /// チップは狭いので、記号で種類を示し、文字は「いつ」だけにする。
    private func offsetText(for kind: TaskKind) -> String {
        if kind.isMinuteBased {
            return ReminderText.compactMinutes(course.attendanceLeadMinutes)
        }
        if kind == .assignment, course.assignmentDeadlineMode == .beforeNextClass {
            return "next class"
        }
        return ReminderText.compact(course.delayDays(for: kind))
    }
}

private struct ReminderChip: View {
    let text: String
    let symbol: String
    let color: Color
    let accessibilityText: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.14), in: .capsule)
            .foregroundStyle(color)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
    }
}

#Preview {
    CourseListView()
        .modelContainer(PreviewData.container)
}
