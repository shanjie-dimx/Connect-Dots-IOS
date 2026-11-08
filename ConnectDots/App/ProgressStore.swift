import Foundation

/// Remembers which levels have been solved, persisted in UserDefaults.
final class ProgressStore: ObservableObject {
    private static let key = "connect-dots-progress-v2"

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

    /// Zero-based index of the first playable level not yet solved, if any.
    func nextUnsolvedIndex(levels: [Level]) -> Int? {
        levels.indices.first { !levels[$0].dots.isEmpty && !solved.contains($0 + 1) }
    }

    /// A playable level is unlocked when it is the first one, or the previous playable level is solved.
    func isLevelUnlocked(_ levelNumber: Int, levels: [Level] = LEVELS) -> Bool {
        let index = levelNumber - 1
        guard levels.indices.contains(index), !levels[index].dots.isEmpty else { return false }
        guard let previous = (0..<index).reversed().first(where: { !levels[$0].dots.isEmpty }) else {
            return true
        }
        return isSolved(previous + 1)
    }

    /// A giant location unlocks when its first playable sub-level is unlocked.
    func isLocationUnlocked(_ location: Int, levels: [Level] = LEVELS) -> Bool {
        let range = SceneArt.levels(in: location)
        guard let firstPlayable = range.first(where: { !levels[$0].dots.isEmpty }) else {
            return location == 0 || isLocationCompleted(location - 1, levels: levels)
        }
        return isLevelUnlocked(firstPlayable + 1, levels: levels)
    }

    func isLocationCompleted(_ location: Int, levels: [Level] = LEVELS) -> Bool {
        let playable = SceneArt.levels(in: location).filter { !levels[$0].dots.isEmpty }
        guard !playable.isEmpty else { return true }
        return playable.allSatisfy { isSolved($0 + 1) }
    }

    /// First unlocked, unsolved playable level inside a location, if any.
    func nextPlayableIndex(in location: Int, levels: [Level] = LEVELS) -> Int? {
        SceneArt.levels(in: location).first {
            !levels[$0].dots.isEmpty && isLevelUnlocked($0 + 1, levels: levels) && !isSolved($0 + 1)
        }
    }
}
