import AppKit
import UniformTypeIdentifiers

final class PuttygenWindowController: NSWindowController {
    private var key: PPKKey?
    private var typeLabel: WinLabel!
    private var bitsLabel: WinLabel!
    private var commentLabel: WinLabel!
    private var pass1Label: WinLabel!
    private var pass2Label: WinLabel!
    private var fpTitle: WinLabel!
    private var fpValue: WinLabel!
    private var pubLabel: WinLabel!
    private var group: WinGroupBox!
    private var typeRadio: WinRadio!
    private var bitsField: WinTextField!
    private var commentField: WinTextField!
    private var pass1: WinSecureField!
    private var pass2: WinSecureField!
    private var pubView: NSTextView!
    private var genBtn: WinButton!
    private var savePrivBtn: WinButton!
    private var savePubBtn: WinButton!
    private var loadBtn: WinButton!

    init() {
        let win = WinChromeWindow(contentSize: NSSize(width: WinPalette.windowWidth, height: 420))
        super.init(window: win)
        win.setTitleKey("puttygen.title")
        win.onHelp = { Dialogs.help() }
        build(in: win.clientView)
        NotificationCenter.default.addObserver(self, selector: #selector(langChanged), name: .blmLanguageChanged, object: nil)
        showEmpty()
    }

    required init?(coder: NSCoder) { fatalError() }

    func present() {
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func build(in client: NSView) {
        let W = WinPalette.windowWidth
        group = WinGroupBox(key: "puttygen.type", frame: NSRect(x: 16, y: 12, width: W - 32, height: 72))
        client.addSubview(group)

        typeLabel = WinLabel(key: "puttygen.ed25519", frame: NSRect(x: 24, y: 34, width: 220, height: 16))
        client.addSubview(typeLabel)
        typeRadio = WinRadio(key: "puttygen.ed25519", frame: NSRect(x: 24, y: 52, width: 220, height: 18))
        typeRadio.state = .on
        client.addSubview(typeRadio)

        bitsLabel = WinLabel(key: "puttygen.bits", frame: NSRect(x: 250, y: 34, width: 180, height: 16))
        client.addSubview(bitsLabel)
        bitsField = WinTextField(frame: NSRect(x: 250, y: 52, width: 70, height: 21))
        bitsField.stringValue = "256"
        bitsField.isEditable = false
        bitsField.isEnabled = false
        client.addSubview(bitsField)

        genBtn = WinButton(key: "btn.generate", frame: NSRect(x: W - 16 - 88, y: 46, width: 88, height: 24), defaultLook: true)
        genBtn.target = self
        genBtn.action = #selector(generate)
        client.addSubview(genBtn)

        pubLabel = WinLabel(key: "puttygen.pub", frame: NSRect(x: 16, y: 92, width: W - 32, height: 32))
        pubLabel.maximumNumberOfLines = 2
        pubLabel.lineBreakMode = .byWordWrapping
        client.addSubview(pubLabel)

        let scroll = NSScrollView(frame: NSRect(x: 16, y: 126, width: W - 32, height: 120))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.drawsBackground = true
        pubView = NSTextView(frame: scroll.bounds)
        pubView.font = WinFont.mono(11)
        pubView.isEditable = false
        pubView.isHorizontallyResizable = false
        pubView.textContainerInset = NSSize(width: 4, height: 4)
        scroll.documentView = pubView
        client.addSubview(scroll)

        commentLabel = WinLabel(key: "puttygen.comment", frame: NSRect(x: 16, y: 254, width: 200, height: 16))
        client.addSubview(commentLabel)
        commentField = WinTextField(frame: NSRect(x: 16, y: 272, width: W - 32, height: 24))
        commentField.stringValue = "blm-tty@\(ProcessInfo.processInfo.hostName)"
        client.addSubview(commentField)

        pass1Label = WinLabel(key: "puttygen.pass1", frame: NSRect(x: 16, y: 304, width: 250, height: 16))
        client.addSubview(pass1Label)
        pass1 = WinSecureField(frame: NSRect(x: 16, y: 322, width: 250, height: 24))
        client.addSubview(pass1)

        pass2Label = WinLabel(key: "puttygen.pass2", frame: NSRect(x: W - 16 - 250, y: 304, width: 250, height: 16))
        client.addSubview(pass2Label)
        pass2 = WinSecureField(frame: NSRect(x: W - 16 - 250, y: 322, width: 250, height: 24))
        client.addSubview(pass2)

        fpTitle = WinLabel(key: "puttygen.fp", frame: NSRect(x: 16, y: 354, width: 160, height: 16))
        client.addSubview(fpTitle)
        fpValue = WinLabel(text: L.t("puttygen.empty"), frame: NSRect(x: 176, y: 354, width: W - 192, height: 16))
        fpValue.font = WinFont.mono(11)
        client.addSubview(fpValue)

        let bottomSep = NSBox(frame: NSRect(x: 0, y: 380, width: W, height: 1))
        bottomSep.boxType = .separator
        client.addSubview(bottomSep)

        loadBtn = WinButton(key: "puttygen.load", frame: NSRect(x: 16, y: 390, width: 88, height: 24))
        loadBtn.target = self
        loadBtn.action = #selector(loadKey)
        client.addSubview(loadBtn)

        savePubBtn = WinButton(key: "puttygen.savePub", frame: NSRect(x: W - 16 - 130 - 8 - 130, y: 390, width: 130, height: 24))
        savePubBtn.target = self
        savePubBtn.action = #selector(savePublic)
        client.addSubview(savePubBtn)

        savePrivBtn = WinButton(key: "puttygen.savePriv", frame: NSRect(x: W - 16 - 130, y: 390, width: 130, height: 24))
        savePrivBtn.target = self
        savePrivBtn.action = #selector(savePrivate)
        client.addSubview(savePrivBtn)
    }

    private func showEmpty() {
        pubView.string = L.t("puttygen.empty")
        fpValue.stringValue = L.t("puttygen.empty")
        key = nil
    }

    private func display(_ k: PPKKey) {
        key = k
        commentField.stringValue = k.comment
        pubView.string = k.authorizedKeysLine()
        fpValue.stringValue = k.fingerprintSHA256()
    }

    @objc private func generate() {
        var comment = commentField.stringValue.trimmingCharacters(in: .whitespaces)
        if comment.isEmpty { comment = "blm-tty-key" }
        let (k, _) = PPKKey.generateEd25519(comment: comment)
        display(k)
    }

    @objc private func loadKey() {
        let p = NSOpenPanel()
        p.allowedContentTypes = [.item]
        p.allowsMultipleSelection = false
        p.canChooseDirectories = false
        p.title = L.t("puttygen.load")
        guard p.runModal() == .OK, let url = p.url else { return }
        var pass: String? = nil
        if let text = try? String(contentsOf: url, encoding: .utf8),
           text.contains("Encryption: aes") || text.contains("Encryption: argon") {
            pass = Dialogs.passphrase(comment: url.lastPathComponent)
        }
        do {
            let k = try PPKKey.load(path: url.path, passphrase: pass)
            display(k)
        } catch {
            Dialogs.alert(L.t("puttygen.loadFailed"))
        }
    }

    @objc private func savePrivate() {
        guard let key else {
            Dialogs.alert(L.t("puttygen.empty"))
            return
        }
        let a = pass1.stringValue
        let b = pass2.stringValue
        if a != b {
            Dialogs.alert(L.t("puttygen.passMismatch"))
            return
        }
        let p = NSSavePanel()
        p.nameFieldStringValue = "id_ed25519.ppk"
        p.allowedContentTypes = [.item]
        p.title = L.t("puttygen.savePriv")
        guard p.runModal() == .OK, let url = p.url else { return }
        let text = key.serializePPK2(passphrase: a.isEmpty ? nil : a)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            Dialogs.alert(L.t("puttygen.savedPriv"))
        } catch {
            Dialogs.alert(error.localizedDescription)
        }
    }

    @objc private func savePublic() {
        guard let key else {
            Dialogs.alert(L.t("puttygen.empty"))
            return
        }
        let p = NSSavePanel()
        p.nameFieldStringValue = "id_ed25519.pub"
        p.title = L.t("puttygen.savePub")
        guard p.runModal() == .OK, let url = p.url else { return }
        do {
            try (key.authorizedKeysLine() + "\n").write(to: url, atomically: true, encoding: .utf8)
            Dialogs.alert(L.t("puttygen.savedPub"))
        } catch {
            Dialogs.alert(error.localizedDescription)
        }
    }

    @objc private func langChanged() {
        (window as? WinChromeWindow)?.setTitleKey("puttygen.title")
        group.reloadTexts()
        typeLabel.reloadTexts()
        typeRadio.reloadTexts()
        bitsLabel.reloadTexts()
        commentLabel.reloadTexts()
        pass1Label.reloadTexts()
        pass2Label.reloadTexts()
        fpTitle.reloadTexts()
        pubLabel.reloadTexts()
        genBtn.reloadTexts()
        savePrivBtn.reloadTexts()
        savePubBtn.reloadTexts()
        loadBtn.reloadTexts()
        if key == nil {
            pubView.string = L.t("puttygen.empty")
            fpValue.stringValue = L.t("puttygen.empty")
        }
    }
}
