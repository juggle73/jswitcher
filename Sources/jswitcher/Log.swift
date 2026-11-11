#if DEBUG
import os
#endif
import JswitcherCore

/// Typed, text-free diagnostics. Compiled to nothing in release builds.
enum Log {
    #if DEBUG
    private static let logger = Logger(subsystem: "io.github.juggle73.jswitcher", category: "events")
    #endif

    static func corrected(length: Int, from: Lang, to: Lang) {
        #if DEBUG
        logger.debug("corrected length=\(length) \(String(describing: from))->\(String(describing: to))")
        #endif
    }

    static func converted(length: Int, from: Lang, to: Lang) {
        #if DEBUG
        logger.debug("converted length=\(length) \(String(describing: from))->\(String(describing: to))")
        #endif
    }

    static func convertedSelection(length: Int, to: Lang) {
        #if DEBUG
        logger.debug("converted selection length=\(length) ->\(String(describing: to))")
        #endif
    }

    static func tapReenabled() {
        #if DEBUG
        logger.debug("event tap re-enabled")
        #endif
    }
}
