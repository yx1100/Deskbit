import AppKit

@main
struct ShortcutProbe {
    @MainActor
    static func main() {
        _ = NSApplication.shared
        let editor = StickyTextView()
        var boldCount = 0
        var bulletCount = 0
        var todoCount = 0
        var linkCount = 0
        var orderedCount = 0
        var italicCount = 0
        var checkedCount = 0
        var indentationDeltas: [Int] = []
        editor.onToggleBold = { boldCount += 1 }
        editor.onToggleBulletList = { bulletCount += 1 }
        editor.onToggleTodo = { todoCount += 1 }
        editor.onEditLink = { linkCount += 1 }
        editor.onToggleOrderedList = { orderedCount += 1 }
        editor.onToggleItalic = { italicCount += 1 }
        editor.onToggleChecked = { checkedCount += 1 }
        editor.onAdjustBulletLevel = { delta in
            indentationDeltas.append(delta)
            return true
        }

        let plainAsterisk = keyEvent(modifiers: [.shift], characters: "*", ignoringModifiers: "*")
        _ = editor.performKeyEquivalent(with: plainAsterisk)
        let markdownAsteriskPassedThrough = bulletCount == 0

        let bold = keyEvent(modifiers: [.command], characters: "b", ignoringModifiers: "b")
        _ = editor.performKeyEquivalent(with: bold)

        // Apple Notes layout: ⇧⌘7 bulleted, ⇧⌘9 numbered, ⇧⌘L checklist, ⇧⌘U mark as checked, ⌘I italic.
        let bullet = keyEvent(modifiers: [.command, .shift], characters: "&", ignoringModifiers: "&")
        _ = editor.performKeyEquivalent(with: bullet)

        let todo = keyEvent(modifiers: [.command, .shift], characters: "L", ignoringModifiers: "L")
        _ = editor.performKeyEquivalent(with: todo)

        let checked = keyEvent(modifiers: [.command, .shift], characters: "U", ignoringModifiers: "U")
        _ = editor.performKeyEquivalent(with: checked)

        let italic = keyEvent(modifiers: [.command], characters: "i", ignoringModifiers: "i")
        _ = editor.performKeyEquivalent(with: italic)

        let oldTodo = keyEvent(modifiers: [.command, .shift], characters: "X", ignoringModifiers: "X")
        _ = editor.performKeyEquivalent(with: oldTodo)

        let link = keyEvent(modifiers: [.command], characters: "k", ignoringModifiers: "k")
        _ = editor.performKeyEquivalent(with: link)

        let ordered = keyEvent(modifiers: [.command, .shift], characters: "(", ignoringModifiers: "(")
        _ = editor.performKeyEquivalent(with: ordered)

        editor.insertTab(nil)
        editor.insertBacktab(nil)

        let editingShortcuts = [
            StickyEditingShortcut.command(for: [.command], key: "c"),
            StickyEditingShortcut.command(for: [.command], key: "x"),
            StickyEditingShortcut.command(for: [.command], key: "v"),
            StickyEditingShortcut.command(for: [.command], key: "a")
        ]

        print("boldShortcut=\(boldCount == 1) bulletShortcut=\(bulletCount == 1) todoShortcut=\(todoCount == 1) linkShortcut=\(linkCount == 1) markdownAsterisk=\(markdownAsteriskPassedThrough) nestingShortcuts=\(indentationDeltas == [1, -1]) editingShortcuts=\(editingShortcuts == [.copy, .cut, .paste, .selectAll])")
        guard boldCount == 1,
              bulletCount == 1,
              todoCount == 1,
              linkCount == 1,
              orderedCount == 1,
              italicCount == 1,
              checkedCount == 1,
              markdownAsteriskPassedThrough,
              indentationDeltas == [1, -1],
              editingShortcuts == [.copy, .cut, .paste, .selectAll] else { exit(1) }
    }

    private static func keyEvent(modifiers: NSEvent.ModifierFlags, characters: String, ignoringModifiers: String) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: ignoringModifiers,
            isARepeat: false,
            keyCode: 0
        )!
    }
}
