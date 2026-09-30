import AppKit

/// The 已完成的便签 popover: a fixed-width list of completed notes. Restoring a note removes
/// its row and keeps the popover open, so several notes can be restored one after another.
@MainActor
final class HistoryPopoverViewController: NSViewController {
    static let width: CGFloat = 320
    static let maximumHeight: CGFloat = 420
    private static let minimumHeight: CGFloat = 180
    private static let rowHeight: CGFloat = 56
    private static let rowSpacing: CGFloat = 6
    /// The header above the list and the 全部删除 button below it.
    private static let chromeHeight: CGFloat = 85
    private static let emptyListHeight: CGFloat = 92

    private(set) var notes: [StickyNote]
    private let onRestore: (UUID) -> Void
    private let onDelete: (UUID) -> Void
    private let onClear: () -> Void
    /// The note under the mouse and its row, or nil when the mouse leaves the rows.
    private let onHover: (StickyNote?, NSView?) -> Void

    private let countLabel = NSTextField(labelWithString: "")
    private let list = NSStackView()
    private let clearButton = NSButton(title: "全部删除", target: nil, action: nil)
    private var heightConstraint: NSLayoutConstraint?
    private var documentHeightConstraint: NSLayoutConstraint?
    private var hoveredNoteID: UUID?

    init(
        notes: [StickyNote],
        onRestore: @escaping (UUID) -> Void,
        onDelete: @escaping (UUID) -> Void,
        onClear: @escaping () -> Void,
        onHover: @escaping (StickyNote?, NSView?) -> Void = { _, _ in }
    ) {
        self.notes = notes
        self.onRestore = onRestore
        self.onDelete = onDelete
        self.onClear = onClear
        self.onHover = onHover
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = NSSize(width: Self.width, height: Self.height(forNoteCount: notes.count))
    }

    required init?(coder: NSCoder) { nil }

    static func height(forNoteCount count: Int) -> CGFloat {
        min(maximumHeight, max(minimumHeight, chromeHeight + listHeight(forNoteCount: count)))
    }

    private static func listHeight(forNoteCount count: Int) -> CGFloat {
        guard count > 0 else { return emptyListHeight }
        return CGFloat(count) * rowHeight + CGFloat(count - 1) * rowSpacing + 4
    }

    override func loadView() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "已完成的便签")
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.textColor = .labelColor

        countLabel.font = .systemFont(ofSize: 11, weight: .medium)
        countLabel.textColor = .secondaryLabelColor

        let header = NSStackView(views: [title, NSView(), countLabel])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(header)

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(scrollView)

        let document = FlippedHistoryDocumentView()
        document.translatesAutoresizingMaskIntoConstraints = false
        list.orientation = .vertical
        list.alignment = .width
        list.spacing = Self.rowSpacing
        list.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(list)
        scrollView.documentView = document

        clearButton.target = self
        clearButton.action = #selector(clearHistory)
        clearButton.isBordered = false
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        clearButton.setAccessibilityLabel("删除所有已完成的便签")
        root.addSubview(clearButton)

        let height = root.heightAnchor.constraint(equalToConstant: preferredContentSize.height)
        let documentHeight = document.heightAnchor.constraint(equalToConstant: 0)
        heightConstraint = height
        documentHeightConstraint = documentHeight
        NSLayoutConstraint.activate([
            // A fixed width: long titles are cut short instead of widening the popover.
            root.widthAnchor.constraint(equalToConstant: Self.width),
            height,
            document.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            documentHeight,
            list.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 2),
            list.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -2),
            list.topAnchor.constraint(equalTo: document.topAnchor, constant: 2),
            list.bottomAnchor.constraint(lessThanOrEqualTo: document.bottomAnchor, constant: -2),
            header.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            header.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            header.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            header.heightAnchor.constraint(equalToConstant: 24),
            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            scrollView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            scrollView.bottomAnchor.constraint(equalTo: clearButton.topAnchor, constant: -8),
            clearButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            clearButton.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -9),
            clearButton.heightAnchor.constraint(equalToConstant: 24)
        ])

        view = root
        reloadRows()
    }

    private func reloadRows() {
        list.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if notes.isEmpty {
            let empty = NSTextField(labelWithString: "没有已完成的便签")
            empty.alignment = .center
            empty.font = .systemFont(ofSize: 13)
            empty.textColor = .tertiaryLabelColor
            empty.translatesAutoresizingMaskIntoConstraints = false
            list.addArrangedSubview(empty)
            empty.heightAnchor.constraint(equalToConstant: 88).isActive = true
        } else {
            for note in notes {
                let row = HistoryNoteRowView(
                    note: note,
                    onRestore: { [weak self] id in self?.restore(id) },
                    onDelete: onDelete,
                    onHover: { [weak self] row, isHovered in self?.rowHoverChanged(row, isHovered: isHovered) }
                )
                list.addArrangedSubview(row)
                row.heightAnchor.constraint(equalToConstant: Self.rowHeight).isActive = true
            }
        }

        countLabel.stringValue = "\(notes.count) 条"
        clearButton.isEnabled = !notes.isEmpty
        clearButton.attributedTitle = NSAttributedString(string: "全部删除", attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: notes.isEmpty ? NSColor.tertiaryLabelColor : NSColor.systemRed
        ])

        let height = Self.height(forNoteCount: notes.count)
        preferredContentSize = NSSize(width: Self.width, height: height)
        heightConstraint?.constant = height
        documentHeightConstraint?.constant = max(Self.listHeight(forNoteCount: notes.count), height - Self.chromeHeight)
    }

    private func restore(_ id: UUID) {
        onRestore(id)
        notes.removeAll { $0.id == id }
        if hoveredNoteID != nil {
            hoveredNoteID = nil
            onHover(nil, nil)
        }
        // The row's button is still handling the click, so hide the row now and rebuild the
        // list once the click is done.
        list.arrangedSubviews.first { ($0 as? HistoryNoteRowView)?.note.id == id }?.isHidden = true
        DispatchQueue.main.async { [weak self] in self?.reloadRows() }
    }

    private func rowHoverChanged(_ row: HistoryNoteRowView, isHovered: Bool) {
        if isHovered {
            hoveredNoteID = row.note.id
            onHover(row.note, row)
        } else if hoveredNoteID == row.note.id {
            hoveredNoteID = nil
            onHover(nil, nil)
        }
    }

    @objc private func clearHistory() { onClear() }
}

/// The title shown for a completed note: its first line with text, without a list marker.
enum HistoryNoteTitle {
    private static let markers: Set<Character> = ["☐", "☑", "•", "∘", "▪", "◦", "○"]

    static func title(for text: String) -> String {
        for rawLine in text.split(whereSeparator: \.isNewline) {
            var line = String(rawLine).replacingOccurrences(of: "\u{FFFC}", with: "🖼")
            if let first = line.first, markers.contains(first), line.dropFirst().first == " " {
                line = String(line.dropFirst(2))
            }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !isDivider(trimmed) else { continue }
            return trimmed
        }
        return "空白便签"
    }

    private static func isDivider(_ line: String) -> Bool {
        guard line.count >= 3, let first = line.first, "-*_".contains(first) else { return false }
        return line.allSatisfy { $0 == first }
    }
}

private final class FlippedHistoryDocumentView: NSView {
    override var isFlipped: Bool { true }
}

/// A completed note drawn as a small note of its own color, with 恢复 and delete buttons.
@MainActor
private final class HistoryNoteRowView: NSView {
    let note: StickyNote
    private let onRestore: (UUID) -> Void
    private let onDelete: (UUID) -> Void
    private let onHover: (HistoryNoteRowView, Bool) -> Void
    private var isHovered = false { didSet { updateBorder() } }

    init(
        note: StickyNote,
        onRestore: @escaping (UUID) -> Void,
        onDelete: @escaping (UUID) -> Void,
        onHover: @escaping (HistoryNoteRowView, Bool) -> Void
    ) {
        self.note = note
        self.onRestore = onRestore
        self.onDelete = onDelete
        self.onHover = onHover
        super.init(frame: .zero)
        // Rows are light paper whatever the system appearance.
        appearance = NSAppearance(named: .aqua)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = note.color.background.cgColor
        layer?.borderWidth = 1
        updateBorder()

        let title = NSTextField(labelWithString: HistoryNoteTitle.title(for: note.text))
        title.font = .systemFont(ofSize: 13, weight: .medium)
        title.textColor = NoteAppearance.textColor
        title.lineBreakMode = .byTruncatingTail
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let completed = NSTextField(labelWithString: Self.formattedDate(note.completedAt))
        completed.font = .systemFont(ofSize: 11)
        completed.textColor = NSColor.black.withAlphaComponent(0.5)
        completed.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let labels = NSStackView(views: [title, completed])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 3
        labels.translatesAutoresizingMaskIntoConstraints = false
        labels.setContentHuggingPriority(.defaultLow, for: .horizontal)
        addSubview(labels)

        let restore = HistoryRestoreButton(accent: note.color.accent, target: self, action: #selector(restoreNote))
        restore.toolTip = "恢复便签"
        restore.setAccessibilityLabel("恢复便签")
        addSubview(restore)

        let delete = HistoryDeleteButton(target: self, action: #selector(deleteNote))
        delete.toolTip = "删除"
        delete.setAccessibilityLabel("删除便签")
        addSubview(delete)

        NSLayoutConstraint.activate([
            labels.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            labels.centerYAnchor.constraint(equalTo: centerYAnchor),
            labels.trailingAnchor.constraint(lessThanOrEqualTo: restore.leadingAnchor, constant: -8),
            restore.trailingAnchor.constraint(equalTo: delete.leadingAnchor, constant: -4),
            restore.centerYAnchor.constraint(equalTo: centerYAnchor),
            restore.widthAnchor.constraint(equalToConstant: 52),
            restore.heightAnchor.constraint(equalToConstant: 24),
            delete.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            delete.centerYAnchor.constraint(equalTo: centerYAnchor),
            delete.widthAnchor.constraint(equalToConstant: 26),
            delete.heightAnchor.constraint(equalToConstant: 26)
        ])

        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    required init?(coder: NSCoder) { nil }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        onHover(self, true)
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        onHover(self, false)
    }

    private func updateBorder() {
        layer?.borderColor = note.color.accent.withAlphaComponent(isHovered ? 0.55 : 0.18).cgColor
    }

    @objc private func restoreNote() { onRestore(note.id) }
    @objc private func deleteNote() { onDelete(note.id) }

    private static func formattedDate(_ date: Date?) -> String {
        guard let date else { return "完成时间未知" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh-Hans")
        formatter.setLocalizedDateFormatFromTemplate("MMMdjm")
        return formatter.string(from: date)
    }
}

/// 恢复: a small white capsule with the note's accent color.
private final class HistoryRestoreButton: NSButton {
    private static let label = "恢复"
    private let accent: NSColor
    private var isHovered = false { didSet { needsDisplay = true } }

    init(accent: NSColor, target: AnyObject, action: Selector) {
        self.accent = accent
        super.init(frame: .zero)
        self.target = target
        self.action = action
        // Drawn below; an empty title keeps AppKit from drawing a second one on top.
        title = ""
        isBordered = false
        focusRingType = .none
        translatesAutoresizingMaskIntoConstraints = false
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    required init?(coder: NSCoder) { nil }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    // The popover's translucent background would otherwise wash the capsule out to white.
    override var allowsVibrancy: Bool { false }
    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }

    override func draw(_ dirtyRect: NSRect) {
        let capsule = NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2)
        NSColor.white.withAlphaComponent(isHighlighted ? 0.95 : (isHovered ? 0.8 : 0.55)).setFill()
        capsule.fill()
        accent.withAlphaComponent(isHovered ? 0.5 : 0.3).setStroke()
        let outline = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
            xRadius: bounds.height / 2 - 0.5,
            yRadius: bounds.height / 2 - 0.5
        )
        outline.lineWidth = 1
        outline.stroke()
        let label = NSAttributedString(string: Self.label, attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: accent
        ])
        let size = label.size()
        label.draw(at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2))
    }
}

/// Delete: a quiet trash icon that turns red under the mouse.
private final class HistoryDeleteButton: NSButton {
    private var isHovered = false { didSet { refresh() } }

    init(target: AnyObject, action: Selector) {
        super.init(frame: .zero)
        self.target = target
        self.action = action
        let configuration = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        image = NSImage(systemSymbolName: "trash", accessibilityDescription: "删除便签")?
            .withSymbolConfiguration(configuration)
        imagePosition = .imageOnly
        imageScaling = .scaleNone
        isBordered = false
        focusRingType = .none
        translatesAutoresizingMaskIntoConstraints = false
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
        refresh()
    }

    required init?(coder: NSCoder) { nil }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var allowsVibrancy: Bool { false }
    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }

    override func draw(_ dirtyRect: NSRect) {
        if isHovered {
            NSColor.systemRed.withAlphaComponent(0.12).setFill()
            NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1)).fill()
        }
        super.draw(dirtyRect)
    }

    private func refresh() {
        contentTintColor = isHovered ? .systemRed : NSColor.black.withAlphaComponent(0.42)
        needsDisplay = true
    }
}
