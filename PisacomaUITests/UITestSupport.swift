import XCTest

/// Launch helpers and screenshots for the XCUITests. Screenshots are attached to the result bundle
/// (kept always) and exported by tools/export-shots.py as the `ui-<run>` artifact.
enum UI {
    /// Launches the app with the content seeded and the mode «todo» (the default test state).
    static func launch(_ extra: [String] = [], seeded: Bool = true, mode: String? = "todo", clearUserState: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        var args: [String] = []
        if seeded { args.append("-seedContent") }
        if let mode { args += ["-mode", mode] }
        if clearUserState { args.append("-clearUserState") }
        args += extra
        app.launchArguments = args
        app.launch()
        return app
    }

    static func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// Waits for the element; lazy lists only materialise what is on screen, so it also scrolls down a few times.
    @discardableResult
    static func waitFor(_ app: XCUIApplication, _ id: String, timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let e = element(app, id)
        if e.waitForExistence(timeout: timeout) { return e }
        for _ in 0..<8 {
            app.swipeUp()
            if e.waitForExistence(timeout: 1) { return e }
        }
        XCTAssertTrue(e.exists, "\(id) did not appear", file: file, line: line)
        return e
    }

    static func tap(_ app: XCUIApplication, _ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let e = waitFor(app, id, file: file, line: line)
        guard e.exists else { return }
        var tries = 0
        while !e.isHittable && tries < 6 { app.swipeUp(); tries += 1 }
        e.tap()
    }

    /// Opens the full menu and taps one of the eleven destinations by its label.
    static func menu(_ app: XCUIApplication, _ label: String) {
        tap(app, "nav-menu")
        waitFor(app, "menu-panel")
        tap(app, "menu-\(label)")
    }

    static func shot(_ app: XCUIApplication, _ name: String, _ test: XCTestCase) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name + ".png"
        a.lifetime = .keepAlways
        test.add(a)
    }
}
