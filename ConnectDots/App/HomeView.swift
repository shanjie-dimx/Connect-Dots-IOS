import SwiftUI
import UIKit

/// Adventure map: 12 giant locations only. Sub-levels live inside each location scene, not on the map.
struct HomeView: View {
    @EnvironmentObject private var progress: ProgressStore
    let onSelectLocation: (Int) -> Void
    let onPlay: (Int) -> Void

    private var playableCount: Int { LEVELS.filter { !$0.dots.isEmpty }.count }

    /// First location that still has an unsolved level.
    private var currentLocation: Int? {
        progress.nextUnsolvedIndex(levels: LEVELS).map(SceneArt.location(ofLevel:))
    }

    private var nextLevelIndex: Int? {
        progress.nextUnsolvedIndex(levels: LEVELS)
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
                            LocationMarker(
                                number: i + 1,
                                name: location.name,
                                solved: playable.filter { progress.isSolved($0 + 1) }.count,
                                total: playable.count,
                                isCurrent: i == currentLocation,
                                isUnlocked: progress.isLocationUnlocked(i),
                                action: {
                                    SoundPlayer.shared.play(.tap)
                                    guard progress.isLocationUnlocked(i) else { return }
                                    onSelectLocation(i)
                                }
                            )
                            .id(i)
                            .position(x: location.x * width, y: location.y * height)
                        }
                        // Scroll target so the beach / start is visible first, not the locked summit.
                        Color.clear
                            .frame(width: 1, height: 1)
                            .id("map-bottom")
                            .position(x: width / 2, y: height - 1)
                    }
                    .frame(width: width, height: height)
                    .id("map-content")
                }
                .scrollIndicators(.hidden)
                .ignoresSafeArea(edges: .bottom)
                .onAppear { scrollToStart(reader) }
                .task {
                    // Layout may not be ready on the first onAppear pass.
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    scrollToStart(reader)
                }
            }
        }
        .overlay(alignment: .top) { header }
        .safeAreaInset(edge: .bottom, spacing: 0) { playBar }
        .background(Color(hex: 0x0C4A6E).ignoresSafeArea())
    }

    /// Open on the beach / current progress — never leave the player staring at the locked summit.
    private func scrollToStart(_ reader: ScrollViewProxy) {
        if let focus = currentLocation, focus > 0 {
            reader.scrollTo(focus, anchor: .center)
        } else {
            reader.scrollTo(0, anchor: .bottom)
            reader.scrollTo("map-bottom", anchor: .bottom)
        }
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

    @ViewBuilder
    private var playBar: some View {
        if let next = nextLevelIndex {
            Button {
                SoundPlayer.shared.play(.tap)
                onPlay(next)
            } label: {
                Text("Play")
                    .font(.system(size: 22, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Theme.primaryGradient, in: Capsule())
                    .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
            }
            .buttonStyle(PressableStyle())
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
            .accessibilityLabel("Play level \(next + 1)")
            .accessibilityIdentifier("play")
        }
    }
}

private struct LocationMarker: View {
    let number: Int
    let name: String
    let solved: Int
    let total: Int
    let isCurrent: Bool
    let isUnlocked: Bool
    let action: () -> Void

    @State private var pulse = false

    private var done: Bool { total > 0 && solved >= total }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
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
                .frame(width: 54, height: 54)
                .overlay {
                    if isCurrent && isUnlocked {
                        Circle()
                            .stroke(Theme.accent, lineWidth: 4)
                            .scaleEffect(pulse ? 1.4 : 1.1)
                            .opacity(pulse ? 0.2 : 0.9)
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
        }
        .buttonStyle(PressableStyle())
        .saturation(isUnlocked ? 1 : 0)
        .opacity(isUnlocked ? 1 : 0.85)
        .disabled(!isUnlocked)
        .onAppear {
            guard isCurrent && isUnlocked else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier("location-\(number)")
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

    private var accessibilityText: String {
        if !isUnlocked {
            return "\(name), location \(number), locked"
        }
        return "\(name), location \(number), \(solved) of \(total) solved"
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
