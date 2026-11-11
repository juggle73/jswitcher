import XCTest
@testable import JswitcherCore

final class InputRulesTests: XCTestCase {
    let layouts = Fixtures.layouts

    // MARK: ControlTapDetector

    func testLeftControlTapFires() {
        var d = ControlTapDetector()
        XCTAssertFalse(d.flagsChanged(keyCode: 59, flags: [.control], at: 0))
        XCTAssertTrue(d.flagsChanged(keyCode: 59, flags: [], at: 0.1))
    }

    func testCapsLockIgnoredForTap() {
        var d = ControlTapDetector()
        XCTAssertFalse(d.flagsChanged(keyCode: 59, flags: [.control, .capsLock], at: 0))
        XCTAssertTrue(d.flagsChanged(keyCode: 59, flags: [.capsLock], at: 0.1))
    }

    func testLongHoldDoesNotFire() {
        var d = ControlTapDetector()
        _ = d.flagsChanged(keyCode: 59, flags: [.control], at: 0)
        XCTAssertFalse(d.flagsChanged(keyCode: 59, flags: [], at: 0.6))
    }

    func testKeyInBetweenCancels() {
        var d = ControlTapDetector()
        _ = d.flagsChanged(keyCode: 59, flags: [.control], at: 0)
        d.otherEvent()
        XCTAssertFalse(d.flagsChanged(keyCode: 59, flags: [], at: 0.1))
    }

    func testRightControlIgnored() {
        var d = ControlTapDetector()
        XCTAssertFalse(d.flagsChanged(keyCode: 62, flags: [.control], at: 0))
        XCTAssertFalse(d.flagsChanged(keyCode: 62, flags: [], at: 0.1))
    }

    func testControlWithShiftCancels() {
        var d = ControlTapDetector()
        XCTAssertFalse(d.flagsChanged(keyCode: 59, flags: [.control], at: 0))
        XCTAssertFalse(d.flagsChanged(keyCode: 56, flags: [.control, .shift], at: 0.05))
        XCTAssertFalse(d.flagsChanged(keyCode: 56, flags: [.control], at: 0.1))
        XCTAssertFalse(d.flagsChanged(keyCode: 59, flags: [], at: 0.15))
    }

    func testReleaseWithoutPressDoesNotFire() {
        var d = ControlTapDetector()
        XCTAssertFalse(d.flagsChanged(keyCode: 59, flags: [], at: 0.1))
    }

    // MARK: KeyClassifier

    func classify(_ code: UInt16, _ flags: ModifierFlags = []) -> KeyClass {
        KeyClassifier.classify(keyCode: code, flags: flags, layouts: layouts)
    }

    func testBoundaries() {
        XCTAssertEqual(classify(49), .boundary(.space))
        XCTAssertEqual(classify(36), .boundary(.enter))
        XCTAssertEqual(classify(48), .boundary(.tab))
    }

    func testKeypadEnterIsBoundary() {
        XCTAssertEqual(classify(76), .boundary(.enter))
        XCTAssertEqual(classify(36, [.shift]), .boundary(.enter))
    }

    func testBackspace() {
        XCTAssertEqual(classify(51), .backspace)
    }

    func testOldPauseHotkeyIsJustAShortcut() {
        XCTAssertEqual(classify(35, [.control, .option, .command]), .reset)
    }

    func testShortcutsReset() {
        XCTAssertEqual(classify(8, [.command]), .reset)
        XCTAssertEqual(classify(8, [.control]), .reset)
    }

    func testOptionResets() {
        XCTAssertEqual(classify(0, [.option]), .reset)
    }

    func testNavigationResets() {
        for code: UInt16 in [123, 124, 125, 126, 115, 119, 116, 121, 117, 53] {
            XCTAssertEqual(classify(code), .reset, "\(code)")
        }
    }

    func testCharacters() {
        XCTAssertEqual(classify(0), .character(KeyStroke(keyCode: 0, shift: false)))
        XCTAssertEqual(classify(0, [.shift]), .character(KeyStroke(keyCode: 0, shift: true)))
        XCTAssertEqual(classify(0, [.capsLock]), .character(KeyStroke(keyCode: 0, shift: false, capsLock: true)))
        XCTAssertEqual(classify(43), .character(KeyStroke(keyCode: 43, shift: false)))
    }

    func testAutorepeatResets() {
        XCTAssertEqual(KeyClassifier.classify(keyCode: 0, flags: [], isAutorepeat: true, layouts: layouts), .reset)
        XCTAssertEqual(KeyClassifier.classify(keyCode: 51, flags: [], isAutorepeat: true, layouts: layouts), .reset)
    }

    func testFnResets() {
        XCTAssertEqual(classify(3, [.function]), .reset)   // Globe+F
    }

    func testLayoutSwitchModifiersReset() {
        XCTAssertTrue(KeyClassifier.flagsChangedResets(keyCode: 57))   // Caps Lock (can switch to ABC)
        XCTAssertTrue(KeyClassifier.flagsChangedResets(keyCode: 63))   // Fn / Globe
        XCTAssertFalse(KeyClassifier.flagsChangedResets(keyCode: 56))  // Shift
        XCTAssertFalse(KeyClassifier.flagsChangedResets(keyCode: 59))  // left Control (tap)
    }

}

final class ModifierChordTests: XCTestCase {
    func testControlOptionTapFires() {
        var d = ModifierChordDetector()
        XCTAssertFalse(d.flagsChanged(flags: [.control], at: 0))
        XCTAssertFalse(d.flagsChanged(flags: [.control, .option], at: 0.05))
        XCTAssertFalse(d.flagsChanged(flags: [.option], at: 0.2))
        XCTAssertTrue(d.flagsChanged(flags: [], at: 0.25))
    }

    func testOptionFirstAlsoFires() {
        var d = ModifierChordDetector()
        _ = d.flagsChanged(flags: [.option], at: 0)
        _ = d.flagsChanged(flags: [.option, .control], at: 0.05)
        _ = d.flagsChanged(flags: [.control], at: 0.1)
        XCTAssertTrue(d.flagsChanged(flags: [], at: 0.15))
    }

    func testCapsLockIgnored() {
        var d = ModifierChordDetector()
        _ = d.flagsChanged(flags: [.control, .capsLock], at: 0)
        _ = d.flagsChanged(flags: [.control, .option, .capsLock], at: 0.05)
        XCTAssertTrue(d.flagsChanged(flags: [.capsLock], at: 0.1))
    }

    func testKeyInBetweenCancels() {   // Control+Option+arrow etc.
        var d = ModifierChordDetector()
        _ = d.flagsChanged(flags: [.control, .option], at: 0)
        d.otherEvent()
        XCTAssertFalse(d.flagsChanged(flags: [], at: 0.1))
    }

    func testExtraModifierCancels() {
        var d = ModifierChordDetector()
        _ = d.flagsChanged(flags: [.control, .option], at: 0)
        _ = d.flagsChanged(flags: [.control, .option, .command], at: 0.05)
        _ = d.flagsChanged(flags: [.control, .option], at: 0.1)
        XCTAssertFalse(d.flagsChanged(flags: [], at: 0.15))
    }

    func testControlAloneDoesNotFire() {
        var d = ModifierChordDetector()
        _ = d.flagsChanged(flags: [.control], at: 0)
        XCTAssertFalse(d.flagsChanged(flags: [], at: 0.1))
    }

    func testSlowChordDoesNotFire() {
        var d = ModifierChordDetector()
        _ = d.flagsChanged(flags: [.control], at: 0)
        _ = d.flagsChanged(flags: [.control, .option], at: 0.5)
        XCTAssertFalse(d.flagsChanged(flags: [], at: 1.2))
    }

    func testNextChordWorksAfterCancel() {
        var d = ModifierChordDetector()
        _ = d.flagsChanged(flags: [.control, .option], at: 0)
        d.otherEvent()
        _ = d.flagsChanged(flags: [], at: 0.1)
        _ = d.flagsChanged(flags: [.control], at: 1)
        _ = d.flagsChanged(flags: [.control, .option], at: 1.05)
        XCTAssertTrue(d.flagsChanged(flags: [], at: 1.1))
    }
}
