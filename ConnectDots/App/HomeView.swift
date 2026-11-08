import SwiftUI
import UIKit

/// Adventure map: 12 giant locations, each with 10 sub-levels nested underneath (no separate level list page).
struct HomeView: View {
    @EnvironmentObject private var progress: ProgressStore
    let onSelectLevel: (Int) -> Void

    @State private var expandedLocation: Int?

    private var playableCount: Int { LEVELS.filter { !$0.dots.isEmpty }.count }

    /// First location that still has an unsolved level.
    private var currentLocation: Int? {
        progress.nextUnsolvedIndex(levels: LEVELS).map(SceneArt.location(ofLevel:))
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = width * SceneArt.mapAspect
            ScrollViewReader { reader in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        mapImage
                            .frame(width: width, height: height)
                        ForEach(SceneArt.locations.indices, id: \.self) { i in
                            let location = SceneArt.locations[i]
                            let range = SceneArt.levels(in: i)
                            let playable = range.filter { !LEVELS[$0].dots.isEmpty }
                            GiantLevelMarker(
                                number: i + 1,
                                name: location.name,
                                solved: playable.filter { progress.isSolved($0 + 1) }.count,
                                total: playable.count,
                                isCurrent: i == currentLocation,
                                isUnlocked: progress.isLocationUnlocked(i),
                                isExpanded: expandedLocation == i,
                                subLevels: range.map { index in
                                    SubLevelInfo(
                                        index: index,
                                        localNumber: index - range.lowerBound + 1,
                                        done: progress.isSolved(index + 1),
                                        unlocked: progress.isLevelUnlocked(index + 1),
                                        isNext: index == progress.nextUnsolvedIndex(levels: LEVELS),
                                        isEmpty: LEVELS[index].dots.isEmpty
                                    )
                                },
                                onToggle: {
                                    SoundPlayer.shared.play(.tap)
                                    guard progress.isLocationUnlocked(i) else { return }
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        expandedLocation = expandedLocation == i ? nil : i
                                    }
                                },
                                onSelectSubLevel: { index in
                                    SoundPlayer.shared.play(.tap)
                                    onSelectLevel(index)
                                }
                            )
                            .id(i)
                            // Anchor the pad center on the map point; content grows downward.
                            .offset(
                                x: location.x * width - GiantLevelMarker.contentWidth / 2,
                                y: location.y * height - GiantLevelMarker.padSize / 2
                            )
                        }
                    }
                    .frame(width: width, height: height)
                }
                .scrollIndicators(.hidden)
                .ignoresSafeArea(edges: .bottom)
                .onAppear {
                    let focus = currentLocation ?? 0
                    if progress.isLocationUnlocked(focus) {
                        expandedLocation = focus
                    }
                    reader.scrollTo(focus, anchor: .center)
                }
            }
        }
        .overlay(alignment: .top) { header }
        .background(Color(hex: 0x0C4A6E).ignoresSafeArea())
    }

    @ViewBuilder
    private var mapImage: some View {
        if let image = UIImage(named: SceneArt.mapName) {
            Image(uiImage: image).resizable()
        } else {
            LinearGradient(colors: [Color(hex: 0x1E3A8A), Color(hex: 0x0EA5E9), Color(hex: 0xFDE68A)], startPoint: .top, endPoint: .bottom)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                .accessibilityLabel("Connect Dots")
            Spacer()
            SoundToggle()
            Text("Solved \(progress.solved.count) / \(playableCount)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(.black.opacity(0.45), in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }
}

private struct SubLevelInfo: Identifiable {
    var id: Int { index }
    let index: Int
    let localNumber: Int
    let done: Bool
    let unlocked: Bool
    let isNext: Bool
    let isEmpty: Bool
}

/// One giant location pad on the map, with its 10 sub-level chips nested underneath when expanded.
private struct GiantLevelMarker: View {
    static let padSize: CGFloat = 54
    /// Wide enough for the 5×2 sub-level strip so the pad stays centered as content expands.
    static let contentWidth: CGFloat = 176

    let number: Int
    let name: String
    let solved: Int
    let total: Int
    let isCurrent: Bool
    let isUnlocked: Bool
    let isExpanded: Bool
    let subLevels: [SubLevelInfo]
    let onToggle: () -> Void
    let onSelectSubLevel: (Int) -> Void

    @State private var pulse = false

    private var done: Bool { total > 0 && solved >= total }

    var body: some View {
        VStack(spacing: 4) {
            Button(action: onToggle) {
                pad
                    .frame(width: Self.padSize, height: Self.padSize)
                    .overlay {
                        if isCurrent && isUnlocked {
                            Circle()
                                .stroke(Theme.accent, lineWidth: 4)
                                .scaleEffect(pulse ? 1.4 : 1.1)
                                .opacity(pulse ? 0.2 : 0.9)
                                .allowsHitTesting(false)
                        }
                    }
                    .overlay(alignment: .top) {
                        if isCurrent && isUnlocked {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(.white, Theme.danger)
                                .shadow(radius: 3)
                                .offset(y: -38)
                                .accessibilityHidden(true)
                        }
                    }
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(accessibilityText)
            .accessibilityIdentifier("location-\(number)")
            .accessibilityHint(isUnlocked ? (isExpanded ? "Collapse sub-levels" : "Show sub-levels") : "Locked")

            label

            if isUnlocked && isExpanded {
                subLevelStrip
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(width: Self.contentWidth, alignment: .top)
        .saturation(isUnlocked ? 1 : 0)
        .opacity(isUnlocked ? 1 : 0.85)
        .onAppear {
            guard isCurrent && isUnlocked else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private var pad: some View {
        ZStack {
            Circle()
                .fill(padGradient)
                .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                .shadow(color: .black.opacity(0.45), radius: 4, y: 3)
            if !isUnlocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white.opacity(0.95))
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            } else if done {
                Image(systemName: "star.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Text("\(number)")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(.white)
            }
        }
    }

    private var padGradient: LinearGradient {
        if !isUnlocked {
            return LinearGradient(
                colors: [Color(hex: 0x94A3B8), Color(hex: 0x475569)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        if done {
            return LinearGradient(
                colors: [Color(hex: 0xFACC15), Color(hex: 0xD97706)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: [Color(hex: 0xF43F5E), Color(hex: 0x9F1239)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var label: some View {
        VStack(spacing: 0) {
            Text(name)
                .font(.system(size: 13, weight: .heavy))
            Text(isUnlocked ? "\(solved)/\(total)" : "Locked")
                .font(.system(size: 11, weight: .bold))
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(.vertical, 3)
        .padding(.horizontal, 10)
        .background(.black.opacity(0.5), in: Capsule())
        .fixedSize()
    }

    private var subLevelStrip: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 5), count: 5), spacing: 5) {
            ForEach(subLevels) { sub in
                SubLevelChip(info: sub) {
                    onSelectSubLevel(sub.index)
                }
            }
        }
        .padding(8)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.25)))
        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
        .fixedSize()
    }

    private var accessibilityText: String {
        if !isUnlocked {
            return "\(name), location \(number), locked"
        }
        return "\(name), location \(number), \(solved) of \(total) solved"
    }
}

private struct SubLevelChip: View {
    let info: SubLevelInfo
    let action: () -> Void

    private var canPlay: Bool { info.unlocked && !info.isEmpty }

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(fillStyle)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(borderColor, lineWidth: info.isNext ? 2.5 : 1.5))
                if !info.unlocked && !info.isEmpty {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                } else if info.done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(info.localNumber)")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 28, height: 28)
            .saturation(info.unlocked || info.isEmpty ? 1 : 0)
            .opacity(info.isEmpty ? 0.35 : info.unlocked ? 1 : 0.75)
        }
        .buttonStyle(PressableStyle())
        .disabled(!canPlay)
        .accessibilityLabel(chipLabel)
        .accessibilityIdentifier("level-\(info.index + 1)")
    }

    private var fillStyle: AnyShapeStyle {
        if !info.unlocked && !info.isEmpty {
            return AnyShapeStyle(LinearGradient(
                colors: [Color(hex: 0x94A3B8), Color(hex: 0x64748B)],
                startPoint: .top,
                endPoint: .bottom
            ))
        }
        if info.done {
            return AnyShapeStyle(LinearGradient(
                colors: [Color(hex: 0xFACC15), Color(hex: 0xD97706)],
                startPoint: .top,
                endPoint: .bottom
            ))
        }
        return AnyShapeStyle(Color.black.opacity(0.45))
    }

    private var borderColor: Color {
        if info.isNext { return Theme.accent }
        return .white.opacity(0.55)
    }

    private var chipLabel: String {
        let n = info.index + 1
        if info.isEmpty { return "Level \(n) (coming soon)" }
        if !info.unlocked { return "Level \(n) (locked)" }
        if info.done { return "Level \(n) (solved)" }
        return "Level \(n)"
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
