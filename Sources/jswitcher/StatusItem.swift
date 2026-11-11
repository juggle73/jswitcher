import AppKit
import JswitcherCore

enum AppState: Equatable {
    case active(Lang), paused(Lang?), inactiveLayout, noPermissions
}

@MainActor
final class StatusItem: NSObject {
    var onTogglePause: (() -> Void)?
    var onOpenExclusions: (() -> Void)?

    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let pauseItem = NSMenuItem(title: "Пауза   ⌃⌥", action: #selector(togglePause), keyEquivalent: "")
    private let settingsItem = NSMenuItem(title: "Открыть настройки доступа…", action: #selector(openSettings), keyEquivalent: "")
    private let relaunchItem = NSMenuItem(title: "Перезапустить jswitcher", action: #selector(relaunch), keyEquivalent: "")

    override init() {
        super.init()
        pauseItem.target = self
        settingsItem.target = self
        relaunchItem.target = self
        let menu = NSMenu()
        menu.addItem(pauseItem)
        let exclusionsItem = NSMenuItem(title: "Исключения…", action: #selector(openExclusions), keyEquivalent: "")
        exclusionsItem.target = self
        menu.addItem(exclusionsItem)
        menu.addItem(settingsItem)
        menu.addItem(relaunchItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Выход", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
    }

    func refresh(state: AppState) {
        var paused = false
        switch state {
        case .active(let lang): setTitle(Self.label(lang))
        case .paused(let lang):
            paused = true
            // Paused: the same layout letters, grey and struck through.
            item.button?.attributedTitle = NSAttributedString(string: lang.map(Self.label) ?? "—", attributes: [
                .foregroundColor: NSColor.disabledControlTextColor,
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .font: NSFont.menuBarFont(ofSize: 0),
            ])
        case .inactiveLayout: setTitle("—")
        case .noPermissions: setTitle("⚠︎")
        }
        pauseItem.state = paused ? .on : .off
        settingsItem.isHidden = state != .noPermissions
        relaunchItem.isHidden = state != .noPermissions
    }

    nonisolated private static func label(_ lang: Lang) -> String { lang == .en ? "EN" : "RU" }

    private func setTitle(_ title: String) {
        item.button?.attributedTitle = NSAttributedString(string: title, attributes: [.font: NSFont.menuBarFont(ofSize: 0)])
    }

    @objc private func togglePause() { onTogglePause?() }
    @objc private func openExclusions() { onOpenExclusions?() }
    @objc private func openSettings() { Permissions.openSettings() }
    @objc private func relaunch() { Permissions.relaunch() }
}
