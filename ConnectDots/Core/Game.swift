import Foundation

/// Rules engine for one level. Mirrors src/game.js.
public final class Game {
    public enum MoveResult: Equatable, Sendable {
        case moved, blocked, connected
    }

    public struct Stroke {
        public let color: Int
        public let start: Dot
        public let target: Dot
        public internal(set) var points: [Point]
        let replaced: [Point]?
    }

    private static let step = 0.02
    private static let minStep = 0.012
    private static let backtrackRadius = 0.045
    private static let backtrackMinArc = 0.12
    private static let pickRadius = Geometry.dotRadius * 1.8

    public let level: Level
    public let dots: [Dot]
    public let colors: [Int]
    public private(set) var paths: Paths = [:]
    public private(set) var active: Stroke?
    public private(set) var blocked: Point?
    public private(set) var blockReason: BlockReason?
    private var history: [Paths] = []

    public init(level: Level) {
        self.level = level
        self.dots = level.dots
        var seen = Set<Int>()
        self.colors = level.dots.map(\.color).filter { seen.insert($0).inserted }
    }

    public var canUndo: Bool { !history.isEmpty }

    public var isSolved: Bool { colors.allSatisfy { paths[$0] != nil } }

    public func dotAt(_ p: Point) -> Dot? {
        var best: Dot?
        var bestD = Self.pickRadius
        for dot in dots {
            let d = dist(dot.point, p)
            if d < bestD {
                best = dot
                bestD = d
            }
        }
        return best
    }

    /// Starts drawing from the dot under `p`. Returns true if a stroke began.
    @discardableResult
    public func pointerDown(_ p: Point) -> Bool {
        blocked = nil
        guard let dot = dotAt(p),
              let target = dots.first(where: { $0.color == dot.color && $0 != dot }) else { return false }
        let replaced = paths.removeValue(forKey: dot.color)
        active = Stroke(color: dot.color, start: dot, target: target, points: [dot.point], replaced: replaced)
        return true
    }

    /// Extends the active stroke towards `p`.
    @discardableResult
    public func pointerMove(_ p: Point) -> MoveResult? {
        guard var a = active else { return nil }
        defer { if active != nil { active = a } }
        let origin = a.points[a.points.count - 1]
        let steps = max(1, Int((dist(origin, p) / Self.step).rounded(.up)))
        blocked = nil
        for i in 1...steps {
            let q = lerp(origin, p, Double(i) / Double(steps))
            if backtrack(&a.points, q) { continue }
            let prev = a.points[a.points.count - 1]
            let reachesTarget = dist(q, a.target.point) <= Geometry.dotRadius
            if dist(prev, q) < Self.minStep && !reachesTarget { continue }
            if let reason = conflict(prev, q, stroke: a) {
                blocked = q
                blockReason = reason
                return .blocked
            }
            a.points.append(q)
            if reachesTarget {
                a.points.append(a.target.point)
                active = a
                commit()
                return .connected
            }
        }
        return .moved
    }

    /// Ends the stroke; an unfinished stroke is discarded and any path it replaced comes back.
    public func pointerUp() {
        guard let a = active else { return }
        if let replaced = a.replaced { paths[a.color] = replaced }
        active = nil
        blocked = nil
    }

    @discardableResult
    public func undo() -> Bool {
        if active != nil { pointerUp() }
        guard let previous = history.popLast() else { return false }
        paths = previous
        return true
    }

    @discardableResult
    public func reset() -> Bool {
        if active != nil { pointerUp() }
        if paths.isEmpty { return false }
        history.append(paths)
        paths = [:]
        return true
    }

    private func commit() {
        guard let a = active else { return }
        var before = paths
        if let replaced = a.replaced { before[a.color] = replaced }
        history.append(before)
        paths[a.color] = a.points
        active = nil
    }

    /// Moving back over the stroke erases it up to that point.
    private func backtrack(_ pts: inout [Point], _ q: Point) -> Bool {
        guard pts.count >= 2 else { return false }
        var arc = 0.0
        var arcFromEnd = [Double](repeating: 0, count: pts.count)
        for i in stride(from: pts.count - 2, through: 0, by: -1) {
            arc += dist(pts[i], pts[i + 1])
            arcFromEnd[i] = arc
        }
        for i in 0..<(pts.count - 1) {
            if arcFromEnd[i] < Self.backtrackMinArc { break }
            let radius = i == 0 ? Geometry.dotRadius : Self.backtrackRadius
            if dist(pts[i], q) < radius {
                pts.removeSubrange((i + 1)...)
                return true
            }
        }
        return false
    }

    private func conflict(_ prev: Point, _ q: Point, stroke: Stroke) -> BlockReason? {
        if let reason = segmentConflict(prev, q, color: stroke.color, dots: dots, paths: paths) { return reason }
        let pts = stroke.points
        var i = 0
        while i + 2 < pts.count {
            if segmentsIntersect(prev, q, pts[i], pts[i + 1]) { return .line }
            i += 1
        }
        return nil
    }
}
