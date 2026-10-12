import Foundation

/// 「何日後」「何分後」の言い回しをまとめる。表示する場所によって形を変える。
enum ReminderText {
    // MARK: - 日単位（FS・課題）

    /// 一覧の値として出す形。例: "Same day" / "2 days later"
    static func offset(_ days: Int) -> String {
        switch days {
        case ..<1: return "Same day"
        case 1: return "1 day later"
        default: return "\(days) days later"
        }
    }

    /// ピッカーの選択肢。offset と同じ文言を使う。
    static func picker(_ days: Int) -> String { offset(days) }

    /// 文章に埋める形。例: "2 days after class"
    static func afterClass(_ days: Int) -> String {
        switch days {
        case ..<1: return "on the day of class"
        case 1: return "1 day after class"
        default: return "\(days) days after class"
        }
    }

    /// 期限から逆算する言い回し。例: "1 day before"
    static func before(_ days: Int) -> String {
        switch days {
        case ..<1: return "On the due date"
        case 1: return "1 day before"
        default: return "\(days) days before"
        }
    }

    /// チップなど狭い場所。例: "+2d"
    static func compact(_ days: Int) -> String {
        days < 1 ? "same day" : "+\(days)d"
    }

    // MARK: - 分単位（出席）

    /// 一覧の値として出す形。例: "At class start" / "3 min after start"
    static func minuteOffset(_ minutes: Int) -> String {
        minutes < 1 ? "At class start" : "\(minutes) min after start"
    }

    /// 文章に埋める形。例: "right when class starts"
    static func atClassStart(_ minutes: Int) -> String {
        minutes < 1 ? "right when class starts" : "\(minutes) minutes after class starts"
    }

    /// チップなど狭い場所。例: "at start" / "+3m"
    static func compactMinutes(_ minutes: Int) -> String {
        minutes < 1 ? "at start" : "+\(minutes)m"
    }
}
