import Foundation

public enum EngineInput: Sendable {
    case character(KeyStroke), boundary(Boundary), backspace, controlTap, reset
}

public struct TypedKey: Equatable, Sendable {
    public let stroke: KeyStroke
    public let character: Character

    public init(stroke: KeyStroke, character: Character) {
        self.stroke = stroke
        self.character = character
    }
}

public struct Replacement: Equatable, Sendable {
    /// Characters to erase with Backspace (word length, +1 when the trailing space is retyped).
    public let deleteCount: Int
    public let keys: [TypedKey]
    public let switchTo: Lang
    /// Boundary to (re)send after the word; `nil` — none.
    public let trailingBoundary: Boundary?
}

public enum EngineAction: Equatable, Sendable {
    case pass, replace(Replacement), switchLayout(to: Lang)
}

/// Holds key strokes of the current word and of one previous word — nothing else — and decides what to do.
public final class Engine {
    private let layouts: LayoutPair
    private let detector: Detector
    private let maxWordLength: Int
    private let idleTimeout: TimeInterval

    private var current: [KeyStroke] = []
    private var overflow = false
    /// The current word was converted with Control: the user chose its layout, auto-correct must not undo it.
    private var manuallyConverted = false
    private var previous: (strokes: [KeyStroke], boundary: Boundary)?
    private var lastLang: Lang?
    private var lastTime: TimeInterval?

    public init(layouts: LayoutPair, detector: Detector, maxWordLength: Int = 48, idleTimeout: TimeInterval = 10) {
        self.layouts = layouts
        self.detector = detector
        self.maxWordLength = maxWordLength
        self.idleTimeout = idleTimeout
    }

    /// `autoCorrect: false` — excluded app: words are still buffered for Control, but never auto-corrected.
    public func handle(_ input: EngineInput, current lang: Lang, now: TimeInterval, autoCorrect: Bool = true) -> EngineAction {
        if let t = lastTime, now - t > idleTimeout { resetAll() }
        if lastLang != lang { resetAll() }
        lastTime = now
        lastLang = lang

        switch input {
        case let .character(stroke):
            if current.count >= maxWordLength { overflow = true } else { current.append(stroke) }
            return .pass

        case .backspace:
            if current.isEmpty { previous = nil } else { current.removeLast() }
            return .pass

        case let .boundary(b):
            defer { current = []; manuallyConverted = false }
            if overflow || current.isEmpty {
                previous = nil
                overflow = false
                return .pass
            }
            previous = (current, b)
            guard autoCorrect, !manuallyConverted, detector.shouldConvert(current, from: lang),
                  let r = replacement(current, to: lang.other, extraDelete: 0, boundary: b) else { return .pass }
            lastLang = lang.other
            return .replace(r)

        case .controlTap:
            var action: EngineAction = .switchLayout(to: lang.other)
            if !current.isEmpty {
                if !overflow, let r = replacement(current, to: lang.other, extraDelete: 0, boundary: nil) {
                    action = .replace(r)
                    manuallyConverted = true
                }
            } else if let p = previous, p.boundary == .space,
                      let r = replacement(p.strokes, to: lang.other, extraDelete: 1, boundary: .space) {
                action = .replace(r)
            }
            lastLang = lang.other
            return action

        case .reset:
            resetAll()
            return .pass
        }
    }

    private func replacement(_ strokes: [KeyStroke], to lang: Lang, extraDelete: Int, boundary: Boundary?) -> Replacement? {
        let map = layouts.map(lang)
        var keys: [TypedKey] = []
        keys.reserveCapacity(strokes.count)
        for s in strokes {
            guard let ch = map.character(for: s) else { return nil }
            keys.append(TypedKey(stroke: s, character: ch))
        }
        return Replacement(deleteCount: strokes.count + extraDelete, keys: keys, switchTo: lang, trailingBoundary: boundary)
    }

    private func resetAll() {
        current = []
        overflow = false
        manuallyConverted = false
        previous = nil
    }
}
