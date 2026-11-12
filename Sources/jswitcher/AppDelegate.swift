import AppKit
import Carbon.HIToolbox
import JswitcherCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var isPaused = false
    var onStateChange: (() -> Void)?

    private var statusItem: StatusItem?
    private var permissionTimer: Timer?
    private let inputSources = InputSources()
    private var tap: EventTap?
    private var dictionaries: Dictionaries?
    private var engine: Engine?
    private var controlTap = ControlTapDetector()
    private var pauseChord = ModifierChordDetector()
    private var frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    private var frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
    private var selectionConverter: SelectionConverter?
    private static let exclusionsKey = "excludedBundleIDs"
    private var exclusions = ExclusionList(stored: UserDefaults.standard.stringArray(forKey: AppDelegate.exclusionsKey))
    private var exclusionsWindow: ExclusionsWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = StatusItem()
        item.onTogglePause = { [weak self] in self?.togglePause() }
        item.onOpenExclusions = { [weak self] in self?.openExclusions() }
        statusItem = item
        onStateChange = { [weak self] in self?.refreshStatus() }

        LoginItem.registerOnce()
        dictionaries = Self.loadDictionaries()
        inputSources.onChange = { [weak self] in self?.layoutsChanged() }
        rebuildEngine()

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let id = app?.bundleIdentifier, pid = app?.processIdentifier
            MainActor.assumeIsolated {
                self?.frontmostBundleID = id
                self?.refreshStatus()
                self?.frontmostPID = pid
                self?.resetEngine()
            }
        }

        tap = EventTap { [weak self] proxy, type, event in
            // Not `self?.handle(...) ?? pass`: that would turn a deliberate nil (drop the event) into pass.
            guard let self else { return Unmanaged.passUnretained(event) }
            return self.handle(proxy: proxy, type: type, event: event)
        }
        Log.launched(version: Self.version, accessibilityGranted: Permissions.granted)
        if !startTapIfPermitted() {
            // The system prompt is shown by itself only once, on the very first launch. Later launches
            // without access only show ⚠︎ and the menu items: right after login macOS may briefly answer
            // "not trusted" although access is granted, and a prompt then would be false.
            if !UserDefaults.standard.bool(forKey: Self.accessibilityAskedKey) {
                UserDefaults.standard.set(true, forKey: Self.accessibilityAskedKey)
                Permissions.request()
                Log.permissionPromptShown(secondsSinceLaunch: secondsSinceLaunch)
            }
            // Poll only until permissions arrive, then stop.
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, self.startTapIfPermitted() else { return }
                    self.permissionTimer?.invalidate()
                    self.permissionTimer = nil
                }
            }
        }
        refreshStatus()
    }

    /// Set once the system prompt was shown or access was seen granted: jswitcher is then in the
    /// Accessibility list and never shows the prompt by itself again.
    private static let accessibilityAskedKey = "accessibilityAsked"
    private let launchedAt = ProcessInfo.processInfo.systemUptime

    private var secondsSinceLaunch: Int { Int(ProcessInfo.processInfo.systemUptime - launchedAt) }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    private var tapStartLogged = false
    private var tapRefusalLogged = false

    private func startTapIfPermitted() -> Bool {
        let granted = Permissions.granted
        // Installs from before this flag existed: access already granted means the user was asked.
        if granted { UserDefaults.standard.set(true, forKey: Self.accessibilityAskedKey) }
        let started = granted && (tap?.start() ?? false)
        if started {
            if !tapStartLogged {
                tapStartLogged = true
                Log.tapStarted(secondsSinceLaunch: secondsSinceLaunch)
            }
        } else if granted, !tapRefusalLogged {
            tapRefusalLogged = true
            Log.tapStartRefused()
        }
        refreshStatus()
        return started
    }

    private var state: AppState {
        guard tap?.isRunning == true else { return .noPermissions }
        if isEffectivelyPaused { return .paused(inputSources.currentLang) }
        guard let lang = inputSources.currentLang else { return .inactiveLayout }
        return .active(lang)
    }

    private func refreshStatus() {
        statusItem?.refresh(state: state)
    }

    private func openExclusions() {
        if exclusionsWindow == nil {
            exclusionsWindow = ExclusionsWindow(list: exclusions) { [weak self] list in
                self?.exclusions = list
                self?.refreshStatus()
                UserDefaults.standard.set(list.stored, forKey: Self.exclusionsKey)
                self?.resetEngine()
            }
        }
        exclusionsWindow?.show()
    }

    func togglePause() {
        isPaused.toggle()
        resetEngine()
        onStateChange?()
    }

    // MARK: - Engine lifecycle

    private struct Dictionaries {
        let en, ru, enTop, ruTop, tech: WordList
        let enModel, ruModel: NgramModel
    }

    private static func loadDictionaries() -> Dictionaries? {
        func load(_ name: String) -> WordList? {
            Bundle.main.url(forResource: name, withExtension: "bin").flatMap { try? WordList(contentsOf: $0) }
        }
        func model(_ name: String) -> NgramModel? {
            Bundle.main.url(forResource: name, withExtension: "bin").flatMap { try? NgramModel(contentsOf: $0) }
        }
        guard let en = load("dict_en"), let ru = load("dict_ru"),
              let enTop = load("dict_en_top"), let ruTop = load("dict_ru_top"),
              let tech = load("dict_tech"),
              let enModel = model("ngram_en"), let ruModel = model("ngram_ru") else { return nil }
        return Dictionaries(en: en, ru: ru, enTop: enTop, ruTop: ruTop, tech: tech, enModel: enModel, ruModel: ruModel)
    }

    private var lastLayouts: LayoutPair?

    /// Called on every layout switch too. No reset here: Engine resets itself when the language it
    /// sees differs from the one it expects, and a reset would break Control-undo after our own switch.
    private func layoutsChanged() {
        rebuildEngine()
        onStateChange?()
    }

    private func rebuildEngine() {
        guard let layouts = inputSources.layouts, let dicts = dictionaries else {
            engine = nil
            return
        }
        // Rebuild only when the layout set changes, not on every layout switch.
        if engine != nil, let last = lastLayouts, last.en.table == layouts.en.table, last.ru.table == layouts.ru.table { return }
        lastLayouts = layouts
        selectionConverter = SelectionConverter(layouts: layouts)
        engine = Engine(layouts: layouts, detector: Detector(layouts: layouts, en: dicts.en, ru: dicts.ru, enTop: dicts.enTop, ruTop: dicts.ruTop, tech: dicts.tech,
                                                                      enModel: dicts.enModel, ruModel: dicts.ruModel))
    }

    private func resetEngine() {
        _ = engine?.handle(.reset, current: inputSources.currentLang ?? .en, now: ProcessInfo.processInfo.systemUptime)
    }

    /// Text may be touched only when no secure (password) input is active.
    private var textAllowed: Bool {
        !IsSecureEventInputEnabled()
    }

    /// Two modes: normal (auto-correct + Control) and paused (Control only). An excluded app is paused.
    private var isEffectivelyPaused: Bool {
        isPaused || exclusions.contains(frontmostBundleID)
    }

    private var autoCorrectAllowed: Bool { !isEffectivelyPaused }

    // MARK: - Event handling

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            tap?.reenable()
            resetEngine()
            Log.tapDisabled(byTimeout: type == .tapDisabledByTimeout)
            return pass
        default:
            break
        }
        if event.getIntegerValueField(.eventSourceUserData) == SyntheticTyper.magic { return pass }
        let now = ProcessInfo.processInfo.systemUptime

        switch type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            controlTap.otherEvent()
            pauseChord.otherEvent()
            resetEngine()
            return pass

        case .flagsChanged:
            let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            if KeyClassifier.flagsChangedResets(keyCode: code) { resetEngine() }
            // Control+Option tapped together toggles pause — works in any state and layout.
            if pauseChord.flagsChanged(flags: Self.modifiers(event.flags), at: now) {
                togglePause()
                return pass
            }
            guard controlTap.flagsChanged(keyCode: code, flags: Self.modifiers(event.flags), at: now),
                  let lang = inputSources.currentLang else { return pass }
            guard textAllowed, let engine else {
                inputSources.select(lang.other)
                return pass
            }
            if convertSelection(current: lang) { return pass }
            perform(engine.handle(.controlTap, current: lang, now: now), from: lang, original: nil, proxy: proxy)
            return pass

        case .keyDown:
            controlTap.otherEvent()
            pauseChord.otherEvent()
            guard let layouts = inputSources.layouts else { return pass }
            let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            let keyClass = KeyClassifier.classify(
                keyCode: code, flags: Self.modifiers(event.flags), isAutorepeat: isRepeat, layouts: layouts)
            guard let engine, let lang = inputSources.currentLang, textAllowed else {
                resetEngine()
                return pass
            }
            let input: EngineInput
            switch keyClass {
            case let .character(stroke): input = .character(stroke)
            case let .boundary(b): input = .boundary(b)
            case .backspace: input = .backspace
            case .reset: input = .reset
            }
            let suppressed = perform(engine.handle(input, current: lang, now: now, autoCorrect: autoCorrectAllowed), from: lang, original: event, proxy: proxy)
            return suppressed ? nil : pass

        default:
            return pass
        }
    }

    /// Control with a selection in the focused field: convert the whole selection, keep it selected,
    /// switch layout. Returns false if there's no selection (fall back to the typed word).
    private func convertSelection(current lang: Lang) -> Bool {
        guard let converter = selectionConverter, let pid = frontmostPID else { return false }
        switch FocusedSelection.probe(pid: pid) {
        case .none:
            return false
        case .blocked:
            resetEngine()
            inputSources.select(lang.other)
            return true
        case let .replaceable(target):
            guard let result = converter.convert(target.text, current: lang),
                  result.text == target.text || FocusedSelection.replace(target, with: result.text) else {
                resetEngine()
                inputSources.select(lang.other)
                return true
            }
            resetEngine()
            inputSources.select(result.switchTo)
            Log.convertedSelection(length: result.text.count, to: result.switchTo)
            return true
        }
    }

    /// Executes an engine action. Returns true if the original event must be dropped (it was re-posted).
    @discardableResult
    private func perform(_ action: EngineAction, from lang: Lang, original: CGEvent?, proxy: CGEventTapProxy) -> Bool {
        switch action {
        case .pass:
            return false
        case let .replace(r):
            SyntheticTyper.apply(r, original: original, proxy: proxy)
            inputSources.select(r.switchTo)
            if original != nil {
                Log.corrected(length: r.keys.count, from: lang, to: r.switchTo)
            } else {
                Log.converted(length: r.keys.count, from: lang, to: r.switchTo)
            }
            return original != nil
        case let .switchLayout(to):
            inputSources.select(to)
            return false
        }
    }

    private static func modifiers(_ f: CGEventFlags) -> ModifierFlags {
        var m: ModifierFlags = []
        if f.contains(.maskShift) { m.insert(.shift) }
        if f.contains(.maskControl) { m.insert(.control) }
        if f.contains(.maskAlternate) { m.insert(.option) }
        if f.contains(.maskCommand) { m.insert(.command) }
        if f.contains(.maskAlphaShift) { m.insert(.capsLock) }
        if f.contains(.maskSecondaryFn) { m.insert(.function) }
        return m
    }
}
