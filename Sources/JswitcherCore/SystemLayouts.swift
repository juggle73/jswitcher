import Carbon.HIToolbox
import Foundation

public enum SystemLayouts {
    public static let enIDs = ["com.apple.keylayout.ABC", "com.apple.keylayout.US"]
    public static let ruIDs = ["com.apple.keylayout.Russian", "com.apple.keylayout.RussianWin"]

    /// Builds a KeyMap from an installed keyboard layout (enabled or not).
    public static func keyMap(inputSourceID: String) -> KeyMap? {
        let filter = [kTISPropertyInputSourceID as String: inputSourceID] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource],
              let source = list.first,
              let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
        let map = KeyMap.build(fromLayoutData: data)
        return map.table.isEmpty ? nil : map
    }
}
