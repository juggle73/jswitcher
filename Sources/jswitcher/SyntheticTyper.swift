import CoreGraphics
import JswitcherCore

/// Posts the correction straight into the tap's position in the event stream,
/// so it lands before any key the user presses next.
enum SyntheticTyper {
    static let magic: Int64 = 0x4A53_5743   // "JSWC"
    private static let backspace: CGKeyCode = 51
    private static let space: CGKeyCode = 49

    static func apply(_ r: Replacement, original boundaryEvent: CGEvent?, proxy: CGEventTapProxy) {
        let source = CGEventSource(stateID: .privateState)
        for _ in 0..<r.deleteCount {
            press(backspace, flags: [], text: nil, source: source, proxy: proxy)
        }
        for key in r.keys {
            press(CGKeyCode(key.stroke.keyCode), flags: key.stroke.shift ? .maskShift : [],
                  text: String(key.character), source: source, proxy: proxy)
        }
        guard r.trailingBoundary != nil else { return }
        if let original = boundaryEvent?.copy() {
            original.setIntegerValueField(.eventSourceUserData, value: magic)
            original.tapPostEvent(proxy)
        } else {
            press(space, flags: [], text: nil, source: source, proxy: proxy)
        }
    }

    private static func press(_ code: CGKeyCode, flags: CGEventFlags, text: String?, source: CGEventSource?, proxy: CGEventTapProxy) {
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { continue }
            e.flags = flags
            if let text {
                let units = Array(text.utf16)
                e.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
            }
            e.setIntegerValueField(.eventSourceUserData, value: magic)
            e.tapPostEvent(proxy)
        }
    }
}
