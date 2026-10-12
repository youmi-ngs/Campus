import Foundation

/// 時間割の1コマ分の時間枠。学期ごとに編集できる。
struct PeriodSlot: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    /// 1限なら 1、2限なら 2。
    var index: Int
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int

    init(
        id: UUID = UUID(),
        index: Int,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int
    ) {
        self.id = id
        self.index = index
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
    }

    var label: String { "Period \(index)" }
    /// 時間割の左端のように幅が狭いところ用。
    var shortLabel: String { "P\(index)" }
    var startText: String { TimeText.string(hour: startHour, minute: startMinute) }
    var endText: String { TimeText.string(hour: endHour, minute: endMinute) }
    var rangeText: String { "\(startText)–\(endText)" }

    /// VoiceOver 向けの読み上げ文。
    var accessibilityRangeText: String {
        "\(startText) to \(endText)"
    }

    /// 既定の時間割（駿河台キャンパス）。2限と3限のあいだが昼休み。
    static let standard: [PeriodSlot] = [
        PeriodSlot(index: 1, startHour: 8, startMinute: 40, endHour: 10, endMinute: 10),
        PeriodSlot(index: 2, startHour: 10, startMinute: 20, endHour: 11, endMinute: 50),
        PeriodSlot(index: 3, startHour: 12, startMinute: 40, endHour: 14, endMinute: 10),
        PeriodSlot(index: 4, startHour: 14, startMinute: 20, endHour: 15, endMinute: 50),
        PeriodSlot(index: 5, startHour: 16, startMinute: 0, endHour: 17, endMinute: 30),
        PeriodSlot(index: 6, startHour: 17, startMinute: 40, endHour: 19, endMinute: 10),
    ]

    /// 既存のコマ列の末尾に足す新しいコマ。
    static func next(after slots: [PeriodSlot]) -> PeriodSlot {
        guard let last = slots.max(by: { $0.index < $1.index }) else {
            return standard[0]
        }
        let start = last.endHour * 60 + last.endMinute + 10
        let end = start + 90
        return PeriodSlot(
            index: last.index + 1,
            startHour: min(23, start / 60),
            startMinute: start % 60,
            endHour: min(23, end / 60),
            endMinute: end % 60
        )
    }
}
