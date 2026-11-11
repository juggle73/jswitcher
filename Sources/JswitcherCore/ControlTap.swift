import Foundation

/// Recognises a lone tap of the LEFT Control key (key code 59).
public struct ControlTapDetector: Sendable {
    private static let leftControl: UInt16 = 59
    private let maxDuration: TimeInterval
    private var pressedAt: TimeInterval?

    public init(maxDuration: TimeInterval = 0.5) {
        self.maxDuration = maxDuration
    }

    /// Returns `true` exactly on the release that completes a valid tap.
    public mutating func flagsChanged(keyCode: UInt16, flags: ModifierFlags, at time: TimeInterval) -> Bool {
        let mods = flags.subtracting(.capsLock)
        let started = pressedAt
        pressedAt = nil
        guard keyCode == Self.leftControl else { return false }
        if mods == [.control] {
            pressedAt = time
            return false
        }
        guard !mods.contains(.control), let start = started else { return false }
        return time - start < maxDuration
    }

    /// Any key press or mouse click cancels a pending tap.
    public mutating func otherEvent() {
        pressedAt = nil
    }
}

/// Recognises a lone Control+Option chord (either side, any order): both held together, then all released,
/// with no other key, click or modifier in between, within `maxDuration`. Toggles pause.
public struct ModifierChordDetector: Sendable {
    private static let chord: ModifierFlags = [.control, .option]
    private let maxDuration: TimeInterval
    private var start: TimeInterval?
    private var armed = false
    private var cancelled = false

    public init(maxDuration: TimeInterval = 1.0) {
        self.maxDuration = maxDuration
    }

    /// Returns `true` exactly when the last modifier of a valid chord is released.
    public mutating func flagsChanged(flags: ModifierFlags, at time: TimeInterval) -> Bool {
        let mods = flags.subtracting(.capsLock)
        if mods.isEmpty {
            defer { start = nil; armed = false; cancelled = false }
            guard let start, armed, !cancelled else { return false }
            return time - start < maxDuration
        }
        if start == nil { start = time }
        if !mods.isSubset(of: Self.chord) { cancelled = true }
        if mods == Self.chord { armed = true }
        return false
    }

    public mutating func otherEvent() {
        if start != nil { cancelled = true }
    }
}
