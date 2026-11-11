import Foundation

/// Read-only word set. On disk: LZFSE-compressed UTF-8 text, one word per line,
/// unique and sorted bytewise. In memory: the decompressed bytes plus word start offsets.
public struct WordList: Sendable {
    private let bytes: [UInt8]
    private let starts: [Int32]   // start of each word; word i ends at starts[i+1]-1 (newline)

    public var count: Int { starts.count }

    public init(words: [String]) {
        self.init(sortedText: Self.joinedSorted(words))
    }

    public init(contentsOf url: URL) throws {
        let compressed = try Data(contentsOf: url) as NSData
        let raw = try compressed.decompressed(using: .lzfse) as Data
        self.init(sortedText: [UInt8](raw))
    }

    public static func encode(_ words: [String]) throws -> Data {
        let text = Data(joinedSorted(words)) as NSData
        return try text.compressed(using: .lzfse) as Data
    }

    public static func normalize(_ s: some StringProtocol) -> String {
        s.lowercased().replacingOccurrences(of: "ё", with: "е")
    }

    /// `normalized` must already be passed through `normalize`.
    public func contains(_ normalized: some StringProtocol) -> Bool {
        var key = String(normalized)
        return key.withUTF8 { k in
            var lo = 0, hi = starts.count - 1
            while lo <= hi {
                let mid = (lo + hi) >> 1
                let c = compare(word: mid, with: k)
                if c == 0 { return true }
                if c < 0 { lo = mid + 1 } else { hi = mid - 1 }
            }
            return false
        }
    }

    // MARK: - Private

    private init(sortedText: [UInt8]) {
        var starts: [Int32] = []
        var lineStart = 0
        for (i, b) in sortedText.enumerated() where b == 0x0A {
            if i > lineStart { starts.append(Int32(lineStart)) }
            lineStart = i + 1
        }
        self.bytes = sortedText
        self.starts = starts
    }

    private static func joinedSorted(_ words: [String]) -> [UInt8] {
        let unique = Set(words.map { normalize($0) }.filter { !$0.isEmpty })
        let sorted = unique.map { Array($0.utf8) }.sorted { $0.lexicographicallyPrecedes($1) }
        var out: [UInt8] = []
        for w in sorted {
            out.append(contentsOf: w)
            out.append(0x0A)
        }
        return out
    }

    /// Bytewise comparison of word `i` with `key`: <0, 0, >0.
    private func compare(word i: Int, with key: UnsafeBufferPointer<UInt8>) -> Int {
        var p = Int(starts[i])
        var j = 0
        while true {
            let wb = bytes[p]
            let atWordEnd = wb == 0x0A
            let atKeyEnd = j == key.count
            if atWordEnd || atKeyEnd {
                return atWordEnd && atKeyEnd ? 0 : (atWordEnd ? -1 : 1)
            }
            if wb != key[j] { return wb < key[j] ? -1 : 1 }
            p += 1
            j += 1
        }
    }
}
