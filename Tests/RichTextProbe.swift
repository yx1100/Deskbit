import AppKit
import CoreText

@main
struct RichTextProbe {
    @MainActor
    static func main() {
        func markerDiameter(_ symbol: String) -> CGFloat {
            let baseFont = NoteAppearance.bodyFont() as CTFont
            let value = symbol as CFString
            let font = CTFontCreateForString(
                baseFont,
                value,
                CFRange(location: 0, length: CFStringGetLength(value))
            )
            var characters = Array(symbol.utf16)
            var glyphs = [CGGlyph](repeating: 0, count: characters.count)
            CTFontGetGlyphsForCharacters(font, &characters, &glyphs, characters.count)
            var glyph = glyphs[0]
            return CTFontGetBoundingRectsForGlyphs(font, .default, &glyph, nil, 1).height
        }

        let filledDiameter = markerDiameter("•")
        let ringDiameter = markerDiameter("∘")
        let squareDiameter = markerDiameter("▪")
        let markerProportionsAreBalanced = (1.45...1.75).contains(ringDiameter / filledDiameter)
            && (1.0...1.5).contains(squareDiameter / filledDiameter)

        let value = NSMutableAttributedString(string: "重点\n第二段")
        let bold = NSFontManager.shared.convert(NoteAppearance.bodyFont(), toHaveTrait: .boldFontMask)
        value.addAttribute(.font, value: bold, range: NSRange(location: 0, length: 2))
        value.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 3, length: 3))
        value.replaceCharacters(in: NSRange(location: 3, length: 0), with: "• ")

        guard let data = RichTextCodec.encode(value), let restored = RichTextCodec.decode(data) else { exit(1) }
        let restoredFont = restored.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        let boldSurvived = restoredFont.map { NSFontManager.shared.traits(of: $0).contains(.boldFontMask) } ?? false
        let bulletSurvived = restored.string.contains("• 第二段")
        let strikeSurvived = (restored.attribute(.strikethroughStyle, at: 5, effectiveRange: nil) as? Int) == NSUnderlineStyle.single.rawValue

        let editor = NSTextView()
        editor.isRichText = true
        editor.string = "普通文本"
        editor.typingAttributes = [.font: NoteAppearance.bodyFont()]
        editor.setSelectedRange(NSRange(location: editor.string.utf16.count, length: 0))
        RichTextFormatting.toggleBold(in: editor)
        let futureBoldOn = RichTextFormatting.isBold(in: editor)
        RichTextFormatting.toggleBold(in: editor)
        let futureBoldOff = !RichTextFormatting.isBold(in: editor)

        let todoEditor = NSTextView()
        todoEditor.isRichText = true
        todoEditor.string = "第一项\n第二项"
        todoEditor.setSelectedRange(NSRange(location: 0, length: todoEditor.string.utf16.count))
        RichTextFormatting.toggleTodo(in: todoEditor)
        let todoPending = todoEditor.string == "☐ 第一项\n☐ 第二项"
            && RichTextFormatting.todoState(in: todoEditor) == .pending
        // Checking happens by clicking the circle, not with the to-do button.
        RichTextFormatting.toggleTodoCompletion(atParagraphStart: 0, in: todoEditor)
        RichTextFormatting.toggleTodoCompletion(atParagraphStart: 6, in: todoEditor)
        let firstTaskTextRange = NSRange(location: 2, length: 3)
        let firstTaskStrike = (todoEditor.textStorage?.attribute(.strikethroughStyle, at: firstTaskTextRange.location, effectiveRange: nil) as? NSNumber)?.intValue
        let todoCompleted = todoEditor.string == "☑ 第一项\n☑ 第二项"
            && RichTextFormatting.todoState(in: todoEditor) == .completed
            && firstTaskStrike == NSUnderlineStyle.single.rawValue
            && todoEditor.textStorage?.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) == nil
        let completedRoundTrip = todoEditor.textStorage
            .flatMap(RichTextCodec.encode)
            .flatMap(RichTextCodec.decode)
        let todoSurvived = completedRoundTrip?.string == todoEditor.string
            && (completedRoundTrip?.attribute(.strikethroughStyle, at: firstTaskTextRange.location, effectiveRange: nil) as? NSNumber)?.intValue == NSUnderlineStyle.single.rawValue
        // The button removes to-dos whether or not they are checked.
        RichTextFormatting.toggleTodo(in: todoEditor)
        let todoRemoved = todoEditor.string == "第一项\n第二项"
            && RichTextFormatting.todoState(in: todoEditor) == .plain
            && todoEditor.textStorage?.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) == nil
        let todoSelectionPreserved = todoEditor.selectedRange() == NSRange(location: 0, length: todoEditor.string.utf16.count)

        let completedTodoNewlineEditor = NSTextView()
        completedTodoNewlineEditor.isRichText = true
        completedTodoNewlineEditor.string = "☑ 已完成"
        completedTodoNewlineEditor.textStorage?.addAttribute(
            .strikethroughStyle,
            value: NSUnderlineStyle.single.rawValue,
            range: NSRange(location: 2, length: 3)
        )
        completedTodoNewlineEditor.typingAttributes = [.strikethroughStyle: NSUnderlineStyle.single.rawValue]
        completedTodoNewlineEditor.setSelectedRange(NSRange(location: completedTodoNewlineEditor.string.utf16.count, length: 0))
        let continuedTodo = RichTextFormatting.handleStructuredNewline(in: completedTodoNewlineEditor)
        let completedTodoNewline = continuedTodo
            && completedTodoNewlineEditor.string == "☑ 已完成\n☐ "
            && completedTodoNewlineEditor.typingAttributes[.strikethroughStyle] == nil
            && completedTodoNewlineEditor.textStorage?.attribute(.strikethroughStyle, at: 2, effectiveRange: nil) != nil
            && completedTodoNewlineEditor.textStorage?.attribute(.strikethroughStyle, at: 6, effectiveRange: nil) == nil

        let splitCompletedTodoEditor = NSTextView()
        splitCompletedTodoEditor.isRichText = true
        splitCompletedTodoEditor.string = "☑ 前后"
        splitCompletedTodoEditor.textStorage?.addAttribute(
            .strikethroughStyle,
            value: NSUnderlineStyle.single.rawValue,
            range: NSRange(location: 2, length: 2)
        )
        splitCompletedTodoEditor.typingAttributes = [.strikethroughStyle: NSUnderlineStyle.single.rawValue]
        splitCompletedTodoEditor.setSelectedRange(NSRange(location: 3, length: 0))
        let splitTodo = RichTextFormatting.handleStructuredNewline(in: splitCompletedTodoEditor)
        let splitCompletedTodo = splitTodo
            && splitCompletedTodoEditor.string == "☑ 前\n☐ 后"
            && splitCompletedTodoEditor.textStorage?.attribute(.strikethroughStyle, at: 2, effectiveRange: nil) != nil
            && splitCompletedTodoEditor.textStorage?.attribute(.strikethroughStyle, at: 6, effectiveRange: nil) == nil

        let bulletEditor = NSTextView()
        bulletEditor.isRichText = true
        bulletEditor.string = "第一项\n第二项"
        bulletEditor.setSelectedRange(NSRange(location: 0, length: bulletEditor.string.utf16.count))
        RichTextFormatting.toggleBulletList(in: bulletEditor)
        let bulletsOn = bulletEditor.string == "• 第一项\n• 第二项"
        RichTextFormatting.toggleBulletList(in: bulletEditor)
        let bulletsOff = bulletEditor.string == "第一项\n第二项"
        let bulletSelectionPreserved = bulletEditor.selectedRange() == NSRange(location: 0, length: bulletEditor.string.utf16.count)

        let listModeEditor = NSTextView()
        listModeEditor.isRichText = true
        listModeEditor.string = "• 项目"
        listModeEditor.setSelectedRange(NSRange(location: listModeEditor.string.utf16.count, length: 0))
        RichTextFormatting.toggleTodo(in: listModeEditor)
        let bulletBecameTodo = listModeEditor.string == "☐ 项目"
            && RichTextFormatting.todoState(in: listModeEditor) == .pending
            && !RichTextFormatting.isBulletList(in: listModeEditor)
        RichTextFormatting.toggleBulletList(in: listModeEditor)
        let todoBecameBullet = listModeEditor.string == "• 项目"
            && RichTextFormatting.todoState(in: listModeEditor) == .plain
            && RichTextFormatting.isBulletList(in: listModeEditor)

        let markdownEditor = NSTextView()
        markdownEditor.isRichText = true
        markdownEditor.font = NoteAppearance.bodyFont()
        markdownEditor.string = "**重点**\n- 第一项\n* 第二项"
        markdownEditor.setSelectedRange(NSRange(location: markdownEditor.string.utf16.count, length: 0))
        let markdownChanged = RichTextFormatting.applyMarkdownSyntax(in: markdownEditor)
        let markdownFont = markdownEditor.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        let markdownBold = markdownFont.map { NSFontManager.shared.traits(of: $0).contains(.boldFontMask) } ?? false
        let markdownBullets = markdownEditor.string == "重点\n• 第一项\n• 第二项"

        func convertedEditor(_ text: String) -> NSTextView {
            let editor = NSTextView()
            editor.isRichText = true
            editor.font = NoteAppearance.bodyFont()
            editor.typingAttributes = [.font: NoteAppearance.bodyFont()]
            editor.string = text
            editor.setSelectedRange(NSRange(location: editor.string.utf16.count, length: 0))
            _ = RichTextFormatting.applyMarkdownSyntax(in: editor)
            return editor
        }
        func fontAt(_ editor: NSTextView, _ location: Int) -> NSFont? {
            editor.textStorage?.attribute(.font, at: location, effectiveRange: nil) as? NSFont
        }

        let strikeEditor = convertedEditor("~~删除~~")
        let strikeMarkdown = strikeEditor.string == "删除"
            && (strikeEditor.textStorage?.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) as? Int) == NSUnderlineStyle.single.rawValue

        let headingEditor = convertedEditor("## 标题")
        let headingMarkdown = headingEditor.string == "标题"
            && RichTextFormatting.headingLevel(of: fontAt(headingEditor, 0)) == 2
            && RichTextFormatting.headingLevel(of: headingEditor.typingAttributes[.font] as? NSFont) == 2

        let italicEditor = convertedEditor("一个*斜体*词")
        let italicMarkdown = italicEditor.string == "一个斜体词"
            && fontAt(italicEditor, 2).map { NSFontManager.shared.traits(of: $0).contains(.italicFontMask) } == true
        let arithmeticUntouched = convertedEditor("2*3*4").string == "2*3*4"

        let codeEditor = convertedEditor("运行 `swift build`")
        let codeMarkdown = codeEditor.string == "运行 swift build"
            && fontAt(codeEditor, 3)?.isFixedPitch == true

        let linkEditor = convertedEditor("见 [官网](https://example.com)")
        let linkMarkdown = linkEditor.string == "见 官网"
            && (linkEditor.textStorage?.attribute(.link, at: 2, effectiveRange: nil) as? URL)?.absoluteString == "https://example.com"
        let nonLinkUntouched = convertedEditor("[注释](不是网址)").string == "[注释](不是网址)"

        let todoMarkdownEditor = convertedEditor("- [ ] 买牛奶\n- [x] 已完成")
        let todoMarkdown = todoMarkdownEditor.string == "☐ 买牛奶\n☑ 已完成"

        // Clicking a checkbox flips only that item between open and done.
        let clickEditor = NSTextView()
        clickEditor.isRichText = true
        clickEditor.allowsUndo = true
        clickEditor.string = "☐ 买牛奶\n☑ 已完成"
        let firstChecked = RichTextFormatting.toggleTodoCompletion(atParagraphStart: 0, in: clickEditor)
            && clickEditor.string == "☑ 买牛奶\n☑ 已完成"
            && (clickEditor.textStorage?.attribute(.strikethroughStyle, at: 2, effectiveRange: nil) as? Int) == NSUnderlineStyle.single.rawValue
        let secondUnchecked = RichTextFormatting.toggleTodoCompletion(atParagraphStart: 6, in: clickEditor)
            && clickEditor.string == "☑ 买牛奶\n☐ 已完成"
            && clickEditor.textStorage?.attribute(.strikethroughStyle, at: 8, effectiveRange: nil) == nil
        let plainIgnored = !RichTextFormatting.toggleTodoCompletion(atParagraphStart: 2, in: clickEditor)
        // Backspace right after a marker removes the whole marker instead of leaving "☐".
        let backspaceEditor = NSTextView()
        backspaceEditor.isRichText = true
        backspaceEditor.allowsUndo = true
        backspaceEditor.string = "☐ \n• 列表"
        backspaceEditor.setSelectedRange(NSRange(location: 2, length: 0))
        let todoBackspace = RichTextFormatting.handleMarkerBackspace(in: backspaceEditor)
            && backspaceEditor.string == "\n• 列表"
        backspaceEditor.setSelectedRange(NSRange(location: 3, length: 0))
        let bulletBackspace = RichTextFormatting.handleMarkerBackspace(in: backspaceEditor)
            && backspaceEditor.string == "\n列表"
        backspaceEditor.setSelectedRange(NSRange(location: 2, length: 0))
        let ordinaryBackspace = !RichTextFormatting.handleMarkerBackspace(in: backspaceEditor)

        // Lines broken by older versions ("☐123") become to-dos again.
        let repairEditor = NSTextView()
        repairEditor.isRichText = true
        repairEditor.string = "☐123\n☑"
        let repaired = RichTextFormatting.normalizeTodoMarkers(in: repairEditor)
            && repairEditor.string == "☐ 123\n☑ "
            && !RichTextFormatting.normalizeTodoMarkers(in: repairEditor)

        // The to-do button toggles between to-do and plain, never checking the item.
        let buttonEditor = NSTextView()
        buttonEditor.isRichText = true
        buttonEditor.string = "任务"
        buttonEditor.setSelectedRange(NSRange(location: 0, length: 0))
        RichTextFormatting.toggleTodo(in: buttonEditor)
        let buttonAdds = buttonEditor.string == "☐ 任务"
        RichTextFormatting.toggleTodo(in: buttonEditor)
        let buttonRemoves = buttonEditor.string == "任务"

        // In an empty note the marker keeps the note's font instead of AppKit's default.
        let noteFont = NSFont.systemFont(ofSize: 18)
        for toggle in [RichTextFormatting.toggleTodo(in:), RichTextFormatting.toggleBulletList(in:)] {
            let emptyEditor = NSTextView()
            emptyEditor.isRichText = true
            emptyEditor.typingAttributes = [.font: noteFont]
            toggle(emptyEditor)
            guard (emptyEditor.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize == 18,
                  (emptyEditor.typingAttributes[.font] as? NSFont)?.pointSize == 18 else { exit(3) }
        }

        let checkboxClicks = firstChecked && secondUnchecked && plainIgnored && buttonAdds && buttonRemoves
            && todoBackspace && bulletBackspace && ordinaryBackspace && repaired

        let extendedMarkdown = strikeMarkdown && headingMarkdown && italicMarkdown && arithmeticUntouched
            && codeMarkdown && linkMarkdown && nonLinkUntouched && todoMarkdown

        let boldMarkdownEditor = NSTextView()
        boldMarkdownEditor.isRichText = true
        boldMarkdownEditor.font = NoteAppearance.bodyFont()
        boldMarkdownEditor.typingAttributes = [.font: NoteAppearance.bodyFont()]
        boldMarkdownEditor.string = "**重点**"
        boldMarkdownEditor.setSelectedRange(NSRange(location: boldMarkdownEditor.string.utf16.count, length: 0))
        _ = RichTextFormatting.applyMarkdownSyntax(in: boldMarkdownEditor)
        boldMarkdownEditor.insertText(" 后续", replacementRange: boldMarkdownEditor.selectedRange())
        let trailingFont = boldMarkdownEditor.textStorage?.attribute(.font, at: boldMarkdownEditor.string.utf16.count - 1, effectiveRange: nil) as? NSFont
        let trailingIsRegular = trailingFont.map { !NSFontManager.shared.traits(of: $0).contains(.boldFontMask) } ?? false

        let emptyBulletEditor = NSTextView()
        emptyBulletEditor.isRichText = true
        emptyBulletEditor.string = "• "
        let listStyle = NSMutableParagraphStyle()
        listStyle.headIndent = 18
        emptyBulletEditor.textStorage?.addAttribute(.paragraphStyle, value: listStyle, range: NSRange(location: 0, length: 2))
        emptyBulletEditor.typingAttributes = [.font: NoteAppearance.bodyFont(), .paragraphStyle: listStyle]
        emptyBulletEditor.setSelectedRange(NSRange(location: 2, length: 0))
        let exitedEmptyBullet = RichTextFormatting.handleStructuredNewline(in: emptyBulletEditor)
        let exitStyle = emptyBulletEditor.typingAttributes[.paragraphStyle] as? NSParagraphStyle
        let listExitClean = exitedEmptyBullet && emptyBulletEditor.string.isEmpty && (exitStyle?.headIndent ?? 0) == 0

        let nestedBulletEditor = NSTextView()
        nestedBulletEditor.isRichText = true
        nestedBulletEditor.string = "• 父级\n• 子项一\n• 子项二"
        nestedBulletEditor.setSelectedRange(NSRange(location: 5, length: 11))
        let indented = RichTextFormatting.adjustBulletLevel(in: nestedBulletEditor, delta: 1)
        let firstNestedStyle = nestedBulletEditor.textStorage?.attribute(.paragraphStyle, at: 5, effectiveRange: nil) as? NSParagraphStyle
        let secondNestedStyle = nestedBulletEditor.textStorage?.attribute(.paragraphStyle, at: 11, effectiveRange: nil) as? NSParagraphStyle
        let multiLevelOn = indented
            && nestedBulletEditor.string == "• 父级\n∘ 子项一\n∘ 子项二"
            && firstNestedStyle?.firstLineHeadIndent == 18
            && firstNestedStyle?.headIndent == 36
            && secondNestedStyle?.firstLineHeadIndent == 18
            && secondNestedStyle?.headIndent == 36
        let nestedRoundTrip = RichTextCodec.encode(nestedBulletEditor.attributedString())
            .flatMap(RichTextCodec.decode)
        let restoredNestedStyle = nestedRoundTrip?.attribute(.paragraphStyle, at: 5, effectiveRange: nil) as? NSParagraphStyle
        let multiLevelSurvived = restoredNestedStyle?.firstLineHeadIndent == 18
            && restoredNestedStyle?.headIndent == 36
        let outdented = RichTextFormatting.adjustBulletLevel(in: nestedBulletEditor, delta: -1)
        let rootStyle = nestedBulletEditor.textStorage?.attribute(.paragraphStyle, at: 5, effectiveRange: nil) as? NSParagraphStyle
        let multiLevelOff = outdented && rootStyle?.firstLineHeadIndent == 0 && rootStyle?.headIndent == 18
            && nestedBulletEditor.string == "• 父级\n• 子项一\n• 子项二"

        let deepBulletEditor = NSTextView()
        deepBulletEditor.isRichText = true
        deepBulletEditor.string = "• 根\n• 一级\n• 二级\n• 三级"
        deepBulletEditor.setSelectedRange(NSRange(location: 6, length: 0))
        _ = RichTextFormatting.adjustBulletLevel(in: deepBulletEditor, delta: 1)
        deepBulletEditor.setSelectedRange(NSRange(location: 11, length: 0))
        _ = RichTextFormatting.adjustBulletLevel(in: deepBulletEditor, delta: 1)
        _ = RichTextFormatting.adjustBulletLevel(in: deepBulletEditor, delta: 1)
        deepBulletEditor.setSelectedRange(NSRange(location: 16, length: 0))
        _ = RichTextFormatting.adjustBulletLevel(in: deepBulletEditor, delta: 1)
        _ = RichTextFormatting.adjustBulletLevel(in: deepBulletEditor, delta: 1)
        _ = RichTextFormatting.adjustBulletLevel(in: deepBulletEditor, delta: 1)
        let tieredMarkers = deepBulletEditor.string == "• 根\n∘ 一级\n▪ 二级\n▪ 三级"

        let inheritedMarkerEditor = NSTextView()
        inheritedMarkerEditor.isRichText = true
        inheritedMarkerEditor.string = "• 父级\n∘ 子项"
        let inheritedStyle = NSMutableParagraphStyle()
        inheritedStyle.firstLineHeadIndent = 18
        inheritedStyle.headIndent = 36
        inheritedMarkerEditor.textStorage?.addAttribute(.paragraphStyle, value: inheritedStyle, range: NSRange(location: 5, length: 4))
        inheritedMarkerEditor.typingAttributes = [.font: NoteAppearance.bodyFont(), .paragraphStyle: inheritedStyle]
        inheritedMarkerEditor.setSelectedRange(NSRange(location: inheritedMarkerEditor.string.utf16.count, length: 0))
        let insertedNestedLine = RichTextFormatting.handleStructuredNewline(in: inheritedMarkerEditor)
        let inheritedMarker = insertedNestedLine && inheritedMarkerEditor.string.hasSuffix("\n∘ ")

        let legacyMarkerEditor = NSTextView()
        legacyMarkerEditor.isRichText = true
        legacyMarkerEditor.string = "• 父级\n◦ 小圆旧版\n○ 大圆旧版"
        legacyMarkerEditor.textStorage?.addAttribute(
            .paragraphStyle,
            value: inheritedStyle,
            range: NSRange(location: 5, length: legacyMarkerEditor.string.utf16.count - 5)
        )
        let normalizedLegacyMarker = RichTextFormatting.normalizeBulletMarkers(in: legacyMarkerEditor)
            && legacyMarkerEditor.string == "• 父级\n∘ 小圆旧版\n∘ 大圆旧版"

        let orphanBulletEditor = NSTextView()
        orphanBulletEditor.isRichText = true
        orphanBulletEditor.string = "• 首项"
        orphanBulletEditor.setSelectedRange(NSRange(location: 2, length: 0))
        let orphanPrevented = !RichTextFormatting.adjustBulletLevel(in: orphanBulletEditor, delta: 1)

        print("bold=\(boldSurvived) legacyStrike=\(strikeSurvived) todo=\(todoPending && todoCompleted && todoRemoved && todoSurvived && todoSelectionPreserved && completedTodoNewline && splitCompletedTodo) bullet=\(bulletSurvived) futureBold=\(futureBoldOn && futureBoldOff) bulletToggle=\(bulletsOn && bulletsOff && bulletSelectionPreserved && bulletBecameTodo && todoBecameBullet) markdown=\(markdownChanged && markdownBold && markdownBullets && extendedMarkdown && trailingIsRegular) listExit=\(listExitClean) nesting=\(multiLevelOn && multiLevelOff && multiLevelSurvived && orphanPrevented && tieredMarkers && inheritedMarker && normalizedLegacyMarker) markerProportions=\(markerProportionsAreBalanced) bytes=\(data.count)")
        guard boldSurvived, bulletSurvived, strikeSurvived, futureBoldOn, futureBoldOff, todoPending, todoCompleted, todoRemoved, todoSurvived, todoSelectionPreserved, completedTodoNewline, splitCompletedTodo, bulletsOn, bulletsOff, bulletSelectionPreserved, bulletBecameTodo, todoBecameBullet, markdownChanged, markdownBold, markdownBullets, extendedMarkdown, checkboxClicks, trailingIsRegular, listExitClean, multiLevelOn, multiLevelOff, multiLevelSurvived, orphanPrevented, tieredMarkers, inheritedMarker, normalizedLegacyMarker, markerProportionsAreBalanced else { exit(1) }
    }
}
