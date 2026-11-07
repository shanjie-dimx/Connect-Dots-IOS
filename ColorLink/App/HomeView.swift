import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var progress: ProgressStore
    let onSelectLevel: (Int) -> Void

    static let levelsPerChapter = 10
    private static let chapterNames = [
        "Warm-up", "Beginner", "Easy", "Steady", "Tricky", "Twisty",
        "Hard", "Harder", "Expert", "Master", "Genius", "Legend",
    ]

    private var playableCount: Int { LEVELS.filter { !$0.dots.isEmpty }.count }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                hero
                rules
                ForEach(0..<chapterCount, id: \.self) { chapter in
                    let range = chapterRange(chapter)
                    levelGroup(
                        title: "Chapter \(chapter + 1) · \(Self.chapterNames[chapter % Self.chapterNames.count])",
                        subtitle: "Levels \(range.lowerBound + 1)–\(range.upperBound) · \(pairsLabel(range))",
                        range: range
                    )
                }
                Text("Solved \(progress.solved.count) / \(playableCount)")
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

    private var chapterCount: Int {
        (LEVELS.count + Self.levelsPerChapter - 1) / Self.levelsPerChapter
    }

    private func chapterRange(_ chapter: Int) -> Range<Int> {
        let start = chapter * Self.levelsPerChapter
        return start..<min(start + Self.levelsPerChapter, LEVELS.count)
    }

    private func pairsLabel(_ range: Range<Int>) -> String {
        let counts = range.map { LEVELS[$0].dots.count / 2 }.filter { $0 > 0 }
        guard let lo = counts.min(), let hi = counts.max() else { return "coming soon" }
        return lo == hi ? "\(lo) pairs" : "\(lo)–\(hi) pairs"
    }

    private var hero: some View {
        VStack(spacing: 4) {
            LogoMark()
                .frame(width: 76, height: 76)
                .shadow(color: .black.opacity(0.35), radius: 10, y: 8)
            Text("Color Link")
                .font(.system(size: 40, weight: .black))
                .kerning(2)
                .foregroundStyle(Theme.titleGradient)
                .shadow(color: .black.opacity(0.25), radius: 0, y: 3)
                .padding(.top, 8)
            Text("Only a 120 IQ can clear every level")
                .font(.system(size: 15))
                .foregroundStyle(Theme.muted)
        }
    }

    private var rules: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Connect dots of the \(Text("same color").bold().foregroundColor(.white)) inside the circle")
            Text("Lines \(Text("can't cross").bold().foregroundColor(.white)), can't \(Text("pass through other dots").bold().foregroundColor(.white)), and can't \(Text("leave the circle").bold().foregroundColor(.white))")
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
        let next = progress.nextUnsolvedIndex(levels: LEVELS)
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
                        isEmpty: LEVELS[i].dots.isEmpty,
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
    let isEmpty: Bool
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
                .opacity(isEmpty ? 0.35 : 1)
        }
        .buttonStyle(PressableStyle())
        .foregroundStyle(.white)
        .disabled(isEmpty)
        .accessibilityLabel("Level \(number)\(done ? " (solved)" : isEmpty ? " (coming soon)" : "")")
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
