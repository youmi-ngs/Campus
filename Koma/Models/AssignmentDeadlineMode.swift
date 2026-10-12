import Foundation

/// 毎週出る課題の、提出期限の決め方。
enum AssignmentDeadlineMode: String, CaseIterable, Identifiable, Codable, Sendable {
    /// 授業から数えて何日後の何時か。
    case daysAfterClass
    /// 次の授業が始まるまで。コマの時間が変われば期限も一緒に動く。
    case beforeNextClass

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daysAfterClass: return "Days after class"
        case .beforeNextClass: return "Before next class"
        }
    }
}
