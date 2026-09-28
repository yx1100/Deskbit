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
    static func diameter(for font: NSFont) -> CGFloat {
        min(20, (font.pointSize * 0.85).rounded())
    }

    /// Space the marker takes in the line: the circle plus a small gap before the following space.
    static func markerWidth(for font: NSFont) -> CGFloat {
        diameter(for: font) + 4
    }

    /// Where the checkbox for the marker glyph sits, in text container coordinates.
    static func rect(forGlyphAt glyphIndex: Int, layoutManager: NSLayoutManager) -> NSRect {
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
        let location = layoutManager.location(forGlyphAt: glyphIndex)
        let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        let markerFont = font(at: characterIndex, in: layoutManager.textStorage)
        // Center on the item's text, which follows the marker and its space.
        let textFont = font(at: characterIndex + 2, in: layoutManager.textStorage) ?? markerFont
        let size = diameter(for: markerFont ?? NoteAppearance.bodyFont())
        let baseline = lineRect.minY + location.y
        let centerY = baseline - (textFont ?? NoteAppearance.bodyFont()).pointSize * 0.33
        return NSRect(
            x: lineRect.minX + location.x,
            y: (centerY - size / 2).rounded(),
            width: size,
            height: size
        )
    }

    private static func font(at index: Int, in storage: NSTextStorage?) -> NSFont? {
        guard let storage, index >= 0, index < storage.length else { return nil }
        return storage.attribute(.font, at: index, effectiveRange: nil) as? NSFont
    }

    /// Draws into a flipped view (text views are flipped: y grows downward).
    static func draw(isCompleted: Bool, in rect: NSRect, accent: NSColor) {
        let circle = NSBezierPath(ovalIn: rect.insetBy(dx: 0.75, dy: 0.75))
        guard isCompleted else {
            NoteAppearance.checkboxStrokeColor.setStroke()
            circle.lineWidth = 1.4
            circle.stroke()
            return
        }
        accent.setFill()
        circle.fill()
        let check = NSBezierPath()
        check.move(to: NSPoint(x: rect.minX + rect.width * 0.29, y: rect.minY + rect.height * 0.52))
        check.line(to: NSPoint(x: rect.minX + rect.width * 0.44, y: rect.minY + rect.height * 0.67))
        check.line(to: NSPoint(x: rect.minX + rect.width * 0.72, y: rect.minY + rect.height * 0.35))
        check.lineWidth = max(1.5, rect.width * 0.11)
        check.lineCapStyle = .round
        check.lineJoinStyle = .round
        NSColor.white.setStroke()
        check.stroke()
    }
}

/// Draws to-do markers as round checkboxes in place of the ☐ / ☑ glyphs.
/// The marker glyph is laid out as fixed-width whitespace, so the gap between
/// the circle and the text does not depend on which font happens to draw ☐.
final class NoteLayoutManager: NSLayoutManager, NSLayoutManagerDelegate {
    /// Fill of checked circles; follows the note color.
    var checkboxAccent: NSColor = NoteAppearance.iconColor

    override init() {
        super.init()
        delegate = self
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        delegate = self
    }

    /// Whether a character is a marker depends on its neighbors, so re-layout whole paragraphs.
    override func invalidateGlyphs(
        forCharacterRange charRange: NSRange,
        changeInLength delta: Int,
        actualCharacterRange actualCharRange: NSRangePointer?
    ) {
        guard let string = textStorage?.string as NSString?, charRange.location <= string.length else {
            super.invalidateGlyphs(forCharacterRange: charRange, changeInLength: delta, actualCharacterRange: actualCharRange)
            return
        }
        let length = min(charRange.length, string.length - charRange.location)
        let paragraphs = string.paragraphRange(for: NSRange(location: charRange.location, length: length))
        super.invalidateGlyphs(
            forCharacterRange: NSUnionRange(charRange, paragraphs),
            changeInLength: delta,
            actualCharacterRange: actualCharRange
        )
    }

    func layoutManager(
        _ layoutManager: NSLayoutManager,
        shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>,
        properties props: UnsafePointer<NSLayoutManager.GlyphProperty>,
        characterIndexes charIndexes: UnsafePointer<Int>,
        font aFont: NSFont,
        forGlyphRange glyphRange: NSRange
    ) -> Int {
        guard let storage = layoutManager.textStorage else { return 0 }
        let string = storage.string as NSString
        var properties: [NSLayoutManager.GlyphProperty]?
        for offset in 0..<glyphRange.length
        where TodoMarker.isCompleted(in: string, at: charIndexes[offset]) != nil {
            if properties == nil {
                properties = Array(UnsafeBufferPointer(start: props, count: glyphRange.length))
            }
            properties?[offset] = .controlCharacter
        }
        guard let properties else { return 0 }
        properties.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            layoutManager.setGlyphs(
                glyphs,
                properties: base,
                characterIndexes: charIndexes,
                font: aFont,
                forGlyphRange: glyphRange
            )
        }
        return glyphRange.length
    }

    func layoutManager(
        _ layoutManager: NSLayoutManager,
        shouldUse action: NSLayoutManager.ControlCharacterAction,
        forControlCharacterAt charIndex: Int
    ) -> NSLayoutManager.ControlCharacterAction {
        guard let storage = layoutManager.textStorage,
              TodoMarker.isCompleted(in: storage.string as NSString, at: charIndex) != nil else { return action }
        return .whitespace
    }

    func layoutManager(
        _ layoutManager: NSLayoutManager,
        boundingBoxForControlGlyphAt glyphIndex: Int,
        for textContainer: NSTextContainer,
        proposedLineFragment proposedRect: NSRect,
        glyphPosition: NSPoint,
        characterIndex charIndex: Int
    ) -> NSRect {
        let font = layoutManager.textStorage?.attribute(.font, at: charIndex, effectiveRange: nil) as? NSFont
            ?? NoteAppearance.bodyFont()
        return NSRect(x: glyphPosition.x, y: glyphPosition.y, width: TodoCheckbox.markerWidth(for: font), height: 0)
    }

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
