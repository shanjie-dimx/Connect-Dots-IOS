import SwiftUI

struct PlayView: View {
    @EnvironmentObject private var progress: ProgressStore
    @StateObject private var model: GameModel
    let onSelectLevel: (Int) -> Void
    let onHome: () -> Void

    init(levelIndex: Int, onSelectLevel: @escaping (Int) -> Void, onHome: @escaping () -> Void) {
        _model = StateObject(wrappedValue: GameModel(levelIndex: levelIndex))
        self.onSelectLevel = onSelectLevel
        self.onHome = onHome
    }

    /// The scene shows first; the puzzle floats in on top of it a moment later.
    @State private var boardVisible = false

    private var chapter: Int { SceneArt.location(ofLevel: model.levelIndex) }

    var body: some View {
        VStack(spacing: 10) {
            topBar
            ZStack(alignment: .bottom) {
                BoardView(model: model)
                toast
            }
            .animation(.easeOut(duration: 0.2), value: model.toast)
            .modifier(ShakeEffect(animatableData: CGFloat(model.shakes)))
            .animation(.linear(duration: 0.35), value: model.shakes)
            .shadow(color: .black.opacity(0.45), radius: 24, y: 18)
            .scaleEffect(boardVisible ? 1 : 0.7)
            .offset(y: boardVisible ? 0 : 60)
            .opacity(boardVisible ? 1 : 0)
            Text(model.levelIndex == 0 ? "Hold a dot and drag it to the other dot of the same color" : "Lines can't cross or pass through other dots")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.vertical, 6)
                .padding(.horizontal, 14)
                .background(.black.opacity(0.35), in: Capsule())
                .frame(minHeight: 20)
            controls
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SceneBackground(name: SceneArt.backgroundName(chapter: chapter), fallback: chapter))
        .task { @MainActor in
            // UI tests drag at fixed board coordinates, so the board must not be mid-animation.
            if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-uiTest") }) {
                boardVisible = true
                return
            }
            try? await Task.sleep(nanoseconds: 450_000_000)
            SoundPlayer.shared.play(.whoosh, volume: 0.6)
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) { boardVisible = true }
        }
        .overlay {
            if model.showWin {
                WinCard(
                    isLast: model.isLastLevel,
                    levelNumber: model.levelIndex + 1,
                    solvedCount: progress.solved.count,
                    totalCount: LEVELS.filter { !$0.dots.isEmpty }.count,
                    onReplay: { SoundPlayer.shared.play(.tap); onSelectLevel(model.levelIndex) },
                    onNext: {
                        SoundPlayer.shared.play(.tap)
                        if let next = model.nextLevelIndex { onSelectLevel(next) } else { onHome() }
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: model.showWin)
        .onChange(of: model.showWin) { won in
            if won { progress.markSolved(model.levelIndex + 1) }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { SoundPlayer.shared.play(.tap); onHome() } label: { Image(systemName: "chevron.left") }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel("Back to map")
            VStack(spacing: 2) {
                Text("Level \(model.levelIndex + 1)")
                    .font(.system(size: 22, weight: .black))
                    .kerning(1)
                Text("\(model.game.colors.count) pairs · \(model.connectedCount)/\(model.game.colors.count) connected")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .accessibilityIdentifier("level-sub")
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 16)
            .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .frame(maxWidth: .infinity)
            Button {
                SoundPlayer.shared.play(.tap)
                if let next = model.nextLevelIndex { onSelectLevel(next) }
            } label: { Image(systemName: "chevron.right") }
                .buttonStyle(IconButtonStyle())
                .disabled(model.isLastLevel)
                .accessibilityLabel("Next level")
        }
    }

    @ViewBuilder
    private var toast: some View {
        if let text = model.toast {
            Text(text)
                .font(.system(size: 14))
                .padding(.vertical, 6)
                .padding(.horizontal, 14)
                .background(Theme.danger.opacity(0.92), in: Capsule())
                .padding(.bottom, 4)
                .transition(.opacity.combined(with: .offset(y: 8)))
                .allowsHitTesting(false)
                .accessibilityIdentifier("toast")
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button(action: model.undo) { Label("Undo", systemImage: "arrow.uturn.backward") }
                .buttonStyle(CardButtonStyle())
                .disabled(!model.game.canUndo)
                .opacity(model.game.canUndo ? 1 : 0.4)
                .keyboardShortcut("z", modifiers: .command)
                .accessibilityIdentifier("undo")
            Button(action: model.reset) { Label("Reset", systemImage: "arrow.counterclockwise") }
                .buttonStyle(CardButtonStyle())
                .disabled(model.game.paths.isEmpty)
                .opacity(model.game.paths.isEmpty ? 0.4 : 1)
                .keyboardShortcut("r", modifiers: [])
                .accessibilityIdentifier("reset")
        }
    }
}

private struct WinCard: View {
    let isLast: Bool
    let levelNumber: Int
    let solvedCount: Int
    let totalCount: Int
    let onReplay: () -> Void
    let onNext: () -> Void

    @State private var appeared = false
    @State private var spin = false
    @State private var stars = 0

    var body: some View {
        ZStack {
            Color(hex: 0x0F0A28, opacity: 0.55)
                .background(.ultraThinMaterial.opacity(0.4))
                .ignoresSafeArea()
            ConfettiView()
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: "star.fill")
                            .font(.system(size: i == 1 ? 44 : 34))
                            .foregroundStyle(Theme.accent)
                            .shadow(color: Color(hex: 0xF59E0B).opacity(0.8), radius: 8)
                            .scaleEffect(stars > i ? 1 : 0.01)
                            .rotationEffect(.degrees(stars > i ? 0 : -90))
                            .offset(y: i == 1 ? -6 : 0)
                            .animation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.2 + Double(i) * 0.18), value: stars)
                    }
                }
                .padding(.bottom, 4)
                .accessibilityHidden(true)
                Text(isLast ? "All clear!" : "Solved!")
                    .font(.system(size: 32, weight: .heavy))
                    .kerning(2)
                    .foregroundStyle(Theme.accent)
                Text(isLast
                    ? "You cleared every level. Your IQ is over 120!"
                    : "Level \(levelNumber) done · \(solvedCount)/\(totalCount) solved")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 14)
                HStack(spacing: 10) {
                    Button("Play again", action: onReplay)
                        .buttonStyle(CardButtonStyle(background: AnyShapeStyle(Color.white.opacity(0.08))))
                    Button(isLast ? "Map" : "Next level", action: onNext)
                        .buttonStyle(CardButtonStyle(background: AnyShapeStyle(Theme.primaryGradient), bordered: false))
                }
            }
            .padding(.top, 28)
            .padding(.horizontal, 22)
            .padding(.bottom, 20)
            .frame(maxWidth: 340)
            .background {
                ZStack {
                    LinearGradient(colors: [Color(hex: 0x312E81), Color(hex: 0x6D28D9)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    SunBurst()
                        .fill(Theme.accent.opacity(0.12))
                        .scaleEffect(2.2)
                        .rotationEffect(.degrees(spin ? 360 : 0))
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.25)))
            .shadow(color: .black.opacity(0.45), radius: 30, y: 20)
            .padding(.horizontal, 28)
            .scaleEffect(appeared ? 1 : 0.6)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { appeared = true }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) { spin = true }
            stars = 3
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

/// Alternating rays like the web version's conic-gradient burst.
private struct SunBurst: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = hypot(rect.width, rect.height)
        var path = Path()
        for i in stride(from: 0, to: 360, by: 24) {
            let a0 = Angle.degrees(Double(i) + 12)
            let a1 = Angle.degrees(Double(i) + 24)
            path.move(to: c)
            path.addArc(center: c, radius: r, startAngle: a0, endAngle: a1, clockwise: false)
            path.closeSubpath()
        }
        return path
    }
}
