import SwiftUI

/// One map location: its background fills the screen and its 10 levels float on top.
struct LocationView: View {
    @EnvironmentObject private var progress: ProgressStore
    let location: Int
    let onSelectLevel: (Int) -> Void
    let onBack: () -> Void

    @State private var cardVisible = false

    private var range: Range<Int> { SceneArt.levels(in: location) }
    private var playable: [Int] { range.filter { !LEVELS[$0].dots.isEmpty } }

    var body: some View {
        let next = progress.nextUnsolvedIndex(levels: LEVELS)
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Button { SoundPlayer.shared.play(.tap); onBack() } label: { Image(systemName: "map.fill") }
                    .buttonStyle(IconButtonStyle())
                    .accessibilityLabel("Back to map")
                VStack(spacing: 2) {
                    Text(SceneArt.locations[location].name)
                        .font(.system(size: 22, weight: .black))
                    Text("Location \(location + 1) · Levels \(range.lowerBound + 1)–\(range.upperBound) · \(pairsLabel)")
                        .font(.system(size: 12, weight: .semibold))
                        .opacity(0.85)
                }
                .foregroundStyle(.white)
                .padding(.vertical, 6)
                .padding(.horizontal, 14)
                .background(.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .frame(maxWidth: .infinity)
                SoundToggle()
            }

            Spacer()

            VStack(spacing: 14) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                    ForEach(range, id: \.self) { i in
                        LevelButton(
                            number: i + 1,
                            done: progress.isSolved(i + 1),
                            isNext: i == next,
                            isEmpty: LEVELS[i].dots.isEmpty,
                            action: { SoundPlayer.shared.play(.tap); onSelectLevel(i) }
                        )
                    }
                }
                Text("Solved \(playable.filter { progress.isSolved($0 + 1) }.count) / \(playable.count)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.35)))
            .shadow(color: .black.opacity(0.35), radius: 20, y: 12)
            .scaleEffect(cardVisible ? 1 : 0.8)
            .opacity(cardVisible ? 1 : 0)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 20)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SceneBackground(name: SceneArt.backgroundName(chapter: location), fallback: location))
        .task { @MainActor in
            if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-uiTest") }) {
                cardVisible = true
                return
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { cardVisible = true }
        }
    }

    private var pairsLabel: String {
        let counts = playable.map { LEVELS[$0].dots.count / 2 }
        guard let lo = counts.min(), let hi = counts.max() else { return "coming soon" }
        return lo == hi ? "\(lo) pairs" : "\(lo)–\(hi) pairs"
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
                    done
                        ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFACC15), Color(hex: 0xD97706)], startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(Color.black.opacity(0.35)),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.6), lineWidth: 2))
                .overlay(alignment: .topTrailing) {
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(6)
                    }
                }
                .overlay {
                    if isNext {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Theme.accent, lineWidth: 3)
                            .padding(-4)
                    }
                }
                .opacity(isEmpty ? 0.4 : 1)
        }
        .buttonStyle(PressableStyle())
        .foregroundStyle(.white)
        .disabled(isEmpty)
        .accessibilityLabel("Level \(number)\(done ? " (solved)" : isEmpty ? " (coming soon)" : "")")
        .accessibilityIdentifier("level-\(number)")
    }
}
