import AppKit

@MainActor
enum RichTextFormatting {
    enum TodoState: Equatable {
        case plain
        case pending
        case completed
    }

    private static let listIndentStep: CGFloat = 18
    private static let maximumListLevel = 8
    private static let bulletMarkers = ["•", "∘", "▪"]
    private static let legacyBulletMarkers = ["◦", "○"]
    private static let pendingTodoMarker = "☐"
    private static let completedTodoMarker = "☑"

    static func toggleBold(in textView: NSTextView) {
        let storage = textView.textStorage ?? NSTextStorage()
        let selected = textView.selectedRange()
        let currentFont = font(in: textView)
        let shouldBold = !NSFontManager.shared.traits(of: currentFont).contains(.boldFontMask)

        if selected.length > 0 {
            storage.beginEditing()
            storage.enumerateAttribute(.font, in: selected) { value, range, _ in
                let source = (value as? NSFont) ?? NoteAppearance.bodyFont()
                let converted = shouldBold
                    ? NSFontManager.shared.convert(source, toHaveTrait: .boldFontMask)
                    : NSFontManager.shared.convert(source, toNotHaveTrait: .boldFontMask)
                storage.addAttribute(.font, value: converted, range: range)
            }
            storage.endEditing()
        } else {
            var typing = textView.typingAttributes
            typing[.font] = shouldBold
                ? NSFontManager.shared.convert(currentFont, toHaveTrait: .boldFontMask)
                : NSFontManager.shared.convert(currentFont, toNotHaveTrait: .boldFontMask)
            textView.typingAttributes = typing
        }
    }

    static func toggleTodo(in textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        let selected = textView.selectedRange()
        let starts = paragraphStarts(in: storage.string, selection: selected)
        var newLocation = selected.location
        var newLength = selected.length

        storage.beginEditing()
        for start in starts.reversed() {
            switch todoState(in: storage.string, at: start) {
            case .plain:
                if hasBullet(in: storage.string, at: start) {
                    storage.replaceCharacters(in: NSRange(location: start, length: 1), with: pendingTodoMarker)
                    applyListIndent(false, storage: storage, location: start)
                } else {
                    storage.replaceCharacters(in: NSRange(location: start, length: 0), with: "\(pendingTodoMarker) ")
                    adjustSelection(location: &newLocation, length: &newLength, changeAt: start, delta: 2)
                }
                applyTodoCompletion(false, storage: storage, paragraphStart: start)
            case .pending:
                storage.replaceCharacters(in: NSRange(location: start, length: 1), with: completedTodoMarker)
                applyTodoCompletion(true, storage: storage, paragraphStart: start)
            case .completed:
                storage.replaceCharacters(in: NSRange(location: start, length: 2), with: "")
                adjustSelection(location: &newLocation, length: &newLength, changeAt: start, delta: -2)
                applyTodoCompletion(false, storage: storage, paragraphStart: min(start, storage.length))
            }
        }
        storage.endEditing()

        let selection = NSRange(
            location: min(newLocation, storage.length),
            length: min(newLength, max(0, storage.length - newLocation))
        )
        textView.setSelectedRange(selection)
        setTypingListIndent(false, textView: textView)
        setTypingTodoCompletion(todoState(in: textView) == .completed, textView: textView)
    }

    /// Checks or unchecks the to-do item whose marker is at `start`; used by clicks on the checkbox.
    /// Unlike `toggleTodo`, it never turns the line back into plain text.
    @discardableResult
    static func toggleTodoCompletion(atParagraphStart start: Int, in textView: NSTextView) -> Bool {
        guard let storage = textView.textStorage else { return false }
        let state = todoState(in: storage.string, at: start)
        guard state != .plain else { return false }
        let paragraph = (storage.string as NSString).paragraphRange(for: NSRange(location: start, length: 0))
        // Registering the whole paragraph lets undo restore both the marker and the strikethrough.
        guard textView.shouldChangeText(in: paragraph, replacementString: nil) else { return false }
        let completed = state == .pending
        storage.beginEditing()
        storage.replaceCharacters(
            in: NSRange(location: start, length: 1),
            with: completed ? completedTodoMarker : pendingTodoMarker
        )
        applyTodoCompletion(completed, storage: storage, paragraphStart: start)
        storage.endEditing()
        textView.didChangeText()
        return true
    }

    static func toggleBulletList(in textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        let selected = textView.selectedRange()
        let starts = paragraphStarts(in: storage.string, selection: selected)
        let allBulleted = !starts.isEmpty && starts.allSatisfy { hasBullet(in: storage.string, at: $0) }
        var newLocation = selected.location
        var newLength = selected.length

        storage.beginEditing()
        for start in starts.reversed() {
            if allBulleted, hasBullet(in: storage.string, at: start) {
                storage.replaceCharacters(in: NSRange(location: start, length: 2), with: "")
                adjustSelection(location: &newLocation, length: &newLength, changeAt: start, delta: -2)
                applyListIndent(false, storage: storage, location: min(start, storage.length))
            } else if !allBulleted, !hasBullet(in: storage.string, at: start) {
                if todoState(in: storage.string, at: start) == .plain {
                    storage.replaceCharacters(in: NSRange(location: start, length: 0), with: "• ")
                    adjustSelection(location: &newLocation, length: &newLength, changeAt: start, delta: 2)
                } else {
                    storage.replaceCharacters(in: NSRange(location: start, length: 1), with: "•")
                    applyTodoCompletion(false, storage: storage, paragraphStart: start)
                }
                applyListIndent(true, storage: storage, location: start)
            }
        }
        storage.endEditing()
        setTypingListIndent(!allBulleted, textView: textView)
        if !allBulleted { setTypingTodoCompletion(false, textView: textView) }
        textView.setSelectedRange(NSRange(location: min(newLocation, storage.length), length: min(newLength, max(0, storage.length - newLocation))))
    }

    @discardableResult
    static func adjustBulletLevel(in textView: NSTextView, delta: Int) -> Bool {
        guard delta == -1 || delta == 1, let storage = textView.textStorage else { return false }
        let originalSelection = textView.selectedRange()
        let starts = paragraphStarts(in: storage.string, selection: originalSelection)
            .filter { hasBullet(in: storage.string, at: $0) }
        guard !starts.isEmpty else { return false }

        var changed = false
        storage.beginEditing()
        for start in starts {
            guard start < storage.length else { continue }
            let paragraphRange = (storage.string as NSString).paragraphRange(for: NSRange(location: start, length: 0))
            let existing = storage.attribute(.paragraphStyle, at: start, effectiveRange: nil) as? NSParagraphStyle
            let style = existing?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            let currentLevel = max(0, Int(round(style.firstLineHeadIndent / listIndentStep)))
            let requestedLevel = min(maximumListLevel, max(0, currentLevel + delta))
            let newLevel: Int
            if delta > 0 {
                let parentLimit = previousBulletLevel(before: start, storage: storage).map { $0 + 1 } ?? 0
                newLevel = min(requestedLevel, parentLimit)
            } else {
                newLevel = requestedLevel
            }
            guard newLevel != currentLevel else { continue }
            storage.replaceCharacters(
                in: NSRange(location: start, length: 1),
                with: bulletMarker(for: newLevel)
            )
            style.firstLineHeadIndent = CGFloat(newLevel) * listIndentStep
            style.headIndent = CGFloat(newLevel + 1) * listIndentStep
            storage.addAttribute(.paragraphStyle, value: style, range: paragraphRange)
            changed = true
        }
        storage.endEditing()

        if changed {
            let selection = NSRange(
                location: min(originalSelection.location, storage.length),
                length: min(originalSelection.length, max(0, storage.length - originalSelection.location))
            )
            textView.setSelectedRange(selection)
            let location = storage.length == 0 ? 0 : min(selection.location, storage.length - 1)
            let style = storage.length == 0 ? nil : storage.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle
            setTypingListLevel(max(0, Int(round((style?.firstLineHeadIndent ?? 0) / listIndentStep))), textView: textView)
        }
        return changed
    }

    /// Backspace right after a to-do or list marker removes the whole marker, turning
    /// the line into plain text. Deleting only the space would leave a bare "☐" glyph.
    static func handleMarkerBackspace(in textView: NSTextView) -> Bool {
        guard let storage = textView.textStorage else { return false }
        let selection = textView.selectedRange()
        guard selection.length == 0, selection.location >= 2 else { return false }
        let start = selection.location - 2
        let nsString = storage.string as NSString
        guard nsString.paragraphRange(for: NSRange(location: start, length: 0)).location == start,
              todoState(in: storage.string, at: start) != .plain || hasBullet(in: storage.string, at: start) else {
            return false
        }
        let markerRange = NSRange(location: start, length: 2)
        guard textView.shouldChangeText(in: markerRange, replacementString: "") else { return false }
        storage.beginEditing()
        storage.replaceCharacters(in: markerRange, with: "")
        applyTodoCompletion(false, storage: storage, paragraphStart: start)
        applyListIndent(false, storage: storage, location: start)
        storage.endEditing()
        textView.setSelectedRange(NSRange(location: start, length: 0))
        setTypingListIndent(false, textView: textView)
        setTypingTodoCompletion(false, textView: textView)
        textView.didChangeText()
        return true
    }

    /// Repairs to-do markers that lost the space after them, which older versions allowed.
    @discardableResult
    static func normalizeTodoMarkers(in textView: NSTextView) -> Bool {
        guard let storage = textView.textStorage, storage.length > 0 else { return false }
        let starts = paragraphStarts(in: storage.string, selection: NSRange(location: 0, length: storage.length))
        var changed = false
        storage.beginEditing()
        for start in starts.reversed() where start < storage.length {
            let nsString = storage.string as NSString
            let marker = nsString.substring(with: NSRange(location: start, length: 1))
            guard marker == pendingTodoMarker || marker == completedTodoMarker,
                  todoState(in: storage.string, at: start) == .plain else { continue }
            let attributes = storage.attributes(at: start, effectiveRange: nil)
            storage.insert(NSAttributedString(string: " ", attributes: attributes), at: start + 1)
            changed = true
        }
        storage.endEditing()
        return changed
    }

    @discardableResult
    static func normalizeBulletMarkers(in textView: NSTextView) -> Bool {
        guard let storage = textView.textStorage, storage.length > 0 else { return false }
        let starts = paragraphStarts(
            in: storage.string,
            selection: NSRange(location: 0, length: storage.length)
        ).filter { hasBullet(in: storage.string, at: $0) }
        var changed = false
        storage.beginEditing()
        for start in starts {
            let style = storage.attribute(.paragraphStyle, at: start, effectiveRange: nil) as? NSParagraphStyle
            let level = max(0, Int(round((style?.firstLineHeadIndent ?? 0) / listIndentStep)))
            let expected = bulletMarker(for: level)
            guard bulletMarker(in: storage.string, at: start) != expected else { continue }
            storage.replaceCharacters(in: NSRange(location: start, length: 1), with: expected)
            changed = true
        }
        storage.endEditing()
        return changed
    }

    private static func previousBulletLevel(before start: Int, storage: NSTextStorage) -> Int? {
        guard start > 0, storage.length > 0 else { return nil }
        let previousRange = (storage.string as NSString).paragraphRange(for: NSRange(location: start - 1, length: 0))
        guard hasBullet(in: storage.string, at: previousRange.location) else { return nil }
        let style = storage.attribute(.paragraphStyle, at: previousRange.location, effectiveRange: nil) as? NSParagraphStyle
        return max(0, Int(round((style?.firstLineHeadIndent ?? 0) / listIndentStep)))
    }

    static func isBold(in textView: NSTextView) -> Bool {
        NSFontManager.shared.traits(of: font(in: textView)).contains(.boldFontMask)
    }

    static func todoState(in textView: NSTextView) -> TodoState {
        guard let storage = textView.textStorage else { return .plain }
        let start = paragraphStarts(in: storage.string, selection: textView.selectedRange()).first ?? 0
        return todoState(in: storage.string, at: start)
    }

    static func isBulletList(in textView: NSTextView) -> Bool {
        guard let storage = textView.textStorage else { return false }
        return paragraphStarts(in: storage.string, selection: textView.selectedRange()).first.map {
            hasBullet(in: storage.string, at: $0)
        } ?? false
    }

    private static let headingSizes: [CGFloat] = [34, 30, 27]
    private static let codeBackground = NSColor.black.withAlphaComponent(0.07)

    static func headingFont(level: Int) -> NSFont {
        let clamped = min(max(level, 1), headingSizes.count)
        return NSFont.systemFont(ofSize: headingSizes[clamped - 1], weight: clamped == 3 ? .semibold : .bold)
    }

    static func headingLevel(of font: NSFont?) -> Int? {
        guard let font else { return nil }
        return headingSizes.firstIndex(where: { abs($0 - font.pointSize) < 0.5 }).map { $0 + 1 }
    }

    static func codeFont() -> NSFont {
        NSFont.monospacedSystemFont(ofSize: NoteAppearance.bodyFontSize - 1, weight: .regular)
    }

    /// Converts Markdown syntax into rich text as it is typed or pasted:
    /// `# 标题`, `**粗体**`, `*斜体*`, `~~删除线~~`, `` `代码` ``, `[文字](网址)`, `- 列表`, `- [ ] 待办`.
    @discardableResult
    static func applyMarkdownSyntax(in textView: NSTextView) -> Bool {
        guard let storage = textView.textStorage, !textView.hasMarkedText() else { return false }
        var selection = textView.selectedRange()
        let originalTypingAttributes = textView.typingAttributes
        var headingTypingFont: NSFont?
        var changed = false

        func matches(_ pattern: String) -> [NSTextCheckingResult] {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
            return expression.matches(in: storage.string, range: NSRange(location: 0, length: storage.length))
        }

        func replace(_ range: NSRange, with replacement: NSAttributedString) {
            storage.replaceCharacters(in: range, with: replacement)
            selection = adjustedSelection(selection, replacing: range, newLength: replacement.length)
            changed = true
        }

        func inner(_ match: NSTextCheckingResult, group: Int = 1) -> NSMutableAttributedString {
            NSMutableAttributedString(attributedString: storage.attributedSubstring(from: match.range(at: group)))
        }

        func convertFonts(in value: NSMutableAttributedString, _ transform: @escaping (NSFont) -> NSFont) {
            value.enumerateAttribute(.font, in: NSRange(location: 0, length: value.length)) { font, range, _ in
                value.addAttribute(.font, value: transform((font as? NSFont) ?? NoteAppearance.bodyFont()), range: range)
            }
        }

        // [文字](网址) — image syntax `![...](...)` is left alone.
        for match in matches(#"(?<!!)\[([^\]\n]+)\]\(([^)\s]+)\)"#).reversed() {
            let address = (storage.string as NSString).substring(with: match.range(at: 2))
            guard let url = NoteLinks.url(from: address) else { continue }
            let replacement = inner(match)
            replacement.addAttribute(.link, value: url, range: NSRange(location: 0, length: replacement.length))
            replace(match.range, with: replacement)
        }

        // `代码`
        for match in matches(#"`([^`\n]+)`"#).reversed() {
            let replacement = inner(match)
            let whole = NSRange(location: 0, length: replacement.length)
            replacement.addAttribute(.font, value: codeFont(), range: whole)
            replacement.addAttribute(.backgroundColor, value: codeBackground, range: whole)
            replace(match.range, with: replacement)
        }

        // **粗体**
        for match in matches(#"\*\*([^*\n]+)\*\*"#).reversed() {
            let replacement = inner(match)
            convertFonts(in: replacement) { NSFontManager.shared.convert($0, toHaveTrait: .boldFontMask) }
            replace(match.range, with: replacement)
        }

        // *斜体* — not inside words like 2*3*4, and never a list marker.
        for match in matches(#"(?<![*A-Za-z0-9\\])\*(?![\s*])([^*\n]*?[^\s*])\*(?![*A-Za-z0-9])"#).reversed() {
            let replacement = inner(match)
            convertFonts(in: replacement) { NSFontManager.shared.convert($0, toHaveTrait: .italicFontMask) }
            replace(match.range, with: replacement)
        }

        // ~~删除线~~
        for match in matches(#"~~([^~\n]+)~~"#).reversed() {
            let replacement = inner(match)
            replacement.addAttribute(
                .strikethroughStyle,
                value: NSUnderlineStyle.single.rawValue,
                range: NSRange(location: 0, length: replacement.length)
            )
            replace(match.range, with: replacement)
        }

        // # 标题 / ## 标题 / ### 标题
        for match in matches(#"(?m)^(#{1,3}) "#).reversed() {
            let font = headingFont(level: match.range(at: 1).length)
            let start = match.range.location
            replace(match.range, with: NSAttributedString())
            let paragraph = start < storage.length
                ? (storage.string as NSString).paragraphRange(for: NSRange(location: start, length: 0))
                : NSRange(location: start, length: 0)
            if paragraph.length > 0 {
                storage.addAttribute(.font, value: font, range: paragraph)
            }
            var contentEnd = NSMaxRange(paragraph)
            if contentEnd > paragraph.location,
               (storage.string as NSString).substring(with: NSRange(location: contentEnd - 1, length: 1)) == "\n" {
                contentEnd -= 1
            }
            if selection.location >= paragraph.location, selection.location <= contentEnd {
                headingTypingFont = font
            }
        }

        // - [ ] 待办 / - [x] 已完成 (also after "- " has already become "• ")
        for match in matches(#"(?m)^[*\-•] \[( |x|X)\] "#).reversed() {
            let start = match.range.location
            let isDone = (storage.string as NSString).substring(with: match.range(at: 1)) != " "
            var attributes = storage.attributes(at: start, effectiveRange: nil)
            attributes.removeValue(forKey: .strikethroughStyle)
            replace(match.range, with: NSAttributedString(
                string: "\(isDone ? completedTodoMarker : pendingTodoMarker) ",
                attributes: attributes
            ))
            applyListIndent(false, storage: storage, location: start)
            applyTodoCompletion(isDone, storage: storage, paragraphStart: start)
        }

        // - 列表 / * 列表
        for match in matches(#"(?m)^[*-] "#).reversed() {
            storage.replaceCharacters(in: match.range, with: "• ")
            applyListIndent(true, storage: storage, location: match.range.location)
            changed = true
        }

        if changed {
            textView.setSelectedRange(NSRange(location: min(selection.location, storage.length), length: min(selection.length, max(0, storage.length - selection.location))))
            textView.typingAttributes = originalTypingAttributes
            setTypingListIndent(isBulletList(in: textView), textView: textView)
            if let headingTypingFont {
                var typing = textView.typingAttributes
                typing[.font] = headingTypingFont
                textView.typingAttributes = typing
            }
        }
        return changed
    }

    static func handleStructuredNewline(in textView: NSTextView) -> Bool {
        guard let storage = textView.textStorage else { return false }
        let selection = textView.selectedRange()
        guard selection.length == 0, selection.location <= storage.length else { return false }
        let nsString = storage.string as NSString
        let lookup = storage.length == 0 ? 0 : min(selection.location, storage.length - 1)
        let paragraph = storage.length == 0
            ? NSRange(location: 0, length: 0)
            : nsString.paragraphRange(for: NSRange(location: lookup, length: 0))

        let taskState = todoState(in: storage.string, at: paragraph.location)
        if taskState != .plain {
            let marker = taskState == .pending ? pendingTodoMarker : completedTodoMarker
            let content = nsString.substring(with: paragraph).trimmingCharacters(in: .whitespacesAndNewlines)
            setTypingTodoCompletion(false, textView: textView)
            if content == marker {
                storage.replaceCharacters(in: NSRange(location: paragraph.location, length: 2), with: "")
                textView.setSelectedRange(NSRange(location: paragraph.location, length: 0))
                textView.didChangeText()
            } else {
                let insertion = NSAttributedString(
                    string: "\n\(pendingTodoMarker) ",
                    attributes: textView.typingAttributes
                )
                storage.beginEditing()
                storage.replaceCharacters(in: selection, with: insertion)
                applyTodoCompletion(false, storage: storage, paragraphStart: selection.location + 1)
                storage.endEditing()
                textView.setSelectedRange(NSRange(location: selection.location + insertion.length, length: 0))
                textView.didChangeText()
            }
            return true
        }

        guard let marker = bulletMarker(in: storage.string, at: paragraph.location) else {
            return endHeadingOnNewline(in: textView, selection: selection)
        }

        let content = nsString.substring(with: paragraph).trimmingCharacters(in: .whitespacesAndNewlines)
        if content == marker {
            storage.replaceCharacters(in: NSRange(location: paragraph.location, length: 2), with: "")
            setTypingListIndent(false, textView: textView)
            textView.setSelectedRange(NSRange(location: paragraph.location, length: 0))
            textView.didChangeText()
        } else {
            textView.insertText("\n\(marker) ", replacementRange: selection)
        }
        return true
    }

    /// Return at the end of a heading starts a normal body paragraph.
    private static func endHeadingOnNewline(in textView: NSTextView, selection: NSRange) -> Bool {
        guard headingLevel(of: textView.typingAttributes[.font] as? NSFont) != nil else { return false }
        textView.insertText("\n", replacementRange: selection)
        var typing = textView.typingAttributes
        typing[.font] = NoteAppearance.bodyFont()
        textView.typingAttributes = typing
        return true
    }

    private static func font(in textView: NSTextView) -> NSFont {
        let selected = textView.selectedRange()
        if selected.length == 0 {
            return (textView.typingAttributes[.font] as? NSFont) ?? NoteAppearance.bodyFont()
        }
        if let storage = textView.textStorage, storage.length > 0 {
            let location = min(selected.location, storage.length - 1)
            return (storage.attribute(.font, at: location, effectiveRange: nil) as? NSFont) ?? NoteAppearance.bodyFont()
        }
        return NoteAppearance.bodyFont()
    }

    private static func paragraphStarts(in string: String, selection: NSRange) -> [Int] {
        let nsString = string as NSString
        if nsString.length == 0 { return [0] }
        if selection.length == 0, selection.location == nsString.length, string.hasSuffix("\n") { return [nsString.length] }

        let safeLocation = min(selection.location, nsString.length - 1)
        let safeLength = min(selection.length, nsString.length - safeLocation)
        let encompassing = nsString.paragraphRange(for: NSRange(location: safeLocation, length: safeLength))
        var starts: [Int] = []
        var cursor = encompassing.location
        while cursor < NSMaxRange(encompassing), cursor < nsString.length {
            starts.append(cursor)
            let paragraph = nsString.paragraphRange(for: NSRange(location: cursor, length: 0))
            let next = NSMaxRange(paragraph)
            if next <= cursor { break }
            cursor = next
        }
        return starts
    }

    private static func hasBullet(in string: String, at location: Int) -> Bool {
        bulletMarker(in: string, at: location) != nil
    }

    private static func todoState(in string: String, at location: Int) -> TodoState {
        let nsString = string as NSString
        guard location + 2 <= nsString.length,
              nsString.substring(with: NSRange(location: location + 1, length: 1)) == " " else { return .plain }
        switch nsString.substring(with: NSRange(location: location, length: 1)) {
        case pendingTodoMarker: return .pending
        case completedTodoMarker: return .completed
        default: return .plain
        }
    }

    private static func applyTodoCompletion(_ completed: Bool, storage: NSTextStorage, paragraphStart: Int) {
        guard storage.length > 0, paragraphStart < storage.length else { return }
        let nsString = storage.string as NSString
        let paragraph = nsString.paragraphRange(for: NSRange(location: paragraphStart, length: 0))
        storage.removeAttribute(.strikethroughStyle, range: paragraph)
        guard completed else { return }

        let contentStart = min(paragraphStart + 2, NSMaxRange(paragraph))
        var contentEnd = NSMaxRange(paragraph)
        if contentEnd > contentStart,
           nsString.substring(with: NSRange(location: contentEnd - 1, length: 1)) == "\n" {
            contentEnd -= 1
        }
        guard contentEnd > contentStart else { return }
        storage.addAttribute(
            .strikethroughStyle,
            value: NSUnderlineStyle.single.rawValue,
            range: NSRange(location: contentStart, length: contentEnd - contentStart)
        )
    }

    private static func setTypingTodoCompletion(_ completed: Bool, textView: NSTextView) {
        var typing = textView.typingAttributes
        if completed {
            typing[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        } else {
            typing.removeValue(forKey: .strikethroughStyle)
        }
        textView.typingAttributes = typing
    }

    private static func bulletMarker(in string: String, at location: Int) -> String? {
        let nsString = string as NSString
        guard location + 2 <= nsString.length,
              nsString.substring(with: NSRange(location: location + 1, length: 1)) == " " else { return nil }
        let marker = nsString.substring(with: NSRange(location: location, length: 1))
        return (bulletMarkers + legacyBulletMarkers).contains(marker) ? marker : nil
    }

    private static func bulletMarker(for level: Int) -> String {
        bulletMarkers[min(max(0, level), bulletMarkers.count - 1)]
    }

    private static func applyListIndent(_ enabled: Bool, storage: NSTextStorage, location: Int) {
        guard storage.length > 0 else { return }
        let safeLocation = min(location, storage.length - 1)
        let range = (storage.string as NSString).paragraphRange(for: NSRange(location: safeLocation, length: 0))
        let existing = storage.attribute(.paragraphStyle, at: safeLocation, effectiveRange: nil) as? NSParagraphStyle
        let style = existing?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
        style.firstLineHeadIndent = 0
        style.headIndent = enabled ? listIndentStep : 0
        storage.addAttribute(.paragraphStyle, value: style, range: range)
    }

    private static func setTypingListIndent(_ enabled: Bool, textView: NSTextView) {
        setTypingListLevel(enabled ? 0 : nil, textView: textView)
    }

    private static func setTypingListLevel(_ level: Int?, textView: NSTextView) {
        var typing = textView.typingAttributes
        let existing = typing[.paragraphStyle] as? NSParagraphStyle
        let style = existing?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
        style.firstLineHeadIndent = CGFloat(level ?? 0) * listIndentStep
        style.headIndent = level.map { CGFloat($0 + 1) * listIndentStep } ?? 0
        typing[.paragraphStyle] = style
        textView.typingAttributes = typing
    }

    private static func adjustSelection(location: inout Int, length: inout Int, changeAt: Int, delta: Int) {
        let originalLocation = location
        let originalEnd = location + length
        if length == 0 {
            if changeAt <= originalLocation { location = max(0, originalLocation + delta) }
        } else if changeAt < originalLocation {
            location = max(0, originalLocation + delta)
        } else if changeAt <= originalEnd {
            length = max(0, length + delta)
        }
    }

    private static func adjustedSelection(_ selection: NSRange, replacing range: NSRange, newLength: Int) -> NSRange {
        func adjust(_ offset: Int) -> Int {
            if offset <= range.location { return offset }
            if offset >= NSMaxRange(range) { return offset - range.length + newLength }
            return min(offset, range.location + newLength)
        }
        let start = adjust(selection.location)
        let end = adjust(NSMaxRange(selection))
        return NSRange(location: start, length: max(0, end - start))
    }
}
