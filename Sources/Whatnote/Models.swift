import AppKit

/// Note colors. Raw values match earlier versions so saved notes keep their color:
/// the former pink notes become red and the former mint notes become green.
enum NoteColor: String, Codable, CaseIterable {
    case red = "pink"
    case green = "mint"
    case blue
    case yellow

    /// The note paper, also the fill of the color dot.
    var background: NSColor {
        switch self {
        case .red: return Self.srgb(0xFF8077)
        case .green: return Self.srgb(0x8AE63E)
        case .blue: return Self.srgb(0x78B7FF)
        case .yellow: return Self.srgb(0xF1D546)
        }
    }

    /// Deeper shade for the dot's ring, checked to-do circles and active buttons.
    var accent: NSColor {
        switch self {
        case .red: return Self.srgb(0xB74A42)
        case .green: return Self.srgb(0x52A210)
        case .blue: return Self.srgb(0x4379B7)
        case .yellow: return Self.srgb(0xAB9318)
        }
    }

    var title: String {
        switch self {
        case .red: return "红色"
        case .green: return "绿色"
        case .blue: return "蓝色"
        case .yellow: return "黄色"
        }
    }

    private static func srgb(_ hex: Int) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

struct WindowFrame: Codable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(_ frame: NSRect) {
        x = frame.origin.x
        y = frame.origin.y
        width = frame.size.width
        height = frame.size.height
    }

    var rect: NSRect { NSRect(x: x, y: y, width: width, height: height) }
}

struct StickyNote: Codable, Identifiable {
    var id: UUID
    var text: String
    var richTextData: Data?
    var color: NoteColor
    var frame: WindowFrame
    var isPinned: Bool
    var isHidden: Bool
    var reminderDate: Date?
    var completedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    static func fresh(index: Int = 0, frame: NSRect? = nil) -> StickyNote {
        let size = NoteAppearance.defaultSize
        let initialFrame: NSRect
        if let frame {
            initialFrame = frame
        } else {
            let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let offset = CGFloat((index % 6) * 26)
            let origin = NSPoint(
                x: screen.midX - size.width / 2 + offset,
                y: screen.midY - size.height / 2 - offset
            )
            initialFrame = NSRect(origin: origin, size: size)
        }
        return StickyNote(
            id: UUID(),
            text: "",
            richTextData: nil,
            color: NoteColor.allCases[index % NoteColor.allCases.count],
            frame: WindowFrame(initialFrame),
            isPinned: false,
            isHidden: false,
            reminderDate: nil,
            completedAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
