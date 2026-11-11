import Foundation

/// Apps (exact bundle IDs, edited by the user) where words are never auto-corrected.
/// A left Control tap still converts there.
public struct ExclusionList: Equatable, Sendable {
    public private(set) var bundleIDs: [String]

    /// First launch: only Terminal.
    public static let `default` = ExclusionList(bundleIDs: ["com.apple.Terminal"])

    private init(bundleIDs: [String]) {
        self.bundleIDs = bundleIDs
    }

    /// From the persisted form; `nil` (never saved) gives the default list.
    public init(stored: [String]?) {
        guard let stored else {
            self = .default
            return
        }
        var ids: [String] = []
        for raw in stored {
            let id = raw.trimmingCharacters(in: .whitespaces)
            if !id.isEmpty, !ids.contains(id) { ids.append(id) }
        }
        bundleIDs = ids
    }

    public var stored: [String] { bundleIDs }

    public func contains(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return bundleIDs.contains(bundleID)
    }

    @discardableResult
    public mutating func add(_ bundleID: String) -> Bool {
        guard !bundleID.isEmpty, !bundleIDs.contains(bundleID) else { return false }
        bundleIDs.append(bundleID)
        return true
    }

    public mutating func remove(_ bundleID: String) {
        bundleIDs.removeAll { $0 == bundleID }
    }
}
