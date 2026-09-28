import AppKit

enum NoteAppearance {
    static let defaultSize = NSSize(width: 300, height: 200)
    static let minimumSize = NSSize(width: 280, height: 160)
    static let bodyFontSize: CGFloat = 16
    static let cornerRadius: CGFloat = 16

    /// Floating glass controls: the top strip doubles as the drag handle,
    /// and text scrolls underneath both bars.
    static let topBarHeight: CGFloat = 44
    static let bottomBarHeight: CGFloat = 44
    static let capsuleHeight: CGFloat = 30
    static let barMargin: CGFloat = 7

    static let textColor = NSColor.black.withAlphaComponent(0.82)
    static let iconColor = NSColor.black.withAlphaComponent(0.72)
    static let checkboxStrokeColor = NSColor.black.withAlphaComponent(0.45)

    static func bodyFont(weight: NSFont.Weight = .regular) -> NSFont {
        NSFont.systemFont(ofSize: bodyFontSize, weight: weight)
    }

    /// Text size changes from the 13 pt era: body, headings and inline code.
    static let legacyFontSizes: [CGFloat: CGFloat] = [13: 16, 20: 24, 17: 20, 15: 18, 12: 15]

    /// Enlarges text saved with the old sizes. Returns whether anything changed.
    @discardableResult
    static func upgradeLegacyFontSizes(in text: NSMutableAttributedString) -> Bool {
        guard !isUpgraded(text) else { return false }
        var changed = false
        text.enumerateAttribute(.font, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            guard let font = value as? NSFont,
                  let newSize = legacyFontSizes[font.pointSize],
                  let resized = NSFont(descriptor: font.fontDescriptor, size: newSize) else { return }
            text.addAttribute(.font, value: resized, range: range)
            changed = true
        }
        return changed
    }

    /// Text that already uses the new body size must not be enlarged again.
    private static func isUpgraded(_ text: NSAttributedString) -> Bool {
        var upgraded = false
        text.enumerateAttribute(.font, in: NSRange(location: 0, length: text.length)) { value, _, stop in
            if (value as? NSFont)?.pointSize == bodyFontSize {
                upgraded = true
                stop.pointee = true
            }
        }
        return upgraded
    }
}
