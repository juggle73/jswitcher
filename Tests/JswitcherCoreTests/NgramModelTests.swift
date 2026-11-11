import XCTest
@testable import JswitcherCore

final class NgramModelTests: XCTestCase {
    func testScoresOwnLanguageHigher() {
        let en = NgramModel.train(words: ["hello", "world", "help", "word"], lang: .en)
        XCTAssertGreaterThan(en.score("hello"), en.score("ghbdtn"))
    }

    func testRoundTripsThroughEncoding() throws {
        let m = NgramModel.train(words: ["привет", "мир"], lang: .ru)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ngram-test.bin")
        try m.encode().write(to: url)
        let loaded = try NgramModel(contentsOf: url)
        XCTAssertEqual(loaded.lang, .ru)
        XCTAssertEqual(loaded.score("привет"), m.score("привет"), accuracy: 0.001)
        XCTAssertEqual(loaded.score("gthtcj,hfk"), m.score("gthtcj,hfk"), accuracy: 0.001)
    }
}
