import XCTest

/// Drives the real app with touch drags on fixed test levels.
final class ColorLinkUITests: XCTestCase {
    // Dots of the -uiTestCrossLevel level (see GameModel), keyed by color.
    private let pairs: [Int: (CGPoint, CGPoint)] = [
        0: (CGPoint(x: 0, y: -0.8), CGPoint(x: 0, y: 0.8)),
        1: (CGPoint(x: -0.6, y: 0.4), CGPoint(x: 0.6, y: 0.4)),
        2: (CGPoint(x: -0.6, y: -0.4), CGPoint(x: 0.6, y: -0.4)),
    ]

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testDrawingLinesOnLevelOne() throws {
        app.launchArguments = ["-uiTestCrossLevel"]
        app.launch()
        let levelButton = app.buttons["level-1"]
        XCTAssertTrue(levelButton.waitForExistence(timeout: 10))
        saveScreenshot("01-home")
        levelButton.tap()

        let board = app.descendants(matching: .any)["board"]
        XCTAssertTrue(board.waitForExistence(timeout: 5))
        let sub = app.staticTexts["level-sub"]
        XCTAssertEqual(sub.label, "3 pairs · 0/3 connected")
        saveScreenshot("02-level-1")

        drag(color: 2, on: board)
        XCTAssertTrue(waitForLabel(sub, "3 pairs · 1/3 connected"))
        drag(color: 1, on: board)
        XCTAssertTrue(waitForLabel(sub, "3 pairs · 2/3 connected"))

        // A straight line for the last pair would cross the lines just drawn.
        // The toast is gone ~1 s after release, which a slow simulator can miss; the board's
        // accessibility value keeps the reason until the next touch.
        drag(color: 0, on: board)
        saveScreenshot("03-blocked")
        XCTAssertEqual(board.value as? String, "Connected 2 / 3, Lines can't cross")
        XCTAssertEqual(sub.label, "3 pairs · 2/3 connected")

        app.buttons["undo"].tap()
        XCTAssertTrue(waitForLabel(sub, "3 pairs · 1/3 connected"))
        app.buttons["reset"].tap()
        XCTAssertTrue(waitForLabel(sub, "3 pairs · 0/3 connected"))
    }

    func testSolvingALevelShowsTheWinCardAndSavesProgress() throws {
        app.launchArguments = ["-uiTestStraightLevel"]
        app.launch()
        app.buttons["level-1"].tap()
        let board = app.descendants(matching: .any)["board"]
        XCTAssertTrue(board.waitForExistence(timeout: 5))
        for y in [-0.4, 0, 0.4] {
            drag(from: CGPoint(x: -0.6, y: y), to: CGPoint(x: 0.6, y: y), on: board)
        }
        XCTAssertTrue(app.staticTexts["Solved!"].waitForExistence(timeout: 3))
        saveScreenshot("04-win")
        app.buttons["Play again"].tap()
        XCTAssertTrue(waitForLabel(app.staticTexts["level-sub"], "3 pairs · 0/3 connected"))
        app.buttons["Back to levels"].tap()
        XCTAssertTrue(app.buttons["level-1"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["level-1"].label, "Level 1 (solved)")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Solved 1 / ")).firstMatch.exists)
        saveScreenshot("05-home-progress")
    }

    private func drag(color: Int, on board: XCUIElement) {
        let (a, b) = pairs[color]!
        drag(from: a, to: b, on: board)
    }

    private func drag(from a: CGPoint, to b: CGPoint, on board: XCUIElement) {
        let start = point(a, on: board)
        let end = point(b, on: board)
        start.press(forDuration: 0.2, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
    }

    /// Mirrors BoardLayout: the board is a centered square inside the element's frame.
    private func point(_ p: CGPoint, on board: XCUIElement) -> XCUICoordinate {
        let frame = board.frame
        let size = min(frame.width, frame.height)
        let radius = size / 2 - max(8, size * 0.03)
        let origin = app.coordinate(withNormalizedOffset: .zero)
        return origin.withOffset(CGVector(dx: frame.midX + p.x * radius, dy: frame.midY + p.y * radius))
    }

    private func waitForLabel(_ element: XCUIElement, _ label: String) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)], timeout: 3) == .completed
    }

    private func saveScreenshot(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !dir.isEmpty {
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }
}
