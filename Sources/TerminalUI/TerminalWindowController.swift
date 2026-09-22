import AppKit

/// Terminal penceresi: başlık çubuğuna sağ tık → oturum menüsü (içerik alanı yapıştırma olarak kalır).
final class TerminalSessionWindow: NSWindow {
    var onTitlebarRightClick: ((NSEvent) -> Void)?

    override func sendEvent(_ event: NSEvent) {
        let right = event.type == .rightMouseDown
        let ctrlClick = event.type == .leftMouseDown && event.modifierFlags.contains(.control)
        if (right || ctrlClick), isTitlebarEvent(event) {
            onTitlebarRightClick?(event)
            return
        }
        super.sendEvent(event)
    }

    private func isTitlebarEvent(_ event: NSEvent) -> Bool {
        let loc = event.locationInWindow
        guard let cv = contentView else { return false }
        let contentRect = cv.convert(cv.bounds, to: nil)
        if contentRect.contains(loc) { return false }
        // Trafik ışıkları: native menüyü bozma.
        if loc.x < 78 { return false }
        return loc.y >= contentRect.maxY - 1
    }
}

final class TerminalWindowController: NSWindowController, NSWindowDelegate, NSMenuItemValidation {
    let config: SessionConfig
    let termView: TerminalView
    let emulator: TerminalEmulator
    let eventLog: EventLogController
    private var engine: ConnectionEngine?
    private var logger: SessionLogger?
    private var closedClean = false
    var onClosed: (() -> Void)?
    private var changeCtl: ConfigWindowController?

    init(config: SessionConfig) {
        self.config = config
        self.emulator = TerminalEmulator(config: config)
        self.termView = TerminalView(emulator: emulator, config: config)
        self.eventLog = EventLogController(title: String(format: L.t("log.window"), config.displayTitle()))
        let size = termView.intrinsicTerminalSize()
        let style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        let win = TerminalSessionWindow(contentRect: NSRect(origin: .zero, size: size),
                                        styleMask: style, backing: .buffered, defer: false)
        win.title = String(format: L.t("term.title"), config.displayTitle())
        win.isReleasedWhenClosed = false
        win.titlebarSeparatorStyle = .line
        win.tabbingMode = .automatic
        win.backgroundColor = config.colours[2].nsColor
        win.isOpaque = true
        win.hasShadow = true
        super.init(window: win)
        win.delegate = self
        win.onTitlebarRightClick = { [weak self] event in
            self?.popTitlebarMenu(event)
        }
        win.contentView = termView
        win.setContentSize(size)
        win.contentResizeIncrements = termView.cellSize
        win.contentMinSize = NSSize(width: termView.cellSize.width * 2 + 12,
                                    height: termView.cellSize.height * 2 + 12)
        if config.alwaysOnTop { win.level = .floating }
        termView.frame = win.contentView?.bounds ?? NSRect(origin: .zero, size: size)
        termView.autoresizingMask = [.width, .height]
        termView.onInput = { [weak self] data in self?.engine?.send(data) }
        emulator.onTitle = { [weak self] t in
            DispatchQueue.main.async { self?.window?.title = t }
        }
        emulator.onResize = { [weak self] c, r in
            self?.engine?.resize(cols: c, rows: r)
        }
        emulator.onWrite = { [weak self] d in self?.engine?.send(d) }
        if config.logType != .none {
            logger = SessionLogger(config: config)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func start() {
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(termView)
        window?.contentResizeIncrements = termView.cellSize
        syncTerminalSize()
        config.width = emulator.cols
        config.height = emulator.rows
        log("Connecting to \(config.displayTitle())...")
        engine = ConnectionEngine(config: config)
        engine?.onData = { [weak self] data in
            DispatchQueue.main.async {
                self?.termView.feed(data)
                self?.logger?.writeSession(data)
            }
        }
        engine?.onLog = { [weak self] s in
            DispatchQueue.main.async { self?.log(s) }
        }
        engine?.onClose = { [weak self] clean, error in
            DispatchQueue.main.async { self?.handleClose(clean: clean, error: error) }
        }
        engine?.connect()
        engine?.resize(cols: emulator.cols, rows: emulator.rows)
    }

    private func syncTerminalSize() {
        let s = window?.contentView?.bounds.size ?? termView.bounds.size
        termView.applyResize(to: s)
        engine?.resize(cols: emulator.cols, rows: emulator.rows)
    }

    private func log(_ s: String) {
        eventLog.append(s)
    }

    private func handleClose(clean: Bool, error: String?) {
        closedClean = clean
        if let error {
            termView.feed(("\r\n" + error + "\r\n").data(using: .utf8)!)
            log(error)
        } else {
            termView.feed(("\r\n" + L.t("term.disconnected") + "\r\n").data(using: .utf8)!)
        }
        switch config.closeOnExit {
        case .always: window?.close()
        case .clean:
            if clean { window?.close() }
        case .never: break
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if config.warnOnClose, engine?.isConnected == true {
            let a = NSAlert()
            a.alertStyle = .warning
            a.messageText = L.t("beh.warnPrompt")
            a.addButton(withTitle: L.t("btn.ok"))
            a.addButton(withTitle: L.t("btn.cancel"))
            if a.runModal() != .alertFirstButtonReturn { return false }
        }
        engine?.close()
        return true
    }

    func windowWillClose(_ notification: Notification) {
        engine?.close()
        logger?.close()
        onClosed?()
    }

    func windowDidResize(_ notification: Notification) {
        syncTerminalSize()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        syncTerminalSize()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool { true }

    @objc func showEventLog(_ sender: Any?) { eventLog.showWindow(nil) }
    @objc func resetTerminal(_ sender: Any?) { emulator.reset(); termView.needsDisplay = true }
    @objc func clearScrollback(_ sender: Any?) {
        termView.scrollOffset = 0
        emulator.clearScrollback()
        termView.needsDisplay = true
    }
    @objc func changeSettings(_ sender: Any?) {
        let c = ConfigWindowController(config: config.clone(), applyMode: true)
        c.onOpen = { [weak self] cfg in
            guard let self else { return }
            self.config.apply(from: cfg)
        }
        c.present()
        changeCtl = c
    }
    @objc func restartSession(_ sender: Any?) {
        engine?.close()
        start()
    }

    @objc func titlebarNewSession(_ sender: Any?) {
        AppDelegate.shared.newSession(sender)
    }

    @objc func titlebarDuplicateSession(_ sender: Any?) {
        AppDelegate.shared.openSession(config.clone())
    }

    private func popTitlebarMenu(_ event: NSEvent) {
        window?.makeKeyAndOrderFront(nil)
        let menu = NSMenu()
        let newItem = NSMenuItem(title: L.t("menu.new"), action: #selector(titlebarNewSession(_:)), keyEquivalent: "n")
        newItem.target = self
        let dupItem = NSMenuItem(title: L.t("menu.dup"), action: #selector(titlebarDuplicateSession(_:)), keyEquivalent: "")
        dupItem.target = self
        let restartItem = NSMenuItem(title: L.t("menu.restart"), action: #selector(restartSession(_:)), keyEquivalent: "")
        restartItem.target = self
        menu.addItem(newItem)
        menu.addItem(dupItem)
        menu.addItem(.separator())
        menu.addItem(restartItem)
        NSMenu.popUpContextMenu(menu, with: event, for: termView)
    }

    @objc func findText(_ sender: Any?) {
        let a = NSAlert()
        a.messageText = L.t("find.title")
        a.informativeText = L.t("find.prompt")
        a.addButton(withTitle: L.t("btn.ok"))
        a.addButton(withTitle: L.t("btn.cancel"))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 22))
        a.accessoryView = field
        DispatchQueue.main.async { a.window.makeFirstResponder(field) }
        guard a.runModal() == .alertFirstButtonReturn else { return }
        let needle = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return }
        if !emulator.allText().localizedCaseInsensitiveContains(needle) {
            Dialogs.alert(L.t("find.none"))
        }
    }
}

final class SessionLogger {
    private var handle: FileHandle?
    init(config: SessionConfig) {
        let name = SessionLogger.expand(config.logFileName)
        let url = URL(fileURLWithPath: (name as NSString).expandingTildeInPath)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        handle = try? FileHandle(forWritingTo: url)
        if config.logOverlap != 1 {
            try? handle?.truncate(atOffset: 0)
        } else {
            _ = try? handle?.seekToEnd()
        }
        if config.logHeader {
            let h = "==== BLM-TTY session log \(Date()) ====\n"
            try? handle?.write(contentsOf: h.data(using: .utf8)!)
        }
    }
    func writeSession(_ data: Data) {
        try? handle?.write(contentsOf: data)
    }
    func close() { try? handle?.close() }

    static func expand(_ s: String) -> String {
        let f = DateFormatter()
        var out = s
        let map: [(String, String)] = [
            ("&Y", "yyyy"), ("&M", "MM"), ("&D", "dd"), ("&T", "HHmmss"), ("&h", "HH")
        ]
        let now = Date()
        for (k, fmt) in map {
            f.dateFormat = fmt
            out = out.replacingOccurrences(of: k, with: f.string(from: now))
        }
        return out
    }
}
