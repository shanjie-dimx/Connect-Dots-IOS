import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var progress: ProgressStore
    let onSelectLevel: (Int) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                hero
                rules
                levelGroup(title: "入门 · 六个点", subtitle: "第 1–10 关", range: 0..<10)
                levelGroup(title: "进阶 · 八个点", subtitle: "第 11–20 关", range: 10..<20)
                Text("已通过 \(progress.solved.count) / \(LEVELS.count) 关")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 28)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private var hero: some View {
        VStack(spacing: 4) {
            LogoMark()
                .frame(width: 76, height: 76)
                .shadow(color: .black.opacity(0.35), radius: 10, y: 8)
            Text("同色连线")
                .font(.system(size: 40, weight: .black))
                .kerning(4)
                .foregroundStyle(Theme.titleGradient)
                .shadow(color: .black.opacity(0.25), radius: 0, y: 3)
                .padding(.top, 8)
            Text("智商没有 120，都过不了这一关")
                .font(.system(size: 15))
                .foregroundStyle(Theme.muted)
        }
    }

    private var rules: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("在圆内把\(Text("颜色相同").bold().foregroundColor(.white))的点连起来")
            Text("线路\(Text("不能交叉").bold().foregroundColor(.white))，不能\(Text("穿过其他点").bold().foregroundColor(.white))，也不能\(Text("超出圆圈").bold().foregroundColor(.white))")
        }
        .font(.system(size: 14))
        .lineSpacing(4)
        .foregroundStyle(Theme.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial.opacity(0.5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.cardBorder))
    }

    private func levelGroup(title: String, subtitle: String, range: Range<Int>) -> some View {
        let next = progress.nextUnsolvedIndex(levelCount: LEVELS.count)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(size: 16, weight: .bold))
                Spacer()
                Text(subtitle).font(.system(size: 13)).foregroundStyle(Theme.muted)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                ForEach(range, id: \.self) { i in
                    LevelButton(
                        number: i + 1,
                        done: progress.isSolved(i + 1),
                        isNext: i == next,
                        action: { onSelectLevel(i) }
                    )
                }
            }
        }
    }
}

private struct LevelButton: View {
    let number: Int
    let done: Bool
    let isNext: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Text("\(number)").font(.system(size: 20, weight: .heavy))
                }
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .background(
                    done ? AnyShapeStyle(Theme.doneGradient) : AnyShapeStyle(Theme.card),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.cardBorder))
                .overlay(alignment: .topTrailing) {
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(hex: 0xBBF7D0))
                            .padding(6)
                    }
                }
                .overlay {
                    if isNext {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Theme.accent, lineWidth: 2)
                            .padding(-4)
                    }
                }
        }
        .buttonStyle(PressableStyle())
        .foregroundStyle(.white)
        .accessibilityLabel("第 \(number) 关\(done ? "（已通过）" : "")")
        .accessibilityIdentifier("level-\(number)")
    }
}

private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Same artwork as icon.svg (the app icon), minus the square background.
struct LogoMark: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 64
            func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * s, y: y * s) }
            let disk = Path(ellipseIn: CGRect(x: 3 * s, y: 3 * s, width: 58 * s, height: 58 * s))
            ctx.fill(disk, with: .color(Color(hex: 0xE0F2FE)))
            ctx.stroke(disk, with: .color(Color(hex: 0x1E1B4B)), lineWidth: 4 * s)

            let curves: [(Color, CGPoint, CGPoint, CGPoint, CGPoint)] = [
                (Theme.palette[0].fill, p(17, 27), p(21, 12), p(43, 12), p(47, 27)),
                (Theme.palette[1].fill, p(20, 43), p(25, 53), p(39, 53), p(44, 43)),
            ]
            for (color, a, c1, c2, b) in curves {
                var path = Path()
                path.move(to: a)
                path.addCurve(to: b, control1: c1, control2: c2)
                ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 5 * s, lineCap: .round))
                for end in [a, b] {
                    ctx.fill(Path(ellipseIn: CGRect(x: end.x - 5 * s, y: end.y - 5 * s, width: 10 * s, height: 10 * s)), with: .color(color))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
