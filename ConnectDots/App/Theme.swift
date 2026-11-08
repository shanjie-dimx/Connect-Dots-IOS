import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

struct DotPalette {
    let fill: Color
    let dark: Color
}

enum Theme {
    /// One entry per color index; levels use up to 10 pairs.
    static let palette: [DotPalette] = [
        DotPalette(fill: Color(hex: 0xF43F5E), dark: Color(hex: 0x9F1239)),
        DotPalette(fill: Color(hex: 0x22C55E), dark: Color(hex: 0x166534)),
        DotPalette(fill: Color(hex: 0x2563EB), dark: Color(hex: 0x1E3A8A)),
        DotPalette(fill: Color(hex: 0xFACC15), dark: Color(hex: 0xA16207)),
        DotPalette(fill: Color(hex: 0xF97316), dark: Color(hex: 0x9A3412)),
        DotPalette(fill: Color(hex: 0xA855F7), dark: Color(hex: 0x6B21A8)),
        DotPalette(fill: Color(hex: 0xEC4899), dark: Color(hex: 0x9D174D)),
        DotPalette(fill: Color(hex: 0x92400E), dark: Color(hex: 0x451A03)),
        DotPalette(fill: Color(hex: 0x334155), dark: Color(hex: 0x020617)),
        DotPalette(fill: Color(hex: 0xFFFFFF), dark: Color(hex: 0x64748B)),
    ]

    static let accent = Color(hex: 0xFACC15)
    static let muted = Color.white.opacity(0.72)
    static let card = Color.white.opacity(0.1)
    static let cardBorder = Color.white.opacity(0.18)
    static let boardRim = Color(hex: 0x111827)
    static let danger = Color(hex: 0xE11D48)

    static let titleGradient = LinearGradient(
        colors: [Color(hex: 0x4ADE80), Color(hex: 0xFACC15), Color(hex: 0xFB7185)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let primaryGradient = LinearGradient(
        colors: [Color(hex: 0xF59E0B), Color(hex: 0xF43F5E)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let doneGradient = LinearGradient(
        colors: [Color(hex: 0x22C55E, opacity: 0.55), Color(hex: 0x14B8A6, opacity: 0.35)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x1E1B4B), Color(hex: 0x4C1D95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color(hex: 0xBE185D), .clear],
                center: UnitPoint(x: 0.1, y: 0),
                startRadius: 0,
                endRadius: 520
            )
            RadialGradient(
                colors: [Color(hex: 0x0E7490), .clear],
                center: UnitPoint(x: 1, y: 1),
                startRadius: 0,
                endRadius: 480
            )
        }
        .ignoresSafeArea()
    }
}

/// One giant stop on the adventure map. Each location nests 10 sub-levels and has its own background.
struct MapLocation {
    let name: String
    /// Center of the location's pad on the map image, as fractions of its width and height.
    let x: Double
    let y: Double
}

/// Names of the scene images in Assets.xcassets. Missing images fall back to a gradient.
enum SceneArt {
    static let mapName = "Map"
    /// The map image is 1024 × 3072.
    static let mapAspect = 3.0
    static let levelsPerLocation = 10

    /// From the bottom of the map (start) to the top.
    static let locations: [MapLocation] = [
        MapLocation(name: "Sunny Beach", x: 0.497, y: 0.944),
        MapLocation(name: "Coral Reef", x: 0.462, y: 0.863),
        MapLocation(name: "Pirate Wreck", x: 0.502, y: 0.794),
        MapLocation(name: "Palm Oasis", x: 0.488, y: 0.709),
        MapLocation(name: "Golden Dunes", x: 0.523, y: 0.612),
        MapLocation(name: "Lost Ruins", x: 0.506, y: 0.519),
        MapLocation(name: "Jungle River", x: 0.521, y: 0.423),
        MapLocation(name: "Thunder Falls", x: 0.487, y: 0.339),
        MapLocation(name: "Mushroom Grove", x: 0.571, y: 0.256),
        MapLocation(name: "Crystal Cave", x: 0.451, y: 0.184),
        MapLocation(name: "Aurora Peak", x: 0.559, y: 0.132),
        MapLocation(name: "Sky Summit", x: 0.448, y: 0.087),
    ]

    static func location(ofLevel index: Int) -> Int { index / levelsPerLocation }

    static func levels(in location: Int) -> Range<Int> {
        let start = location * levelsPerLocation
        return start..<min(start + levelsPerLocation, LEVELS.count)
    }

    static func backgroundName(chapter: Int) -> String {
        String(format: "Background%02d", chapter + 1)
    }

    fileprivate static let fallbacks: [(UInt32, UInt32)] = [
        (0x0EA5E9, 0x1E3A8A), (0x22C55E, 0x14532D), (0xF59E0B, 0x9A3412), (0x06B6D4, 0x164E63),
        (0xA855F7, 0x4C1D95), (0xEC4899, 0x831843), (0x84CC16, 0x365314), (0xF97316, 0x7C2D12),
        (0x6366F1, 0x1E1B4B), (0x14B8A6, 0x134E4A), (0xEF4444, 0x450A0A), (0x64748B, 0x0F172A),
    ]
}

/// Full-screen scene picture behind the map or a level.
struct SceneBackground: View {
    let name: String
    let fallback: Int

    var body: some View {
        Color.clear
            .overlay {
                if let image = UIImage(named: name) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    let colors = SceneArt.fallbacks[fallback % SceneArt.fallbacks.count]
                    LinearGradient(colors: [Color(hex: colors.0), Color(hex: colors.1)], startPoint: .top, endPoint: .bottom)
                }
            }
            .clipped()
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

struct CardButtonStyle: ButtonStyle {
    var background: AnyShapeStyle = AnyShapeStyle(Theme.card)
    var bordered = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                if bordered {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.cardBorder)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct IconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.cardBorder))
            .opacity(isEnabled ? 1 : 0.3)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}
