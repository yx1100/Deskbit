import AppKit

@main
struct HistoryDismissalProbe {
    @MainActor
    static func main() {
        _ = NSApplication.shared
        let popoverWindow = NSWindow()
        let otherWindow = NSWindow()
        var dismissCount = 0
        let monitor = HistoryPopoverDismissalMonitor(
            popoverWindow: { popoverWindow },
            onDismiss: { dismissCount += 1 }
        )

        monitor.handleLocalMouseDown(in: popoverWindow)
        guard dismissCount == 0 else { exit(1) }
        monitor.handleLocalMouseDown(in: otherWindow)
        guard dismissCount == 1 else { exit(2) }
        monitor.handleGlobalMouseDown()
        guard dismissCount == 2 else { exit(3) }
        // Esc in the popover closes it; other keys and other windows are left alone.
        guard monitor.handleKeyDown(keyCode: 53, in: popoverWindow), dismissCount == 3 else { exit(4) }
        guard !monitor.handleKeyDown(keyCode: 0, in: popoverWindow),
              !monitor.handleKeyDown(keyCode: 53, in: otherWindow),
              dismissCount == 3 else { exit(5) }

        print("history dismissal: pass")
    }
}
