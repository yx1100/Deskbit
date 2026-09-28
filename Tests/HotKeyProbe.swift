import AppKit
import Carbon.HIToolbox

@main
struct HotKeyProbe {
    static func main() {
        let defaults = UserDefaults(suiteName: "whatnote-hotkey-probe-\(UUID().uuidString)")!

        let fallback = HotKeyPreferences.newNoteShortcut(in: defaults)
        guard fallback == .defaultNewNote,
              fallback?.keyCode == UInt32(kVK_Space),
              fallback?.modifiers == [.control, .option, .command],
              fallback?.displayString == "⌃⌥⌘空格",
              fallback?.carbonModifiers == UInt32(controlKey | optionKey | cmdKey) else { exit(1) }

        let custom = HotKeyShortcut(keyCode: UInt32(kVK_ANSI_N), modifiers: [.command, .shift, .capsLock])
        guard custom.modifiers == [.command, .shift], custom.displayString == "⇧⌘N" else { exit(2) }
        HotKeyPreferences.setNewNoteShortcut(custom, in: defaults)
        guard HotKeyPreferences.newNoteShortcut(in: defaults) == custom else { exit(3) }

        HotKeyPreferences.setNewNoteShortcut(nil, in: defaults)
        guard HotKeyPreferences.newNoteShortcut(in: defaults) == nil else { exit(4) }

        HotKeyPreferences.setNewNoteShortcut(.defaultNewNote, in: defaults)
        guard defaults.object(forKey: HotKeyPreferences.newNoteKey) == nil,
              HotKeyPreferences.newNoteShortcut(in: defaults) == .defaultNewNote else { exit(5) }

        guard !HotKeyShortcut(keyCode: UInt32(kVK_ANSI_A), modifiers: [.shift]).isValidGlobalShortcut,
              !HotKeyShortcut(keyCode: UInt32(kVK_ANSI_A), modifiers: []).isValidGlobalShortcut,
              HotKeyShortcut(keyCode: UInt32(kVK_ANSI_A), modifiers: [.option]).isValidGlobalShortcut else { exit(6) }

        print("hotkey preferences: pass")
    }
}
