import SwiftUI

/// The circular board: draws dots and lines and turns touches into strokes.
struct BoardView: View {
    @ObservedObject var model: GameModel

    var body: some View {
        GeometryReader { geo in
            let size = max(200, min(geo.size.width, geo.size.height))
            let layout = BoardLayout(size: size)
            TimelineView(.animation(paused: !model.isAnimating(at: Date()))) { timeline in
                Canvas { ctx, _ in
                    draw(in: &ctx, layout: layout, now: timeline.date)
                }
            }
            .frame(width: size, height: size)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        model.dragChanged(start: layout.toBoard(value.startLocation), location: layout.toBoard(value.location))
                    }
                    .onEnded { value in
                        model.dragChanged(start: layout.toBoard(value.startLocation), location: layout.toBoard(value.location))
                        model.dragEnded()
                    }
            )
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityElement()
        .accessibilityIdentifier("board")
        .accessibilityLabel("Game board")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        let status = "Connected \(model.connectedCount) / \(model.game.colors.count)"
        guard let message = model.lastBlockMessage else { return status }
        return "\(status), \(message)"
    }

    private func draw(in ctx: inout GraphicsContext, layout: BoardLayout, now: Date) {
        let game = model.game
        drawBoard(&ctx, layout)
        for color in game.paths.keys.sorted() {
            strokePath(&ctx, layout, game.paths[color]!, color: color)
        }
        if let active = game.active {
            strokePath(&ctx, layout, active.points, color: active.color, alpha: 0.85)
        }
        for dot in game.dots {
            drawDot(&ctx, layout, dot, now: now)
        }
        for burst in model.bursts where burst.isActive(at: now) {
            burst.draw(in: &ctx, layout: layout, now: now)
        }
        if let blocked = model.blockedAt, now < model.blockedUntil {
            drawCross(&ctx, layout, blocked, fade: min(1, model.blockedUntil.timeIntervalSince(now) / 0.25))
        }
    }

    private func drawBoard(_ ctx: inout GraphicsContext, _ l: BoardLayout) {
        let c = l.size / 2
        let r = l.radius
        let border = max(6, l.size * 0.022)
        let rim = Path(ellipseIn: CGRect(x: c - r - border / 2, y: c - r - border / 2, width: (r + border / 2) * 2, height: (r + border / 2) * 2))

        ctx.drawLayer { layer in
            layer.addFilter(.shadow(color: .black.opacity(0.4), radius: l.size * 0.02, x: 0, y: l.size * 0.012))
            layer.fill(rim, with: .color(Theme.boardRim))
        }

        let disk = Path(ellipseIn: CGRect(x: c - r, y: c - r, width: r * 2, height: r * 2))
        var water = ctx
        water.clip(to: disk)
        water.fill(disk, with: .radialGradient(
            Gradient(stops: [
                .init(color: Color(hex: 0xF0F9FF), location: 0),
                .init(color: Color(hex: 0xBAE6FD), location: 0.55),
                .init(color: Color(hex: 0x7DD3FC), location: 1),
            ]),
            center: CGPoint(x: c - r * 0.3, y: c - r * 0.4),
            startRadius: r * 0.1,
            endRadius: r * 1.45
        ))
        for k in 0..<9 {
            let y = c - r + (Double(k) + 0.5) * (r * 2) / 9
            var wave = Path()
            var x = c - r
            wave.move(to: CGPoint(x: x, y: y + sin((x / r) * 5 + Double(k) * 1.7) * r * 0.03))
            while x <= c + r {
                x += 6
                wave.addLine(to: CGPoint(x: x, y: y + sin((x / r) * 5 + Double(k) * 1.7) * r * 0.03))
            }
            water.stroke(wave, with: .color(.white.opacity(0.45)), lineWidth: max(1, l.size * 0.004))
        }

        ctx.stroke(rim, with: .color(Theme.boardRim), lineWidth: border)
        let inner = Path(ellipseIn: CGRect(x: c - r + 1, y: c - r + 1, width: (r - 1) * 2, height: (r - 1) * 2))
        ctx.stroke(inner, with: .color(.white.opacity(0.8)), lineWidth: 2)
    }

    private func strokePath(_ ctx: inout GraphicsContext, _ l: BoardLayout, _ points: [Point], color: Int, alpha: Double = 1) {
        guard points.count >= 2 else { return }
        var path = Path()
        path.addLines(points.map(l.toScreen))
        let w = Geometry.lineWidth * l.radius
        let palette = Theme.palette[color % Theme.palette.count]
        var layer = ctx
        layer.opacity = alpha
        func style(_ width: Double) -> StrokeStyle { StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round) }
        layer.stroke(path, with: .color(palette.dark), style: style(w + 3))
        layer.stroke(path, with: .color(palette.fill), style: style(w))
        layer.stroke(path, with: .color(.white.opacity(0.35)), style: style(w * 0.28))
    }

    private func drawDot(_ ctx: inout GraphicsContext, _ l: BoardLayout, _ dot: Dot, now: Date) {
        let center = l.toScreen(dot.point)
        let r = Geometry.dotRadius * l.radius
        let game = model.game
        let connected = game.paths[dot.color] != nil
        let active = game.active?.color == dot.color
        let palette = Theme.palette[dot.color % Theme.palette.count]
        func circle(_ radius: Double) -> Path {
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        }

        if active || connected {
            let pulse = active ? 1 + 0.12 * sin(now.timeIntervalSinceReferenceDate * 1000 / 120) : 1
            ctx.fill(circle(r * 1.45 * pulse), with: .color(palette.fill.opacity(active ? 0.33 : 0.2)))
        }
        ctx.drawLayer { layer in
            layer.addFilter(.shadow(color: .black.opacity(0.3), radius: r * 0.25, x: 0, y: r * 0.15))
            layer.fill(circle(r), with: .color(palette.dark))
        }
        ctx.fill(circle(r * 0.8), with: .radialGradient(
            Gradient(stops: [
                .init(color: .white, location: 0),
                .init(color: palette.fill, location: 0.25),
                .init(color: palette.fill, location: 1),
            ]),
            center: CGPoint(x: center.x - r * 0.35, y: center.y - r * 0.4),
            startRadius: r * 0.1,
            endRadius: r * 1.2
        ))
    }

    private func drawCross(_ ctx: inout GraphicsContext, _ l: BoardLayout, _ p: Point, fade: Double) {
        let c = l.toScreen(p)
        let s = Geometry.dotRadius * l.radius * 0.9
        var cross = Path()
        cross.move(to: CGPoint(x: c.x - s, y: c.y - s))
        cross.addLine(to: CGPoint(x: c.x + s, y: c.y + s))
        cross.move(to: CGPoint(x: c.x + s, y: c.y - s))
        cross.addLine(to: CGPoint(x: c.x - s, y: c.y + s))
        var layer = ctx
        layer.opacity = max(0, fade)
        layer.stroke(cross, with: .color(.white), style: StrokeStyle(lineWidth: s * 0.55, lineCap: .round))
        layer.stroke(cross, with: .color(Theme.danger), style: StrokeStyle(lineWidth: s * 0.32, lineCap: .round))
    }
}

/// Maps between normalized board coordinates (unit disk) and view points.
struct BoardLayout {
    let size: Double
    let radius: Double

    init(size: Double) {
        self.size = size
        radius = size / 2 - max(8, size * 0.03)
    }

    func toScreen(_ p: Point) -> CGPoint {
        CGPoint(x: size / 2 + p.x * radius, y: size / 2 + p.y * radius)
    }

    func toBoard(_ p: CGPoint) -> Point {
        Point(x: (p.x - size / 2) / radius, y: (p.y - size / 2) / radius)
    }
}
