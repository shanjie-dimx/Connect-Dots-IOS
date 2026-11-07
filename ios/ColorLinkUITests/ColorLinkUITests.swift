import XCTest

/// Drives the real app with touch drags on level 1.
final class ColorLinkUITests: XCTestCase {
    // Level 1 dots (see src/levels.js), keyed by color.
    private let pairs: [Int: (CGPoint, CGPoint)] = [
        0: (CGPoint(x: 0.4396, y: 0.6061), CGPoint(x: -0.3125, y: -0.86)),
        1: (CGPoint(x: 0.8649, y: 0.2985), CGPoint(x: -0.782, y: -0.1194)),
        2: (CGPoint(x: 0.6716, y: -0.6214), CGPoint(x: 0.8598, y: -0.3129)),
    ]

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testDrawingLinesOnLevelOne() throws {
        let levelButton = app.buttons["level-1"]
        XCTAssertTrue(levelButton.waitForExistence(timeout: 10))
        saveScreenshot("01-home")
        levelButton.tap()

        let board = app.descendants(matching: .any)["board"]
        XCTAssertTrue(board.waitForExistence(timeout: 5))
        let sub = app.staticTexts["level-sub"]
        XCTAssertEqual(sub.label, "6 个点 · 已连接 0/3")
        saveScreenshot("02-level-1")

        drag(color: 2, on: board)
        XCTAssertTrue(waitForLabel(sub, "6 个点 · 已连接 1/3"))
        drag(color: 1, on: board)
        XCTAssertTrue(waitForLabel(sub, "6 个点 · 已连接 2/3"))

        // A straight line for the last pair would cross the line just drawn.
        // The toast is gone ~1 s after release, which a slow simulator can miss; the board's
        // accessibility value keeps the reason until the next touch.
        drag(color: 0, on: board)
        saveScreenshot("03-blocked")
        XCTAssertEqual(board.value as? String, "已连接 2 / 3，线路不能交叉")
        XCTAssertEqual(sub.label, "6 个点 · 已连接 2/3")

        app.buttons["undo"].tap()
        XCTAssertTrue(waitForLabel(sub, "6 个点 · 已连接 1/3"))
        app.buttons["reset"].tap()
        XCTAssertTrue(waitForLabel(sub, "6 个点 · 已连接 0/3"))
    }

    func testSolvingALevelShowsTheWinCardAndSavesProgress() throws {
        app.terminate()
        app.launchArguments = ["-uiTestStraightLevel"]
        app.launch()
        app.buttons["level-1"].tap()
        let board = app.descendants(matching: .any)["board"]
        XCTAssertTrue(board.waitForExistence(timeout: 5))
        for y in [-0.4, 0, 0.4] {
            drag(from: CGPoint(x: -0.6, y: y), to: CGPoint(x: 0.6, y: y), on: board)
        }
        XCTAssertTrue(app.staticTexts["过关！"].waitForExistence(timeout: 3))
        saveScreenshot("04-win")
        app.buttons["再玩一次"].tap()
        XCTAssertTrue(waitForLabel(app.staticTexts["level-sub"], "6 个点 · 已连接 0/3"))
        app.buttons["返回关卡列表"].tap()
        XCTAssertTrue(app.buttons["level-1"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["level-1"].label, "第 1 关（已通过）")
        XCTAssertTrue(app.staticTexts["已通过 1 / 20 关"].exists)
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
