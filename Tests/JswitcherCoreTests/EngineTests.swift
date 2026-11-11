import XCTest
@testable import JswitcherCore

final class EngineTests: XCTestCase {
    let layouts = Fixtures.layouts
    var engine: Engine!

    override func setUp() {
        let detector = Detector(layouts: layouts, en: WordList(words: ["hello"]), ru: WordList(words: ["привет", "тест"]))
        engine = Engine(layouts: layouts, detector: detector)
    }

    /// Types `s` as it appears in layout `lang`, with the active layout also `lang`.
    func type(_ s: String, _ lang: Lang, at t: TimeInterval = 0, file: StaticString = #filePath, line: UInt = #line) {
        typeStrokes(layouts.map(lang).strokes(typing: s, file: file, line: line), current: lang, at: t, file: file, line: line)
    }

    func typeStrokes(_ strokes: [KeyStroke], current: Lang, at t: TimeInterval = 0, file: StaticString = #filePath, line: UInt = #line) {
        for s in strokes {
            XCTAssertEqual(engine.handle(.character(s), current: current, now: t), .pass, file: file, line: line)
        }
    }

    func assertReplace(_ action: EngineAction, delete: Int, text: String, to lang: Lang, boundary: Boundary?,
                       file: StaticString = #filePath, line: UInt = #line) {
        guard case let .replace(r) = action else {
            return XCTFail("expected replace, got \(action)", file: file, line: line)
        }
        XCTAssertEqual(r.deleteCount, delete, "deleteCount", file: file, line: line)
        XCTAssertEqual(String(r.keys.map(\.character)), text, file: file, line: line)
        XCTAssertEqual(r.switchTo, lang, file: file, line: line)
        XCTAssertEqual(r.trailingBoundary, boundary, file: file, line: line)
        for k in r.keys {
            XCTAssertEqual(layouts.map(lang).character(for: k.stroke), k.character, "stroke matches character", file: file, line: line)
        }
    }

    func testAutoCorrectOnSpace() {
        type("ghbdtn", .en)
        assertReplace(engine.handle(.boundary(.space), current: .en, now: 0), delete: 6, text: "привет", to: .ru, boundary: .space)
    }

    func testValidWordPasses() {
        type("hello", .en)
        XCTAssertEqual(engine.handle(.boundary(.space), current: .en, now: 0), .pass)
    }

    func testControlConvertsCurrentAndBack() {
        type("ghbdtn", .en)
        assertReplace(engine.handle(.controlTap, current: .en, now: 0), delete: 6, text: "привет", to: .ru, boundary: nil)
        assertReplace(engine.handle(.controlTap, current: .ru, now: 0), delete: 6, text: "ghbdtn", to: .en, boundary: nil)
    }

    func testControlAfterAutoCorrectUndoes() {
        type("ghbdtn", .en)
        _ = engine.handle(.boundary(.space), current: .en, now: 0)
        assertReplace(engine.handle(.controlTap, current: .ru, now: 0), delete: 7, text: "ghbdtn", to: .en, boundary: .space)
    }

    func testControlAfterSpaceConvertsPrevious() {
        type("hello", .en)
        XCTAssertEqual(engine.handle(.boundary(.space), current: .en, now: 0), .pass)
        assertReplace(engine.handle(.controlTap, current: .en, now: 0), delete: 6, text: "руддщ", to: .ru, boundary: .space)
    }

    func testControlAfterEnterOnlySwitches() {
        for b in [Boundary.enter, .tab] {
            setUp()
            type("hello", .en)
            XCTAssertEqual(engine.handle(.boundary(b), current: .en, now: 0), .pass)
            XCTAssertEqual(engine.handle(.controlTap, current: .en, now: 0), .switchLayout(to: .ru), "\(b)")
        }
    }

    func testControlOnEmptySwitches() {
        XCTAssertEqual(engine.handle(.controlTap, current: .en, now: 0), .switchLayout(to: .ru))
    }

    func testBackspaceEditsWord() {
        type("ghbdtnx", .en)
        XCTAssertEqual(engine.handle(.backspace, current: .en, now: 0), .pass)
        assertReplace(engine.handle(.boundary(.space), current: .en, now: 0), delete: 6, text: "привет", to: .ru, boundary: .space)
    }

    func testIdleTimeoutResets() {
        type("ghbdtn", .en, at: 0)
        XCTAssertEqual(engine.handle(.boundary(.space), current: .en, now: 10.5), .pass)
    }

    func testLayoutChangeMidWordResets() {
        let abc = layouts.en
        typeStrokes(abc.strokes(typing: "ghb"), current: .en)
        typeStrokes(abc.strokes(typing: "dtn"), current: .ru)
        XCTAssertEqual(engine.handle(.boundary(.space), current: .ru, now: 0), .pass)
        assertReplace(engine.handle(.controlTap, current: .ru, now: 0), delete: 4, text: "dtn", to: .en, boundary: .space)
    }

    func testOverflowNeverCorrects() {
        let long = String(String(repeating: "ghbdtn", count: 9).prefix(49))
        type(long, .en)
        XCTAssertEqual(engine.handle(.boundary(.space), current: .en, now: 0), .pass)
        XCTAssertEqual(engine.handle(.controlTap, current: .en, now: 0), .switchLayout(to: .ru))
    }

    func testNewWordAfterPreviousConversion() {
        type("hello", .en)
        _ = engine.handle(.boundary(.space), current: .en, now: 0)
        assertReplace(engine.handle(.controlTap, current: .en, now: 0), delete: 6, text: "руддщ", to: .ru, boundary: .space)
        typeStrokes([KeyStroke(keyCode: 0, shift: false)], current: .ru)
        assertReplace(engine.handle(.controlTap, current: .ru, now: 0), delete: 1, text: "a", to: .en, boundary: nil)
    }

    func testManualConversionNotUndoneByAutoCorrect() {
        type("hello", .en)
        assertReplace(engine.handle(.controlTap, current: .en, now: 0), delete: 5, text: "руддщ", to: .ru, boundary: nil)
        XCTAssertEqual(engine.handle(.boundary(.space), current: .ru, now: 0), .pass)
    }

    /// Excluded apps (IDE, terminal): no auto-correct, but Control still converts.
    func testNoAutoCorrectButControlConverts() {
        type("ghbdtn", .en)
        XCTAssertEqual(engine.handle(.boundary(.space), current: .en, now: 0, autoCorrect: false), .pass)
        assertReplace(engine.handle(.controlTap, current: .en, now: 0, autoCorrect: false),
                      delete: 7, text: "привет", to: .ru, boundary: .space)
    }
}
