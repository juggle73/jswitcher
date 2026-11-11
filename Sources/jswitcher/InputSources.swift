import Carbon.HIToolbox
import Foundation
import JswitcherCore

/// Tracks the enabled EN/RU keyboard layouts and the current one.
@MainActor
final class InputSources: NSObject {
    private(set) var currentLang: Lang?
    private(set) var layouts: LayoutPair?
    var onChange: (() -> Void)?

    private var enSource: TISInputSource?
    private var ruSource: TISInputSource?
    override init() {
        super.init()
        rebuild()
        // .deliverImmediately: a menu-bar app is almost never active, and the default suspension
        // behaviour would hold layout-change notifications back, leaving currentLang stale.
        let center = DistributedNotificationCenter.default()
        center.addObserver(
            self, selector: #selector(selectedSourceChanged),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil, suspensionBehavior: .deliverImmediately)
        center.addObserver(
            self, selector: #selector(enabledSourcesChanged),
            name: NSNotification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String),
            object: nil, suspensionBehavior: .deliverImmediately)
    }

    @objc private func selectedSourceChanged() { refreshCurrent() }
    @objc private func enabledSourcesChanged() { rebuild() }

    func select(_ lang: Lang) {
        guard let source = lang == .en ? enSource : ruSource else { return }
        TISSelectInputSource(source)
        currentLang = lang
        onChange?()
    }

    private func rebuild() {
        let list = (TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource]) ?? []
        let byID = Dictionary(list.compactMap { s in Self.id(of: s).map { ($0, s) } }, uniquingKeysWith: { a, _ in a })
        enSource = SystemLayouts.enIDs.lazy.compactMap { byID[$0] }.first
        ruSource = SystemLayouts.ruIDs.lazy.compactMap { byID[$0] }.first
        if let en = enSource.flatMap(Self.id).flatMap(SystemLayouts.keyMap(inputSourceID:)),
           let ru = ruSource.flatMap(Self.id).flatMap(SystemLayouts.keyMap(inputSourceID:)) {
            layouts = LayoutPair(en: en, ru: ru)
        } else {
            layouts = nil
        }
        refreshCurrent()
    }

    private func refreshCurrent() {
        let id = TISCopyCurrentKeyboardInputSource().flatMap { Self.id(of: $0.takeRetainedValue()) }
        if layouts == nil {
            currentLang = nil
        } else if let id, SystemLayouts.enIDs.contains(id) {
            currentLang = .en
        } else if let id, SystemLayouts.ruIDs.contains(id) {
            currentLang = .ru
        } else {
            currentLang = nil
        }
        onChange?()
    }

    nonisolated private static func id(of source: TISInputSource) -> String? {
        guard let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }
}
