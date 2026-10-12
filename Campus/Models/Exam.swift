import Foundation
import SwiftData

/// 試験。授業にひもづけて日時を登録すると、前もって通知が来る。
/// 中間と期末のように複数持てる。
@Model
final class Exam {
    var uid: UUID = UUID()
    var title: String = "Exam"
    /// 試験の開始日時。
    var date: Date = Date.now
    var room: String = ""
    /// 出題範囲や持ち込みの可否など。
    var note: String = ""

    /// 何日前に知らせるか。2回に分けて出す。
    var firstReminderDaysBefore: Int = 7
    var secondReminderDaysBefore: Int = 1
    var reminderHour: Int = 19
    var reminderMinute: Int = 0

    var course: Course?

    init(title: String = "Exam", date: Date = .now, course: Course? = nil) {
        self.uid = UUID()
        self.title = title
        self.date = date
        self.course = course
    }

    var displayTitle: String { title.isEmpty ? "Exam" : title }

    var dateText: String {
        date.formatted(.dateTime.month(.abbreviated).day().weekday(.abbreviated).hour().minute())
    }

    /// 通知を出す日時。早い順に返す。同じ日時になるぶんはまとめる。
    func reminderDates(calendar: Calendar = .current) -> [Date] {
        let offsets = Set([max(0, firstReminderDaysBefore), max(0, secondReminderDaysBefore)])
        let dates = offsets.compactMap { days -> Date? in
            guard let shifted = calendar.date(byAdding: .day, value: -days, to: date) else { return nil }
            guard let at = calendar.date(
                bySettingHour: reminderHour,
                minute: reminderMinute,
                second: 0,
                of: shifted
            ) else { return shifted }
            // 当日ぶんは、指定時刻が試験開始より後になることがある。その場合は1時間前に寄せる。
            guard at < date else {
                return calendar.date(byAdding: .hour, value: -1, to: date) ?? date
            }
            return at
        }
        return Set(dates).sorted()
    }
}
