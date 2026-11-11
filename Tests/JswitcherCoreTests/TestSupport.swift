import XCTest
@testable import JswitcherCore

extension KeyMap {
    /// Reverse lookup: which strokes type `text` in this layout.
    func strokes(typing text: String, file: StaticString = #filePath, line: UInt = #line) -> [KeyStroke] {
        var reverse: [Character: KeyStroke] = [:]
        // Deterministic: prefer unshifted, then the lowest key code (main block before keypad).
        for (stroke, ch) in table {
            if let cur = reverse[ch], (cur.shift ? 1 : 0, cur.keyCode) <= (stroke.shift ? 1 : 0, stroke.keyCode) { continue }
            reverse[ch] = stroke
        }
        return text.compactMap { ch in
            guard let s = reverse[ch] else {
                XCTFail("no key for \(ch)", file: file, line: line)
                return nil
            }
            return s
        }
    }
}

enum Fixtures {
    static let abc = SystemLayouts.keyMap(inputSourceID: "com.apple.keylayout.ABC")!
    static let russian = SystemLayouts.keyMap(inputSourceID: "com.apple.keylayout.Russian")!
    static let layouts = LayoutPair(en: abc, ru: russian)
}

func loadDict(_ lang: Lang, top: Bool = false, name: String? = nil) -> WordList {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let url = root.appendingPathComponent("Resources/dict_\(name ?? ((lang == .en ? "en" : "ru") + (top ? "_top" : ""))).bin")
    return try! WordList(contentsOf: url)
}

func loadModel(_ lang: Lang) -> NgramModel {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    return try! NgramModel(contentsOf: root.appendingPathComponent("Resources/ngram_\(lang == .en ? "en" : "ru").bin"))
}
