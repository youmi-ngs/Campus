import Foundation
import SwiftData

/// 授業が入っている時間割のコマ（曜日 × 限）。週2コマの授業は Meeting を2つ持つ。
@Model
final class Meeting {
    /// Calendar と同じ並び。1 = 日曜 … 7 = 土曜。
    var weekday: Int = 2
    /// 1限なら 1。
    var period: Int = 1
    /// このコマだけ教室が違うときに使う。
    var roomOverride: String = ""

    var course: Course?

    init(weekday: Int = 2, period: Int = 1, roomOverride: String = "") {
        self.weekday = weekday
        self.period = period
        self.roomOverride = roomOverride
    }

    /// 月曜を先頭にした並び替え用の値。
    var sortWeekday: Int { weekday == 1 ? 8 : weekday }

    var weekdayText: String { WeekdayText.full(weekday) }
    var weekdayShortText: String { WeekdayText.short(weekday) }

    var slotText: String { "\(weekdayShortText) · Period \(period)" }
}
