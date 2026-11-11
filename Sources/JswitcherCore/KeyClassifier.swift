public enum KeyClass: Equatable, Sendable {
    case character(KeyStroke), boundary(Boundary), backspace, reset
}

public enum KeyClassifier {
    /// Auto-repeat and Fn/Globe combos reset: with press-and-hold, the accent popup and Globe shortcuts,
    /// such key-downs do not put one character on screen each, so the buffer would stop matching the screen.
    public static func classify(keyCode: UInt16, flags: ModifierFlags, isAutorepeat: Bool = false, layouts: LayoutPair) -> KeyClass {
        if isAutorepeat { return .reset }
        if !flags.isDisjoint(with: [.command, .control, .option, .function]) { return .reset }
        switch keyCode {
        case 49: return .boundary(.space)
        case 36, 76: return .boundary(.enter)
        case 48: return .boundary(.tab)
        case 51: return .backspace
        default: break
        }
        let stroke = KeyStroke(keyCode: keyCode, shift: flags.contains(.shift), capsLock: flags.contains(.capsLock))
        if layouts.en.character(for: stroke) != nil || layouts.ru.character(for: stroke) != nil {
            return .character(stroke)
        }
        return .reset
    }

    /// Modifier keys whose press can switch the keyboard layout (Caps Lock, Fn/Globe): the buffer must be cleared.
    public static func flagsChangedResets(keyCode: UInt16) -> Bool {
        keyCode == 57 || keyCode == 63
    }
}
