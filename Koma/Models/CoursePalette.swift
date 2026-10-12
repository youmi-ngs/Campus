import SwiftUI

/// 時間割のコマに使う色。システムの色を使い、ライト／ダークの両方で読みやすい濃さにしている。
enum CoursePalette {
    static let colors: [Color] = [
        .blue, .teal, .green, .indigo, .purple, .pink, .orange, .brown, .red, .cyan,
    ]

    static let names: [String] = [
        "Blue", "Teal", "Green", "Indigo", "Purple",
        "Pink", "Orange", "Brown", "Red", "Cyan",
    ]

    static func color(at index: Int) -> Color {
        colors[((index % colors.count) + colors.count) % colors.count]
    }

    static func name(at index: Int) -> String {
        names[((index % names.count) + names.count) % names.count]
    }
}
