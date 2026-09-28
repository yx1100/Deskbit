import AppKit

@MainActor
final class StickyWindowController: NSWindowController, NSWindowDelegate, NSTextViewDelegate, StickyToolbarDelegate {
    private var note: StickyNote
    private let rootView: StickyRootView
    private let windowResidency: StickyWindowResidency
    private var isApplyingMarkdown = false
    weak var appController: AppController?
    var isPinned: Bool { note.isPinned }

    init(note: StickyNote) {
        self.note = note
        rootView = StickyRootView(note: note)
        let residentWindow = StickyWindow(
            contentRect: note.frame.rect,
            styleMask: [.borderless, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        windowResidency = StickyWindowResidency(residentWindow: residentWindow)
        super.init(window: residentWindow)
        configureWindow(residentWindow)
        residentWindow.contentView = rootView
        rootView.toolbar.delegate = self
        rootView.footer.delegate = self
        rootView.textView.delegate = self
        rootView.textView.onToggleBold = { [weak self] in self?.didTapBold() }
        rootView.textView.onToggleBulletList = { [weak self] in self?.didTapBulletList() }
        rootView.textView.onToggleOrderedList = { [weak self] in self?.didTapOrderedList() }
        rootView.textView.onToggleTodo = { [weak self] in self?.didTapTodo() }
        rootView.textView.onEditLink = { [weak self] in self?.didTapLink() }
        rootView.textView.onToggleTodoMarker = { [weak self] index in self?.toggleTodoMarker(at: index) }
        rootView.textView.onStructuredNewline = { [weak self] in
            guard let self else { return false }
            return RichTextFormatting.handleStructuredNewline(in: self.rootView.textView)
        }
        rootView.textView.onAdjustBulletLevel = { [weak self] delta in
            guard let self else { return false }
            let changed = RichTextFormatting.adjustBulletLevel(in: self.rootView.textView, delta: delta)
            if changed { self.rootView.textView.didChangeText() }
            return changed
        }
        rootView.textView.onDeleteBackward = { [weak self] in
            guard let self else { return false }
            return RichTextFormatting.handleMarkerBackspace(in: self.rootView.textView)
        }
        let repairedBullets = RichTextFormatting.normalizeBulletMarkers(in: rootView.textView)
        let repairedTodos = RichTextFormatting.normalizeTodoMarkers(in: rootView.textView)
        if repairedBullets || repairedTodos {
            self.note.text = rootView.textView.string
            self.note.richTextData = rootView.textView.textStorage.flatMap(RichTextCodec.encode)
            NoteStore.shared.update(self.note)
        }
        applyPinState()
        updateFormattingState()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func close() {
        windowResidency.closeAll()
    }

    func showAndFocus() {
        note.isHidden = false
        NoteStore.shared.update(note)
        window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKey()
        window?.makeFirstResponder(rootView.textView)
    }

    /// Brings the note onto the current desktop (Space) and back on screen.
    func gatherToCurrentDesktop() {
        guard let window else { return }
        note.isHidden = false
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(window.frame) }),
           let visible = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame {
            let size = window.frame.size
            window.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2))
        }
        if note.isPinned {
            // Pinned notes already appear on every desktop.
            window.makeKeyAndOrderFront(nil)
        } else {
            let behavior = window.collectionBehavior
            window.collectionBehavior = behavior.union(.moveToActiveSpace)
            window.makeKeyAndOrderFront(nil)
            DispatchQueue.main.async { [weak window] in window?.collectionBehavior = behavior }
        }
        note.frame = WindowFrame(window.frame)
        NoteStore.shared.update(note)
    }

    func windowDidMove(_ notification: Notification) {
        guard let frame = window?.frame else { return }
        if appController?.shouldDeferFramePersistence(for: note.id) != true {
            saveFrame(frame)
        }
        appController?.noteWindowDidMove(id: note.id, frame: frame)
    }
    func windowDidResize(_ notification: Notification) { saveFrame() }

    func windowDidResignKey(_ notification: Notification) {
        // Unpinned notes use the normal macOS window ordering. Losing keyboard
        // focus must not force the note behind every other window.
    }

    func textDidChange(_ notification: Notification) {
        if !isApplyingMarkdown {
            isApplyingMarkdown = true
            _ = RichTextFormatting.applyMarkdownSyntax(in: rootView.textView)
            isApplyingMarkdown = false
        }
        persistText()
        updateFormattingState()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        updateFormattingState()
    }

    func didChooseColor(_ color: NoteColor) {
        note.color = color
        rootView.updateColor(color)
        rootView.toolbar.update(color: color, isPinned: note.isPinned)
        NoteStore.shared.update(note)
    }

    func didTapArrange() { appController?.arrangeNotes() }

    func didBeginToolbarDrag(with event: NSEvent) {
        appController?.beginDragging(noteID: note.id, event: event)
    }

    func didTapBold() {
        let textView = rootView.textView
        RichTextFormatting.toggleBold(in: textView)
        textView.didChangeText()
        window?.makeFirstResponder(textView)
    }

    func didTapBulletList() {
        let textView = rootView.textView
        RichTextFormatting.toggleBulletList(in: textView)
        textView.didChangeText()
        window?.makeFirstResponder(textView)
    }

    func didTapOrderedList() {
        let textView = rootView.textView
        RichTextFormatting.toggleOrderedList(in: textView)
        textView.didChangeText()
        window?.makeFirstResponder(textView)
    }

    func didTapTodo() {
        let textView = rootView.textView
        RichTextFormatting.toggleTodo(in: textView)
        textView.didChangeText()
        window?.makeFirstResponder(textView)
    }

    func didTapLink() {
        let textView = rootView.textView
        window?.makeFirstResponder(textView)
        NoteLinks.editLink(in: textView)
    }

    func didTapImage() {
        let textView = rootView.textView
        window?.makeFirstResponder(textView)
        NoteImages.chooseImages(into: textView)
    }

    func didTapNew() {
        guard let window else {
            appController?.createNote()
            return
        }
        let sourceFrame = window.frame
        let targetScreen = window.screen ?? NSScreen.screens.max { first, second in
            let firstIntersection = first.visibleFrame.intersection(sourceFrame)
            let secondIntersection = second.visibleFrame.intersection(sourceFrame)
            return firstIntersection.width * firstIntersection.height < secondIntersection.width * secondIntersection.height
        }
        guard let visibleFrame = targetScreen?.visibleFrame else {
            appController?.createNote()
            return
        }
        appController?.createNote(near: sourceFrame, in: visibleFrame)
    }

    func didTapPin() {
        if let appController {
            appController.togglePin(noteID: note.id)
            return
        }
        setPinned(!note.isPinned, focus: true)
    }

    func setPinned(_ isPinned: Bool, focus: Bool) {
        guard note.isPinned != isPinned else { return }
        let wasPinned = note.isPinned
        note.isPinned = isPinned
        applyPinState(previouslyPinned: wasPinned, focusWhenPinned: focus)
        NoteStore.shared.update(note)
    }

    func didTapComplete() {
        let id = note.id
        window?.orderOut(nil)
        appController?.completeNote(id: id)
    }

    private func applyPinState(previouslyPinned: Bool? = nil, focusWhenPinned: Bool = false) {
        let isBecomingPinned = previouslyPinned == false && note.isPinned
        let isBecomingUnpinned = previouslyPinned == true && !note.isPinned

        if note.isPinned, windowResidency.pinnedWindow == nil {
            let proxyWindow = windowResidency.beginPinnedPresentation { [unowned self] in
                let window = StickyWindow(
                    contentRect: self.windowResidency.residentWindow.frame,
                    styleMask: [.borderless, .resizable, .fullSizeContentView],
                    backing: .buffered,
                    defer: false
                )
                self.configureWindow(window)
                return window
            }
            self.window = proxyWindow
        } else if !note.isPinned, windowResidency.pinnedWindow != nil {
            self.window = windowResidency.endPinnedPresentation()
        }

        if let window {
            StickyWindowPresentation.apply(isPinned: note.isPinned, to: window)
        }
        rootView.toolbar.update(color: note.color, isPinned: note.isPinned)
        if isBecomingPinned {
            window?.orderFrontRegardless()
            if focusWhenPinned {
                window?.makeKey()
                window?.makeFirstResponder(rootView.textView)
            }
        } else if isBecomingUnpinned {
            window?.orderBack(nil)
        }
    }

    func move(to frame: NSRect) {
        guard let window else { return }
        window.minSize = NSSize(
            width: min(window.minSize.width, frame.width),
            height: min(window.minSize.height, frame.height)
        )
        window.setFrame(frame, display: true, animate: true)
        note.frame = WindowFrame(frame)
        NoteStore.shared.update(note)
    }

    func arrangeOnDesktop(to frame: NSRect) {
        guard let window else { return }
        let wasPinned = note.isPinned
        note.isPinned = false
        if wasPinned {
            applyPinState(previouslyPinned: true)
        } else {
            StickyWindowPresentation.apply(isPinned: false, to: window)
            rootView.toolbar.update(color: note.color, isPinned: false)
        }
        move(to: frame)
        self.window?.orderBack(nil)
    }

    func performWindowDrag(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    func updateSelection(_ isSelected: Bool) {
        rootView.updateSelection(isSelected)
    }

    func captureCurrentFrame() -> WindowFrame? {
        guard let frame = window?.frame else { return nil }
        note.frame = WindowFrame(frame)
        return note.frame
    }

    private func persistText() {
        note.text = rootView.textView.string
        if let storage = rootView.textView.textStorage {
            note.richTextData = RichTextCodec.encode(storage)
        }
        NoteStore.shared.update(note)
    }

    /// A click on a to-do circle checks or unchecks that item.
    private func toggleTodoMarker(at index: Int) {
        let textView = rootView.textView
        guard RichTextFormatting.toggleTodoCompletion(atParagraphStart: index, in: textView) else { return }
        window?.makeFirstResponder(textView)
        updateFormattingState()
    }

    private func updateFormattingState() {
        let textView = rootView.textView
        rootView.footer.updateFormatting(
            isBold: RichTextFormatting.isBold(in: textView),
            isBulletList: RichTextFormatting.isBulletList(in: textView),
            isOrderedList: RichTextFormatting.isOrderedList(in: textView),
            isTodoItem: RichTextFormatting.todoState(in: textView) != .plain
        )
    }

    private func saveFrame() {
        guard let frame = window?.frame else { return }
        saveFrame(frame)
    }

    private func saveFrame(_ frame: NSRect) {
        note.frame = WindowFrame(frame)
        NoteStore.shared.update(note)
    }

    private func configureWindow(_ window: StickyWindow) {
        window.delegate = self
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.minSize = NoteAppearance.minimumSize
        window.isMovableByWindowBackground = false
        window.animationBehavior = .utilityWindow
    }

}
