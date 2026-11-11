import AppKit
import ApplicationServices

/// jswitcher needs only Accessibility: an active (event-modifying) tap is allowed with it.
/// Whether the tap really starts is the final check — see AppDelegate.startTapIfPermitted().
enum Permissions {
    static var granted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt (which also adds jswitcher to the Accessibility list).
    static func request() {
        if !AXIsProcessTrusted() {
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        }
    }

    @MainActor
    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Starts a fresh instance of the app and quits this one. Some permission changes reach
    /// a process only at launch.
    @MainActor
    static func relaunch() {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { _, error in
            guard error == nil else { return }
            DispatchQueue.main.async { NSApplication.shared.terminate(nil) }
        }
    }
}
