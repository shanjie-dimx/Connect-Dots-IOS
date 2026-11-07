import Foundation
import XCTest
@testable import ConnectDots

private func pt(_ x: Double, _ y: Double) -> Point { Point(x: x, y: y) }

@discardableResult
private func drag(_ game: Game, _ points: [Point], file: StaticString = #filePath, line: UInt = #line) -> Game.MoveResult? {
    XCTAssertTrue(game.pointerDown(points[0]), "stroke should start on a dot", file: file, line: line)
    var result: Game.MoveResult?
    for p in points.dropFirst() {
        result = game.pointerMove(p)
        if result != .moved { break }
    }
    game.pointerUp()
    return result
}

/// Reference solutions shared with the web version, when that file is present.
private func loadSolutions() throws -> [[String: [[Double]]]] {
    let besideTest = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("solutions.json")
    let legacy = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("../../../tests/solutions.json")
        .standardized
    guard let url = [besideTest, legacy].first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
        throw XCTSkip("solutions.json is not in this app repository")
    }
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode([[String: [[Double]]]].self, from: data)
}

private let simple = Level(id: 0, dots: [
    Dot(x: -0.6, y: 0, color: 0),
    Dot(x: 0.6, y: 0, color: 0),
    Dot(x: 0, y: -0.6, color: 1),
    Dot(x: 0, y: 0.6, color: 1),
])

final class GameTests: XCTestCase {
    func testThereAre120LevelsGoingFromThreeToTenPairs() {
        XCTAssertEqual(LEVELS.count, 120)
        var previous = 3
        for (i, level) in LEVELS.enumerated() where !level.dots.isEmpty {
            let pairs = level.dots.count / 2
            XCTAssertEqual(level.dots.count, pairs * 2, "level \(i + 1)")
            XCTAssertEqual(Set(level.dots.map(\.color)).count, pairs, "level \(i + 1)")
            XCTAssertGreaterThanOrEqual(pairs, previous, "level \(i + 1)")
            previous = pairs
        }
        XCTAssertTrue(LEVELS[0..<10].allSatisfy { $0.dots.count == 6 })
        XCTAssertEqual(LEVELS.last(where: { !$0.dots.isEmpty })?.dots.count, 20)
    }

    func testEveryLevelCanBeSolvedByDrawingItsReferenceSolution() throws {
        let solutions = try loadSolutions()
        XCTAssertEqual(solutions.count, LEVELS.count)
        for (i, level) in LEVELS.enumerated() where !level.dots.isEmpty {
            let game = Game(level: level)
            for key in solutions[i].keys.sorted() {
                let pts = solutions[i][key]!.map { pt($0[0], $0[1]) }
                XCTAssertFalse(game.isSolved, "level \(i + 1)")
                XCTAssertEqual(drag(game, pts), .connected, "level \(i + 1) color \(key)")
            }
            XCTAssertTrue(game.isSolved, "level \(i + 1)")
            XCTAssertNil(validateSolution(level, game.paths), "level \(i + 1)")
        }
    }

    func testLinesOfDifferentColorsCannotCross() {
        let game = Game(level: simple)
        XCTAssertEqual(drag(game, [pt(-0.6, 0), pt(0.6, 0)]), .connected)
        XCTAssertEqual(drag(game, [pt(0, -0.6), pt(0, 0.6)]), .blocked)
        XCTAssertEqual(game.blockReason, .line)
        XCTAssertEqual(game.paths.count, 1)
    }

    func testLinesCannotPassThroughADotOfAnotherColor() {
        let game = Game(level: Level(id: 0, dots: [
            Dot(x: -0.6, y: 0, color: 0),
            Dot(x: 0.6, y: 0, color: 0),
            Dot(x: 0, y: 0, color: 1),
            Dot(x: 0, y: 0.6, color: 1),
        ]))
        XCTAssertEqual(drag(game, [pt(-0.6, 0), pt(0.6, 0)]), .blocked)
        XCTAssertEqual(game.blockReason, .dot)
        XCTAssertEqual(game.paths.count, 0)
    }

    func testLinesCannotLeaveTheCircle() {
        let game = Game(level: simple)
        XCTAssertEqual(drag(game, [pt(-0.6, 0), pt(-0.99, 0)]), .blocked)
        XCTAssertEqual(game.blockReason, .edge)
    }

    func testSecondColorCanGoAroundTheFirstLine() {
        let game = Game(level: Level(id: 0, dots: [
            Dot(x: -0.6, y: 0.2, color: 0),
            Dot(x: 0.6, y: 0.2, color: 0),
            Dot(x: 0, y: -0.3, color: 1),
            Dot(x: 0, y: 0.6, color: 1),
        ]))
        XCTAssertEqual(drag(game, [pt(-0.6, 0.2), pt(0.6, 0.2)]), .connected)
        let around = [pt(0, -0.3), pt(0.5, -0.3), pt(0.85, 0), pt(0.8, 0.4), pt(0.4, 0.6), pt(0, 0.6)]
        XCTAssertEqual(drag(game, around), .connected)
        XCTAssertTrue(game.isSolved)
    }

    func testUnfinishedStrokeIsDiscardedOnRelease() {
        let game = Game(level: simple)
        XCTAssertEqual(drag(game, [pt(-0.6, 0), pt(-0.2, 0)]), .moved)
        XCTAssertEqual(game.paths.count, 0)
        XCTAssertFalse(game.canUndo)
    }

    func testUndoAndReset() {
        let game = Game(level: simple)
        drag(game, [pt(-0.6, 0), pt(-0.3, 0.3), pt(0.6, 0)])
        drag(game, [pt(-0.6, 0), pt(0.6, 0)])
        XCTAssertFalse(game.paths[0]!.isEmpty)
        XCTAssertTrue(game.undo())
        XCTAssertTrue(game.paths[0]!.contains { $0.y > 0.2 }, "undo restores the previous route")
        XCTAssertTrue(game.reset())
        XCTAssertEqual(game.paths.count, 0)
        XCTAssertTrue(game.undo(), "reset can be undone")
        XCTAssertEqual(game.paths.count, 1)
        XCTAssertTrue(game.undo())
        XCTAssertEqual(game.paths.count, 0)
        XCTAssertFalse(game.undo())
    }

    func testRedrawingFromAConnectedDotButGivingUpKeepsTheOldLine() {
        let game = Game(level: simple)
        drag(game, [pt(-0.6, 0), pt(0.6, 0)])
        drag(game, [pt(0.6, 0), pt(0.3, 0.3)])
        XCTAssertEqual(game.paths.count, 1)
    }

    func testMovingBackOverTheStrokeErasesIt() {
        let game = Game(level: simple)
        game.pointerDown(pt(-0.6, 0))
        game.pointerMove(pt(-0.6, 0.5))
        game.pointerMove(pt(-0.6, 0.1))
        XCTAssertTrue(game.active!.points.allSatisfy { $0.y < 0.2 })
        game.pointerUp()
    }
}
