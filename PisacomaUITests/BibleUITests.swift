import XCTest

/// Biblia: Juan 3 by default, next chapter, the picker, bookmarks.
final class BibleUITests: XCTestCase {
    func testJuan3NextAndPicker() {
        let app = UI.launch()
        UI.waitFor(app, "home", timeout: 20)
        UI.menu(app, "Biblia")
        UI.waitFor(app, "bible-list")
        UI.waitFor(app, "verse-1", timeout: 20)
        UI.shot(app, "biblia-juan-3", self)
        UI.tap(app, "bible-next")
        UI.waitFor(app, "verse-1", timeout: 20)
        UI.shot(app, "biblia-juan-4", self)
        UI.tap(app, "bible-title")
        UI.waitFor(app, "bible-picker")
        UI.shot(app, "biblia-picker", self)
        // The picker opens on the current book's chapters; «Cambiar libro» shows the book list.
        UI.tap(app, "picker-books")
        UI.tap(app, "picker-book-43")
        UI.tap(app, "picker-chapter-1")
        UI.waitFor(app, "verse-1", timeout: 20)
    }

    func testBookmarkAndDrawer() {
        let app = UI.launch()
        UI.waitFor(app, "home", timeout: 20)
        UI.menu(app, "Biblia")
        UI.waitFor(app, "verse-1", timeout: 20)
        UI.tap(app, "bible-bookmark")
        UI.tap(app, "bible-panel")
        UI.waitFor(app, "bible-drawer")
        UI.tap(app, "panel-tab-bookmarks")
        UI.shot(app, "biblia-panel-bookmarks", self)
    }
}
