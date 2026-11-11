import XCTest
@testable import JswitcherCore

final class WordListTests: XCTestCase {
    func testRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("jswitcher-test-\(UUID()).bin")
        defer { try? FileManager.default.removeItem(at: url) }
        try WordList.encode(["привет", "hello", "ёлка"]).write(to: url)
        let list = try WordList(contentsOf: url)
        XCTAssertTrue(list.contains("привет"))
        XCTAssertTrue(list.contains("hello"))
        XCTAssertTrue(list.contains("елка"))
        XCTAssertFalse(list.contains("прив"))
        XCTAssertEqual(list.count, 3)
    }

    func testNormalize() {
        XCTAssertEqual(WordList.normalize("ЁЛКА"), "елка")
        XCTAssertEqual(WordList.normalize("Hello"), "hello")
    }

    func testRealDictionaries() {
        let en = loadDict(.en), ru = loadDict(.ru)
        XCTAssertTrue(en.contains("hello"))
        XCTAssertTrue(ru.contains("привет"))
        XCTAssertTrue(ru.contains("добрый"))
        XCTAssertTrue(ru.contains("тест"))
        XCTAssertFalse(en.contains("ghbdtn"))
        XCTAssertFalse(ru.contains("руддщ"))
        XCTAssertTrue((150_000...200_000).contains(en.count), "en \(en.count)")
        XCTAssertTrue((150_000...200_000).contains(ru.count), "ru \(ru.count)")
    }
}
