import AppKit

final class ConfigWindowController: NSWindowController {
    let config: SessionConfig
    private var tree: WinTreeView!
    private var panelHost: NSView!
    private var currentPanel: ConfigPanel?
    private var currentId = "session"
    private var catLabel: WinLabel!
    private var aboutBtn: WinButton!
    private var helpBtn: WinButton!
    private var openBtn: WinButton!
    private var cancelBtn: WinButton!
    private var langCombo: WinComboBox!
    var onOpen: ((SessionConfig) -> Void)?
    var onCancel: (() -> Void)?
    private let applyMode: Bool

    init(config: SessionConfig? = nil, applyMode: Bool = false) {
        self.config = config ?? (SessionStore.shared.load(SessionStore.defaultName) ?? SessionConfig())
        self.applyMode = applyMode
        let win = WinChromeWindow(contentSize: NSSize(width: WinPalette.windowWidth, height: WinPalette.clientHeight))
        super.init(window: win)
        win.setTitleKey("win.title")
        win.onHelp = { [weak self] in self?.showHelp() }
        build(in: win.clientView)
        NotificationCenter.default.addObserver(self, selector: #selector(langChanged), name: .blmLanguageChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(configReloaded), name: Notification.Name("blmConfigReloaded"), object: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func build(in client: NSView) {
        let W = WinPalette.windowWidth
        let H = WinPalette.clientHeight
        let sideW = WinPalette.sidebarWidth
        let barH = WinPalette.bottomBarHeight
        let btnW = WinPalette.buttonW
        let btnH = WinPalette.buttonH
        let btnY = H - barH + (barH - btnH) / 2

        let sidebar = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: sideW, height: H))
        sidebar.material = .sidebar
        sidebar.blendingMode = .behindWindow
        sidebar.state = .followsWindowActiveState
        sidebar.wantsLayer = true
        client.addSubview(sidebar)

        let split = NSBox(frame: NSRect(x: sideW, y: 0, width: 1, height: H))
        split.boxType = .separator
        client.addSubview(split)

        catLabel = WinLabel(key: "cat.header", frame: NSRect(x: 14, y: 10, width: sideW - 20, height: 16))
        catLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        catLabel.textColor = .secondaryLabelColor
        client.addSubview(catLabel)

        tree = WinTreeView(frame: NSRect(x: 4, y: 28, width: sideW - 8, height: H - 28 - barH))
        tree.setRoot(ConfigCategory.tree())
        tree.onSelect = { [weak self] id in self?.showPanel(id) }
        client.addSubview(tree)

        let panelX: CGFloat = sideW + 14
        panelHost = DialogFaceView(frame: NSRect(x: panelX, y: 12, width: WinPalette.panelWidth, height: H - barH - 16))
        client.addSubview(panelHost)

        let bottomSep = NSBox(frame: NSRect(x: sideW, y: H - barH, width: W - sideW, height: 1))
        bottomSep.boxType = .separator
        client.addSubview(bottomSep)

        aboutBtn = WinButton(key: "btn.about", frame: NSRect(x: 10, y: btnY, width: 78, height: btnH))
        aboutBtn.target = self; aboutBtn.action = #selector(showAbout)
        client.addSubview(aboutBtn)

        helpBtn = WinButton(key: "btn.help", frame: NSRect(x: 92, y: btnY, width: 78, height: btnH))
        helpBtn.target = self; helpBtn.action = #selector(showHelp)
        client.addSubview(helpBtn)

        langCombo = WinComboBox(frame: NSRect(x: panelX, y: btnY, width: 118, height: btnH))
        langCombo.items = [("en", "lang.english"), ("tr", "lang.turkish")]
        langCombo.selectedIndex = L.language == .tr ? 1 : 0
        langCombo.onChange = { idx in
            L.setLanguage(idx == 1 ? .tr : .en)
        }
        client.addSubview(langCombo)

        openBtn = WinButton(key: applyMode ? "btn.apply" : "btn.open",
                            frame: NSRect(x: W - 16 - btnW, y: btnY, width: btnW, height: btnH),
                            defaultLook: true)
        openBtn.target = self; openBtn.action = #selector(openSession)
        client.addSubview(openBtn)

        cancelBtn = WinButton(key: "btn.cancel",
                              frame: NSRect(x: W - 16 - btnW - 8 - btnW, y: btnY, width: btnW, height: btnH))
        cancelBtn.target = self; cancelBtn.action = #selector(cancel)
        client.addSubview(cancelBtn)

        showPanel("session")
    }

    private func showPanel(_ id: String) {
        currentPanel?.saveToConfig()
        currentPanel?.removeFromSuperview()
        currentId = id
        let p = PanelFactory.make(id: id, config: config, frame: panelHost.bounds)
        p.autoresizingMask = [.width, .height]
        panelHost.addSubview(p)
        currentPanel = p
        if let session = p as? SessionPanel, !applyMode {
            session.onConnectRequest = { [weak self] in self?.openSession() }
        }
    }

    @objc private func langChanged() {
        window?.title = L.t("win.title")
        (window as? WinChromeWindow)?.setTitleKey("win.title")
        catLabel.reloadTexts()
        aboutBtn.reloadTexts()
        helpBtn.reloadTexts()
        cancelBtn.reloadTexts()
        openBtn.key = applyMode ? "btn.apply" : "btn.open"
        openBtn.reloadTexts()
        langCombo.reloadTexts()
        tree.selectedId = currentId
        tree.setRoot(ConfigCategory.tree())
        currentPanel?.reloadTexts()
        window?.contentView?.needsDisplay = true
    }

    @objc private func configReloaded() {
        currentPanel?.bind(config)
        currentPanel?.loadFromConfig()
    }

    @objc private func showAbout() { Dialogs.about() }
    @objc private func showHelp() { Dialogs.help() }

    @objc private func cancel() {
        onCancel?()
        window?.close()
    }

    @objc func openSession() {
        currentPanel?.saveToConfig()
        if applyMode {
            onOpen?(config)
            return
        }
        if config.protocolType == .serial {
            if config.serline.trimmingCharacters(in: .whitespaces).isEmpty {
                Dialogs.alert(L.t("session.noSerial")); return
            }
        } else if config.host.trimmingCharacters(in: .whitespaces).isEmpty {
            Dialogs.alert(L.t("session.noHost")); return
        }
        onOpen?(config.clone())
        window?.orderOut(nil)
    }

    func present() {
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
