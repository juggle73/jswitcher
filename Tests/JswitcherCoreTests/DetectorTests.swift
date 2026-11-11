import XCTest
@testable import JswitcherCore

final class DetectorTests: XCTestCase {
    static let detector = Detector(layouts: Fixtures.layouts, en: loadDict(.en), ru: loadDict(.ru),
                                   enTop: loadDict(.en, top: true), ruTop: loadDict(.ru, top: true),
                                   tech: loadDict(.en, name: "tech"),
                                   enModel: loadModel(.en), ruModel: loadModel(.ru))

    func decide(_ text: String, typedIn lang: Lang, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let strokes = Fixtures.layouts.map(lang).strokes(typing: text, file: file, line: line)
        return Self.detector.shouldConvert(strokes, from: lang)
    }

    func testConverts() {
        let cases: [(String, Lang)] = [
            ("ghbdtn", .en), ("Ghbdtn", .en), ("ntcn", .en), ("lj,hsq", .en),
            ("руддщ", .ru), ("цщкдв", .ru),
        ]
        for (text, lang) in cases {
            XCTAssertTrue(decide(text, typedIn: lang), "should convert: \(text)")
        }
    }

    func testLeavesAlone() {
        let cases: [(String, Lang)] = [
            ("и", .ru), ("в", .ru), ("a", .en), ("I", .en), ("ok", .en), ("ок", .ru),
            ("git", .en), ("npm", .en), ("ls", .en), ("cd", .en), ("API", .en), ("НДС", .ru),
            ("hello", .en), ("привет", .ru), ("ghbdtn2", .en), ("user_name", .en),
            ("user@mail.ru", .en), ("github.com/ntcn", .en), ("https://ntcn", .en),
            ("/usr/local", .en), ("go", .en), ("is", .en), ("x", .en),
            ("vs", .en), ("dj", .en), ("ещё", .ru), ("шею", .ru), ("бин", .ru),
        ]
        for (text, lang) in cases {
            XCTAssertFalse(decide(text, typedIn: lang), "should leave: \(text)")
        }
    }

    /// A rare word in the typed layout loses to a frequent word in the other one ("dct" is subtitle noise).
    func testFrequentWordBeatsRareNoise() {
        for (text, lang) in [("dct", Lang.en), ("nfr", .en), ("gjrf", .en), ("Dct", .en), ("xfce", .en)] {
            XCTAssertTrue(decide(text, typedIn: lang), "should convert: \(text)")
        }
    }

    /// short words always by a list of frequent short words, like Punto.
    func testShortWordsByList() {
        let cases: [(String, Lang)] = [
            ("b", .en), ("d", .en), ("f", .en), ("B", .en), ("jy", .en), ("yt", .en), ("yf", .en), ("Jy", .en),
            ("шы", .ru), ("ше", .ru), ("ещ", .ru), ("шт", .ru),
        ]
        for (text, lang) in cases {
            XCTAssertTrue(decide(text, typedIn: lang), "should convert: \(text)")
        }
    }

    /// frequent two-letter IT terms, also in capitals ("ШЗ" → "IP").
    func testItTermsIncludingCapitals() {
        for (text, lang) in [("шз", Lang.ru), ("ШЗ", .ru), ("Шз", .ru), ("шв", .ru), ("щы", .ru), ("ви", .ru), ("ЗК", .ru), ("щл", .ru), ("ЩЛ", .ru), ("Щл", .ru)] {
            XCTAssertTrue(decide(text, typedIn: lang), "should convert: \(text)")
        }
        for (text, lang) in [("ip", Lang.en), ("IP", .en), ("ID", .en), ("OK", .en), ("API", .en), ("НДС", .ru), ("ИП", .ru)] {
            XCTAssertFalse(decide(text, typedIn: lang), "should leave: \(text)")
        }
    }

    /// tech words from the cspell dictionaries (docx, golang, kubectl…) typed in the RU layout.
    func testTechWordsTypedInRussianLayout() {
        for word in ["docx", "xlsx", "json", "yaml", "golang", "kubectl", "github", "nginx", "docker", "webhook", "Docx"] {
            let strokes = Fixtures.layouts.map(.en).strokes(typing: word)
            XCTAssertTrue(Self.detector.shouldConvert(strokes, from: Lang.ru), "should convert: \(word)")
        }
        for (text, lang) in [("docx", Lang.en), ("kubectl", .en), ("DOCX", .en)] {
            XCTAssertFalse(decide(text, typedIn: lang), "should leave: \(text)")
        }
    }

    /// words unknown to both dictionaries are decided by letter trigrams (≥4 letters, medium threshold).
    func testUnknownWordsByTrigrams() {
        for word in ["пересобрал", "пересобрала", "пересоздал", "перезапустил", "задеплоил", "закоммитил", "Пересобрал"] {
            let strokes = Fixtures.layouts.map(.ru).strokes(typing: word)
            XCTAssertTrue(Self.detector.shouldConvert(strokes, from: Lang.en), "should convert: \(word)")
        }
        for (text, lang) in [("stdout", Lang.en), ("struct", .en), ("async", .en), ("enum", .en), ("webpack", .en),
                             ("localhost", .en), ("xcodebuild", .en), ("nvim", .en), ("argv", .en), ("asdf", .en),
                             ("zshrc", .en), ("israelyan", .en), ("пересобрал", .ru), ("задеплоил", .ru)] {
            XCTAssertFalse(decide(text, typedIn: lang), "should leave: \(text)")
        }
    }

    /// a letter at the start of the typed word must not turn into a sign that gets trimmed
    /// ("бешу" → ",tie" → "tie"); a sign at the end is fine ("руддщю" → "hello.").
    func testLeadingSignBlocksConversion() {
        for (text, lang) in [("бешу", Lang.ru), ("хертл", .ru), ("жусь", .ru), ("бере", .ru)] {
            XCTAssertFalse(decide(text, typedIn: lang), "should leave: \(text)")
        }
        for word in ["hello.", "hello,", "thanks."] {
            XCTAssertTrue(Self.detector.shouldConvert(Fixtures.layouts.map(.en).strokes(typing: word), from: Lang.ru), "should convert: \(word)")
        }
    }

    /// English contractions: the source list splits them ("don" + "'t"), so they are recognised by parts.
    func testContractions() {
        for word in ["don't", "Don't", "it's", "can't", "isn't", "we're", "I'm", "I'll", "you've", "he'd"] {
            XCTAssertTrue(Self.detector.shouldConvert(Fixtures.layouts.map(.en).strokes(typing: word), from: Lang.ru), "should convert: \(word)")
        }
        for (text, lang) in [("don't", Lang.en), ("I'm", .en), ("it's", .en)] {
            XCTAssertFalse(decide(text, typedIn: lang), "should leave: \(text)")
        }
    }

    /// 3–4 capitals convert only to a frequent (top-20k) word, and only if the typed reading
    /// is not frequent ("ЫУЕ" → "SET"); known abbreviations stay ("API", "НДС", "ЦРУ", "МВД").
    func testCapsToFrequentWord() {
        for word in ["SET", "THE", "AND", "HOW", "THAT"] {
            XCTAssertTrue(Self.detector.shouldConvert(Fixtures.layouts.map(.en).strokes(typing: word), from: Lang.ru), "should convert: \(word)")
        }
        for word in ["ВСЕ", "КАК", "ЧТО"] {
            XCTAssertTrue(Self.detector.shouldConvert(Fixtures.layouts.map(.ru).strokes(typing: word), from: Lang.en), "should convert: \(word)")
        }
        for (text, lang) in [("API", Lang.en), ("НДС", .ru), ("ЦРУ", .ru), ("МВД", .ru), ("ООО", .ru), ("JSON", .en), ("HTML", .en), ("CEO", .en)] {
            XCTAssertFalse(decide(text, typedIn: lang), "should leave: \(text)")
        }
    }

    /// mixed case converts only to a frequent (top-20k) word ("ыуЕ" → "seT", "ghbDtn" → "приВет");
    /// identifiers stay ("getUser", "myVar", "iPhone", "macOS").
    func testMixedCaseToFrequentWord() {
        for word in ["seT", "sET", "heLLo"] {
            XCTAssertTrue(Self.detector.shouldConvert(Fixtures.layouts.map(.en).strokes(typing: word), from: Lang.ru), "should convert: \(word)")
        }
        XCTAssertTrue(decide("ghbDtn", typedIn: .en), "should convert: ghbDtn")
        for (text, lang) in [("getUser", Lang.en), ("myVar", .en), ("iPhone", .en), ("macOS", .en), ("onClick", .en)] {
            XCTAssertFalse(decide(text, typedIn: lang), "should leave: \(text)")
        }
    }
}
