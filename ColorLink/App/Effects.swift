import SwiftUI

/// Sparks that fly out of a dot when its pair connects.
struct Burst {
    let center: Point
    let color: Int
    let start: Date

    static let duration: TimeInterval = 0.7

    func isActive(at now: Date) -> Bool { now.timeIntervalSince(start) < Self.duration }

    func draw(in ctx: inout GraphicsContext, layout: BoardLayout, now: Date) {
        let t = now.timeIntervalSince(start) / Self.duration
        guard t >= 0, t < 1 else { return }
        let c = layout.toScreen(center)
        let palette = Theme.palette[color % Theme.palette.count]
        let ease = 1 - pow(1 - t, 3)
        let unit = layout.radius

        let ringRadius = unit * (Geometry.dotRadius + 0.22 * ease)
        let ring = Path(ellipseIn: CGRect(x: c.x - ringRadius, y: c.y - ringRadius, width: ringRadius * 2, height: ringRadius * 2))
        var ringLayer = ctx
        ringLayer.opacity = 1 - t
        ringLayer.stroke(ring, with: .color(.white), lineWidth: max(1, unit * 0.02 * (1 - t)))

        for k in 0..<14 {
            let angle = Double(k) / 14 * 2 * .pi + Double(color) * 0.4
            let reach = unit * (0.08 + (k.isMultiple(of: 2) ? 0.26 : 0.18) * ease)
            let p = CGPoint(x: c.x + cos(angle) * reach, y: c.y + sin(angle) * reach + unit * 0.05 * t * t)
            let r = unit * 0.022 * (1 - t * 0.7)
            var spark = ctx
            spark.opacity = 1 - t
            let fill = k.isMultiple(of: 3) ? Color.white : palette.fill
            spark.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(fill))
        }
    }
}

/// Side-to-side wobble used when a line is blocked.
struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 7 * sin(animatableData * .pi * 4), y: 0))
    }
}

/// Confetti that rains over the win card.
struct ConfettiView: View {
    private struct Piece {
        let x: Double
        let delay: Double
        let speed: Double
        let sway: Double
        let spin: Double
        let size: Double
        let color: Color
    }

    private let pieces: [Piece]
    @State private var start = Date()

    init(count: Int = 90) {
        var rng = SeededRandom(seed: 42)
        pieces = (0..<count).map { _ in
            Piece(
                x: rng.next(),
                delay: rng.next() * 0.8,
                speed: 0.35 + rng.next() * 0.35,
                sway: 0.02 + rng.next() * 0.05,
                spin: 2 + rng.next() * 6,
                size: 6 + rng.next() * 7,
                color: Theme.palette[Int(rng.next() * Double(Theme.palette.count)) % Theme.palette.count].fill
            )
        }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let elapsed = timeline.date.timeIntervalSince(start)
                for piece in pieces {
                    let t = elapsed - piece.delay
                    guard t > 0 else { continue }
                    let y = -20 + t * piece.speed * size.height
                    guard y < size.height + 20 else { continue }
                    let x = piece.x * size.width + sin(t * 3 + piece.x * 10) * piece.sway * size.width
                    var layer = ctx
                    layer.translateBy(x: x, y: y)
                    layer.rotate(by: .radians(t * piece.spin))
                    let w = piece.size
                    let h = piece.size * 0.45 * (0.4 + 0.6 * abs(cos(t * piece.spin)))
                    layer.fill(Path(roundedRect: CGRect(x: -w / 2, y: -h / 2, width: w, height: h), cornerRadius: 1.5), with: .color(piece.color))
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Small deterministic generator so effects look the same every run.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 | 1 }

    /// Uniform value in 0..<1.
    mutating func next() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Double(state >> 11) / Double(1 << 53)
    }
}
