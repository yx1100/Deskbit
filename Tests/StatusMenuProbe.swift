import AppKit

@MainActor
private final class MenuTarget: NSObject, DeskbitStatusMenuTarget {
    @objc func newNoteFromMenu() {}
    @objc func arrangeNotes() {}
    @objc func showHistoryFromMenu() {}
    @objc func showAllNotes() {}
    @objc func showPreferencesFromMenu() {}
    @objc func quit() {}
}

@main
struct StatusMenuProbe {
    @MainActor
    static func main() {
        _ = NSApplication.shared
        let target = MenuTarget()
        let menu = DeskbitStatusMenu.make(target: target)
        let titles = menu.items.filter { !$0.isSeparatorItem }.map(\.title)

        guard titles == [
            "新建便签",
            "自动排序便签",
            "历史便签",
            "显示所有便签",
            "偏好设置…",
            "退出 Deskbit"
        ],
        !titles.contains("编辑"),
        menu.items
            .filter({ !$0.isSeparatorItem && $0.title != "退出 Deskbit" })
            .allSatisfy({ $0.image != nil }),
        menu.items.first(where: { $0.title == "偏好设置…" })?.action == #selector(MenuTarget.showPreferencesFromMenu),
        menu.items.first(where: { $0.title == "偏好设置…" })?.image != nil else { exit(1) }

        guard menu.items
            .filter({ !$0.isSeparatorItem && $0.submenu == nil && $0.action != nil })
            .allSatisfy({ target.responds(to: $0.action!) }) else { exit(2) }

        print("status menu: pass")
    }
}
