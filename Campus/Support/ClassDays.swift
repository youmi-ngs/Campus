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
