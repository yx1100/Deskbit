import AppKit

@main
struct ColorProbe {
    static func main() {
        func rgb(_ hex: Int) -> [CGFloat] {
            [CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255]
        }
        let expected: [(NoteColor, String, String, [CGFloat], [CGFloat])] = [
            (.blue, "blue", "蓝色", rgb(0x2A83A2), rgb(0x1B5A70)),
            (.mint, "mint", "绿色", rgb(0x72C6B9), rgb(0x3E8F83)),
            (.yellow, "yellow", "黄色", rgb(0xDCE49B), rgb(0x9AA24E)),
            (.pink, "pink", "粉色", rgb(0xFCCCC6), rgb(0xD2877E))
        ]

        guard NoteColor.allCases == expected.map(\.0) else { exit(1) }
        for (color, rawValue, title, backgroundComponents, accentComponents) in expected {
            guard color.rawValue == rawValue,
                  color.title == title,
                  let background = color.background.usingColorSpace(.sRGB),
                  let accent = color.accent.usingColorSpace(.sRGB) else { exit(2) }
            let actualBackground = [background.redComponent, background.greenComponent, background.blueComponent]
            let actualAccent = [accent.redComponent, accent.greenComponent, accent.blueComponent]
            guard zip(actualBackground, backgroundComponents).allSatisfy({ abs($0 - $1) < 0.0001 }),
                  zip(actualAccent, accentComponents).allSatisfy({ abs($0 - $1) < 0.0001 }) else { exit(3) }
        }

        // Notes saved by earlier versions keep their color.
        let legacy = Data(#"["yellow","blue","mint","pink"]"#.utf8)
        guard (try? JSONDecoder().decode([NoteColor].self, from: legacy)) == [.yellow, .blue, .mint, .pink] else { exit(4) }

        print("note colors: pass")
    }
}
