import AppKit

@MainActor
protocol StickyToolbarDelegate: AnyObject {
    func didChooseColor(_ color: NoteColor)
    func didTapArrange()
    func didBeginToolbarDrag(with event: NSEvent)
    func didTapBold()
    func didTapBulletList()
    func didTapTodo()
    func didTapLink()
    func didTapImage()
    func didTapNew()
    func didTapPin()
    func didTapComplete()
}

final class ColorDotButton: NSButton {
    let noteColor: NoteColor
    var selectedColor = false {
        didSet {
            state = selectedColor ? .on : .off
            setAccessibilityValue(selectedColor ? 1 : 0)
            needsDisplay = true
        }
    }

    init(color: NoteColor) {
        noteColor = color
        super.init(frame: .zero)
        isBordered = false
        setButtonType(.radio)
        title = ""
        toolTip = color.title
        setAccessibilityLabel(color.title)
    }

    required init?(coder: NSCoder) { nil }
    override var intrinsicContentSize: NSSize { NSSize(width: 18, height: 38) }
    var outlineWidth: CGFloat { selectedColor ? 0 : 0.5 }
    var dotDiameter: CGFloat { selectedColor ? 14 : 12 }
    var haloDiameter: CGFloat { selectedColor ? 18 : 0 }

    override func draw(_ dirtyRect: NSRect) {
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        if selectedColor {
            let halo = NSRect(
                x: center.x - haloDiameter / 2,
                y: center.y - haloDiameter / 2,
                width: haloDiameter,
                height: haloDiameter
            )
            noteColor.swatch.withAlphaComponent(0.22).setFill()
            NSBezierPath(ovalIn: halo).fill()
        }
        let circle = NSRect(
            x: center.x - dotDiameter / 2,
            y: center.y - dotDiameter / 2,
            width: dotDiameter,
            height: dotDiameter
        )
        noteColor.swatch.setFill()
        NSBezierPath(ovalIn: circle).fill()
        if outlineWidth > 0 {
            NSColor.black.withAlphaComponent(0.12).setStroke()
            let outline = NSBezierPath(ovalIn: circle.insetBy(dx: outlineWidth / 2, dy: outlineWidth / 2))
            outline.lineWidth = outlineWidth
            outline.stroke()
        }
    }
}

final class StickyToolbarView: NSView {
    weak var delegate: StickyToolbarDelegate?
    private let stack = NSStackView()
    private var colorButtons: [ColorDotButton] = []
    private var pinButton: NSButton!

    init(color: NoteColor, isPinned: Bool) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        stack.addArrangedSubview(iconButton("rectangle.3.group", tip: "自动排序便签", action: #selector(arrangeNotes)))

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(spacer)

        for item in NoteColor.allCases {
            let button = ColorDotButton(color: item)
            button.target = self
            button.action = #selector(selectColor(_:))
            button.selectedColor = item == color
            colorButtons.append(button)
            stack.addArrangedSubview(button)
        }

        stack.addArrangedSubview(iconButton("plus", tip: "新建便签", action: #selector(newNote)))
        pinButton = iconButton(isPinned ? "pin.fill" : "pin", tip: "置顶", action: #selector(togglePin))
        stack.addArrangedSubview(pinButton)
        stack.addArrangedSubview(iconButton("checkmark", tip: "完成", action: #selector(completeNoteButton)))

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 40),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { nil }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let hit = super.hitTest(point) else { return nil }
        var candidate: NSView? = hit
        while let view = candidate, view !== self {
            if view is NSControl { return hit }
            candidate = view.superview
        }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        delegate?.didBeginToolbarDrag(with: event)
    }

    private func iconButton(_ symbol: String, tip: String, action: Selector) -> NSButton {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip) ?? NSImage(size: NSSize(width: 16, height: 16))
        let button = NSButton(image: image, target: self, action: action)
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.contentTintColor = NSColor.black.withAlphaComponent(0.58)
        button.toolTip = tip
        button.setAccessibilityLabel(tip)
        button.widthAnchor.constraint(equalToConstant: 34).isActive = true
        return button
    }

    func update(color: NoteColor, isPinned: Bool) {
        colorButtons.forEach { $0.selectedColor = $0.noteColor == color }
        let pinTitle = isPinned ? "取消置顶" : "置顶"
        pinButton.image = NSImage(systemSymbolName: isPinned ? "pin.fill" : "pin", accessibilityDescription: pinTitle)
        pinButton.toolTip = pinTitle
        pinButton.setAccessibilityLabel(pinTitle)
        pinButton.contentTintColor = isPinned ? NSColor.black.withAlphaComponent(0.82) : NSColor.black.withAlphaComponent(0.58)
    }

    @objc private func selectColor(_ sender: ColorDotButton) { delegate?.didChooseColor(sender.noteColor) }
    @objc private func arrangeNotes() { delegate?.didTapArrange() }
    @objc private func newNote() { delegate?.didTapNew() }
    @objc private func togglePin() { delegate?.didTapPin() }
    @objc private func completeNoteButton() { delegate?.didTapComplete() }
}

final class StickyFormattingFooterView: NSView {
    weak var delegate: StickyToolbarDelegate?
    let statusLabel = NSTextField(labelWithString: "已保存")
    private let boldButton: NSButton
    private let bulletButton: NSButton
    private let todoButton: NSButton
    private let linkButton: NSButton
    private let imageButton: NSButton

    override init(frame frameRect: NSRect) {
        boldButton = Self.makeButton(symbol: "bold", tip: "加粗（⌘B）", action: #selector(toggleBold))
        bulletButton = Self.makeButton(symbol: "list.bullet", tip: "项目符号（⌘⇧8；Tab / Shift+Tab 调整级别）", action: #selector(toggleBullet))
        todoButton = Self.makeButton(
            symbol: "checklist",
            fallbackSymbol: "checkmark.circle",
            tip: "待办事项（⌘⇧X）",
            action: #selector(toggleTodo)
        )
        linkButton = Self.makeButton(symbol: "link", tip: "链接（⌘K）", action: #selector(editLink))
        imageButton = Self.makeButton(symbol: "photo", tip: "插入图片（也可直接粘贴或拖入）", action: #selector(insertImage))
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [boldButton, bulletButton, todoButton, linkButton, imageButton])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        boldButton.target = self
        bulletButton.target = self
        todoButton.target = self
        linkButton.target = self
        imageButton.target = self
        linkButton.setButtonType(.momentaryChange)
        imageButton.setButtonType(.momentaryChange)
        linkButton.contentTintColor = NSColor.black.withAlphaComponent(0.50)
        imageButton.contentTintColor = NSColor.black.withAlphaComponent(0.50)
        statusLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        statusLabel.textColor = NSColor.black.withAlphaComponent(0.42)
        statusLabel.alignment = .right
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 32),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: stack.trailingAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -11),
            statusLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { nil }

    func updateFormatting(isBold: Bool, isBulletList: Bool, isTodoItem: Bool) {
        update(button: boldButton, active: isBold)
        update(button: bulletButton, active: isBulletList)
        update(button: todoButton, active: isTodoItem)
    }

    private static func makeButton(symbol: String, fallbackSymbol: String? = nil, tip: String, action: Selector) -> NSButton {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: tip)
            ?? fallbackSymbol.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: tip) }
            ?? NSImage(size: NSSize(width: 15, height: 15))
        let button = NSButton(image: image, target: nil, action: action)
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.setButtonType(.toggle)
        button.toolTip = tip
        button.setAccessibilityLabel(tip)
        button.widthAnchor.constraint(equalToConstant: 30).isActive = true
        button.heightAnchor.constraint(equalToConstant: 26).isActive = true
        return button
    }

    private func update(button: NSButton, active: Bool) {
        button.state = active ? .on : .off
        button.contentTintColor = NSColor.black.withAlphaComponent(active ? 0.88 : 0.50)
    }

    @objc private func toggleBold() { delegate?.didTapBold() }
    @objc private func toggleBullet() { delegate?.didTapBulletList() }
    @objc private func toggleTodo() { delegate?.didTapTodo() }
    @objc private func editLink() { delegate?.didTapLink() }
    @objc private func insertImage() { delegate?.didTapImage() }
}

enum StickyEditingShortcut: Equatable {
    case copy, cut, paste, selectAll

    static func command(for modifiers: NSEvent.ModifierFlags, key: String?) -> StickyEditingShortcut? {
        guard modifiers == [.command] else { return nil }
        switch key {
        case "c": return .copy
        case "x": return .cut
        case "v": return .paste
        case "a": return .selectAll
        default: return nil
        }
    }
}

final class StickyTextView: NSTextView {
    var onToggleBold: (() -> Void)?
    var onToggleBulletList: (() -> Void)?
    var onToggleTodo: (() -> Void)?
    var onEditLink: (() -> Void)?
    var onStructuredNewline: (() -> Bool)?
    var onAdjustBulletLevel: ((Int) -> Bool)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting(.capsLock)
        let key = event.charactersIgnoringModifiers?.lowercased()
        if modifiers == [.command], key == "b" {
            onToggleBold?()
            return true
        }
        let isBulletShortcut = modifiers == [.command, .shift] && (key == "8" || key == "*")
        if isBulletShortcut {
            onToggleBulletList?()
            return true
        }
        if modifiers == [.command, .shift], key == "x" {
            onToggleTodo?()
            return true
        }
        if modifiers == [.command], key == "k" {
            onEditLink?()
            return true
        }
        if let command = StickyEditingShortcut.command(for: modifiers, key: key) {
            switch command {
            case .copy: copy(nil)
            case .cut: cut(nil)
            case .paste: paste(nil)
            case .selectAll: selectAll(nil)
            }
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func insertNewline(_ sender: Any?) {
        if onStructuredNewline?() == true { return }
        super.insertNewline(sender)
    }

    override func insertTab(_ sender: Any?) {
        if onAdjustBulletLevel?(1) == true { return }
        super.insertTab(sender)
    }

    override func insertBacktab(_ sender: Any?) {
        if onAdjustBulletLevel?(-1) == true { return }
        super.insertBacktab(sender)
    }

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        let images = NoteImages.images(on: pasteboard)
        if !images.isEmpty, NoteImages.insert(images, into: self) { return }
        let start = selectedRange().location
        super.pasteAsPlainText(sender)
        let end = selectedRange().location
        NoteLinks.detectLinks(in: self, range: NSRange(location: start, length: max(0, end - start)))
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        let fileURLs = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []
        let point = convert(sender.draggingLocation, from: nil)
        let dropRange = NSRange(location: characterIndexForInsertion(at: point), length: 0)

        if !fileURLs.isEmpty {
            let imageURLs = NoteImages.imageFileURLs(on: pasteboard)
            if !imageURLs.isEmpty {
                return NoteImages.insert(imageURLs.compactMap(NSImage.init(contentsOf:)), into: self, replacing: dropRange)
            }
            // Other files become links so the note stays small.
            return insertFileLinks(fileURLs, at: dropRange)
        }

        // Images dragged from a browser; rich text drags keep the default behavior.
        let carriesRichText = pasteboard.availableType(from: [.rtf, .rtfd]) != nil
        if !carriesRichText,
           pasteboard.canReadObject(forClasses: [NSImage.self], options: nil),
           let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           !images.isEmpty {
            return NoteImages.insert(images, into: self, replacing: dropRange)
        }
        return super.performDragOperation(sender)
    }

    private func insertFileLinks(_ urls: [URL], at range: NSRange) -> Bool {
        guard let storage = textStorage else { return false }
        let insertion = NSMutableAttributedString()
        for (index, url) in urls.enumerated() {
            if index > 0 { insertion.append(NSAttributedString(string: " ", attributes: typingAttributes)) }
            var attributes = typingAttributes
            attributes[.link] = url
            insertion.append(NSAttributedString(string: url.lastPathComponent, attributes: attributes))
        }
        let safeRange = NSRange(location: min(range.location, storage.length), length: 0)
        guard shouldChangeText(in: safeRange, replacementString: insertion.string) else { return false }
        storage.replaceCharacters(in: safeRange, with: insertion)
        setSelectedRange(NSRange(location: safeRange.location + insertion.length, length: 0))
        didChangeText()
        return true
    }
}

final class StickyRootView: NSView {
    let toolbar: StickyToolbarView
    let footer = StickyFormattingFooterView()
    let textView = StickyTextView()
    var statusLabel: NSTextField { footer.statusLabel }
    private let divider = NSBox()
    private let footerDivider = NSBox()

    init(note: StickyNote) {
        toolbar = StickyToolbarView(color: note.color, isPinned: note.isPinned)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.masksToBounds = true
        updateColor(note.color)

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        // Touching the layout manager keeps the editor on TextKit 1, which sizes image attachment cells reliably.
        _ = textView.layoutManager
        textView.isRichText = true
        textView.importsGraphics = true
        textView.isAutomaticLinkDetectionEnabled = true
        textView.allowsUndo = true
        textView.font = NoteAppearance.bodyFont()
        textView.textColor = NSColor.black.withAlphaComponent(0.78)
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.textContainerInset = NSSize(width: 14, height: 12)
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]
        textView.setAccessibilityLabel("便签内容")
        if let restored = RichTextCodec.decode(note.richTextData) {
            textView.textStorage?.setAttributedString(restored)
            if let storage = textView.textStorage { NoteImages.fitAttachments(in: storage) }
        } else {
            textView.string = note.text
        }
        textView.typingAttributes = [
            .font: NoteAppearance.bodyFont(),
            .foregroundColor: NSColor.black.withAlphaComponent(0.78)
        ]
        scrollView.documentView = textView

        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        footerDivider.boxType = .separator
        footerDivider.translatesAutoresizingMaskIntoConstraints = false

        addSubview(toolbar)
        addSubview(divider)
        addSubview(scrollView)
        addSubview(footerDivider)
        addSubview(footer)

        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: trailingAnchor),
            toolbar.topAnchor.constraint(equalTo: topAnchor),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor),
            divider.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: divider.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: footerDivider.topAnchor),
            footerDivider.leadingAnchor.constraint(equalTo: leadingAnchor),
            footerDivider.trailingAnchor.constraint(equalTo: trailingAnchor),
            footerDivider.bottomAnchor.constraint(equalTo: footer.topAnchor),
            footer.leadingAnchor.constraint(equalTo: leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { nil }

    func updateColor(_ color: NoteColor) {
        layer?.backgroundColor = color.background.cgColor
    }

    func updateSelection(_ isSelected: Bool) {
        layer?.borderWidth = isSelected ? 3 : 0
        layer?.borderColor = isSelected ? NSColor.controlAccentColor.withAlphaComponent(0.9).cgColor : nil
    }
}
