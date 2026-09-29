import AppKit

@MainActor
@objc protocol AppStatusMenuTarget: AnyObject {
    func newNoteFromMenu()
    func arrangeNotes()
    func showHistoryFromMenu()
    func showAllNotes()
    func showPreferencesFromMenu()
    func quit()
}

@MainActor
enum AppStatusMenu {
    static func make(target: AppStatusMenuTarget) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(item(
            "新建便签",
            action: #selector(AppStatusMenuTarget.newNoteFromMenu),
            key: "n",
            symbol: "square.and.pencil",
            target: target
        ))
        menu.addItem(item(
            "排列便签",
            action: #selector(AppStatusMenuTarget.arrangeNotes),
            symbol: "square.grid.2x2",
            target: target
        ))
        menu.addItem(item(
            "已完成的便签",
            action: #selector(AppStatusMenuTarget.showHistoryFromMenu),
            symbol: "clock.arrow.circlepath",
            target: target
        ))
        let showAll = item(
            "显示所有便签",
            action: #selector(AppStatusMenuTarget.showAllNotes),
            symbol: "macwindow.on.rectangle",
            target: target
        )
        showAll.toolTip = "将所有便签移到当前桌面"
        menu.addItem(showAll)
        menu.addItem(.separator())
        menu.addItem(item(
            "设置…",
            action: #selector(AppStatusMenuTarget.showPreferencesFromMenu),
            key: ",",
            symbol: "gearshape",
            target: target
        ))
        menu.addItem(item("退出随便记", action: #selector(AppStatusMenuTarget.quit), key: "q", target: target))
        return menu
    }

    private static func item(
        _ title: String,
        action: Selector,
        key: String = "",
        symbol: String? = nil,
        target: AppStatusMenuTarget
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target
        if let symbol {
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        }
        return item
    }
}
