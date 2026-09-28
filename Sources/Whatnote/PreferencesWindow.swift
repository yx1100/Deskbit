import AppKit
import Carbon.HIToolbox

/// Click to record: the next key press with ⌘, ⌥ or ⌃ becomes the shortcut.
/// Esc cancels recording, Delete clears the shortcut.
@MainActor
final class HotKeyRecorderView: NSView {
    var shortcut: HotKeyShortcut? { didSet { needsDisplay = true } }
    var onRecordingChanged: ((Bool) -> Void)?
    var onShortcutChanged: ((HotKeyShortcut?) -> Void)?
    private(set) var isRecording = false {
        didSet {
            guard oldValue != isRecording else { return }
            needsDisplay = true
            onRecordingChanged?(isRecording)
        }
    }

    init(shortcut: HotKeyShortcut?) {
        self.shortcut = shortcut
        super.init(frame: .zero)
        setAccessibilityRole(.button)
        setAccessibilityLabel("新建便签快捷键")
    }

    required init?(coder: NSCoder) { nil }

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 180, height: 28) }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    var displayText: String {
        if isRecording { return "请按下快捷键…" }
        return shortcut?.displayString ?? "未设置"
    }

    override func mouseDown(with event: NSEvent) {
        if isRecording {
            stopRecording()
        } else {
            window?.makeFirstResponder(self)
            isRecording = true
        }
    }

    override func resignFirstResponder() -> Bool {
        stopRecording()
        return super.resignFirstResponder()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording, window?.firstResponder === self else {
            return super.performKeyEquivalent(with: event)
        }
        handleRecordedKey(event)
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            if event.keyCode == UInt16(kVK_Space) || event.keyCode == UInt16(kVK_Return) {
                isRecording = true
            } else {
                super.keyDown(with: event)
            }
            return
        }
        handleRecordedKey(event)
    }

    func stopRecording() {
        isRecording = false
    }

    private func handleRecordedKey(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(HotKeyShortcut.supportedModifiers)
        if modifiers.isEmpty {
            switch Int(event.keyCode) {
            case kVK_Escape:
                stopRecording()
                return
            case kVK_Delete, kVK_ForwardDelete:
                shortcut = nil
                stopRecording()
                onShortcutChanged?(nil)
                return
            default:
                break
            }
        }
        let candidate = HotKeyShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        guard candidate.isValidGlobalShortcut else {
            NSSound.beep()
            return
        }
        shortcut = candidate
        stopRecording()
        onShortcutChanged?(candidate)
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        NSColor.textBackgroundColor.setFill()
        path.fill()
        (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = isRecording ? 2 : 1
        path.stroke()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: isRecording || shortcut == nil ? NSColor.secondaryLabelColor : NSColor.labelColor
        ]
        let text = displayText as NSString
        let size = text.size(withAttributes: attributes)
        text.draw(
            at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2),
            withAttributes: attributes
        )
    }
}

@MainActor
final class PreferencesViewController: NSViewController {
    /// Applies a shortcut and returns false when macOS rejects it.
    private let applyShortcut: (HotKeyShortcut?) -> Bool
    private let onRecordingChanged: (Bool) -> Void
    private let recorder: HotKeyRecorderView
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let launchCheckbox = NSButton(checkboxWithTitle: "登录 Mac 时自动启动随便记", target: nil, action: nil)
    private let launchHint = NSTextField(wrappingLabelWithString: "")
    private let openLoginItemsButton = NSButton(title: "打开系统设置…", target: nil, action: nil)

    init(
        shortcut: HotKeyShortcut?,
        applyShortcut: @escaping (HotKeyShortcut?) -> Bool,
        onRecordingChanged: @escaping (Bool) -> Void
    ) {
        self.applyShortcut = applyShortcut
        self.onRecordingChanged = onRecordingChanged
        recorder = HotKeyRecorderView(shortcut: shortcut)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 290))

        let title = NSTextField(labelWithString: "新建便签快捷键：")
        title.font = .systemFont(ofSize: 13, weight: .medium)

        recorder.translatesAutoresizingMaskIntoConstraints = false
        recorder.onRecordingChanged = { [weak self] isRecording in
            self?.onRecordingChanged(isRecording)
        }
        recorder.onShortcutChanged = { [weak self] shortcut in
            self?.commit(shortcut)
        }

        let resetButton = NSButton(title: "恢复默认", target: self, action: #selector(resetToDefault))
        resetButton.bezelStyle = .rounded

        let row = NSStackView(views: [title, recorder, resetButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(row)

        let hint = NSTextField(wrappingLabelWithString: "点击输入框后按下新的组合键（需包含 ⌘、⌥ 或 ⌃）。按 Esc 取消，按 Delete 清除快捷键。默认快捷键：\(HotKeyShortcut.defaultNewNote.displayString)")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(hint)

        statusLabel.font = .systemFont(ofSize: 11, weight: .medium)
        statusLabel.textColor = .systemRed
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(statusLabel)

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(separator)

        launchCheckbox.target = self
        launchCheckbox.action = #selector(toggleLaunchAtLogin)
        launchCheckbox.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(launchCheckbox)

        launchHint.font = .systemFont(ofSize: 11)
        launchHint.textColor = .secondaryLabelColor
        launchHint.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(launchHint)

        openLoginItemsButton.target = self
        openLoginItemsButton.action = #selector(openLoginItems)
        openLoginItemsButton.bezelStyle = .rounded
        openLoginItemsButton.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(openLoginItemsButton)

        NSLayoutConstraint.activate([
            recorder.widthAnchor.constraint(equalToConstant: 180),
            recorder.heightAnchor.constraint(equalToConstant: 28),
            row.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            row.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -20),
            row.topAnchor.constraint(equalTo: root.topAnchor, constant: 24),
            hint.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            hint.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            hint.topAnchor.constraint(equalTo: row.bottomAnchor, constant: 14),
            statusLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            statusLabel.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 10),
            separator.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            separator.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            separator.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            launchCheckbox.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            launchCheckbox.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -20),
            launchCheckbox.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 16),
            launchHint.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 38),
            launchHint.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            launchHint.topAnchor.constraint(equalTo: launchCheckbox.bottomAnchor, constant: 6),
            openLoginItemsButton.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 34),
            openLoginItemsButton.topAnchor.constraint(equalTo: launchHint.bottomAnchor, constant: 8),
            openLoginItemsButton.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -16)
        ])
        view = root
        refreshLaunchAtLogin()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        // The user may have changed it in System Settings meanwhile.
        refreshLaunchAtLogin()
    }

    func refreshLaunchAtLogin(error: String? = nil) {
        let state = LaunchAtLogin.state
        launchCheckbox.state = state == .enabled || state == .requiresApproval ? .on : .off
        launchCheckbox.isEnabled = state != .unsupported
        openLoginItemsButton.isHidden = state == .unsupported

        var hint: String
        switch state {
        case .unsupported:
            hint = "开机自启动需要 macOS 13 或更高版本。"
        case .requiresApproval:
            hint = "还需要在“系统设置 → 通用 → 登录项”中允许随便记。"
        case .enabled, .disabled:
            hint = "也可以在“系统设置 → 通用 → 登录项”中管理。"
        }
        if state != .unsupported, !LaunchAtLogin.isInApplicationsFolder {
            hint += "建议先把随便记拖到“应用程序”文件夹再开启，否则移动或重新构建后自启动可能失效。"
        }
        if let error {
            hint = "设置失败：\(error)"
        }
        launchHint.stringValue = hint
        launchHint.textColor = error == nil && state != .requiresApproval ? .secondaryLabelColor : .systemOrange
    }

    @objc private func toggleLaunchAtLogin() {
        let error = LaunchAtLogin.setEnabled(launchCheckbox.state == .on)
        refreshLaunchAtLogin(error: error)
    }

    @objc private func openLoginItems() {
        LaunchAtLogin.openSystemSettings()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        recorder.stopRecording()
    }

    func update(shortcut: HotKeyShortcut?) {
        recorder.shortcut = shortcut
        statusLabel.stringValue = ""
        refreshLaunchAtLogin()
    }

    @objc private func resetToDefault() {
        recorder.stopRecording()
        recorder.shortcut = .defaultNewNote
        commit(.defaultNewNote)
    }

    private func commit(_ shortcut: HotKeyShortcut?) {
        if applyShortcut(shortcut) {
            statusLabel.stringValue = ""
        } else {
            recorder.shortcut = HotKeyPreferences.newNoteShortcut()
            statusLabel.stringValue = "无法使用这个快捷键（可能已被系统或其他应用占用），请换一个组合。"
        }
    }
}
