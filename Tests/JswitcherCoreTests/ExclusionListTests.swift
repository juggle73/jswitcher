import XCTest
@testable import JswitcherCore

final class ExclusionListTests: XCTestCase {
    func testDefaultIsTerminalOnly() {
        let list = ExclusionList.default
        XCTAssertEqual(list.bundleIDs, ["com.apple.Terminal"])
        XCTAssertTrue(list.contains("com.apple.Terminal"))
        XCTAssertFalse(list.contains("com.jetbrains.goland"))
        XCTAssertFalse(list.contains("com.googlecode.iterm2"))
        XCTAssertFalse(list.contains(nil))
    }

    func testAddRemove() {
        var list = ExclusionList.default
        XCTAssertTrue(list.add("com.jetbrains.goland"))
        XCTAssertFalse(list.add("com.jetbrains.goland"), "no duplicates")
        XCTAssertTrue(list.contains("com.jetbrains.goland"))
        XCTAssertFalse(list.contains("com.jetbrains.pycharm"), "exact bundle IDs, no prefixes")
        list.remove("com.apple.Terminal")
        XCTAssertFalse(list.contains("com.apple.Terminal"))
        XCTAssertEqual(list.bundleIDs, ["com.jetbrains.goland"])
    }

    func testStoredFormRoundTripsAndIgnoresJunk() {
        var list = ExclusionList(stored: nil)
        XCTAssertEqual(list, .default, "nothing stored yet → default")
        list.add("com.tinyspeck.slackmacgap")
        let restored = ExclusionList(stored: list.stored)
        XCTAssertEqual(restored, list)
        XCTAssertEqual(ExclusionList(stored: []).bundleIDs, [], "user emptied the list — stays empty")
        XCTAssertEqual(ExclusionList(stored: ["", "  ", "com.apple.Terminal"]).bundleIDs, ["com.apple.Terminal"])
    }
}
