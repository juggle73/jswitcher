import XCTest
@testable import JswitcherCore

final class KeyMapTests: XCTestCase {
    let abc = Fixtures.abc
    let ru = Fixtures.russian

    func testAbcBasic() {
        XCTAssertEqual(abc.character(for: KeyStroke(keyCode: 0, shift: false)), "a")
        XCTAssertEqual(abc.character(for: KeyStroke(keyCode: 0, shift: true)), "A")
    }

    func testRussianMacLetters() {
        XCTAssertEqual(ru.render(abc.strokes(typing: "ghbdtn")), "привет")
        XCTAssertEqual(ru.render(abc.strokes(typing: "lj,hsq")), "добрый")
        XCTAssertEqual(ru.render(abc.strokes(typing: "k.lb")), "люди")
    }

    func testCapsLockUppercasesLettersOnly() {
        XCTAssertEqual(abc.character(for: KeyStroke(keyCode: 0, shift: false, capsLock: true)), "A")
        XCTAssertEqual(abc.character(for: KeyStroke(keyCode: 18, shift: false, capsLock: true)), "1")
    }

    func testControlCharsExcluded() {
        for code: UInt16 in [49, 36, 48, 51, 53, 117, 123, 124, 125, 126] {
            for shift in [false, true] {
                XCTAssertNil(abc.character(for: KeyStroke(keyCode: code, shift: shift)), "abc \(code)")
                XCTAssertNil(ru.character(for: KeyStroke(keyCode: code, shift: shift)), "ru \(code)")
            }
        }
    }

    func testRussianWinAlsoLoads() {
        XCTAssertNotNil(SystemLayouts.keyMap(inputSourceID: "com.apple.keylayout.RussianWin"))
    }
}
