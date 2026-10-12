import Foundation

/// 授業が行われる日の計算。時間割の生成と休講の編集で共通に使う。
enum ClassDays {
    /// 指定した曜日にあたる日付を期間内で列挙する。
    static func occurrences(
        weekday: Int,
        from start: Date,
        to end: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        let startWeekday = calendar.component(.weekday, from: start)
        let offset = ((weekday - startWeekday) + 7) % 7
        guard var day = calendar.date(byAdding: .day, value: offset, to: start) else { return [] }

        var days: [Date] = []
        while day <= end {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 7, to: day) else { break }
            day = next
        }
        return days
    }

    /// 授業の1コマ。試験を「どの回か」で選ぶときに使う。
    struct Session: Identifiable, Hashable {
        var id: String
        var start: Date
        var period: Int
        var title: String
    }

    /// 休講を除いた、これからの授業のコマを時系列で返す。
    @MainActor
    static func upcomingSessions(
        for course: Course,
        from start: Date = .now,
        calendar: Calendar = .current
    ) -> [Session] {
        guard let semester = course.semester else { return [] }
        let rangeStart = max(calendar.startOfDay(for: semester.startDate), calendar.startOfDay(for: start))
        let rangeEnd = calendar.startOfDay(for: semester.endDate)
        guard rangeStart <= rangeEnd else { return [] }

        var sessions: [Session] = []
        for meeting in course.meetings {
            let slot = semester.period(at: meeting.period)
            for day in occurrences(weekday: meeting.weekday, from: rangeStart, to: rangeEnd, calendar: calendar) {
                guard !course.isCancelled(on: day, calendar: calendar) else { continue }
                guard let begin = calendar.date(
                    bySettingHour: slot?.startHour ?? 9,
                    minute: slot?.startMinute ?? 0,
                    second: 0,
                    of: day
                ) else { continue }

                let label = day.formatted(.dateTime.month(.abbreviated).day().weekday(.abbreviated))
                let time = TimeText.string(hour: slot?.startHour ?? 9, minute: slot?.startMinute ?? 0)
                sessions.append(Session(
                    id: "\(calendar.startOfDay(for: day).timeIntervalSince1970)-\(meeting.period)",
                    start: begin,
                    period: meeting.period,
                    title: "\(label) · P\(meeting.period) \(time)"
                ))
            }
        }
        return sessions.sorted { $0.start < $1.start }
    }

    /// その授業がある日（休講を含む）を重複なく時系列で返す。
    static func allDays(
        for course: Course,
        from start: Date,
        to end: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        var days: Set<Date> = []
        for meeting in course.meetings {
            for day in occurrences(weekday: meeting.weekday, from: start, to: end, calendar: calendar) {
                days.insert(calendar.startOfDay(for: day))
            }
        }
        return days.sorted()
    }
}
