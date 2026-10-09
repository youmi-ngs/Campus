import Foundation
import SwiftData

/// 表示中の学期を決める／切り替えるための小さなヘルパー。
enum SemesterPicker {
    static func current(from semesters: [Semester], now: Date = .now) -> Semester? {
        if let marked = semesters.first(where: { $0.isCurrent }) { return marked }
        if let containing = semesters.first(where: { $0.contains(now) }) { return containing }
        return semesters.first
    }

    static func makeCurrent(_ semester: Semester, among semesters: [Semester]) {
        for candidate in semesters {
            candidate.isCurrent = (candidate.persistentModelID == semester.persistentModelID)
        }
    }
}

/// 初回起動時の下準備。コマの時間だけ用意し、授業は入れない。
enum SeedService {
    @MainActor
    static func ensureSemesterExists(in context: ModelContext, existing: [Semester]) {
        guard existing.isEmpty else { return }
        let range = Semester.suggestedRange()
        let semester = Semester(
            name: Semester.suggestedName(),
            startDate: range.start,
            endDate: range.end,
            isCurrent: true,
            showsSaturday: true
        )
        context.insert(semester)
        try? context.save()
    }
}
