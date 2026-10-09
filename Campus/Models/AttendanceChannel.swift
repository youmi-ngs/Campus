import Foundation

/// 出席の取り方。1つの授業で複数を併用する（サイト + 対面など）ことがある。
enum AttendanceChannel: String, CaseIterable, Identifiable, Codable, Sendable {
    /// 学内サイト1。
    case digiCan
    /// 学内サイト2。
    case campusPortal
    /// 先生が呼名して出席をつける対面方式。
    case inPerson

    var id: String { rawValue }

    var title: String {
        switch self {
        case .digiCan: return "DigiCan"
        case .campusPortal: return "Campus Portal"
        case .inPerson: return "In person (roll call)"
        }
    }

    /// 通知やチップなど短く出す場所用。
    var shortTitle: String {
        switch self {
        case .digiCan: return "DigiCan"
        case .campusPortal: return "Campus Portal"
        case .inPerson: return "In person"
        }
    }

    var symbolName: String {
        switch self {
        case .digiCan: return "globe.asia.australia"
        case .campusPortal: return "building.columns"
        case .inPerson: return "hand.raised"
        }
    }

    /// サイトで自分で出席を押す方式かどうか。時間内に操作しないと欠席になる。
    var isOnline: Bool { self != .inPerson }

    /// 保存順を安定させるための並び。
    var sortOrder: Int {
        switch self {
        case .digiCan: return 0
        case .campusPortal: return 1
        case .inPerson: return 2
        }
    }
}
