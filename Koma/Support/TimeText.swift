import Foundation

/// 時刻と曜日の表示を端末の地域設定に合わせて整える小さなヘルパー。
enum TimeText {
    private static let referenceDay = DateComponents(year: 2001, month: 1, day: 1)

    /// 「9:00」のような時刻表示。24時間表示／午前午後表示は端末の設定に従う。
    static func string(hour: Int, minute: Int) -> String {
        var components = referenceDay
        components.hour = hour
        components.minute = minute
        guard let date = Calendar.current.date(from: components) else {
            return String(format: "%d:%02d", hour, minute)
        }
        return date.formatted(date: .omitted, time: .shortened)
    }

    /// DatePicker と相互変換するための Date。
    static func date(hour: Int, minute: Int) -> Date {
        var components = referenceDay
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? .now
    }

    static func components(from date: Date) -> (hour: Int, minute: Int) {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0, parts.minute ?? 0)
    }
}

/// 曜日番号（1 = 日曜）から表示名を引く。
enum WeekdayText {
    static func full(_ weekday: Int) -> String {
        let symbols = Calendar.current.standaloneWeekdaySymbols
        let index = max(1, min(7, weekday)) - 1
        return symbols.indices.contains(index) ? symbols[index] : ""
    }

    static func short(_ weekday: Int) -> String {
        let symbols = Calendar.current.shortStandaloneWeekdaySymbols
        let index = max(1, min(7, weekday)) - 1
        return symbols.indices.contains(index) ? symbols[index] : ""
    }
}
