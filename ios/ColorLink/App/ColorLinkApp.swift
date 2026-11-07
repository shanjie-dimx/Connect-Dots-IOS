import SwiftUI

@main
struct ColorLinkApp: App {
    @StateObject private var progress = ProgressStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(progress)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @State private var levelIndex: Int?
    /// Bumped on every level start so replaying the same level gets a fresh board.
    @State private var attempt = 0

    var body: some View {
        ZStack {
            AppBackground()
            if let index = levelIndex {
                PlayView(levelIndex: index, onSelectLevel: open, onHome: { levelIndex = nil })
                    .id(attempt)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                HomeView(onSelectLevel: open)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: levelIndex)
    }

    private func open(_ index: Int) {
        attempt += 1
        levelIndex = min(max(index, 0), LEVELS.count - 1)
    }
}
