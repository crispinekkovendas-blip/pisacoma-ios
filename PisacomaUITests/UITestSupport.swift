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

    @discardableResult
    static func waitFor(_ app: XCUIApplication, _ id: String, timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let e = element(app, id)
        XCTAssertTrue(e.waitForExistence(timeout: timeout), "\(id) did not appear", file: file, line: line)
        return e
    }

    static func tap(_ app: XCUIApplication, _ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let e = waitFor(app, id, file: file, line: line)
        if !e.isHittable { app.swipeUp() }
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
