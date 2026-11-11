import Foundation

/// Letter trigram model of one language. `score` is the average natural log-probability per trigram
/// of "^^word$"; higher means "looks more like this language". Used only for words neither dictionary knows.
/// On disk: LZFSE-compressed [lang byte][Int16 log-prob × 1000, little-endian] × size³.
public struct NgramModel: Sendable {
    public let lang: Lang
    private let logp: [Int16]
    private let index: [Character: Int]
    private let size: Int

    private static let scale = 1000.0
    private static let start = 0, end = 1, other = 2

    private static func letters(_ lang: Lang) -> [Character] {
        Array(lang == .en ? "abcdefghijklmnopqrstuvwxyz'" : "абвгдежзийклмнопрстуфхцчшщъыьэюя")
    }

    private init(lang: Lang, logp: [Int16]) {
        self.lang = lang
        self.logp = logp
        let letters = Self.letters(lang)
        self.size = letters.count + 3
        self.index = Dictionary(uniqueKeysWithValues: letters.enumerated().map { ($1, $0 + 3) })
    }

    /// Trains on dictionary words (each word counted once), add-0.01 smoothing.
    public static func train(words: [String], lang: Lang) -> NgramModel {
        let empty = NgramModel(lang: lang, logp: [])
        let n = empty.size
        var tri = [Double](repeating: 0, count: n * n * n)
        var ctx = [Double](repeating: 0, count: n * n)
        for w in words {
            let s = empty.symbols(WordList.normalize(w))
            for i in 0..<(s.count - 2) {
                tri[(s[i] * n + s[i + 1]) * n + s[i + 2]] += 1
                ctx[s[i] * n + s[i + 1]] += 1
            }
        }
        let logp = tri.indices.map { i -> Int16 in
            let p = (tri[i] + 0.01) / (ctx[i / n] + 0.01 * Double(n))
            return Int16((log(p) * scale).rounded())
        }
        return NgramModel(lang: lang, logp: logp)
    }

    public init(contentsOf url: URL) throws {
        let raw = try (Data(contentsOf: url) as NSData).decompressed(using: .lzfse) as Data
        guard let first = raw.first, first <= 1 else { throw CocoaError(.fileReadCorruptFile) }
        let lang: Lang = first == 0 ? .en : .ru
        let body = raw.dropFirst()
        let n = Self.letters(lang).count + 3
        guard body.count == n * n * n * 2 else { throw CocoaError(.fileReadCorruptFile) }
        let bytes = [UInt8](body)
        let logp = stride(from: 0, to: bytes.count, by: 2).map { Int16(bitPattern: UInt16(bytes[$0]) | UInt16(bytes[$0 + 1]) << 8) }
        self.init(lang: lang, logp: logp)
    }

    public func encode() throws -> Data {
        var out = Data([lang == .en ? 0 : 1])
        for v in logp {
            let u = UInt16(bitPattern: v)
            out.append(UInt8(u & 0xFF))
            out.append(UInt8(u >> 8))
        }
        return try (out as NSData).compressed(using: .lzfse) as Data
    }

    /// `word` is normalized here; characters outside the alphabet count as one rare "other" symbol.
    public func score(_ word: some StringProtocol) -> Double {
        let s = symbols(WordList.normalize(word))
        var total = 0
        for i in 0..<(s.count - 2) {
            total += Int(logp[(s[i] * size + s[i + 1]) * size + s[i + 2]])
        }
        return Double(total) / Self.scale / Double(s.count - 2)
    }

    private func symbols(_ w: String) -> [Int] {
        [Self.start, Self.start] + w.map { index[$0] ?? Self.other } + [Self.end]
    }
}
