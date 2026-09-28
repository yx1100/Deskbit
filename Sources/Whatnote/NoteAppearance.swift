import AppKit

enum NoteAppearance {
    static let defaultSize = NSSize(width: 340, height: 260)
    static let minimumSize = NSSize(width: 300, height: 200)
    static let bodyFontSize: CGFloat = 24
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

    /// Earlier text sizes, keyed by their body size: body, headings and inline code map to today's sizes.
    /// Checked in this order: the 16 pt era also used 18 pt, for third-level headings.
    private static let legacySizes: [(body: CGFloat, sizes: [CGFloat: CGFloat])] = [
        (16, [16: 24, 24: 34, 20: 30, 18: 27, 15: 23]),
        (13, [13: 24, 20: 34, 17: 30, 15: 27, 12: 23]),
        (18, [18: 24, 26: 34, 22: 30, 20: 27, 17: 23])
    ]

    /// Enlarges text saved with an earlier body size. Returns whether anything changed.
    @discardableResult
    static func upgradeLegacyFontSizes(in text: NSMutableAttributedString) -> Bool {
        let whole = NSRange(location: 0, length: text.length)
        var sizes = Set<CGFloat>()
        text.enumerateAttribute(.font, in: whole) { value, _, _ in
            if let font = value as? NSFont { sizes.insert(font.pointSize) }
        }
        guard let era = legacySizes.first(where: { sizes.contains($0.body) }) else { return false }
        text.enumerateAttribute(.font, in: whole) { value, range, _ in
            guard let font = value as? NSFont,
                  let newSize = era.sizes[font.pointSize],
                  let resized = NSFont(descriptor: font.fontDescriptor, size: newSize) else { return }
            text.addAttribute(.font, value: resized, range: range)
        }
        return true
    }
}
