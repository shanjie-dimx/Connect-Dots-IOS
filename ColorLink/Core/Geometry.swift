import Foundation

// All coordinates are normalized: the board is the unit disk centered at (0, 0).
// Mirrors src/geometry.js so both versions accept exactly the same moves.
public enum Geometry {
    public static let dotRadius = 0.085
    public static let lineWidth = 0.06
    public static let halfWidth = lineWidth / 2
    public static let lineSeparation = lineWidth * 0.95
    public static let dotClearance = dotRadius + halfWidth
    public static let boardLimit = 1 - halfWidth
}

public struct Point: Hashable, Codable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct Dot: Hashable, Sendable {
    public let x: Double
    public let y: Double
    public let color: Int

    public init(x: Double, y: Double, color: Int) {
        self.x = x
        self.y = y
        self.color = color
    }

    public var point: Point { Point(x: x, y: y) }
}

public struct Level: Sendable {
    public let id: Int
    public let dots: [Dot]

    public init(id: Int, dots: [Dot]) {
        self.id = id
        self.dots = dots
    }
}

public enum BlockReason: String, Sendable {
    case line, dot, edge
}

public typealias Paths = [Int: [Point]]

@inline(__always)
public func dist(_ a: Point, _ b: Point) -> Double {
    hypot(a.x - b.x, a.y - b.y)
}

@inline(__always)
public func lerp(_ a: Point, _ b: Point, _ t: Double) -> Point {
    Point(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
}

public func pointSegDist(_ p: Point, _ a: Point, _ b: Point) -> Double {
    let dx = b.x - a.x
    let dy = b.y - a.y
    let len2 = dx * dx + dy * dy
    var t = len2 == 0 ? 0 : ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2
    t = max(0, min(1, t))
    return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
}

@inline(__always)
private func cross(_ o: Point, _ a: Point, _ b: Point) -> Double {
    (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
}

public func segmentsIntersect(_ a: Point, _ b: Point, _ c: Point, _ d: Point) -> Bool {
    let d1 = cross(c, d, a)
    let d2 = cross(c, d, b)
    let d3 = cross(a, b, c)
    let d4 = cross(a, b, d)
    return ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) && ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))
}

public func segSegDist(_ a: Point, _ b: Point, _ c: Point, _ d: Point) -> Double {
    if segmentsIntersect(a, b, c, d) { return 0 }
    return min(pointSegDist(a, c, d), pointSegDist(b, c, d), pointSegDist(c, a, b), pointSegDist(d, a, b))
}

public func insideBoard(_ p: Point) -> Bool {
    hypot(p.x, p.y) <= Geometry.boardLimit
}

/// Checks a single segment drawn in `color` against the board edge, foreign dots and
/// the committed paths of other colors. Returns nil when legal, otherwise a reason.
public func segmentConflict(_ a: Point, _ b: Point, color: Int, dots: [Dot], paths: Paths) -> BlockReason? {
    if !insideBoard(b) || !insideBoard(a) { return .edge }
    for dot in dots where dot.color != color {
        if pointSegDist(dot.point, a, b) < Geometry.dotClearance { return .dot }
    }
    for (otherColor, pts) in paths where otherColor != color {
        for i in 0..<max(0, pts.count - 1) {
            if segSegDist(a, b, pts[i], pts[i + 1]) < Geometry.lineSeparation { return .line }
        }
    }
    return nil
}

/// Full check of a finished set of paths, used by tests.
public func validateSolution(_ level: Level, _ paths: Paths) -> String? {
    let colors = Set(level.dots.map(\.color)).sorted()
    for color in colors {
        guard let pts = paths[color], pts.count >= 2 else { return "color \(color) not connected" }
        let ends = level.dots.filter { $0.color == color }.map(\.point)
        let first = pts[0]
        let last = pts[pts.count - 1]
        let okEnds = (dist(first, ends[0]) < 1e-9 && dist(last, ends[1]) < 1e-9)
            || (dist(first, ends[1]) < 1e-9 && dist(last, ends[0]) < 1e-9)
        if !okEnds { return "color \(color) has wrong endpoints" }
        for i in 0..<(pts.count - 1) {
            if let reason = segmentConflict(pts[i], pts[i + 1], color: color, dots: level.dots, paths: paths) {
                return "color \(color) segment \(i): \(reason.rawValue)"
            }
        }
    }
    return nil
}
