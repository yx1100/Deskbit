import AppKit

enum FirstLaunchGuide {
    static var text: String { attributedText.string }

    static var attributedText: NSAttributedString {
        let regularFont = NoteAppearance.bodyFont()
        let boldFont = NoteAppearance.bodyFont(weight: .bold)
        let result = NSMutableAttributedString(
            string: "欢迎使用随便记 👋\n\n**快捷键**\n⌃⌥⌘空格  在任何地方新建便签（可在偏好设置中修改）\n⌘B  加粗\n⌘K  插入链接\nTab / Shift+Tab  调整项目符号层级\n\n**待办**\n☐ 点一下左边的圆圈，勾选完成\n行首输入 - [ ] 空格，或点击底部的待办按钮，就能新建待办\n\n**Markdown**\n行首输入 # 空格变成标题，- 空格变成列表；链接、粗体、斜体、删除线、行内代码也能用 Markdown 语法输入\n\n**图片**\n直接粘贴或拖入图片，也可以点击底部的图片按钮插入\n\n**自动排列**\n点击右上角的排列按钮，自动将多个便签排列整齐\n\n**查看历史便签**\n点击 ✓ 完成便签，再点击菜单栏随便记图标 → 历史便签；可恢复或永久删除已完成的便签。",
            attributes: [
                .font: regularFont,
                .foregroundColor: NoteAppearance.textColor
            ]
        )
        let fullRange = NSRange(location: 0, length: result.length)
        guard let expression = try? NSRegularExpression(pattern: #"\*\*([^*\n]+)\*\*"#) else {
            return result
        }

        for match in expression.matches(in: result.string, range: fullRange).reversed() {
            let innerRange = NSRange(location: match.range.location + 2, length: match.range.length - 4)
            let replacement = NSMutableAttributedString(attributedString: result.attributedSubstring(from: innerRange))
            replacement.addAttribute(.font, value: boldFont, range: NSRange(location: 0, length: replacement.length))
            result.replaceCharacters(in: match.range, with: replacement)
        }
        return result
    }
}
