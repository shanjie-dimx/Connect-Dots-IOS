import SwiftUI
import UIKit

/// Drives one level on screen: forwards touches to the rules engine and owns transient UI state.
@MainActor
final class GameModel: ObservableObject {
    private enum DragState {
        case idle, drawing, ignoring
    }

    static let blockMessages: [BlockReason: String] = [
        .line: "Lines can't cross",
        .dot: "Can't pass through other dots",
        .edge: "Can't leave the circle",
    ]

    let levelIndex: Int
    let game: Game

    @Published private(set) var revision = 0
    @Published private(set) var toast: String?
    @Published var showWin = false
    /// Why the most recent stroke got stuck; kept until the next touch so VoiceOver can read it.
    private(set) var lastBlockMessage: String?
    private(set) var blockedAt: Point?
    private(set) var blockedUntil = Date.distantPast

    private var dragState = DragState.idle
    private var toastTask: Task<Void, Never>?
    private var winTask: Task<Void, Never>?
    private let impact = UIImpactFeedbackGenerator(style: .light)
    private let notify = UINotificationFeedbackGenerator()

    init(levelIndex: Int) {
        self.levelIndex = levelIndex
        game = Game(level: Self.level(at: levelIndex))
    }

    private static func level(at index: Int) -> Level {
        #if DEBUG
        // UI tests can only drag in straight lines, so they use fixed levels instead of LEVELS[0].
        let arguments = ProcessInfo.processInfo.arguments
        if index == 0, arguments.contains("-uiTestStraightLevel") {
            return Level(id: 1, dots: [
                Dot(x: -0.6, y: -0.4, color: 0), Dot(x: 0.6, y: -0.4, color: 0),
                Dot(x: -0.6, y: 0, color: 1), Dot(x: 0.6, y: 0, color: 1),
                Dot(x: -0.6, y: 0.4, color: 2), Dot(x: 0.6, y: 0.4, color: 2),
            ])
        }
        if index == 0, arguments.contains("-uiTestCrossLevel") {
            return Level(id: 1, dots: [
                Dot(x: 0, y: -0.8, color: 0), Dot(x: 0, y: 0.8, color: 0),
                Dot(x: -0.6, y: 0.4, color: 1), Dot(x: 0.6, y: 0.4, color: 1),
                Dot(x: -0.6, y: -0.4, color: 2), Dot(x: 0.6, y: -0.4, color: 2),
            ])
        }
        #endif
        return LEVELS[index]
    }

    /// Next level that has dots; blank levels are skipped.
    var nextLevelIndex: Int? {
        LEVELS.indices.first { $0 > levelIndex && !LEVELS[$0].dots.isEmpty }
    }

    var isLastLevel: Bool { nextLevelIndex == nil }
    var connectedCount: Int { game.paths.count }

    /// True while something on the board is animating (pulsing dot or fading cross).
    func isAnimating(at now: Date) -> Bool {
        game.active != nil || (blockedAt != nil && now < blockedUntil)
    }

    func dragChanged(start: Point, location: Point) {
        guard !showWin else { return }
        switch dragState {
        case .idle:
            lastBlockMessage = nil
            if game.pointerDown(start) {
                dragState = .drawing
                impact.prepare()
                move(to: location)
            } else {
                dragState = .ignoring
            }
            changed()
        case .drawing:
            move(to: location)
        case .ignoring:
            break
        }
    }

    func dragEnded() {
        if dragState == .drawing { game.pointerUp() }
        dragState = .idle
        changed()
    }

    func undo() {
        game.undo()
        dragState = .idle
        lastBlockMessage = nil
        changed()
    }

    func reset() {
        game.reset()
        dragState = .idle
        lastBlockMessage = nil
        changed()
    }

    private func move(to location: Point) {
        switch game.pointerMove(location) {
        case .blocked:
            let now = Date()
            if now >= blockedUntil { notify.notificationOccurred(.warning) }
            blockedAt = game.blocked
            blockedUntil = now.addingTimeInterval(0.7)
            let message = Self.blockMessages[game.blockReason ?? .line] ?? "Blocked"
            lastBlockMessage = message
            showToast(message)
        case .connected:
            dragState = .ignoring
            impact.impactOccurred()
            if game.isSolved { scheduleWin() }
        case .moved, .none:
            break
        }
        changed()
    }

    private func changed() {
        revision &+= 1
    }

    private func showToast(_ text: String) {
        if toast != text { UIAccessibility.post(notification: .announcement, argument: text) }
        toast = text
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    private func scheduleWin() {
        winTask?.cancel()
        winTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard let self, !Task.isCancelled, self.game.isSolved else { return }
            self.notify.notificationOccurred(.success)
            self.showWin = true
        }
    }
}
