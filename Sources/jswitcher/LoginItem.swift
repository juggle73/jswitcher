import Foundation
import ServiceManagement

/// Start at login: registered once, on the first launch. If the user later removes jswitcher in
/// System Settings → General → Login Items, it is not re-added.
enum LoginItem {
    private static let doneKey = "loginItemRegistered"

    static func registerOnce() {
        guard !UserDefaults.standard.bool(forKey: doneKey) else { return }
        do {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
            UserDefaults.standard.set(true, forKey: doneKey)
        } catch {
            // Not fatal: try again on the next launch.
        }
    }
}
