/// Decides whether a word typed in layout A was meant for layout B. Dictionaries first, letter trigrams as a fallback.
public struct Detector: Sendable {
    private let layouts: LayoutPair
    private let en: WordList
    private let ru: WordList
    private let enTop: WordList
    private let ruTop: WordList
    private let tech: WordList
    private let enModel: NgramModel?
    private let ruModel: NgramModel?

    /// Trigrams only for words of ≥4 letters, medium threshold (measured: ~87% of unknown words
    /// caught, ~1 in 3000–5000 false conversions of a Russian word).
    static let ngramMinLetters = 4
    static let ngramThreshold = 2.0

    /// Frequent short (1–2 letter) words, converted always — like Punto.
    static let shortRU: Set<String> = [
        "и", "в", "не", "на", "я", "с", "он", "а", "то", "но", "ты", "по", "из", "за", "же", "у", "мы", "да",
        "вы", "бы", "о", "к", "ну", "ли", "уж", "ни", "до", "от", "их", "ее", "её", "ей", "им", "во", "со", "об",
        "ко", "ох", "ах", "эх", "эй", "ой",
    ]
    static let shortEN: Set<String> = [
        "a", "i", "an", "as", "at", "be", "by", "do", "go", "he", "hi", "if", "in", "is", "it", "me", "my",
        "no", "of", "oh", "on", "or", "so", "to", "up", "us", "we", "am",
        "vs", "dj",   // real English words whose other reading is a short Russian word: keep them
        // Frequent two-letter IT terms.
        "ip", "id", "os", "ui", "ux", "db", "vm", "pr", "qa", "ci", "cd", "js", "ts", "pc", "tv", "ai", "ml",
        "hr", "pm", "ok",
    ]

    /// `enTop`/`ruTop` — the most frequent words (top 20 000): a word that is rare in the typed layout
    /// but frequent in the other one is converted even if the dictionary knows it (subtitle noise like "dct").
    /// `tech` — English tech terms from cspell (docx, golang, kubectl…), counted as English words.
    public init(layouts: LayoutPair, en: WordList, ru: WordList,
                enTop: WordList = WordList(words: []), ruTop: WordList = WordList(words: []),
                tech: WordList = WordList(words: []),
                enModel: NgramModel? = nil, ruModel: NgramModel? = nil) {
        self.layouts = layouts
        self.en = en
        self.ru = ru
        self.enTop = enTop
        self.ruTop = ruTop
        self.tech = tech
        self.enModel = enModel
        self.ruModel = ruModel
    }

    public func shouldConvert(_ strokes: [KeyStroke], from a: Lang) -> Bool {
        let b = a.other
        // 1. Both readings must exist.
        guard let wA = layouts.map(a).render(strokes), let wB = layouts.map(b).render(strokes) else { return false }
        // 2. Digits, URLs, e-mails, identifiers in the typed reading.
        if wA.contains(where: \.isNumber) || wA.contains("://") || wA.contains("@") || wA.contains("_") { return false }
        // 3. Target reading must be a plain word of B's alphabet.
        let coreB = Self.trimmed(wB)
        guard Self.isWord(coreB, in: b) else { return false }
        // A letter at the start became a sign that trimming drops ("бешу" → ",tie"): not a real word in B.
        // A sign at the end is fine ("руддщю" → "hello.").
        if wA.first?.isLetter == true, wB.first?.isLetter == false { return false }
        // Letters plus the inner apostrophe of English contractions ("I'm" counts as 3).
        let letters = coreB.filter { $0.isLetter || $0 == "'" }.count
        let coreA = Self.trimmed(wA)
        let nA = WordList.normalize(coreA), nB = WordList.normalize(coreB)
        // 5. Mixed case ("getUser") may be an identifier: convert only to a frequent word that the typed
        //    reading is not ("ыуЕ" → "seT", "ghbDtn" → "приВет").
        if Self.isCamelCase(coreB) { return top(b).contains(nB) && !top(a).contains(nA) }
        // 4. Short words (1–2 letters): only by the lists of frequent short words, in any case ("ШЗ" → "IP").
        if letters < 3 {
            // The same number of letters in both readings: otherwise a letter in A became a sign in B
            // ("ещё" → "to`") and the short B word is an artefact of trimming.
            guard wA.filter(\.isLetter).count == letters else { return false }
            let short = { (l: Lang) in l == .en ? Self.shortEN : Self.shortRU }
            return short(b).contains(WordList.normalize(coreB)) && !short(a).contains(WordList.normalize(coreA))
        }
        // 6. All caps, 3–4 letters: may be an abbreviation ("API", "НДС"). Convert only to a frequent word
        //    and only if the typed reading is not frequent itself ("ЫУЕ" → "SET", "DCT" → "ВСЕ").
        if coreB.count <= 4, !coreB.contains(where: \.isLowercase) {
            return top(b).contains(nB) && !top(a).contains(nA)
        }
        // 7. Already a valid word in A — unless it's rare in A and frequent in B.
        if Self.isWord(coreA, in: a), knows(a, nA), !(top(b).contains(nB) && !top(a).contains(nA)) {
            return false
        }
        // 8. A known word in B.
        if knows(b, nB) { return true }
        // 9. Neither dictionary knows it: letter trigrams decide ("пересобрал"), ≥4 letters only.
        guard letters >= Self.ngramMinLetters, !knows(a, nA),
              let mA = model(a), let mB = model(b) else { return false }
        return mB.score(nB) - mA.score(nA) > Self.ngramThreshold
    }

    private func model(_ lang: Lang) -> NgramModel? { lang == .en ? enModel : ruModel }

    private func knows(_ lang: Lang, _ normalized: String) -> Bool {
        guard lang == .en else { return ru.contains(normalized) }
        if en.contains(normalized) || tech.contains(normalized) { return true }
        return isContraction(normalized)
    }

    /// The source list splits contractions ("don" + "'t"), so "don't" is known if its stem is.
    static let contractionSuffixes = ["'t", "'s", "'m", "'re", "'ll", "'ve", "'d"]
    private func isContraction(_ w: String) -> Bool {
        guard let suffix = Self.contractionSuffixes.first(where: { w.hasSuffix($0) }) else { return false }
        let stem = w.dropLast(suffix.count)
        return !stem.isEmpty && !stem.contains("'") && en.contains(stem)
    }
    private func top(_ lang: Lang) -> WordList { lang == .en ? enTop : ruTop }

    private static func trimmed(_ s: String) -> Substring {
        guard let first = s.firstIndex(where: \.isLetter), let last = s.lastIndex(where: \.isLetter) else { return "" }
        return s[first...last]
    }

    /// Letters of the language's alphabet only; EN also allows an inner apostrophe.
    private static func isWord(_ s: Substring, in lang: Lang) -> Bool {
        guard !s.isEmpty else { return false }
        return s.unicodeScalars.allSatisfy { u in
            switch lang {
            case .en: return (0x61...0x7A).contains(u.value) || (0x41...0x5A).contains(u.value) || u == "'"
            case .ru: return (0x410...0x44F).contains(u.value) || u == "ё" || u == "Ё"
            }
        }
    }

    private static func isCamelCase(_ s: Substring) -> Bool {
        var prevLower = false
        for ch in s {
            if ch.isUppercase, prevLower { return true }
            prevLower = ch.isLowercase
        }
        return false
    }
}
