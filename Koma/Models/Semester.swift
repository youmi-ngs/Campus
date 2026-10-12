import Foundation
import SwiftData

/// 学期。時間割は学期ごとに丸ごと切り替わる。
@Model
final class Semester {
    var name: String = ""
    var startDate: Date = Date.now
    var endDate: Date = Date.now
    /// 時間割タブで表示している学期かどうか。アプリ全体で1つだけ true になる。
    var isCurrent: Bool = false
    /// この学期のコマの時間設定。
    var periods: [PeriodSlot] = PeriodSlot.standard
    var showsSaturday: Bool = true
    var showsSunday: Bool = false
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \Course.semester)
    var courses: [Course] = []

    init(
        name: String,
        startDate: Date,
        endDate: Date,
        isCurrent: Bool = false,
        periods: [PeriodSlot] = PeriodSlot.standard,
        showsSaturday: Bool = true,
        showsSunday: Bool = false
    ) {
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.isCurrent = isCurrent
        self.periods = periods
        self.showsSaturday = showsSaturday
        self.showsSunday = showsSunday
        self.createdAt = .now
    }

    /// 時間割に並べる曜日（日曜始まりの Calendar 準拠：1 = 日曜）。
    var visibleWeekdays: [Int] {
        var days: [Int] = []
        if showsSunday { days.append(1) }
        days.append(contentsOf: [2, 3, 4, 5, 6])
        if showsSaturday { days.append(7) }
        return days
    }

    var sortedPeriods: [PeriodSlot] {
        periods.sorted { $0.index < $1.index }
    }

    var dateRangeText: String {
        let start = startDate.formatted(.dateTime.year().month(.abbreviated).day())
        let end = endDate.formatted(.dateTime.year().month(.abbreviated).day())
        return "\(start) – \(end)"
    }

    func period(at index: Int) -> PeriodSlot? {
        periods.first { $0.index == index }
    }

    func contains(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        return day >= calendar.startOfDay(for: startDate)
            && day <= calendar.startOfDay(for: endDate)
    }

    /// 年度と月から「2026年度 後期」のような既定の名前を作る。
    static func suggestedName(for date: Date = .now) -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)
        // 日本の学年暦は4月始まり。1〜3月は前年度の後期にあたる。
        let academicYear = month < 4 ? year - 1 : year
        if (4...9).contains(month) {
            return "Spring \(academicYear)"
        }
        return "Fall \(academicYear)"
    }

    /// 既定の学期期間（前期は4月〜8月上旬、後期は10月〜2月上旬）。
    static func suggestedRange(for date: Date = .now) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)
        let isSpringTerm = (4...9).contains(month)

        let startComponents: DateComponents
        let endComponents: DateComponents
        if isSpringTerm {
            startComponents = DateComponents(year: year, month: 4, day: 1)
            endComponents = DateComponents(year: year, month: 8, day: 10)
        } else {
            let startYear = month < 4 ? year - 1 : year
            startComponents = DateComponents(year: startYear, month: 10, day: 1)
            endComponents = DateComponents(year: startYear + 1, month: 2, day: 10)
        }
        let start = calendar.date(from: startComponents) ?? date
        let end = calendar.date(from: endComponents) ?? date
        return (start, end)
    }
}
