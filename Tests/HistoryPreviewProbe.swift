import AppKit

@main
struct HistoryPreviewProbe {
    @MainActor
    static func main() {
        _ = NSApplication.shared
        var short = StickyNote.fresh(index: 0)
        short.text = "☐ 买牛奶\n写周报"
        short.completedAt = Date()

        // A short note is shown whole, drawn with the note's own layout (checkboxes and all).
        let shortView = HistoryPreviewView(note: short, width: 300, maximumHeight: 380)
        guard shortView.frame.width == 300,
              shortView.frame.height < 380,
              !shortView.isTruncated,
              shortView.textView.string == short.text,
              shortView.textView.layoutManager is NoteLayoutManager else { exit(1) }

        // A long note is cut at the maximum height and fades out.
        var long = short
        long.text = (1...80).map { "第 \($0) 行" }.joined(separator: "\n")
        let longView = HistoryPreviewView(note: long, width: 300, maximumHeight: 380)
        guard longView.frame.height == 380, longView.isTruncated else { exit(2) }

        // Beside the popover: on its left when there is room, else on its right; the top is
        // level with the row, and the preview stays on screen.
        let visible = NSRect(x: 0, y: 0, width: 1440, height: 875)
        let size = NSSize(width: 300, height: 200)
        let anchor = NSRect(x: 1080, y: 400, width: 340, height: 460)
        let row = NSRect(x: 1092, y: 700, width: 296, height: 56)
        let left = HistoryPreviewController.frame(size: size, rowRect: row, anchor: anchor, visible: visible)
        guard left.maxX <= anchor.minX, left.maxY == row.maxY else { exit(3) }
        let leftEdgeAnchor = NSRect(x: 20, y: 400, width: 340, height: 460)
        let right = HistoryPreviewController.frame(
            size: size,
            rowRect: NSRect(x: 32, y: 700, width: 296, height: 56),
            anchor: leftEdgeAnchor,
            visible: visible
        )
        guard right.minX >= leftEdgeAnchor.maxX else { exit(4) }
        let lowRow = NSRect(x: 1092, y: 20, width: 296, height: 56)
        let clamped = HistoryPreviewController.frame(
            size: NSSize(width: 300, height: 300),
            rowRect: lowRow,
            anchor: anchor,
            visible: visible
        )
        guard clamped.minY >= visible.minY, clamped.maxY <= visible.maxY else { exit(5) }

        // Resting on a row shows the preview after a short pause; leaving hides it.
        let window = NSWindow(
            contentRect: NSRect(x: 800, y: 300, width: 320, height: 400),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let rowView = NSView(frame: NSRect(x: 12, y: 300, width: 296, height: 56))
        window.contentView?.addSubview(rowView)
        let controller = HistoryPreviewController()
        controller.hover(short, row: rowView)
        guard !controller.isShowing else { exit(6) }
        RunLoop.main.run(until: Date().addingTimeInterval(HistoryPreviewController.showDelay + 0.4))
        guard controller.isShowing,
              controller.shownNoteID == short.id,
              controller.shownFrame?.width == HistoryPreviewController.width,
              (controller.shownFrame?.height ?? 0) > 40 else { exit(7) }
        controller.hover(nil, row: nil)
        RunLoop.main.run(until: Date().addingTimeInterval(HistoryPreviewController.hideDelay + 0.4))
        guard !controller.isShowing else { exit(8) }

        print("history preview: pass")
    }
}
