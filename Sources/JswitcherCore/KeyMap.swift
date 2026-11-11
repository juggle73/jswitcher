import Carbon.HIToolbox
import Foundation

/// Characters a keyboard layout produces for key codes 0…127 without and with Shift.
public struct KeyMap: Sendable, Equatable {
    /// Keys are always `capsLock == false`.
    public let table: [KeyStroke: Character]

    public init(table: [KeyStroke: Character]) {
        self.table = table
    }

    public func character(for stroke: KeyStroke) -> Character? {
        guard let ch = table[KeyStroke(keyCode: stroke.keyCode, shift: stroke.shift)] else { return nil }
        guard stroke.capsLock, ch.isLetter else { return ch }
        let flipped = ch.isUppercase ? ch.lowercased() : ch.uppercased()
        return flipped.count == 1 ? Character(flipped) : ch
    }

    /// `nil` if any stroke produces no character in this layout.
    public func render(_ strokes: [KeyStroke]) -> String? {
        var out = ""
        out.reserveCapacity(strokes.count)
        for s in strokes {
            guard let ch = character(for: s) else { return nil }
            out.append(ch)
        }
        return out
    }

    /// Builds the table from `kTISPropertyUnicodeKeyLayoutData` (a `UCKeyboardLayout`).
    public static func build(fromLayoutData data: Data) -> KeyMap {
        var table: [KeyStroke: Character] = [:]
        let kbdType = UInt32(LMGetKbdType())
        data.withUnsafeBytes { raw in
            guard let layout = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return }
            for code in UInt16(0)...127 {
                for shift in [false, true] {
                    let modState: UInt32 = shift ? UInt32(shiftKey >> 8) & 0xFF : 0
                    var deadKeys: UInt32 = 0
                    var length = 0
                    var chars = [UniChar](repeating: 0, count: 4)
                    let status = UCKeyTranslate(
                        layout, code, UInt16(kUCKeyActionDown), modState, kbdType,
                        OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKeys, chars.count, &length, &chars)
                    guard status == noErr, length > 0 else { continue }
                    let s = String(utf16CodeUnits: chars, count: length)
                    guard s.count == 1, let ch = s.first,
                          let first = ch.unicodeScalars.first,
                          first.value >= 0x21, first.value != 0x7F else { continue }
                    table[KeyStroke(keyCode: code, shift: shift)] = ch
                }
            }
        }
        return KeyMap(table: table)
    }
}

public struct LayoutPair: Sendable {
    public let en: KeyMap
    public let ru: KeyMap

    public init(en: KeyMap, ru: KeyMap) {
        self.en = en
        self.ru = ru
    }

    public func map(_ lang: Lang) -> KeyMap { lang == .en ? en : ru }
}
