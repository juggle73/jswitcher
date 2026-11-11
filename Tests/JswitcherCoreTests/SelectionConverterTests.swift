import XCTest
@testable import JswitcherCore

final class SelectionConverterTests: XCTestCase {
    let converter = SelectionConverter(layouts: Fixtures.layouts)

    func testPhraseTypedInEnglish() {
        let r = converter.convert("ghbdtn vbh", current: .en)
        XCTAssertEqual(r?.text, "привет мир")
        XCTAssertEqual(r?.switchTo, .ru)
    }

    func testPhraseTypedInRussian() {
        let r = converter.convert("руддщ цщкдв", current: .ru)
        XCTAssertEqual(r?.text, "hello world")
        XCTAssertEqual(r?.switchTo, .en)
    }

    func testEveryLetterSwapsIncludingMixed() {
        XCTAssertEqual(converter.convert("Привет rfr", current: .en)?.text, "Ghbdtn как")
    }

    func testCommaAlwaysBecomesBe() {
        XCTAssertEqual(converter.convert("lj,hsq", current: .en)?.text, "добрый")
        XCTAssertEqual(converter.convert("привет,", current: .ru)?.text, "ghbdtnб")
        XCTAssertEqual(converter.convert("ghbdtnб", current: .en)?.text, "привет,")
    }

    func testRussianOnlySymbolGoesThroughRussianKey() {
        let no = Fixtures.russian.table.first { $0.value == "№" }!.key
        let expected = Fixtures.abc.character(for: no)!
        XCTAssertEqual(converter.convert("№", current: .ru)?.text, String(expected))
    }

    func testWhitespaceAndNewlinesKept() {
        XCTAssertEqual(converter.convert("ghbdtn\tvbh\nntcn  b", current: .en)?.text, "привет\tмир\nтест  и")
    }

    func testCharactersOutsideTableKept() {
        XCTAssertEqual(converter.convert("ghbdtn 😀 é", current: .en)?.text, "привет 😀 é")
    }

    func testRoundTrip() {
        for s in ["ghbdtn, vbh!", "Привет, как дела?", "lj,hsq dtxth"] {
            let once = converter.convert(s, current: .en)!.text
            XCTAssertEqual(converter.convert(once, current: .en)?.text, s, s)
        }
    }

    func testTieSwitchesToOtherOfCurrent() {
        XCTAssertEqual(converter.convert("123", current: .en)?.switchTo, .ru)
        XCTAssertEqual(converter.convert("123", current: .ru)?.switchTo, .en)
    }

    func testEmptyAndTooLongRejected() {
        XCTAssertNil(converter.convert("", current: .en))
        XCTAssertNil(converter.convert(String(repeating: "a", count: 2001), current: .en))
        XCTAssertNotNil(converter.convert(String(repeating: "a", count: 2000), current: .en))
    }
}
