import AppKit
import UniformTypeIdentifiers

/// Image attachments inside notes. Images are downscaled before they are stored
/// (notes persist as RTFD inside notes.json) and displayed at a size that fits the note.
@MainActor
enum NoteImages {
    static let maxStoredPixelSize: CGFloat = 1600
    static let maxDisplayWidth: CGFloat = 240
    static let maxDisplayHeight: CGFloat = 320
    static let imageFileExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "heic", "heif", "tif", "tiff", "bmp", "webp"]

    /// Image file URLs on the pasteboard, e.g. files copied or dragged from Finder.
    static func imageFileURLs(on pasteboard: NSPasteboard) -> [URL] {
        let urls = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []
        return urls.filter { imageFileExtensions.contains($0.pathExtension.lowercased()) }
    }

    /// Images the pasteboard carries. Text wins over image data so that copying
    /// from apps that also put a rendered picture of the text (Word, Pages) still pastes text.
    static func images(on pasteboard: NSPasteboard) -> [NSImage] {
        let fileImages = imageFileURLs(on: pasteboard).compactMap(NSImage.init(contentsOf:))
        if !fileImages.isEmpty { return fileImages }
        if pasteboard.availableType(from: [.string]) != nil { return [] }
        if pasteboard.availableType(from: [.fileURL]) != nil { return [] }
        return pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage] ?? []
    }

    @discardableResult
    static func insert(_ images: [NSImage], into textView: NSTextView, replacing range: NSRange? = nil) -> Bool {
        guard let storage = textView.textStorage else { return false }
        var attributes: [NSAttributedString.Key: Any] = [:]
        attributes[.font] = textView.typingAttributes[.font] ?? NoteAppearance.bodyFont()
        attributes[.paragraphStyle] = textView.typingAttributes[.paragraphStyle]

        let insertion = NSMutableAttributedString()
        for image in images {
            if let attachment = attachmentString(for: image, attributes: attributes) {
                insertion.append(attachment)
            }
        }
        guard insertion.length > 0 else { return false }

        let target = range ?? textView.selectedRange()
        let safeTarget = NSRange(
            location: min(target.location, storage.length),
            length: min(target.length, max(0, storage.length - min(target.location, storage.length)))
        )
        guard textView.shouldChangeText(in: safeTarget, replacementString: insertion.string) else { return false }
        storage.replaceCharacters(in: safeTarget, with: insertion)
        textView.setSelectedRange(NSRange(location: safeTarget.location + insertion.length, length: 0))
        textView.didChangeText()
        return true
    }

    static func chooseImages(into textView: NSTextView) {
        let panel = NSOpenPanel()
        panel.title = "插入图片"
        panel.prompt = "插入"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return }
        let images = panel.urls.compactMap(NSImage.init(contentsOf:))
        textView.window?.makeKeyAndOrderFront(nil)
        textView.window?.makeFirstResponder(textView)
        insert(images, into: textView)
    }

    static func attachmentString(
        for image: NSImage,
        attributes: [NSAttributedString.Key: Any] = [:]
    ) -> NSAttributedString? {
        guard let stored = storedData(for: image) else { return nil }
        let wrapper = FileWrapper(regularFileWithContents: stored.data)
        wrapper.preferredFilename = "image-\(UUID().uuidString).\(stored.fileExtension)"
        let attachment = NSTextAttachment(fileWrapper: wrapper)
        fitDisplay(of: attachment)
        let result = NSMutableAttributedString(attachment: attachment)
        result.addAttributes(attributes, range: NSRange(location: 0, length: result.length))
        return result
    }

    /// Restored RTFD attachments draw at full size; shrink them to fit the note.
    static func fitAttachments(in storage: NSTextStorage) {
        storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { value, _, _ in
            guard let attachment = value as? NSTextAttachment else { return }
            fitDisplay(of: attachment)
        }
    }

    static func fitDisplay(of attachment: NSTextAttachment) {
        guard let data = attachment.fileWrapper?.regularFileContents,
              let image = NSImage(data: data),
              image.size.width > 0,
              image.size.height > 0 else { return }
        let factor = min(1, maxDisplayWidth / image.size.width, maxDisplayHeight / image.size.height)
        let displayImage = image.copy() as? NSImage ?? image
        displayImage.size = NSSize(
            width: max(1, floor(image.size.width * factor)),
            height: max(1, floor(image.size.height * factor))
        )
        attachment.attachmentCell = NSTextAttachmentCell(imageCell: displayImage)
    }

    private static func storedData(for image: NSImage) -> (data: Data, fileExtension: String)? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              cgImage.width > 0,
              cgImage.height > 0 else { return nil }
        let pixelWidth = CGFloat(cgImage.width)
        let pixelHeight = CGFloat(cgImage.height)
        let scale = min(1, maxStoredPixelSize / max(pixelWidth, pixelHeight))
        let targetWidth = max(1, Int((pixelWidth * scale).rounded()))
        let targetHeight = max(1, Int((pixelHeight * scale).rounded()))

        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: targetWidth,
            pixelsHigh: targetHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        // Keep the point size so Retina screenshots are not shown at double size.
        let pointsPerPixel = image.size.width > 0 ? image.size.width / pixelWidth : 1
        representation.size = NSSize(
            width: CGFloat(targetWidth) * pointsPerPixel,
            height: CGFloat(targetHeight) * pointsPerPixel
        )

        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: representation) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        context.cgContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        NSGraphicsContext.restoreGraphicsState()

        if let png = representation.representation(using: .png, properties: [:]), png.count <= 1_500_000 {
            return (png, "png")
        }
        if let jpeg = representation.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) {
            return (jpeg, "jpg")
        }
        return nil
    }
}

@MainActor
enum NoteLinks {
    /// Accepts full URLs and bare domains such as "example.com".
    static func url(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace) else { return nil }
        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           ["http", "https", "mailto", "file", "ftp"].contains(scheme) {
            return url
        }
        if trimmed.contains("."), !trimmed.hasPrefix("."), !trimmed.hasSuffix("."),
           let url = URL(string: "https://\(trimmed)"), url.host != nil {
            return url
        }
        return nil
    }

    /// ⌘K: link the selection, edit the link under the cursor, or insert a new link.
    static func editLink(in textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        var target = textView.selectedRange()
        var existingURL: URL?
        if storage.length > 0 {
            let probe = min(target.location, storage.length - 1)
            var linkRange = NSRange(location: NSNotFound, length: 0)
            let value = storage.attribute(
                .link,
                at: probe,
                longestEffectiveRange: &linkRange,
                in: NSRange(location: 0, length: storage.length)
            )
            existingURL = value as? URL ?? (value as? String).flatMap { URL(string: $0) }
            if existingURL != nil, target.length == 0 { target = linkRange }
        }

        let selectedText = (storage.string as NSString).substring(with: target)
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.placeholderString = "https://"
        field.stringValue = existingURL?.absoluteString ?? (url(from: selectedText) != nil ? selectedText : "")

        let alert = NSAlert()
        alert.messageText = existingURL == nil ? "插入链接" : "编辑链接"
        alert.informativeText = target.length > 0 ? "为选中的文字添加链接。" : "链接地址会作为文字插入到光标处。"
        alert.accessoryView = field
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")
        if existingURL != nil { alert.addButton(withTitle: "移除链接") }
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        textView.window?.makeKeyAndOrderFront(nil)
        textView.window?.makeFirstResponder(textView)

        switch response {
        case .alertFirstButtonReturn:
            guard let url = url(from: field.stringValue) else {
                NSSound.beep()
                return
            }
            if target.length > 0 {
                guard textView.shouldChangeText(in: target, replacementString: nil) else { return }
                storage.addAttribute(.link, value: url, range: target)
                textView.didChangeText()
                textView.setSelectedRange(NSRange(location: NSMaxRange(target), length: 0))
            } else {
                var attributes = textView.typingAttributes
                attributes[.link] = url
                let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard textView.shouldChangeText(in: target, replacementString: text) else { return }
                storage.replaceCharacters(in: target, with: NSAttributedString(string: text, attributes: attributes))
                textView.didChangeText()
                textView.setSelectedRange(NSRange(location: target.location + (text as NSString).length, length: 0))
            }
            textView.typingAttributes.removeValue(forKey: .link)
        case .alertThirdButtonReturn:
            guard target.length > 0, textView.shouldChangeText(in: target, replacementString: nil) else { return }
            storage.removeAttribute(.link, range: target)
            textView.didChangeText()
        default:
            break
        }
    }
}
