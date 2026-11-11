// Builds Resources/dict_<lang>.bin from a Hermit Dave FrequencyWords list ("word count" per line).
// Usage: build-dicts <input.txt> <en|ru> <limit> <output.bin> [--ngram]
// With --ngram, writes the letter trigram model trained on the same words instead of the word list.
import Foundation
import JswitcherCore

let args = CommandLine.arguments
let ngram = args.count == 6 && args[5] == "--ngram"
guard args.count == 5 || ngram, let limit = Int(args[3]), args[2] == "en" || args[2] == "ru" else {
    FileHandle.standardError.write(Data("usage: build-dicts <input.txt> <en|ru> <limit> <output.bin> [--ngram]\n".utf8))
    exit(2)
}
let isEN = args[2] == "en"

func isAllowed(_ w: String) -> Bool {
    let scalars = Array(w.unicodeScalars)
    guard !scalars.isEmpty else { return false }
    if !isEN {
        return scalars.allSatisfy { (0x430...0x44F).contains($0.value) }   // а–я
    }
    // ^[a-z]+('[a-z]+)?$
    let isLatin: (Unicode.Scalar) -> Bool = { (0x61...0x7A).contains($0.value) }
    let parts = w.split(separator: "'", omittingEmptySubsequences: false)
    guard parts.count <= 2 else { return false }
    return parts.allSatisfy { !$0.isEmpty && $0.unicodeScalars.allSatisfy(isLatin) }
}

let text = try String(contentsOfFile: args[1], encoding: .utf8)
var seen = Set<String>()
var words: [String] = []
for line in text.split(separator: "\n") where words.count < limit {
    guard let token = line.split(separator: " ").first else { continue }
    let w = WordList.normalize(token)
    guard isAllowed(w), seen.insert(w).inserted else { continue }
    words.append(w)
}
let data = ngram ? try NgramModel.train(words: words, lang: isEN ? .en : .ru).encode() : try WordList.encode(words)
try data.write(to: URL(fileURLWithPath: args[4]))
print(words.count)
