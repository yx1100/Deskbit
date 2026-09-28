import AppKit

@main
struct AppearanceProbe {
    static func main() {
        guard NoteAppearance.defaultSize == NSSize(width: 300, height: 200) else { exit(1) }
        guard NoteAppearance.minimumSize == NSSize(width: 280, height: 160) else { exit(2) }
        guard NoteAppearance.bodyFontSize == 16 else { exit(3) }

        let font = NoteAppearance.bodyFont()
        guard font.pointSize == 16 else { exit(4) }

        // Notes written at the old 13 pt size are enlarged once.
        let legacy = NSMutableAttributedString(string: "旧便签", attributes: [.font: NSFont.systemFont(ofSize: 13)])
        guard NoteAppearance.upgradeLegacyFontSizes(in: legacy),
              (legacy.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize == 16,
              !NoteAppearance.upgradeLegacyFontSizes(in: legacy) else { exit(7) }
        let note = StickyNote.fresh()
        guard note.frame.rect.size == NoteAppearance.defaultSize else { exit(5) }
        let requestedFrame = NSRect(x: 1512, y: 240, width: 300, height: 200)
        guard StickyNote.fresh(frame: requestedFrame).frame.rect == requestedFrame else { exit(6) }
        print("appearance defaults: pass")
    }
}
