public enum Lang: Sendable, Equatable {
    case en, ru

    public var other: Lang { self == .en ? .ru : .en }
}

/// One physical key press: key code plus the state that affects the produced character.
public struct KeyStroke: Hashable, Sendable {
    public let keyCode: UInt16
    public let shift: Bool
    public let capsLock: Bool

    public init(keyCode: UInt16, shift: Bool, capsLock: Bool = false) {
        self.keyCode = keyCode
        self.shift = shift
        self.capsLock = capsLock
    }
}

public struct ModifierFlags: OptionSet, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let shift = ModifierFlags(rawValue: 1 << 0)
    public static let control = ModifierFlags(rawValue: 1 << 1)
    public static let option = ModifierFlags(rawValue: 1 << 2)
    public static let command = ModifierFlags(rawValue: 1 << 3)
    public static let capsLock = ModifierFlags(rawValue: 1 << 4)
    /// Fn / Globe held.
    public static let function = ModifierFlags(rawValue: 1 << 5)
}

public enum Boundary: Sendable, Equatable {
    case space, enter, tab
}
