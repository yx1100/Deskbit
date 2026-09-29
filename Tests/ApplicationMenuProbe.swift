import AppKit

@main
struct ApplicationMenuProbe {
    @MainActor
    static func main() {
        _ = NSApplication.shared
        let mainMenu = ApplicationMenu.make()
        guard mainMenu.items.count == 3,
              let appMenu = mainMenu.items[0].submenu,
              let fileMenu = mainMenu.items[1].submenu,
              let editMenu = mainMenu.items[2].submenu else { exit(1) }
        guard appMenu.items.contains(where: { $0.title == "设置…" && $0.keyEquivalent == "," }),
              fileMenu.items.first?.title == "新建便签",
              fileMenu.items.first?.keyEquivalent == "n",
              fileMenu.items.contains(where: {
                  $0.title == "关闭窗口" && $0.action == #selector(NSWindow.performClose(_:)) && $0.keyEquivalent == "w"
              }) else { exit(6) }

        let commands = editMenu.items.compactMap { item -> (String, Selector?, String)? in
            guard !item.isSeparatorItem else { return nil }
            return (item.title, item.action, item.keyEquivalent)
        }
        let expected: [(String, Selector, String)] = [
            ("撤销", Selector(("undo:")), "z"),
            ("重做", Selector(("redo:")), "z"),
            ("剪切", #selector(NSText.cut(_:)), "x"),
            ("拷贝", #selector(NSText.copy(_:)), "c"),
            ("粘贴", #selector(NSText.paste(_:)), "v"),
            ("全选", #selector(NSText.selectAll(_:)), "a")
        ]
        guard commands.count == expected.count else { exit(2) }
        for (actual, expected) in zip(commands, expected) {
            guard actual.0 == expected.0,
                  actual.1 == expected.1,
                  actual.2 == expected.2 else { exit(3) }
        }
        guard editMenu.items.first(where: { $0.title == "重做" })?.keyEquivalentModifierMask == [.command, .shift] else { exit(4) }

        let statusMenu = NSMenu()
        ApplicationMenu.addEditSubmenu(to: statusMenu)
        guard statusMenu.items.count == 1,
              statusMenu.items[0].title == "编辑",
              statusMenu.items[0].submenu?.items.contains(where: { $0.action == #selector(NSText.copy(_:)) }) == true,
              statusMenu.items[0].submenu?.items.contains(where: { $0.action == #selector(NSText.paste(_:)) }) == true else { exit(5) }

        print("application edit menu: pass")
    }
}
