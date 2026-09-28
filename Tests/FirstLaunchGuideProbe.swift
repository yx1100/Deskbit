import AppKit

@main
struct FirstLaunchGuideProbe {
    static func main() {
        let guide = FirstLaunchGuide.text
        let attributedGuide = FirstLaunchGuide.attributedText

        precondition(guide == """
        欢迎使用 Deskbit 👋

        快捷键
        ⌃⌥⌘空格  在任何地方新建便签（可在偏好设置中修改）
        ⌘B  加粗
        ⌘K  插入链接
        Tab / Shift+Tab  调整项目符号层级

        Markdown
        行首输入 # 空格变成标题，- 空格变成列表，- [ ] 空格变成待办；链接、粗体、斜体、删除线、行内代码也能用 Markdown 语法输入

        图片
        直接粘贴或拖入图片，也可以点击底部的图片按钮插入

        自动排列
        点击左上角按钮，自动将多个便签排列整齐

        查看历史便签
        点击 ✓ 完成便签，再点击菜单栏 Deskbit 图标 → 历史便签；可恢复或永久删除已完成的便签。
        """)
        verifyBold(in: attributedGuide, expected: ["快捷键", "Markdown", "图片", "自动排列", "查看历史便签"])
        verifyRegular(in: attributedGuide, expected: ["欢迎使用", "Deskbit", "⌃⌥⌘空格", "加粗", "插入链接", "调整项目符号层级"])
        precondition(!guide.contains("**"))
        precondition(attributedGuide.string == guide)
        print("first-launch guide: pass")
    }

    private static func verifyBold(in guide: NSAttributedString, expected strings: [String]) {
        for string in strings {
            let range = (guide.string as NSString).range(of: string)
            precondition(range.location != NSNotFound)
            let font = guide.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
            precondition(font.map { NSFontManager.shared.traits(of: $0).contains(.boldFontMask) } == true, string)
        }
    }

    private static func verifyRegular(in guide: NSAttributedString, expected strings: [String]) {
        for string in strings {
            let range = (guide.string as NSString).range(of: string)
            precondition(range.location != NSNotFound)
            let font = guide.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
            precondition(font.map { !NSFontManager.shared.traits(of: $0).contains(.boldFontMask) } == true, string)
        }
    }
}
