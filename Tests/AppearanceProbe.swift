import AppKit

@main
struct AppearanceProbe {
    static func main() {
        guard NoteAppearance.defaultSize == NSSize(width: 340, height: 260) else { exit(1) }
        guard NoteAppearance.minimumSize == NSSize(width: 300, height: 200) else { exit(2) }
        guard NoteAppearance.bodyFontSize == 16 else { exit(3) }

        let font = NoteAppearance.bodyFont()
        guard font.pointSize == 16 else { exit(4) }

        // Notes written at the old 13, 16 and 24 pt sizes are converted once.
        for (body, heading, newHeading) in [(CGFloat(13), CGFloat(20), CGFloat(22)), (16, 24, 22), (24, 30, 19), (18, 26, 22)] {
            let legacy = NSMutableAttributedString(string: "标题", attributes: [.font: NSFont.systemFont(ofSize: heading)])
            legacy.append(NSAttributedString(string: "旧便签", attributes: [.font: NSFont.systemFont(ofSize: body)]))
            guard NoteAppearance.upgradeLegacyFontSizes(in: legacy),
                  (legacy.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize == newHeading,
                  (legacy.attribute(.font, at: 2, effectiveRange: nil) as? NSFont)?.pointSize == 16,
                  !NoteAppearance.upgradeLegacyFontSizes(in: legacy) else { exit(7) }
        }
        // Text already at today's sizes is left alone.
        let current = NSMutableAttributedString(string: "标题", attributes: [.font: NSFont.systemFont(ofSize: 22)])
        current.append(NSAttributedString(string: "正文", attributes: [.font: NoteAppearance.bodyFont()]))
        guard !NoteAppearance.upgradeLegacyFontSizes(in: current) else { exit(8) }
        let note = StickyNote.fresh()
        guard note.frame.rect.size == NoteAppearance.defaultSize else { exit(5) }
        let requestedFrame = NSRect(x: 1512, y: 240, width: 300, height: 200)
        guard StickyNote.fresh(frame: requestedFrame).frame.rect == requestedFrame else { exit(6) }
        print("appearance defaults: pass")
    }
}
