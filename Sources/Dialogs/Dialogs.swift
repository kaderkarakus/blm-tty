import AppKit

enum Dialogs {
    static func alert(_ message: String, title: String? = nil) {
        let a = NSAlert()
        a.messageText = title ?? L.t("app.name")
        a.informativeText = message
        a.addButton(withTitle: L.t("btn.ok"))
        a.runModal()
    }

    static func about() {
        let a = NSAlert()
        a.messageText = L.t("about.title")
        a.informativeText = L.t("about.body")
        a.addButton(withTitle: L.t("btn.ok"))
        a.runModal()
    }

    static func help() {
        HelpWindowController.shared.show()
    }

    static func password(user: String, host: String) -> String? {
        prompt(title: L.t("auth.passwordTitle"),
               message: String(format: L.t("auth.passwordPrompt"), user, host),
               secure: true)
    }

    static func passphrase(comment: String) -> String? {
        prompt(title: L.t("auth.passphraseTitle"),
               message: String(format: L.t("auth.passphrasePrompt"), comment),
               secure: true)
    }

    static func prompt(title: String, message: String, secure: Bool) -> String? {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = message
        a.addButton(withTitle: L.t("btn.ok"))
        a.addButton(withTitle: L.t("btn.cancel"))
        let field: NSTextField = secure
            ? NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
            : NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        a.accessoryView = field
        a.window.initialFirstResponder = field
        a.window.level = .floating
        NSApp.activate(ignoringOtherApps: true)
        let r = a.runModal()
        return r == .alertFirstButtonReturn ? field.stringValue : nil
    }

    static func hostKeyNew(host: String, fingerprint: String) -> HostKeyChoice {
        let a = NSAlert()
        a.messageText = L.t("hostkey.title")
        a.informativeText = String(format: L.t("hostkey.new"), host, fingerprint)
        a.addButton(withTitle: L.t("btn.accept"))
        a.addButton(withTitle: L.t("btn.connectOnce"))
        a.addButton(withTitle: L.t("btn.cancel"))
        switch a.runModal() {
        case .alertFirstButtonReturn: return .accept
        case .alertSecondButtonReturn: return .once
        default: return .cancel
        }
    }

    static func hostKeyChanged(cached: String, neu: String) -> HostKeyChoice {
        let a = NSAlert()
        a.messageText = L.t("hostkey.title")
        a.informativeText = String(format: L.t("hostkey.changed"), cached, neu)
        a.addButton(withTitle: L.t("btn.accept"))
        a.addButton(withTitle: L.t("btn.connectOnce"))
        a.addButton(withTitle: L.t("btn.cancel"))
        switch a.runModal() {
        case .alertFirstButtonReturn: return .accept
        case .alertSecondButtonReturn: return .once
        default: return .cancel
        }
    }

    static func banner(_ text: String) -> Bool {
        let a = NSAlert()
        a.messageText = L.t("auth.bannerTitle")
        a.informativeText = text
        a.addButton(withTitle: L.t("btn.continue"))
        a.addButton(withTitle: L.t("btn.cancel"))
        return a.runModal() == .alertFirstButtonReturn
    }

    static func keyboardInteractive(prompts: [String], echos: [Bool]) -> [String]? {
        let a = NSAlert()
        a.messageText = L.t("auth.kiTitle")
        a.addButton(withTitle: L.t("btn.ok"))
        a.addButton(withTitle: L.t("btn.cancel"))
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        var fields: [NSTextField] = []
        for (i, p) in prompts.enumerated() {
            let lab = NSTextField(labelWithString: p)
            lab.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
            stack.addArrangedSubview(lab)
            let f: NSTextField = (echos.indices.contains(i) && !echos[i])
                ? NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
                : NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
            f.isBezeled = true
            f.bezelStyle = .roundedBezel
            f.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
            stack.addArrangedSubview(f)
            fields.append(f)
        }
        stack.frame = NSRect(x: 0, y: 0, width: 280, height: CGFloat(prompts.count) * 44)
        a.accessoryView = stack
        if a.runModal() != .alertFirstButtonReturn { return nil }
        return fields.map { $0.stringValue }
    }
}

enum HostKeyChoice { case accept, once, cancel }

final class HelpWindowController: NSWindowController, NSWindowDelegate {
    static let shared = HelpWindowController()
    private var text: NSTextView!

    private init() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
                         styleMask: [.titled, .closable, .resizable],
                         backing: .buffered, defer: false)
        w.title = L.t("help.title")
        w.titlebarSeparatorStyle = .line
        w.backgroundColor = .textBackgroundColor
        super.init(window: w)
        w.delegate = self
        let scroll = NSScrollView(frame: w.contentView!.bounds)
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        text = NSTextView(frame: scroll.bounds)
        text.isEditable = false
        text.font = NSFont.systemFont(ofSize: 13)
        text.textContainerInset = NSSize(width: 12, height: 12)
        text.backgroundColor = .textBackgroundColor
        text.textColor = .labelColor
        text.string = L.t("help.body")
        scroll.documentView = text
        w.contentView?.addSubview(scroll)
        NotificationCenter.default.addObserver(self, selector: #selector(lang), name: .blmLanguageChanged, object: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
    func show() {
        window?.title = L.t("help.title")
        text.string = L.t("help.body")
        window?.center()
        showWindow(nil)
    }
    @objc private func lang() {
        window?.title = L.t("help.title")
        text.string = L.t("help.body")
    }
}

final class EventLogController: NSWindowController {
    private let view = NSTextView()
    init(title: String) {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 320),
                         styleMask: [.titled, .closable, .resizable, .miniaturizable],
                         backing: .buffered, defer: false)
        w.title = title
        w.titlebarSeparatorStyle = .line
        w.backgroundColor = .textBackgroundColor
        super.init(window: w)
        let scroll = NSScrollView(frame: w.contentView!.bounds)
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        view.font = WinFont.mono(11)
        view.isEditable = false
        view.backgroundColor = .textBackgroundColor
        view.textColor = .labelColor
        view.textContainerInset = NSSize(width: 8, height: 8)
        scroll.documentView = view
        w.contentView?.addSubview(scroll)
    }
    required init?(coder: NSCoder) { fatalError() }
    func append(_ line: String) {
        DispatchQueue.main.async {
            self.view.textStorage?.append(NSAttributedString(
                string: line + "\n",
                attributes: [.font: WinFont.mono(11), .foregroundColor: NSColor.labelColor]
            ))
            self.view.scrollToEndOfDocument(nil)
        }
    }
}
