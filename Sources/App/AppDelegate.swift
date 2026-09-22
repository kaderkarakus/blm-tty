import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    static let shared = AppDelegate()

    private var configWindow: ConfigWindowController?
    private var extraConfigs: [ConfigWindowController] = []
    private var terminals: [TerminalWindowController] = []
    private var puttygen: PuttygenWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = SessionStore.shared
        AppMenu.install()
        NotificationCenter.default.addObserver(self, selector: #selector(languageChanged), name: .blmLanguageChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionsChanged), name: .blmSessionsChanged, object: nil)

        let parsed = CLI.parse(Array(CommandLine.arguments.dropFirst()))
        if let err = parsed.error {
            FileHandle.standardError.write(Data((err + "\n").utf8))
            if parsed.fatal {
                NSApp.terminate(nil)
                return
            }
            Dialogs.alert(err)
        }
        if parsed.openDirect {
            openSession(parsed.config)
        } else {
            showMainConfig(initial: parsed.config)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainConfig()
        }
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    func showMainConfig(initial: SessionConfig? = nil) {
        if configWindow == nil {
            let c = ConfigWindowController(config: initial)
            c.onOpen = { [weak self] cfg in self?.openSession(cfg) }
            configWindow = c
        }
        configWindow?.present()
    }

    func openSession(_ cfg: SessionConfig) {
        let t = TerminalWindowController(config: cfg)
        t.onClosed = { [weak self, weak t] in
            guard let self else { return }
            self.terminals.removeAll { $0 === t }
            if self.terminals.isEmpty {
                NSApp.terminate(nil)
            }
        }
        terminals.append(t)
        t.start()
    }

    private func focusedTerminal() -> TerminalWindowController? {
        if let t = NSApp.keyWindow?.windowController as? TerminalWindowController { return t }
        if let t = NSApp.mainWindow?.windowController as? TerminalWindowController { return t }
        return terminals.last
    }

    @objc func languageChanged() {
        AppMenu.install()
    }

    @objc func sessionsChanged() {
        AppMenu.refreshSavedSessions()
    }

    // MARK: - Menu actions

    @objc func showAbout(_ sender: Any?) { Dialogs.about() }

    @objc func showPreferences(_ sender: Any?) { showMainConfig() }

    @objc func newSession(_ sender: Any?) {
        let base = SessionStore.shared.load(SessionStore.defaultName) ?? SessionConfig()
        let c = ConfigWindowController(config: base.clone())
        c.onOpen = { [weak self] cfg in self?.openSession(cfg) }
        extraConfigs.append(c)
        c.present()
    }

    @objc func duplicateSession(_ sender: Any?) {
        if let t = focusedTerminal() {
            openSession(t.config.clone())
            return
        }
        if let c = configWindow {
            openSession(c.config.clone())
        }
    }

    @objc func openSavedSession(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String,
              let cfg = SessionStore.shared.load(name) else { return }
        openSession(cfg.clone())
    }

    @objc func changeSettings(_ sender: Any?) {
        if let t = focusedTerminal() {
            t.changeSettings(sender)
            return
        }
        showMainConfig()
    }

    @objc func closeWindow(_ sender: Any?) {
        NSApp.keyWindow?.performClose(sender)
    }

    @objc func copySel(_ sender: Any?) {
        if let t = focusedTerminal() {
            t.termView.copyClipboard(sender)
            return
        }
        NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: sender)
    }

    @objc func pasteSel(_ sender: Any?) {
        if let t = focusedTerminal() {
            t.termView.pasteClipboard(sender)
            return
        }
        NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: sender)
    }

    @objc func selectAllText(_ sender: Any?) {
        if let t = focusedTerminal() {
            t.termView.selectAllCells(sender)
            return
        }
        NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: sender)
    }

    @objc func clearScrollback(_ sender: Any?) {
        focusedTerminal()?.clearScrollback(sender)
    }

    @objc func findText(_ sender: Any?) {
        focusedTerminal()?.findText(sender)
    }

    @objc func showEventLog(_ sender: Any?) {
        focusedTerminal()?.showEventLog(sender)
    }

    @objc func resetTerminal(_ sender: Any?) {
        focusedTerminal()?.resetTerminal(sender)
    }

    @objc func restartSession(_ sender: Any?) {
        focusedTerminal()?.restartSession(sender)
    }

    @objc func toggleFullScreen(_ sender: Any?) {
        NSApp.keyWindow?.toggleFullScreen(sender)
    }

    @objc func showHelp(_ sender: Any?) { Dialogs.help() }

    @objc func showPuttygen(_ sender: Any?) {
        if puttygen == nil {
            puttygen = PuttygenWindowController()
        }
        puttygen?.present()
    }

    @objc func setLanguageEnglish(_ sender: Any?) { L.setLanguage(.en) }
    @objc func setLanguageTurkish(_ sender: Any?) { L.setLanguage(.tr) }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let hasTerm = focusedTerminal() != nil
        switch menuItem.action {
        case #selector(duplicateSession(_:)),
             #selector(clearScrollback(_:)),
             #selector(findText(_:)),
             #selector(showEventLog(_:)),
             #selector(resetTerminal(_:)),
             #selector(restartSession(_:)):
            return hasTerm
        case #selector(copySel(_:)),
             #selector(pasteSel(_:)),
             #selector(selectAllText(_:)):
            return true
        default:
            return true
        }
    }
}
