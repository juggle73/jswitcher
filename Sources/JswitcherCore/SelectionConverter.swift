/// Converts selected text with a fixed key-based table: a character produced by some EN key becomes what
/// that key produces in RU (so "," always becomes "б"); a character only RU produces goes through its RU key.
/// Whitespace and characters outside the table are kept.
public struct SelectionConverter: Sendable {
    public struct Result: Equatable, Sendable {
        public let text: String
        public let switchTo: Lang
    }

    public static let maxLength = 2000
    private let table: [Character: Character]

    public init(layouts: LayoutPair) {
        // Deterministic order: unshifted first, then lowest key code (main block before keypad).
        let strokes = (Set(layouts.en.table.keys).union(layouts.ru.table.keys))
            .sorted { ($0.shift ? 1 : 0, $0.keyCode) < ($1.shift ? 1 : 0, $1.keyCode) }
        var table: [Character: Character] = [:]
        for s in strokes {
            if let e = layouts.en.character(for: s), let r = layouts.ru.character(for: s), table[e] == nil {
                table[e] = r
            }
        }
        for s in strokes {
            if let r = layouts.ru.character(for: s), let e = layouts.en.character(for: s), table[r] == nil {
                table[r] = e
            }
        }
        self.table = table
    }

    /// `nil` for empty or longer than `maxLength` text.
    public func convert(_ text: String, current: Lang) -> Result? {
        guard !text.isEmpty, text.count <= Self.maxLength else { return nil }
        var out = ""
        out.reserveCapacity(text.utf8.count)
        var latin = 0, cyrillic = 0
        for ch in text {
            let c = ch.isWhitespace ? ch : (table[ch] ?? ch)
            out.append(c)
            if let u = c.unicodeScalars.first, c.isLetter {
                if (0x41...0x5A).contains(u.value) || (0x61...0x7A).contains(u.value) { latin += 1 }
                if (0x400...0x4FF).contains(u.value) { cyrillic += 1 }
            }
        }
        let target: Lang = cyrillic > latin ? .ru : latin > cyrillic ? .en : current.other
        return Result(text: out, switchTo: target)
    }
}
