import Foundation

/// Keyboard ways to close a note (the same as the 完成 button). Both are on unless turned off.
enum ClosePreferences {
    static let doubleEscapeKey = "CloseNoteWithDoubleEscape"
    static let commandWKey = "CloseNoteWithCommandW"

    static func closesOnDoubleEscape(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: doubleEscapeKey) as? Bool ?? true
    }

    static func closesOnCommandW(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: commandWKey) as? Bool ?? true
    }
}
