import Foundation

/// Remembers which levels have been solved, persisted in UserDefaults.
final class ProgressStore: ObservableObject {
    private static let key = "color-link-progress-v1"

    @Published private(set) var solved: Set<Int>
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        solved = Set(defaults.array(forKey: Self.key) as? [Int] ?? [])
    }

    func isSolved(_ levelNumber: Int) -> Bool {
        solved.contains(levelNumber)
    }

    func markSolved(_ levelNumber: Int) {
        guard solved.insert(levelNumber).inserted else { return }
        defaults.set(solved.sorted(), forKey: Self.key)
    }

    /// Zero-based index of the first level not yet solved, if any.
    func nextUnsolvedIndex(levelCount: Int) -> Int? {
        (0..<levelCount).first { !solved.contains($0 + 1) }
    }
}
