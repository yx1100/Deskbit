import AppKit

@main
struct MediaProbe {
    @MainActor
    static func main() {
        _ = NSApplication.shared

        let image = NSImage(size: NSSize(width: 600, height: 300))
        image.lockFocus()
        NSColor.systemRed.setFill()
        NSRect(x: 0, y: 0, width: 600, height: 300).fill()
        image.unlockFocus()

        guard let attachment = NoteImages.attachmentString(for: image) else { exit(1) }
        let note = NSMutableAttributedString(string: "图片：", attributes: [.font: NoteAppearance.bodyFont()])
        note.append(attachment)
        guard RichTextCodec.containsAttachments(note),
              let data = RichTextCodec.encode(note),
              !data.starts(with: Array("{\\rtf".utf8)),
              let restored = RichTextCodec.decode(data),
              RichTextCodec.containsAttachments(restored),
              restored.string.hasPrefix("图片：") else { exit(2) }

        let storage = NSTextStorage(attributedString: restored)
        NoteImages.fitAttachments(in: storage)
        var cellWidth: CGFloat = 0
        storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { value, _, _ in
            if let cell = (value as? NSTextAttachment)?.attachmentCell { cellWidth = cell.cellSize().width }
        }
        guard cellWidth > 0, cellWidth <= NoteImages.maxDisplayWidth else { exit(3) }

        let plain = NSAttributedString(string: "纯文本")
        guard let plainData = RichTextCodec.encode(plain),
              plainData.starts(with: Array("{\\rtf".utf8)),
              RichTextCodec.decode(plainData)?.string == "纯文本" else { exit(4) }

        guard NoteLinks.url(from: "https://example.com/a?b=1")?.absoluteString == "https://example.com/a?b=1",
              NoteLinks.url(from: "example.com")?.absoluteString == "https://example.com",
              NoteLinks.url(from: "mailto:me@example.com") != nil,
              NoteLinks.url(from: "不是网址") == nil,
              NoteLinks.url(from: "two words.com") == nil else { exit(5) }

        let pasteboard = NSPasteboard(name: NSPasteboard.Name("whatnote-media-probe-\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        guard NoteImages.images(on: pasteboard).count == 1 else { exit(6) }
        pasteboard.clearContents()
        pasteboard.writeObjects([image, "说明文字" as NSString])
        guard NoteImages.images(on: pasteboard).isEmpty else { exit(7) }
        pasteboard.releaseGlobally()

        print("media: pass")
    }
}
