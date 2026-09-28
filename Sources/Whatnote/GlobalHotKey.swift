import AppKit
import Carbon.HIToolbox

struct HotKeyShortcut: Equatable {
    static let supportedModifiers: NSEvent.ModifierFlags = [.control, .option, .shift, .command]
    static let defaultNewNote = HotKeyShortcut(keyCode: UInt32(kVK_Space), modifiers: [.control, .option, .command])

    var keyCode: UInt32
    var modifiers: NSEvent.ModifierFlags

    init(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(Self.supportedModifiers)
    }

    /// A global shortcut needs ⌘, ⌥ or ⌃ so it never swallows ordinary typing.
    var isValidGlobalShortcut: Bool {
        !modifiers.intersection([.control, .option, .command]).isEmpty
    }

    var carbonModifiers: UInt32 {
        var result: UInt32 = 0
        if modifiers.contains(.command) { result |= UInt32(cmdKey) }
        if modifiers.contains(.option) { result |= UInt32(optionKey) }
        if modifiers.contains(.control) { result |= UInt32(controlKey) }
        if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    var displayString: String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        return result + Self.keyName(for: keyCode)
    }

    static func keyName(for keyCode: UInt32) -> String {
        if let name = keyNames[Int(keyCode)] { return name }
        return "键码 \(keyCode)"
    }

    private static let keyNames: [Int: String] = [
        kVK_Space: "空格", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Escape: "⎋",
        kVK_Delete: "⌫", kVK_ForwardDelete: "⌦", kVK_LeftArrow: "←", kVK_RightArrow: "→",
        kVK_UpArrow: "↑", kVK_DownArrow: "↓", kVK_Home: "↖", kVK_End: "↘",
        kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D", kVK_ANSI_E: "E",
        kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H", kVK_ANSI_I: "I", kVK_ANSI_J: "J",
        kVK_ANSI_K: "K", kVK_ANSI_L: "L", kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O",
        kVK_ANSI_P: "P", kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
        kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X", kVK_ANSI_Y: "Y",
        kVK_ANSI_Z: "Z",
        kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3", kVK_ANSI_4: "4",
        kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7", kVK_ANSI_8: "8", kVK_ANSI_9: "9",
        kVK_ANSI_Minus: "-", kVK_ANSI_Equal: "=", kVK_ANSI_LeftBracket: "[", kVK_ANSI_RightBracket: "]",
        kVK_ANSI_Backslash: "\\", kVK_ANSI_Semicolon: ";", kVK_ANSI_Quote: "'", kVK_ANSI_Comma: ",",
        kVK_ANSI_Period: ".", kVK_ANSI_Slash: "/", kVK_ANSI_Grave: "`"
    ]
}

enum HotKeyPreferences {
    static let newNoteKey = "NewNoteHotKey"

    /// Missing preference means the default shortcut; an empty dictionary means the user cleared it.
    static func newNoteShortcut(in defaults: UserDefaults = .standard) -> HotKeyShortcut? {
        guard let stored = defaults.dictionary(forKey: newNoteKey) else { return .defaultNewNote }
        guard let keyCode = stored["keyCode"] as? Int,
              let modifiers = stored["modifiers"] as? Int else { return nil }
        return HotKeyShortcut(
            keyCode: UInt32(keyCode),
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(modifiers))
        )
    }

    static func setNewNoteShortcut(_ shortcut: HotKeyShortcut?, in defaults: UserDefaults = .standard) {
        if shortcut == .defaultNewNote {
            defaults.removeObject(forKey: newNoteKey)
        } else if let shortcut {
            defaults.set(
                ["keyCode": Int(shortcut.keyCode), "modifiers": Int(shortcut.modifiers.rawValue)],
                forKey: newNoteKey
            )
        } else {
            defaults.set([String: Int](), forKey: newNoteKey)
        }
    }
}

private let hotKeySignature: OSType = 0x444B_4254 // "DKBT"

/// System-wide shortcut backed by Carbon hot keys, which work without Accessibility permission.
@MainActor
final class GlobalHotKey {
    private static var actions: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var isHandlerInstalled = false

    private let id: UInt32
    private var hotKeyRef: EventHotKeyRef?
    private(set) var shortcut: HotKeyShortcut?

    init(action: @escaping () -> Void) {
        id = Self.nextID
        Self.nextID += 1
        Self.actions[id] = action
    }

    /// Replaces the current registration. Returns false when macOS refuses the shortcut.
    @discardableResult
    func register(_ shortcut: HotKeyShortcut?) -> Bool {
        unregister()
        guard let shortcut else { return true }
        Self.installHandlerIfNeeded()
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            EventHotKeyID(signature: hotKeySignature, id: id),
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard status == noErr, let reference else { return false }
        hotKeyRef = reference
        self.shortcut = shortcut
        return true
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
        shortcut = nil
    }

    private static func installHandlerIfNeeded() {
        guard !isHandlerInstalled else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            handleHotKeyEvent,
            1,
            &eventType,
            nil,
            nil
        )
        isHandlerInstalled = status == noErr
    }

    fileprivate static func dispatch(id: UInt32) {
        actions[id]?()
    }
}

/// Carbon event callback; a plain function so it can be passed as a C function pointer.
private func handleHotKeyEvent(
    _ handler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr, hotKeyID.signature == hotKeySignature else {
        return OSStatus(eventNotHandledErr)
    }
    let id = hotKeyID.id
    // Carbon delivers application-target events on the main thread.
    MainActor.assumeIsolated { GlobalHotKey.dispatch(id: id) }
    return noErr
}
