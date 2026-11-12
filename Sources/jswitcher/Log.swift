import os
import JswitcherCore

/// Typed, text-free diagnostics. Never logs typed characters, words or selections.
///
/// Health events (launch, permissions, event-tap stalls) are logged in release builds at `notice`
/// level so macOS keeps them on disk; they show whether jswitcher was involved when the system
/// misbehaves. Read with:
///   log show --last 1d --predicate 'subsystem == "io.github.juggle73.jswitcher"'
/// Per-correction events are debug-only.
enum Log {
    private static let logger = Logger(subsystem: "io.github.juggle73.jswitcher", category: "health")
    #if DEBUG
    private static let events = Logger(subsystem: "io.github.juggle73.jswitcher", category: "events")
    #endif

    // MARK: - Health (release too)

    static func launched(version: String, accessibilityGranted: Bool) {
        logger.notice("launched version=\(version, privacy: .public) accessibility=\(accessibilityGranted)")
    }

    static func tapStarted(secondsSinceLaunch: Int) {
        logger.notice("event tap started after=\(secondsSinceLaunch)s")
    }

    static func tapStartRefused() {
        logger.notice("event tap refused by the system although accessibility is granted")
    }

    static func permissionPromptShown(secondsSinceLaunch: Int) {
        logger.notice("accessibility prompt shown after=\(secondsSinceLaunch)s")
    }

    /// The system disabled the tap: `byTimeout` means our callback was too slow (main thread stalled).
    static func tapDisabled(byTimeout: Bool) {
        logger.notice("event tap disabled by=\(byTimeout ? "timeout" : "userInput", privacy: .public), re-enabled")
    }

    /// The tap callback took longer than the slow threshold; `eventType` is CGEventType.rawValue.
    static func slowCallback(eventType: UInt32, milliseconds: Int) {
        logger.notice("slow event tap callback type=\(eventType) duration=\(milliseconds)ms")
    }

    // MARK: - Debug only

    static func corrected(length: Int, from: Lang, to: Lang) {
        #if DEBUG
        events.debug("corrected length=\(length) \(String(describing: from))->\(String(describing: to))")
        #endif
    }

    static func converted(length: Int, from: Lang, to: Lang) {
        #if DEBUG
        events.debug("converted length=\(length) \(String(describing: from))->\(String(describing: to))")
        #endif
    }

    static func convertedSelection(length: Int, to: Lang) {
        #if DEBUG
        events.debug("converted selection length=\(length) ->\(String(describing: to))")
        #endif
    }
}
