import SwiftUI

/// One giant location scene: its background fills the screen and its 10 sub-levels (with locks) sit on top.
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
                    Text("Location \(location + 1) · \(pairsLabel)")
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
                        let levelNumber = i + 1
                        let localNumber = i - range.lowerBound + 1
                        LevelButton(
                            localNumber: localNumber,
                            levelNumber: levelNumber,
                            done: progress.isSolved(levelNumber),
                            unlocked: progress.isLevelUnlocked(levelNumber),
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
    let localNumber: Int
    let levelNumber: Int
    let done: Bool
    let unlocked: Bool
    let isNext: Bool
    let isEmpty: Bool
    let action: () -> Void

    private var canPlay: Bool { unlocked && !isEmpty }

    var body: some View {
        Button(action: action) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if !unlocked && !isEmpty {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 22, weight: .bold))
                    } else if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 22, weight: .bold))
                    } else {
                        Text("\(localNumber)").font(.system(size: 20, weight: .heavy))
                    }
                }
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .background(fillStyle, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(borderColor, lineWidth: isNext ? 3 : 2))
                .overlay {
                    if isNext && canPlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Theme.accent, lineWidth: 3)
                            .padding(-4)
                    }
                }
                .saturation(unlocked || isEmpty ? 1 : 0)
                .opacity(isEmpty ? 0.4 : unlocked ? 1 : 0.85)
        }
        .buttonStyle(PressableStyle())
        .foregroundStyle(.white)
        .disabled(!canPlay)
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier("level-\(levelNumber)")
    }

    private var fillStyle: AnyShapeStyle {
        if !unlocked && !isEmpty {
            return AnyShapeStyle(LinearGradient(
                colors: [Color(hex: 0x94A3B8), Color(hex: 0x64748B)],
                startPoint: .top,
                endPoint: .bottom
            ))
        }
        if done {
            return AnyShapeStyle(LinearGradient(
                colors: [Color(hex: 0xFACC15), Color(hex: 0xD97706)],
                startPoint: .top,
                endPoint: .bottom
            ))
        }
        return AnyShapeStyle(Color.black.opacity(0.35))
    }

    private var borderColor: Color {
        .white.opacity(unlocked ? 0.6 : 0.35)
    }

    private var accessibilityText: String {
        if isEmpty { return "Level \(levelNumber) (coming soon)" }
        if !unlocked { return "Level \(levelNumber) (locked)" }
        if done { return "Level \(levelNumber) (solved)" }
        return "Level \(levelNumber)"
    }
}
