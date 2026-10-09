import SwiftData
import SwiftUI

/// コマの時間を学期ごとに編集する。1限が何時からかは大学によって違うため、ここで合わせる。
struct PeriodEditView: View {
    @Environment(\.modelContext) private var context
    @Bindable var semester: Semester

    @State private var isConfirmingReset = false

    private var sortedIndices: [Int] {
        semester.periods.indices.sorted { semester.periods[$0].index < semester.periods[$1].index }
    }

    var body: some View {
        List {
            ForEach(sortedIndices, id: \.self) { index in
                Section("Period \(semester.periods[index].index)") {
                    DatePicker(
                        "Starts",
                        selection: timeBinding(index: index, isStart: true),
                        displayedComponents: .hourAndMinute
                    )
                    DatePicker(
                        "Ends",
                        selection: timeBinding(index: index, isStart: false),
                        displayedComponents: .hourAndMinute
                    )
                }
            }

            Section {
                Button {
                    addPeriod()
                } label: {
                    Label("Add Period", systemImage: "plus.circle.fill")
                }

                if semester.periods.count > 1 {
                    Button("Remove Last Period", role: .destructive) {
                        removeLastPeriod()
                    }
                }

                Button("Reset to Default Times") {
                    isConfirmingReset = true
                }
            } footer: {
                Text("Changing these times rebuilds the dates behind upcoming reminders.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Period Times")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Reset to default times?",
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                semester.periods = PeriodSlot.standard
                persist()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Replaced with six periods starting at 9:00. Course assignments stay as they are.")
        }
        .onDisappear { persist() }
    }

    private func timeBinding(index: Int, isStart: Bool) -> Binding<Date> {
        Binding(
            get: {
                guard semester.periods.indices.contains(index) else { return .now }
                let slot = semester.periods[index]
                return isStart
                    ? TimeText.date(hour: slot.startHour, minute: slot.startMinute)
                    : TimeText.date(hour: slot.endHour, minute: slot.endMinute)
            },
            set: { newValue in
                guard semester.periods.indices.contains(index) else { return }
                let parts = TimeText.components(from: newValue)
                var slots = semester.periods
                if isStart {
                    slots[index].startHour = parts.hour
                    slots[index].startMinute = parts.minute
                } else {
                    slots[index].endHour = parts.hour
                    slots[index].endMinute = parts.minute
                }
                semester.periods = slots
            }
        )
    }

    private func addPeriod() {
        var slots = semester.periods
        slots.append(PeriodSlot.next(after: slots))
        semester.periods = slots
        persist()
    }

    private func removeLastPeriod() {
        var slots = semester.periods.sorted { $0.index < $1.index }
        guard slots.count > 1 else { return }
        slots.removeLast()
        semester.periods = slots
        persist()
    }

    private func persist() {
        try? context.save()
        Task { await TaskSyncCoordinator.shared.sync(context: context) }
    }
}
