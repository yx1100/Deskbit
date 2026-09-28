import AppKit

enum RichTextCodec {
    /// Plain RTF for text-only notes; RTFD when the note carries images.
    static func encode(_ attributedString: NSAttributedString) -> Data? {
        let range = NSRange(location: 0, length: attributedString.length)
        if containsAttachments(attributedString) {
            return attributedString.rtfd(from: range, documentAttributes: [:])
        }
        return try? attributedString.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }

    static func decode(_ data: Data?) -> NSAttributedString? {
        guard let data else { return nil }
        if !data.starts(with: Array("{\\rtf".utf8)),
           let rtfd = NSAttributedString(rtfd: data, documentAttributes: nil) {
            return rtfd
        }
        return try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
    }

    static func containsAttachments(_ attributedString: NSAttributedString) -> Bool {
        var found = false
        attributedString.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: attributedString.length)
        ) { value, _, stop in
            if value != nil {
                found = true
                stop.pointee = true
            }
        }
        return found
    }
}
