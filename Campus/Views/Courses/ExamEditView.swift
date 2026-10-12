import SwiftData
import SwiftUI

/// 試験の追加・編集。日時を入れると、指定した日数前に通知が出る。
struct ExamEditView: View {
    enum Mode {
        case create(course: Course)
        case edit(Exam)
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let mode: Mode
    @State private var title: String
    @State private var date: Date
    @State private var room: String
    @State private var note: String
    @State private var firstReminderDaysBefore: Int
    @State private var secondReminderDaysBefore: Int
    @State private var reminderTime: Date

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create:
            let calendar = Calendar.current
            let suggested = calendar.date(byAdding: .day, value: 14, to: .now) ?? .now
            _title = State(initialValue: "")
            _date = State(initialValue: calendar.date(bySettingHour: 13, minute: 0, second: 0, of: suggested) ?? suggested)
            _room = State(initialValue: "")
            _note = State(initialValue: "")
            _firstReminderDaysBefore = State(initialValue: 7)
            _secondReminderDaysBefore = State(initialValue: 1)
            _reminderTime = State(initialValue: TimeText.date(hour: 19, minute: 0))
        case let .edit(exam):
            _title = State(initialValue: exam.title)
            _date = State(initialValue: exam.date)
            _room = State(initialValue: exam.room)
            _note = State(initialValue: exam.note)
            _firstReminderDaysBefore = State(initialValue: exam.firstReminderDaysBefore)
            _secondReminderDaysBefore = State(initialValue: exam.secondReminderDaysBefore)
            _reminderTime = State(initialValue: TimeText.date(hour: exam.reminderHour, minute: exam.reminderMinute))
        }
    }

    private var isNew: Bool {
        if case .create = mode { return true }
        return false
    }

    private var course: Course? {
        switch mode {
        case let .create(course): return course
        case let .edit(exam): return exam.course
        }
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. Midterm)", text: $title)
                    DatePicker("Starts", selection: $date)
                    TextField("Room (if different)", text: $room)
                } header: {
                    Text("Exam")
                }

                Section {
                    Picker("First reminder", selection: $firstReminderDaysBefore) {
                        ForEach([3, 7, 10, 14, 21], id: \.self) { days in
                            Text(ReminderText.before(days)).tag(days)
                        }
                    }
                    Picker("Second reminder", selection: $secondReminderDaysBefore) {
                        ForEach([0, 1, 2, 3], id: \.self) { days in
                            Text(ReminderText.before(days)).tag(days)
                        }
                    }
                    DatePicker("Reminder at", selection: $reminderTime, displayedComponents: .hourAndMinute)
                } header: {
                    Text("Reminders")
                } footer: {
                    Text(reminderFooter)
                }

                Section("Notes") {
                    TextField("What it covers, what you can bring", text: $note, axis: .vertical)
                        .lineLimit(2...6)
                }

                if case let .edit(exam) = mode {
                    Section {
                        Button("Delete Exam", role: .destructive) { delete(exam) }
                    }
                }
            }
            .navigationTitle(isNew ? "Add Exam" : "Edit Exam")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Save") { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private var reminderFooter: String {
        let at = reminderTime.formatted(date: .omitted, time: .shortened)
        let first = ReminderText.before(firstReminderDaysBefore).lowercased()
        let second = ReminderText.before(secondReminderDaysBefore).lowercased()
        if firstReminderDaysBefore == secondReminderDaysBefore {
            return "One reminder \(first) at \(at)."
        }
        return "Two reminders: \(first) and \(second), both at \(at). A same-day reminder moves to an hour before the exam if that time has already passed."
    }

    private func save() {
        let parts = TimeText.components(from: reminderTime)
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)

        switch mode {
        case let .create(course):
            let exam = Exam(title: trimmed, date: date, course: course)
            exam.room = room.trimmingCharacters(in: .whitespaces)
            exam.note = note
            exam.firstReminderDaysBefore = firstReminderDaysBefore
            exam.secondReminderDaysBefore = secondReminderDaysBefore
            exam.reminderHour = parts.hour
            exam.reminderMinute = parts.minute
            context.insert(exam)
        case let .edit(exam):
            exam.title = trimmed
            exam.date = date
            exam.room = room.trimmingCharacters(in: .whitespaces)
            exam.note = note
            exam.firstReminderDaysBefore = firstReminderDaysBefore
            exam.secondReminderDaysBefore = secondReminderDaysBefore
            exam.reminderHour = parts.hour
            exam.reminderMinute = parts.minute
        }

        try? context.save()
        dismiss()

        Task {
            await NotificationManager.shared.requestAuthorizationIfNeeded()
            await TaskSyncCoordinator.shared.sync(context: context)
        }
    }

    private func delete(_ exam: Exam) {
        context.delete(exam)
        try? context.save()
        dismiss()
        Task { await TaskSyncCoordinator.shared.sync(context: context) }
    }
}
