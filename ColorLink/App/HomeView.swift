import SwiftUI
import UIKit

/// Adventure map: 12 locations along the trail, walked from the bottom of the map to the top.
struct HomeView: View {
    @EnvironmentObject private var progress: ProgressStore
    let onSelectLocation: (Int) -> Void

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
                            LocationMarker(
                                number: i + 1,
                                name: location.name,
                                solved: SceneArt.levels(in: i).filter { progress.isSolved($0 + 1) }.count,
                                total: SceneArt.levels(in: i).filter { !LEVELS[$0].dots.isEmpty }.count,
                                isCurrent: i == currentLocation,
                                action: { onSelectLocation(i) }
                            )
                            .id(i)
                            .position(x: location.x * width, y: location.y * height)
                        }
                    }
                    .frame(width: width, height: height)
                }
                .scrollIndicators(.hidden)
                .ignoresSafeArea(edges: .bottom)
                .onAppear {
                    reader.scrollTo(currentLocation ?? 0, anchor: .center)
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

private struct LocationMarker: View {
    let number: Int
    let name: String
    let solved: Int
    let total: Int
    let isCurrent: Bool
    let action: () -> Void

    @State private var pulse = false

    private var done: Bool { total > 0 && solved >= total }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: done ? [Color(hex: 0xFACC15), Color(hex: 0xD97706)] : [Color(hex: 0xF43F5E), Color(hex: 0x9F1239)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                        .shadow(color: .black.opacity(0.45), radius: 4, y: 3)
                    if done {
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
                    if isCurrent {
                        Circle()
                            .stroke(Theme.accent, lineWidth: 4)
                            .scaleEffect(pulse ? 1.4 : 1.1)
                            .opacity(pulse ? 0.2 : 0.9)
                    }
                }
                .overlay(alignment: .top) {
                    if isCurrent {
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
                    Text("\(solved)/\(total)")
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
        .onAppear {
            guard isCurrent else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityLabel("\(name), location \(number), \(solved) of \(total) solved")
        .accessibilityIdentifier("location-\(number)")
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
