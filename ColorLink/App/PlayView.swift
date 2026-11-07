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

    var body: some View {
        VStack(spacing: 10) {
            topBar
            ZStack(alignment: .bottom) {
                BoardView(model: model)
                toast
            }
            .animation(.easeOut(duration: 0.2), value: model.toast)
            Text(model.levelIndex == 0 ? "按住一个点，拖到同色的另一个点" : "线路不能交叉，也不能穿过其他点")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .frame(minHeight: 20)
            controls
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .overlay {
            if model.showWin {
                WinCard(
                    isLast: model.isLastLevel,
                    levelNumber: model.levelIndex + 1,
                    solvedCount: progress.solved.count,
                    onReplay: { onSelectLevel(model.levelIndex) },
                    onNext: { model.isLastLevel ? onHome() : onSelectLevel(model.levelIndex + 1) }
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
            Button(action: onHome) { Image(systemName: "chevron.left") }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel("返回关卡列表")
            VStack(spacing: 2) {
                Text("第 \(model.levelIndex + 1) 关")
                    .font(.system(size: 22, weight: .black))
                    .kerning(1)
                Text("\(model.game.dots.count) 个点 · 已连接 \(model.connectedCount)/\(model.game.colors.count)")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .accessibilityIdentifier("level-sub")
            }
            .frame(maxWidth: .infinity)
            Button { onSelectLevel(model.levelIndex + 1) } label: { Image(systemName: "chevron.right") }
                .buttonStyle(IconButtonStyle())
                .disabled(model.isLastLevel)
                .accessibilityLabel("下一关")
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
            Button(action: model.undo) { Label("撤销", systemImage: "arrow.uturn.backward") }
                .buttonStyle(CardButtonStyle())
                .disabled(!model.game.canUndo)
                .opacity(model.game.canUndo ? 1 : 0.4)
                .keyboardShortcut("z", modifiers: .command)
                .accessibilityIdentifier("undo")
            Button(action: model.reset) { Label("重置", systemImage: "arrow.counterclockwise") }
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
    let onReplay: () -> Void
    let onNext: () -> Void

    @State private var appeared = false
    @State private var spin = false

    var body: some View {
        ZStack {
            Color(hex: 0x0F0A28, opacity: 0.55)
                .background(.ultraThinMaterial.opacity(0.4))
                .ignoresSafeArea()
            VStack(spacing: 6) {
                Text(isLast ? "全部通关！" : "过关！")
                    .font(.system(size: 32, weight: .heavy))
                    .kerning(3)
                    .foregroundStyle(Theme.accent)
                Text(isLast
                    ? "\(LEVELS.count) 关全部完成，你的智商超过了 120！"
                    : "第 \(levelNumber) 关完成，已通过 \(solvedCount)/\(LEVELS.count) 关")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 14)
                HStack(spacing: 10) {
                    Button("再玩一次", action: onReplay)
                        .buttonStyle(CardButtonStyle(background: AnyShapeStyle(Color.white.opacity(0.08))))
                    Button(isLast ? "返回关卡" : "下一关", action: onNext)
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
