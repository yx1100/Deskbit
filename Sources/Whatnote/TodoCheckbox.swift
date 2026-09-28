import AppKit

/// To-do items are stored as "☐ " or "☑ " at the start of a paragraph, which keeps
/// the text portable and the Markdown handling simple, and are drawn as round checkboxes.
enum TodoMarker {
    static let pending: unichar = 0x2610
    static let completed: unichar = 0x2611
    static let characters = CharacterSet(charactersIn: "\u{2610}\u{2611}")

    /// nil unless `index` holds a to-do marker at the start of a paragraph;
    /// otherwise whether that item is checked.
    static func isCompleted(in string: NSString, at index: Int) -> Bool? {
        guard index >= 0, index + 1 < string.length, string.character(at: index + 1) == 0x20 else { return nil }
        if index > 0 {
            let previous = string.character(at: index - 1)
            guard previous == 0x0A || previous == 0x0D || previous == 0x2029 else { return nil }
        }
        switch string.character(at: index) {
        case pending: return false
        case completed: return true
        default: return nil
        }
    }
}

enum TodoCheckbox {
    /// Where the checkbox for the marker glyph sits, in text container coordinates.
    static func rect(forGlyphAt glyphIndex: Int, layoutManager: NSLayoutManager) -> NSRect {
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
        let location = layoutManager.location(forGlyphAt: glyphIndex)
        let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        let font = layoutManager.textStorage?.attribute(.font, at: characterIndex, effectiveRange: nil) as? NSFont
            ?? NoteAppearance.bodyFont()
        let diameter = min(18, max(12, font.pointSize + 1))
        let baseline = lineRect.minY + location.y
        let centerY = baseline - font.capHeight / 2
        return NSRect(
            x: lineRect.minX + location.x + 0.5,
            y: centerY - diameter / 2,
            width: diameter,
            height: diameter
        )
    }

    /// Draws into a flipped view (text views are flipped: y grows downward).
    static func draw(isCompleted: Bool, in rect: NSRect, accent: NSColor) {
        let circle = NSBezierPath(ovalIn: rect.insetBy(dx: 0.75, dy: 0.75))
        guard isCompleted else {
            NoteAppearance.checkboxStrokeColor.setStroke()
            circle.lineWidth = 1.3
            circle.stroke()
            return
        }
        accent.setFill()
        circle.fill()
        let check = NSBezierPath()
        check.move(to: NSPoint(x: rect.minX + rect.width * 0.29, y: rect.minY + rect.height * 0.52))
        check.line(to: NSPoint(x: rect.minX + rect.width * 0.44, y: rect.minY + rect.height * 0.67))
        check.line(to: NSPoint(x: rect.minX + rect.width * 0.72, y: rect.minY + rect.height * 0.35))
        check.lineWidth = max(1.4, rect.width * 0.11)
        check.lineCapStyle = .round
        check.lineJoinStyle = .round
        NSColor.white.setStroke()
        check.stroke()
    }
}

/// Draws to-do markers as round checkboxes in place of the ☐ / ☑ glyphs.
final class NoteLayoutManager: NSLayoutManager {
    /// Fill of checked circles; follows the note color.
    var checkboxAccent: NSColor = NoteAppearance.iconColor

    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        guard glyphsToShow.length > 0, let storage = textStorage else {
            super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
            return
        }
        let markers = todoMarkers(in: glyphsToShow, string: storage.string as NSString)
        guard !markers.isEmpty else {
            super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
            return
        }

        var segmentStart = glyphsToShow.location
        for marker in markers {
            if marker.glyph > segmentStart {
                super.drawGlyphs(
                    forGlyphRange: NSRange(location: segmentStart, length: marker.glyph - segmentStart),
                    at: origin
                )
            }
            let box = TodoCheckbox.rect(forGlyphAt: marker.glyph, layoutManager: self)
            TodoCheckbox.draw(
                isCompleted: marker.isCompleted,
                in: box.offsetBy(dx: origin.x, dy: origin.y),
                accent: checkboxAccent
            )
            segmentStart = marker.glyph + 1
        }
        let end = NSMaxRange(glyphsToShow)
        if end > segmentStart {
            super.drawGlyphs(forGlyphRange: NSRange(location: segmentStart, length: end - segmentStart), at: origin)
        }
    }

    private func todoMarkers(in glyphRange: NSRange, string: NSString) -> [(glyph: Int, isCompleted: Bool)] {
        let characters = characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        let searchEnd = NSMaxRange(characters)
        var searchStart = characters.location
        var markers: [(glyph: Int, isCompleted: Bool)] = []
        while searchStart < searchEnd {
            let found = string.rangeOfCharacter(
                from: TodoMarker.characters,
                options: [],
                range: NSRange(location: searchStart, length: searchEnd - searchStart)
            )
            guard found.location != NSNotFound else { break }
            if let isCompleted = TodoMarker.isCompleted(in: string, at: found.location) {
                let glyph = glyphIndexForCharacter(at: found.location)
                if NSLocationInRange(glyph, glyphRange) { markers.append((glyph, isCompleted)) }
            }
            searchStart = NSMaxRange(found)
        }
        return markers
    }
}
