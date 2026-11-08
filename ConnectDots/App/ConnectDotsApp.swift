import SwiftUI

@main
struct ConnectDotsApp: App {
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
    private enum Screen: Equatable {
        case map
        case level(Int)
    }

    @State private var screen = Screen.map
    /// Bumped on every level start so replaying the same level gets a fresh board.
    @State private var attempt = 0

    var body: some View {
        ZStack {
            AppBackground()
            switch screen {
            case .map:
                HomeView(onSelectLevel: open)
                    .transition(.opacity)
            case .level(let index):
                PlayView(levelIndex: index, onSelectLevel: open, onHome: { screen = .map })
                    .id(attempt)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: screen)
    }

    private func open(_ index: Int) {
        attempt += 1
        screen = .level(min(max(index, 0), LEVELS.count - 1))
    }
}
