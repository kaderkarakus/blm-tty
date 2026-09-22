import AppKit

final class SessionPanel: ConfigPanel, NSTextFieldDelegate {
    private var hostField: WinTextField!
    private var portField: WinTextField!
    private var savedField: WinTextField!
    private var list: WinListBox!
    private var protoRadios: [WinRadio] = []
    private var closeRadios: [WinRadio] = []
    private var hostLabel: WinLabel!
    private var portLabel: WinLabel!
    /// Çift tık = seçili kayıtlı oturumu yükle ve bağlan.
    var onConnectRequest: (() -> Void)?
    private var suppressListLoad = false

    override init(config: SessionConfig, frame: NSRect) {
        super.init(config: config, frame: frame)
        build()
        loadFromConfig()
        reloadSessions()
        NotificationCenter.default.addObserver(self, selector: #selector(sessionsChanged), name: .blmSessionsChanged, object: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        group("session.group.basic", NSRect(x: 0, y: 0, width: 334, height: 148))
        label("session.specify", NSRect(x: 10, y: 22, width: 314, height: 16))
        hostLabel = label("session.host", NSRect(x: 10, y: 42, width: 230, height: 14))
        portLabel = label("session.port", NSRect(x: 250, y: 42, width: 74, height: 14))
        hostField = field(NSRect(x: 10, y: 58, width: 230, height: 21))
        portField = field(NSRect(x: 250, y: 58, width: 72, height: 21))
        hostField.delegate = self
        portField.delegate = self
        label("session.connType", NSRect(x: 10, y: 86, width: 310, height: 14))
        let keys = ["session.raw", "session.telnet", "session.rlogin", "session.ssh", "session.serial"]
        var x: CGFloat = 10
        var frames: [NSRect] = []
        let widths: [CGFloat] = [52, 62, 68, 52, 70]
        for w in widths {
            frames.append(NSRect(x: x, y: 106, width: w, height: 18))
            x += w + 4
        }
        protoRadios = radioGroup(keys, frames: frames, get: { [weak self] in
            self?.config.protocolType.rawValue ?? 3
        }, set: { [weak self] v in
            guard let self else { return }
            let p = ProtocolType(rawValue: v) ?? .ssh
            self.config.protocolType = p
            if p != .serial {
                self.config.port = p.defaultPort
                self.portField.stringValue = String(self.config.port)
            }
            self.updateHostPortEnabled()
        })

        group("session.group.saved", NSRect(x: 0, y: 154, width: 334, height: 176))
        label("session.saved", NSRect(x: 10, y: 174, width: 230, height: 14))
        savedField = field(NSRect(x: 10, y: 190, width: 230, height: 21))
        list = WinListBox(frame: NSRect(x: 10, y: 216, width: 230, height: 104))
        addSubview(list)
        let load = button("btn.load", NSRect(x: 248, y: 190, width: 75, height: 23), #selector(loadSession))
        _ = load
        _ = button("btn.save", NSRect(x: 248, y: 219, width: 75, height: 23), #selector(saveSession))
        _ = button("btn.delete", NSRect(x: 248, y: 248, width: 75, height: 23), #selector(deleteSession))
        list.onSelect = { [weak self] i in
            guard let self, i >= 0, i < self.list.items.count else { return }
            let names = SessionStore.shared.names()
            guard i < names.count else { return }
            let name = names[i]
            if name != SessionStore.defaultName { self.savedField.stringValue = name }
            else { self.savedField.stringValue = "" }
            if !self.suppressListLoad {
                self.loadSession()
            }
        }
        list.onActivate = { [weak self] _ in
            self?.loadSession()
            self?.onConnectRequest?()
        }

        label("session.closeOnExit", NSRect(x: 0, y: 338, width: 330, height: 16))
        closeRadios = radioGroup(
            ["session.close.always", "session.close.never", "session.close.clean"],
            frames: [
                NSRect(x: 10, y: 356, width: 90, height: 18),
                NSRect(x: 110, y: 356, width: 90, height: 18),
                NSRect(x: 200, y: 356, width: 130, height: 18),
            ],
            get: { [weak self] in self?.config.closeOnExit.rawValue ?? 2 },
            set: { [weak self] v in self?.config.closeOnExit = CloseOnExit(rawValue: v) ?? .clean }
        )
    }

    override func loadFromConfig() {
        hostField.stringValue = config.host
        portField.stringValue = String(config.port)
        refreshRadios()
        updateHostPortEnabled()
    }

    override func saveToConfig() {
        config.host = hostField.stringValue.trimmingCharacters(in: .whitespaces)
        config.port = Int(portField.stringValue) ?? config.port
    }

    override func extraRadioChanged(_ sender: WinRadio) {
        if protoRadios.contains(where: { $0 === sender }) {
            updateHostPortEnabled()
        }
    }

    private func updateHostPortEnabled() {
        let serial = config.protocolType == .serial
        hostField.isEnabled = !serial
        portField.isEnabled = !serial
        hostLabel.textColor = serial ? .disabledControlTextColor : .labelColor
        portLabel.textColor = serial ? .disabledControlTextColor : .labelColor
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let f = obj.object as? NSTextField else { return }
        if f === hostField { config.host = f.stringValue }
        if f === portField { config.port = Int(f.stringValue) ?? config.port }
    }

    @objc private func sessionsChanged() { reloadSessions() }

    func reloadSessions() {
        let names = SessionStore.shared.names()
        let keep: String = {
            let i = list.selectedIndex
            if i >= 0, i < names.count { return names[i] }
            let typed = savedField.stringValue.trimmingCharacters(in: .whitespaces)
            if !typed.isEmpty { return typed }
            return config.sessionName
        }()
        suppressListLoad = true
        list.items = names.map { $0 == SessionStore.defaultName ? L.t("session.default") : $0 }
        if !keep.isEmpty, let idx = names.firstIndex(of: keep) {
            list.selectedIndex = idx
        } else if list.selectedIndex < 0, !names.isEmpty {
            list.selectedIndex = 0
        }
        suppressListLoad = false
    }

    override func reloadTexts() {
        super.reloadTexts()
        reloadSessions()
    }

    @objc private func loadSession() {
        let i = list.selectedIndex
        guard i >= 0 else { return }
        let names = SessionStore.shared.names()
        guard i < names.count, let loaded = SessionStore.shared.load(names[i]) else { return }
        config.apply(from: loaded)
        config.sessionName = names[i]
        NotificationCenter.default.post(name: Notification.Name("blmConfigReloaded"), object: config)
        loadFromConfig()
    }

    @objc private func saveSession() {
        saveToConfig()
        var name = savedField.stringValue.trimmingCharacters(in: .whitespaces)
        if name.isEmpty {
            let i = list.selectedIndex
            let names = SessionStore.shared.names()
            if i >= 0, i < names.count { name = names[i] }
        }
        if name.isEmpty { name = SessionStore.defaultName }
        SessionStore.shared.save(config, as: name)
        config.sessionName = name
        reloadSessions()
        if let idx = SessionStore.shared.names().firstIndex(of: name) {
            list.selectedIndex = idx
        }
    }

    @objc private func deleteSession() {
        let i = list.selectedIndex
        let names = SessionStore.shared.names()
        guard i >= 0, i < names.count else { return }
        let name = names[i]
        if name == SessionStore.defaultName {
            NSSound.beep()
            let a = NSAlert()
            a.messageText = L.t("session.deleteDefault")
            a.runModal()
            return
        }
        let a = NSAlert()
        a.messageText = L.t("session.deleteConfirm")
        a.addButton(withTitle: L.t("btn.delete"))
        a.addButton(withTitle: L.t("btn.cancel"))
        if a.runModal() == .alertFirstButtonReturn {
            SessionStore.shared.delete(name)
            savedField.stringValue = ""
        }
    }
}
