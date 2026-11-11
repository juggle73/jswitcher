import ApplicationServices
import Foundation

/// Reads and replaces the selection in the focused text element of an app via Accessibility.
/// The selected text is held only for the duration of one Control tap.
enum FocusedSelection {
    struct Target {
        let element: AXUIElement
        let text: String
    }

    /// Short timeout: this runs inside the event-tap callback.
    private static let timeout: Float = 0.25

    enum Probe {
        /// No focused text element or no selection: Control works on the typed word.
        case none
        /// There is a selection we can't (or must not) replace: Control only switches the layout,
        /// because the word path's Backspaces would erase the selection.
        case blocked
        case replaceable(Target)
    }

    static func probe(pid: pid_t) -> Probe {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, timeout)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return .none }
        let element = focused as! AXUIElement
        AXUIElementSetMessagingTimeout(element, timeout)

        // Length first: the text itself is read only when we're going to replace it.
        var rangeValue: CFTypeRef?
        var range = CFRange()
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let rangeValue, CFGetTypeID(rangeValue) == AXValueGetTypeID(),
              AXValueGetValue(rangeValue as! AXValue, .cfRange, &range), range.length > 0 else { return .none }

        var settable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &settable) == .success,
              settable.boolValue else { return .blocked }
        var text: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &text) == .success,
              let selected = text as? String, !selected.isEmpty else { return .blocked }
        return .replaceable(Target(element: element, text: selected))
    }

    /// Replaces the selection in one Accessibility operation. The app decides what stays selected
    /// (by design: no artificial re-selection). Returns false if the app refused.
    static func replace(_ target: Target, with text: String) -> Bool {
        AXUIElementSetAttributeValue(target.element, kAXSelectedTextAttribute as CFString, text as CFString) == .success
    }
}
