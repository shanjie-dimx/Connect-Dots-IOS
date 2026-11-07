import SwiftUI

/// Adventure map: one trail through all levels, walked from one dot to the next.
struct HomeView: View {
    @EnvironmentObject private var progress: ProgressStore
    let onSelectLevel: (Int) -> Void

    static let levelsPerChapter = 10
    static let chapterNames = [
        "Warm-up", "Beginner", "Easy", "Steady", "Tricky", "Twisty",
        "Hard", "Harder", "Expert", "Master", "Genius", "Legend",
    ]

    private let rowHeight: CGFloat = 92
    private let bannerHeight: CGFloat = 64

    private var playableCount: Int { LEVELS.filter { !$0.dots.isEmpty }.count }

    var body: some View {
        let next = progress.nextUnsolvedIndex(levels: LEVELS)
        GeometryReader { geo in
            ScrollViewReader { reader in
                ScrollView {
                    VStack(spacing: 0) {
                        header
                        trail(width: min(geo.size.width, 560), next: next)
                            .frame(maxWidth: .infinity)
                        Text("More adventures coming soon")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.vertical, 30)
                    }
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    if let next { reader.scrollTo(next, anchor: .center) }
                }
            }
        }
        .background(SceneBackground(name: SceneArt.mapName, fallback: 0))
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 220)
                .shadow(color: .black.opacity(0.35), radius: 14, y: 10)
                .accessibilityLabel("Connect Dots")
            Text("Connect same-colored dots. Lines can't cross, can't pass through other dots, and can't leave the circle.")
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 24)
            Text("Solved \(progress.solved.count) / \(playableCount)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .padding(.vertical, 6)
                .padding(.horizontal, 14)
                .background(.black.opacity(0.35), in: Capsule())
        }
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    /// Vertical position of each level node, leaving room for a banner before every chapter.
    private func nodeY(_ i: Int) -> CGFloat {
        let chapter = i / Self.levelsPerChapter
        return CGFloat(chapter + 1) * bannerHeight + CGFloat(i) * rowHeight + rowHeight / 2
    }

    private func nodeX(_ i: Int, width: CGFloat) -> CGFloat {
        width / 2 + (width / 2 - 56) * CGFloat(sin(Double(i) * 0.95))
    }

    private func trail(width: CGFloat, next: Int?) -> some View {
        let count = LEVELS.count
        let chapters = (count + Self.levelsPerChapter - 1) / Self.levelsPerChapter
        let height = nodeY(count - 1) + rowHeight / 2
        return ZStack(alignment: .topLeading) {
            Path { path in
                for i in 0..<count {
                    let p = CGPoint(x: nodeX(i, width: width), y: nodeY(i))
                    if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
                }
            }
            .stroke(Color(hex: 0xFDE68A), style: StrokeStyle(lineWidth: 6, lineCap: .round, dash: [2, 12]))
            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)

            ForEach(0..<chapters, id: \.self) { chapter in
                ChapterBanner(chapter: chapter)
                    .frame(width: width - 32, height: bannerHeight - 14)
                    .position(x: width / 2, y: nodeY(chapter * Self.levelsPerChapter) - rowHeight / 2 - bannerHeight / 2)
            }

            ForEach(0..<count, id: \.self) { i in
                LevelNode(
                    number: i + 1,
                    done: progress.isSolved(i + 1),
                    isNext: i == next,
                    isEmpty: LEVELS[i].dots.isEmpty,
                    action: { onSelectLevel(i) }
                )
                .id(i)
                .position(x: nodeX(i, width: width), y: nodeY(i))
            }
        }
        .frame(width: width, height: height)
    }
}

private struct ChapterBanner: View {
    let chapter: Int

    var body: some View {
        let start = chapter * HomeView.levelsPerChapter
        let range = start..<min(start + HomeView.levelsPerChapter, LEVELS.count)
        let counts = range.map { LEVELS[$0].dots.count / 2 }.filter { $0 > 0 }
        let pairs: String = {
            guard let lo = counts.min(), let hi = counts.max() else { return "coming soon" }
            return lo == hi ? "\(lo) pairs" : "\(lo)–\(hi) pairs"
        }()
        return HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Chapter \(chapter + 1) · \(HomeView.chapterNames[chapter % HomeView.chapterNames.count])")
                    .font(.system(size: 16, weight: .heavy))
                Text("Levels \(range.lowerBound + 1)–\(range.upperBound) · \(pairs)")
                    .font(.system(size: 12, weight: .semibold))
                    .opacity(0.85)
            }
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(maxHeight: .infinity)
        .background(
            LinearGradient(colors: [Color(hex: 0xB45309), Color(hex: 0xF59E0B)], startPoint: .leading, endPoint: .trailing),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color(hex: 0xFDE68A), lineWidth: 2))
        .shadow(color: .black.opacity(0.35), radius: 6, y: 4)
    }
}

private struct LevelNode: View {
    let number: Int
    let done: Bool
    let isNext: Bool
    let isEmpty: Bool
    let action: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(fill)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 3)
                Text("\(number)")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 0, y: 1)
                if done {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white, Color(hex: 0x16A34A))
                        .offset(x: 22, y: -22)
                }
            }
            .frame(width: 58, height: 58)
            .overlay {
                if isNext {
                    Circle()
                        .stroke(Theme.accent, lineWidth: 4)
                        .scaleEffect(pulse ? 1.35 : 1.1)
                        .opacity(pulse ? 0.2 : 0.9)
                }
            }
            .overlay(alignment: .top) {
                if isNext {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white, Theme.danger)
                        .shadow(radius: 3)
                        .offset(y: -40)
                        .accessibilityHidden(true)
                }
            }
            .opacity(isEmpty ? 0.45 : 1)
        }
        .buttonStyle(PressableStyle())
        .disabled(isEmpty)
        .onAppear {
            guard isNext else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityLabel("Level \(number)\(done ? " (solved)" : isEmpty ? " (coming soon)" : isNext ? " (you are here)" : "")")
        .accessibilityIdentifier("level-\(number)")
    }

    private var fill: AnyShapeStyle {
        if isEmpty { return AnyShapeStyle(Color.gray) }
        if done { return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFACC15), Color(hex: 0xF59E0B)], startPoint: .top, endPoint: .bottom)) }
        let palette = Theme.palette[(number - 1) % Theme.palette.count]
        return AnyShapeStyle(LinearGradient(colors: [palette.fill, palette.dark], startPoint: .top, endPoint: .bottom))
    }
}

private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
