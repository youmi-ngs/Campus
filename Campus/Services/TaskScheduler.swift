import Foundation
import SwiftData

/// 時間割から「やること」を作り、通知の内容を組み立てる。
enum TaskScheduler {
    /// 先どこまで作るか。過去側は「授業を登録した日」以降をずっと見る
    /// （休講を取り消したとき、古い回のやることも戻せるようにするため）。
    static let futureWindowDays = 120

    private struct TaskKey: Hashable {
        var kind: TaskKind
        var day: Date
        /// 出席は限ごとに1件作るので限で区別する。ほかの種類は 0（1日1件）。
        var period: Int
    }

    private struct Desired {
        var classDate: Date
        var period: Int
        var dueDate: Date
    }

    /// 出席と FS はコマ単位。連続コマでも、押すのも書くのもコマごとに必要なため。
    private static func key(kind: TaskKind, day: Date, period: Int) -> TaskKey {
        TaskKey(kind: kind, day: day, period: kind.isPerPeriod ? period : 0)
    }

    /// 授業の予定と設定にあわせて TaskItem を作成・更新・削除する。
    @MainActor
    static func generateTasks(in context: ModelContext, now: Date = .now) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let windowEnd = calendar.date(byAdding: .day, value: futureWindowDays, to: today)
        else { return }

        let courses = (try? context.fetch(FetchDescriptor<Course>())) ?? []

        for course in courses {
            let historyStart = historyStart(for: course, calendar: calendar)
            let desired = desiredTasks(
                for: course,
                historyStart: historyStart,
                windowEnd: windowEnd,
                calendar: calendar
            )

            var matched: Set<TaskKey> = []
            for task in course.tasks where !task.isManual {
                // コマ単位にする前に作られたぶんは、どのコマだったかを補っておく。
                // そうしないと完了済みの古い1件が宙に浮き、同じ日に新しい2件が増えてしまう。
                if task.kind.isPerPeriod, task.period == 0,
                   let inferred = inferredPeriod(for: task, course: course, calendar: calendar) {
                    task.period = inferred
                }

                let key = key(
                    kind: task.kind,
                    day: calendar.startOfDay(for: task.classDate),
                    period: task.period
                )
                if let wanted = desired[key], !matched.contains(key) {
                    matched.insert(key)
                    // 完了済みのものは記録として触らない。
                    if !task.isDone {
                        task.classDate = wanted.classDate
                        task.dueDate = wanted.dueDate
                        task.period = wanted.period
                    }
                } else if !task.isDone,
                          task.kind == .finalAssignment
                            // 過去の回でも、休講にしたぶんは片付ける。
                            || course.isCancelled(on: task.classDate, calendar: calendar)
                            || (key.day >= historyStart && key.day <= windowEnd) {
                    // 設定変更やコマの削除で不要になった未完了分を片付ける。
                    context.delete(task)
                }
            }

            for (key, value) in desired where !matched.contains(key) {
                let task = TaskItem(
                    kind: key.kind,
                    classDate: value.classDate,
                    dueDate: value.dueDate,
                    course: course
                )
                task.period = value.period
                context.insert(task)
            }
        }

        try? context.save()
    }

    /// 古いやることの「どのコマだったか」を、開始時刻から割り出す。
    private static func inferredPeriod(for task: TaskItem, course: Course, calendar: Calendar) -> Int? {
        let time = calendar.dateComponents([.hour, .minute], from: task.classDate)
        if let semester = course.semester,
           let slot = semester.periods.first(where: { $0.startHour == time.hour && $0.startMinute == time.minute }) {
            return slot.index
        }
        let weekday = calendar.component(.weekday, from: task.classDate)
        return course.meetings.filter { $0.weekday == weekday }.map(\.period).min()
    }

    /// この授業のやることを面倒みる範囲の始まり。
    /// 学期の開始まで遡る。学期途中で授業を登録しても、
    /// すでに終わった回のぶん（書けていない FS や課題）がちゃんと出てくるようにするため。
    private static func historyStart(for course: Course, calendar: Calendar) -> Date {
        guard let semester = course.semester else {
            return calendar.startOfDay(for: course.createdAt)
        }
        return calendar.startOfDay(for: semester.startDate)
    }

    private static func desiredTasks(
        for course: Course,
        historyStart: Date,
        windowEnd: Date,
        calendar: Calendar
    ) -> [TaskKey: Desired] {
        var result: [TaskKey: Desired] = [:]
        guard let semester = course.semester else { return result }

        // 最終課題は授業にひとつだけ。学期やコマの並びとは関係なく締め切りで決まる。
        if course.finalEnabled {
            let finalKey = key(kind: .finalAssignment, day: calendar.startOfDay(for: course.finalDueDate), period: 0)
            result[finalKey] = Desired(classDate: course.finalDueDate, period: 0, dueDate: course.finalDueDate)
        }

        let kinds = course.enabledReminderKinds.filter(\.isRecurring)
        guard !kinds.isEmpty, !course.meetings.isEmpty else { return result }

        let semesterEnd = calendar.startOfDay(for: semester.endDate)

        // 「次の授業の前まで」を期限にする場合だけ、学期ぶんの授業開始時刻を並べておく。
        let classStarts: [Date] = course.assignmentEnabled
            && course.assignmentDeadlineMode == .beforeNextClass
            ? allClassStarts(for: course, in: semester, from: calendar.startOfDay(for: semester.startDate), to: semesterEnd, calendar: calendar)
            : []

        for kind in kinds {
            // 出席も含め、学期の開始から作る。押しそびれた回も記録として残るようにするため。
            let rangeStart = historyStart
            let rangeEnd = min(semesterEnd, windowEnd)
            guard rangeStart <= rangeEnd else { continue }

            for meeting in course.meetings {
                let slot = semester.period(at: meeting.period)
                for day in ClassDays.occurrences(
                    weekday: meeting.weekday,
                    from: rangeStart,
                    to: rangeEnd,
                    calendar: calendar
                ) {
                    // 休講の回はどの種類のやることも作らない。
                    guard !course.isCancelled(on: day, calendar: calendar) else { continue }

                    let classDate = calendar.date(
                        bySettingHour: slot?.startHour ?? 9,
                        minute: slot?.startMinute ?? 0,
                        second: 0,
                        of: day
                    ) ?? day

                    let slotKey = key(kind: kind, day: day, period: meeting.period)
                    // コマ単位でないものは1日1件。同じ日に2コマある授業は早いコマを基準にする。
                    if !kind.isPerPeriod,
                       let existing = result[slotKey],
                       existing.classDate <= classDate {
                        continue
                    }
                    result[slotKey] = Desired(
                        classDate: classDate,
                        period: meeting.period,
                        dueDate: dueDate(
                            for: kind,
                            course: course,
                            classDay: day,
                            classStart: classDate,
                            nextClassStart: classStarts.first { $0 > classDate },
                            calendar: calendar
                        )
                    )
                }
            }
        }
        return result
    }

    /// この授業の「授業日」を時系列で並べる。
    /// 2時間続きのように同じ日に複数コマある授業は、その日の最初のコマを代表にして1件にまとめる。
    /// まとめないと、1限の課題の期限が同じ日の2限になってしまう。
    private static func allClassStarts(
        for course: Course,
        in semester: Semester,
        from start: Date,
        to end: Date,
        calendar: Calendar
    ) -> [Date] {
        var firstStartByDay: [Date: Date] = [:]
        for meeting in course.meetings {
            let slot = semester.period(at: meeting.period)
            for day in ClassDays.occurrences(weekday: meeting.weekday, from: start, to: end, calendar: calendar) {
                // 休講の回は「次の授業」として数えない。
                guard !course.isCancelled(on: day, calendar: calendar) else { continue }
                guard let classStart = calendar.date(
                    bySettingHour: slot?.startHour ?? 9,
                    minute: slot?.startMinute ?? 0,
                    second: 0,
                    of: day
                ) else { continue }

                let key = calendar.startOfDay(for: day)
                if let existing = firstStartByDay[key], existing <= classStart { continue }
                firstStartByDay[key] = classStart
            }
        }
        return firstStartByDay.values.sorted()
    }

    /// 提出期限を求める。出席は授業開始からの分、課題は設定した決め方による。
    static func dueDate(
        for kind: TaskKind,
        course: Course,
        classDay: Date,
        classStart: Date,
        nextClassStart: Date? = nil,
        calendar: Calendar = .current
    ) -> Date {
        if kind == .assignment, course.assignmentDeadlineMode == .beforeNextClass {
            // 学期最後の回は次が無いので、1週間後の同じ時刻を期限にしておく。
            return nextClassStart
                ?? calendar.date(byAdding: .day, value: 7, to: classStart)
                ?? classStart
        }

        if kind.isMinuteBased {
            return calendar.date(
                byAdding: .minute,
                value: max(0, course.attendanceLeadMinutes),
                to: classStart
            ) ?? classStart
        }

        let day = calendar.startOfDay(for: classDay)
        let shifted = calendar.date(byAdding: .day, value: course.delayDays(for: kind), to: day) ?? day
        let time = course.deadlineTime(for: kind)
        return calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: shifted) ?? shifted
    }

    /// 未完了のやることから通知の予定表を作る。
    @MainActor
    static func reminderPlans(
        in context: ModelContext,
        now: Date = .now
    ) -> (plans: [ReminderPlan], overdueCount: Int) {
        let calendar = Calendar.current
        var descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.isDone == false },
            sortBy: [SortDescriptor(\.dueDate, order: .forward)]
        )
        descriptor.fetchLimit = 400
        let tasks = (try? context.fetch(descriptor)) ?? []

        let overdue = tasks.filter { $0.dueDate <= now }.count
        let plans = tasks
            .filter { $0.notifyDate > now }
            .sorted { $0.notifyDate < $1.notifyDate }
            .map { task in
                ReminderPlan(
                    id: task.uid.uuidString,
                    title: task.courseName,
                    body: task.prompt,
                    subtitle: subtitle(for: task),
                    fireDate: calendar.dateComponents(
                        [.year, .month, .day, .hour, .minute],
                        from: task.notifyDate
                    )
                )
            }

        return (plans, overdue)
    }

    /// 通知の2行目。出席は締め切りを出し、それ以外はどの回の分かを出す。
    private static func subtitle(for task: TaskItem) -> String {
        if task.kind == .attendance, let deadline = task.attendanceDeadline {
            let until = "Open until \(deadline.formatted(date: .omitted, time: .shortened))"
            // 連続コマは通知が続けて届くので、どのコマのぶんか分かるようにする。
            guard let periodText = task.periodText else { return until }
            return "\(periodText) · \(until)"
        }
        if task.kind == .finalAssignment {
            return "Due \(task.dueDate.formatted(.dateTime.month(.abbreviated).day()))"
        }
        let base = "\(task.title) · \(task.classDateText) class"
        // 連続コマは同じ時刻に2件届くので、どのコマのぶんか分かるようにする。
        guard let periodText = task.periodText else { return base }
        return "\(periodText) · \(base)"
    }
}

/// 画面や通知から呼ばれる同期の入口。
@MainActor
final class TaskSyncCoordinator {
    static let shared = TaskSyncCoordinator()

    private init() {}

    /// やることを作り直し、通知も貼り替える。
    func sync(context: ModelContext? = nil) async {
        let context = context ?? ModelContext(AppContainer.shared)
        TaskScheduler.generateTasks(in: context)
        await refreshNotifications(context: context)
    }

    /// データはそのままで、通知だけ貼り替える。
    func refreshNotifications(context: ModelContext? = nil) async {
        let context = context ?? ModelContext(AppContainer.shared)
        let result = TaskScheduler.reminderPlans(in: context)
        await NotificationManager.shared.reschedule(
            with: result.plans,
            badgeCount: result.overdueCount
        )
    }
}
