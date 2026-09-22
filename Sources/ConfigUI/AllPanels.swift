import AppKit
import UniformTypeIdentifiers

final class LoggingPanel: ConfigPanel, NSTextFieldDelegate {
    private var fileField: WinTextField!
    override init(config: SessionConfig, frame: NSRect) {
        super.init(config: config, frame: frame)
        group("log.group", NSRect(x: 0, y: 0, width: 334, height: 360))
        radioGroup(
            ["log.none", "log.print", "log.all", "log.ssh", "log.sshraw"],
            frames: (0..<5).map { NSRect(x: 12, y: 24 + CGFloat($0) * 20, width: 300, height: 18) },
            get: { [weak self] in
                switch self?.config.logType {
                case .none?: return 0
                case .printable: return 1
                case .all: return 2
                case .sshPackets: return 3
                case .sshRaw: return 4
                default: return 0
                }
            },
            set: { [weak self] v in
                let map: [LogType] = [.none, .printable, .all, .sshPackets, .sshRaw]
                self?.config.logType = map[v]
            }
        )
        label("log.file", NSRect(x: 12, y: 132, width: 310, height: 16))
        fileField = field(NSRect(x: 12, y: 150, width: 310, height: 21))
        fileField.delegate = self
        radioGroup(
            ["log.ask", "log.append", "log.overwrite"],
            frames: (0..<3).map { NSRect(x: 12, y: 180 + CGFloat($0) * 20, width: 310, height: 18) },
            get: { [weak self] in self?.config.logOverlap ?? 0 },
            set: { [weak self] v in self?.config.logOverlap = v }
        )
        _ = checkbox("log.flush", NSRect(x: 12, y: 250, width: 310, height: 18),
                     getter: { [weak self] in self?.config.logFlush ?? true },
                     setter: { [weak self] v in self?.config.logFlush = v })
        _ = checkbox("log.header", NSRect(x: 12, y: 270, width: 310, height: 18),
                     getter: { [weak self] in self?.config.logHeader ?? true },
                     setter: { [weak self] v in self?.config.logHeader = v })
        _ = checkbox("log.omitpass", NSRect(x: 12, y: 290, width: 310, height: 18),
                     getter: { [weak self] in self?.config.logOmitPass ?? true },
                     setter: { [weak self] v in self?.config.logOmitPass = v })
        _ = checkbox("log.omitdata", NSRect(x: 12, y: 310, width: 310, height: 18),
                     getter: { [weak self] in self?.config.logOmitData ?? false },
                     setter: { [weak self] v in self?.config.logOmitData = v })
        loadFromConfig()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func loadFromConfig() {
        fileField.stringValue = config.logFileName
        refreshRadios(); refreshChecks()
    }
    func controlTextDidChange(_ obj: Notification) { config.logFileName = fileField.stringValue }
}

final class TerminalPanel: ConfigPanel, NSTextFieldDelegate {
    private var ans: WinTextField!
    private var printer: WinTextField!
    override init(config: SessionConfig, frame: NSRect) {
        super.init(config: config, frame: frame)
        group("term.group.auto", NSRect(x: 0, y: 0, width: 334, height: 370))
        var y: CGFloat = 22
        func chk(_ k: String, get: @escaping () -> Bool, set: @escaping (Bool) -> Void) {
            _ = checkbox(k, NSRect(x: 12, y: y, width: 310, height: 18), getter: get, setter: set)
            y += 20
        }
        chk("term.wrap", get: { [weak self] in self?.config.wrapMode ?? true }, set: { [weak self] v in self?.config.wrapMode = v })
        chk("term.decom", get: { [weak self] in self?.config.decOrigin ?? false }, set: { [weak self] v in self?.config.decOrigin = v })
        chk("term.lfcr", get: { [weak self] in self?.config.lfHasCR ?? false }, set: { [weak self] v in self?.config.lfHasCR = v })
        chk("term.crlf", get: { [weak self] in self?.config.crHasLF ?? false }, set: { [weak self] v in self?.config.crHasLF = v })
        chk("term.bce", get: { [weak self] in self?.config.bce ?? true }, set: { [weak self] v in self?.config.bce = v })
        chk("term.blink", get: { [weak self] in self?.config.blinkText ?? false }, set: { [weak self] v in self?.config.blinkText = v })
        label("term.answerback", NSRect(x: 12, y: y, width: 200, height: 16)); y += 16
        ans = field(NSRect(x: 12, y: y, width: 200, height: 21)); ans.delegate = self; y += 28
        label("term.echo", NSRect(x: 12, y: y, width: 310, height: 16)); y += 18
        _ = radioGroup(["term.auto", "term.forceOn", "term.forceOff"],
                       frames: [NSRect(x: 20, y: y, width: 80, height: 18),
                                NSRect(x: 110, y: y, width: 90, height: 18),
                                NSRect(x: 210, y: y, width: 100, height: 18)],
                       get: { [weak self] in self?.config.localEcho.rawValue ?? 0 },
                       set: { [weak self] v in self?.config.localEcho = ForceTri(rawValue: v) ?? .auto })
        y += 24
        label("term.edit", NSRect(x: 12, y: y, width: 310, height: 16)); y += 18
        _ = radioGroup(["term.auto", "term.forceOn", "term.forceOff"],
                       frames: [NSRect(x: 20, y: y, width: 80, height: 18),
                                NSRect(x: 110, y: y, width: 90, height: 18),
                                NSRect(x: 210, y: y, width: 100, height: 18)],
                       get: { [weak self] in self?.config.localEdit.rawValue ?? 0 },
                       set: { [weak self] v in self?.config.localEdit = ForceTri(rawValue: v) ?? .auto })
        y += 26
        label("term.printer", NSRect(x: 12, y: y, width: 310, height: 16)); y += 16
        printer = field(NSRect(x: 12, y: y, width: 310, height: 21)); printer.delegate = self
        loadFromConfig()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func loadFromConfig() {
        ans.stringValue = config.answerback
        printer.stringValue = config.printer
        refreshChecks(); refreshRadios()
    }
    func controlTextDidChange(_ obj: Notification) {
        config.answerback = ans.stringValue
        config.printer = printer.stringValue
    }
}

final class KeyboardPanel: ConfigPanel {
    override init(config: SessionConfig, frame: NSRect) {
        super.init(config: config, frame: frame)
        group("kbd.group.bs", NSRect(x: 0, y: 0, width: 334, height: 70))
        _ = radioGroup(["kbd.ctrlH", "kbd.ctrlQM"],
                       frames: [NSRect(x: 12, y: 22, width: 140, height: 18), NSRect(x: 160, y: 22, width: 150, height: 18)],
                       get: { [weak self] in (self?.config.bkspIsDelete ?? true) ? 1 : 0 },
                       set: { [weak self] v in self?.config.bkspIsDelete = v == 1 })
        group("kbd.group.home", NSRect(x: 0, y: 76, width: 334, height: 56))
        _ = radioGroup(["kbd.std", "kbd.rxvt"],
                       frames: [NSRect(x: 12, y: 98, width: 140, height: 18), NSRect(x: 160, y: 98, width: 140, height: 18)],
                       get: { [weak self] in (self?.config.rxvtHomeEnd ?? false) ? 1 : 0 },
                       set: { [weak self] v in self?.config.rxvtHomeEnd = v == 1 })
        group("kbd.group.fn", NSRect(x: 0, y: 138, width: 334, height: 120))
        let fn = ["kbd.esc","kbd.linux","kbd.xtermR6","kbd.vt400","kbd.vt100p","kbd.sco","kbd.xterm216"]
        _ = radioGroup(fn, frames: (0..<7).map { NSRect(x: 12 + CGFloat($0 % 2) * 160, y: 160 + CGFloat($0 / 2) * 20, width: 150, height: 18) },
                       get: { [weak self] in self?.config.funkyType ?? 0 },
                       set: { [weak self] v in self?.config.funkyType = v })
        group("kbd.group.alt", NSRect(x: 0, y: 264, width: 334, height: 100))
        _ = checkbox("kbd.altMeta", NSRect(x: 12, y: 286, width: 310, height: 18),
                     getter: { [weak self] in self?.config.altMetaBit ?? false },
                     setter: { [weak self] v in self?.config.altMetaBit = v })
        _ = checkbox("kbd.altHolds", NSRect(x: 12, y: 306, width: 310, height: 18),
                     getter: { [weak self] in self?.config.composeKey ?? false },
                     setter: { [weak self] v in self?.config.composeKey = v })
        _ = checkbox("kbd.ctrlAlt", NSRect(x: 12, y: 326, width: 310, height: 18),
                     getter: { [weak self] in self?.config.ctrlAltKeys ?? true },
                     setter: { [weak self] v in self?.config.ctrlAltKeys = v })
        loadFromConfig()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func loadFromConfig() { refreshRadios(); refreshChecks() }
}

final class BellPanel: ConfigPanel {
    override init(config: SessionConfig, frame: NSRect) {
        super.init(config: config, frame: frame)
        group("bell.group.action", NSRect(x: 0, y: 0, width: 334, height: 120))
        _ = radioGroup(["bell.none","bell.visual","bell.sys","bell.file"],
                       frames: (0..<4).map { NSRect(x: 12, y: 22 + CGFloat($0)*20, width: 310, height: 18) },
                       get: { [weak self] in self?.config.beep ?? 2 },
                       set: { [weak self] v in self?.config.beep = v })
        group("bell.group.overload", NSRect(x: 0, y: 128, width: 334, height: 160))
        _ = checkbox("bell.over", NSRect(x: 12, y: 150, width: 310, height: 18),
                     getter: { [weak self] in self?.config.bellOverload ?? true },
                     setter: { [weak self] v in self?.config.bellOverload = v })
        label("bell.overN", NSRect(x: 12, y: 176, width: 250, height: 16))
        let n = WinSpinner(frame: NSRect(x: 250, y: 174, width: 70, height: 21)); n.value = config.bellOverloadN
        n.onChange = { [weak self] v in self?.config.bellOverloadN = v }; addSubview(n)
        label("bell.overT", NSRect(x: 12, y: 204, width: 250, height: 16))
        let t = WinSpinner(frame: NSRect(x: 250, y: 202, width: 70, height: 21)); t.value = config.bellOverloadT
        t.onChange = { [weak self] v in self?.config.bellOverloadT = v }; addSubview(t)
        label("bell.overS", NSRect(x: 12, y: 248, width: 250, height: 28))
        let s = WinSpinner(frame: NSRect(x: 250, y: 252, width: 70, height: 21)); s.value = config.bellOverloadS
        s.onChange = { [weak self] v in self?.config.bellOverloadS = v }; addSubview(s)
        loadFromConfig()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func loadFromConfig() { refreshRadios(); refreshChecks() }
}

final class FeaturesPanel: ConfigPanel {
    override init(config: SessionConfig, frame: NSRect) {
        super.init(config: config, frame: frame)
        group("feat.group", NSRect(x: 0, y: 0, width: 334, height: 260))
        let items: [(String, KeyPath<SessionConfig, Bool>, ReferenceWritableKeyPath<SessionConfig, Bool>)] = [
            ("feat.appC", \.noApplicC, \.noApplicC),
            ("feat.appK", \.noApplicK, \.noApplicK),
            ("feat.mouse", \.noMouse, \.noMouse),
            ("feat.resize", \.noRemoteResize, \.noRemoteResize),
            ("feat.title", \.noRemoteWintitle, \.noRemoteWintitle),
            ("feat.altscreen", \.noAltScreen, \.noAltScreen),
            ("feat.retitle", \.noRemoteQTitle, \.noRemoteQTitle),
            ("feat.arabic", \.noArabicShaping, \.noArabicShaping),
            ("feat.bidi", \.noBidi, \.noBidi),
        ]
        for (i, it) in items.enumerated() {
            _ = checkbox(it.0, NSRect(x: 12, y: 22 + CGFloat(i)*22, width: 310, height: 18),
                         getter: { [weak self] in self?.config[keyPath: it.1] ?? false },
                         setter: { [weak self] v in self?.config[keyPath: it.2] = v })
        }
        loadFromConfig()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func loadFromConfig() { refreshChecks() }
}

final class WindowPanel: ConfigPanel {
    override init(config: SessionConfig, frame: NSRect) {
        super.init(config: config, frame: frame)
        group("win.group.size", NSRect(x: 0, y: 0, width: 334, height: 70))
        label("win.columns", NSRect(x: 12, y: 24, width: 80, height: 16))
        let cols = WinSpinner(frame: NSRect(x: 90, y: 22, width: 70, height: 21)); cols.value = config.width; cols.range = 1...512
        cols.onChange = { [weak self] v in self?.config.width = v }; addSubview(cols)
        label("win.rows", NSRect(x: 180, y: 24, width: 60, height: 16))
        let rows = WinSpinner(frame: NSRect(x: 240, y: 22, width: 70, height: 21)); rows.value = config.height; rows.range = 1...512
        rows.onChange = { [weak self] v in self?.config.height = v }; addSubview(rows)
        group("win.group.resize", NSRect(x: 0, y: 78, width: 334, height: 90))
        _ = radioGroup(["win.resize.term","win.resize.font","win.resize.none"],
                       frames: (0..<3).map { NSRect(x: 12, y: 100 + CGFloat($0)*20, width: 310, height: 18) },
                       get: { [weak self] in self?.config.resizeAction ?? 0 },
                       set: { [weak self] v in self?.config.resizeAction = v })
        group("win.group.scroll", NSRect(x: 0, y: 176, width: 334, height: 150))
        label("win.lines", NSRect(x: 12, y: 198, width: 180, height: 16))
        let sl = WinSpinner(frame: NSRect(x: 200, y: 196, width: 110, height: 21)); sl.value = config.saveLines; sl.range = 0...99999
        sl.onChange = { [weak self] v in self?.config.saveLines = v }; addSubview(sl)
        _ = checkbox("win.disp", NSRect(x: 12, y: 226, width: 310, height: 18),
                     getter: { [weak self] in self?.config.scrollOnDisp ?? false },
                     setter: { [weak self] v in self?.config.scrollOnDisp = v })
        _ = checkbox("win.key", NSRect(x: 12, y: 246, width: 310, height: 18),
                     getter: { [weak self] in self?.config.scrollOnKey ?? false },
                     setter: { [weak self] v in self?.config.scrollOnKey = v })
        _ = checkbox("win.erase", NSRect(x: 12, y: 266, width: 310, height: 18),
                     getter: { [weak self] in self?.config.eraseToScrollback ?? true },
                     setter: { [weak self] v in self?.config.eraseToScrollback = v })
        loadFromConfig()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func loadFromConfig() { refreshRadios(); refreshChecks() }
}

final class AppearancePanel: ConfigPanel {
    private var fontLabel: WinLabel!
    override init(config: SessionConfig, frame: NSRect) {
        super.init(config: config, frame: frame)
        group("app.group.font", NSRect(x: 0, y: 0, width: 334, height: 110))
        label("app.font", NSRect(x: 12, y: 22, width: 310, height: 16))
        fontLabel = WinLabel(text: "", frame: NSRect(x: 12, y: 42, width: 230, height: 18))
        addSubview(fontLabel)
        _ = button("btn.change", NSRect(x: 248, y: 40, width: 75, height: 23), #selector(pickFont))
        label("app.quality", NSRect(x: 12, y: 70, width: 310, height: 16))
        _ = radioGroup(["app.q.default","app.q.antialias","app.q.non","app.q.clear"],
                       frames: (0..<4).map { NSRect(x: 12 + CGFloat($0)*80, y: 86, width: 78, height: 18) },
                       get: { [weak self] in self?.config.fontQuality ?? 0 },
                       set: { [weak self] v in self?.config.fontQuality = v })
        group("app.group.cursor", NSRect(x: 0, y: 120, width: 334, height: 110))
        _ = radioGroup(["app.block","app.ul","app.vline"],
                       frames: [NSRect(x: 12, y: 142, width: 90, height: 18),
                                NSRect(x: 110, y: 142, width: 90, height: 18),
                                NSRect(x: 210, y: 142, width: 110, height: 18)],
                       get: { [weak self] in self?.config.cursorType ?? 0 },
                       set: { [weak self] v in self?.config.cursorType = v })
        _ = checkbox("app.blink", NSRect(x: 12, y: 168, width: 310, height: 18),
                     getter: { [weak self] in self?.config.blinkCur ?? true },
                     setter: { [weak self] v in self?.config.blinkCur = v })
        label("app.gap", NSRect(x: 12, y: 194, width: 240, height: 16))
        let g = WinSpinner(frame: NSRect(x: 250, y: 192, width: 70, height: 21)); g.value = config.windowBorder
        g.onChange = { [weak self] v in self?.config.windowBorder = v }; addSubview(g)
        loadFromConfig()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func loadFromConfig() {
        fontLabel.stringValue = "\(config.fontName), \(Int(config.fontSize))-point"
        refreshRadios(); refreshChecks()
    }
    @objc private func pickFont() {
        let current = NSFont(name: config.fontName, size: config.fontSize) ?? WinFont.mono(config.fontSize)
        NSFontManager.shared.setSelectedFont(current, isMultiple: false)
        NSFontManager.shared.target = self
        NSFontManager.shared.orderFrontFontPanel(self)
    }

    @objc func changeFont(_ sender: NSFontManager) {
        let current = NSFont(name: config.fontName, size: config.fontSize) ?? WinFont.mono(config.fontSize)
        let f = sender.convert(current)
        config.fontName = f.fontName
        config.fontSize = f.pointSize
        config.fontIsBold = sender.traits(of: f).contains(.boldFontMask)
        loadFromConfig()
    }
}

final class BehaviourPanel: ConfigPanel {
    override init(config: SessionConfig, frame: NSRect) {
        super.init(config: config, frame: frame)
        group("beh.group.warn", NSRect(x: 0, y: 0, width: 334, height: 160))
        _ = checkbox("beh.warn", NSRect(x: 12, y: 22, width: 310, height: 18),
                     getter: { [weak self] in self?.config.warnOnClose ?? true },
                     setter: { [weak self] v in self?.config.warnOnClose = v })
        _ = checkbox("beh.altF4", NSRect(x: 12, y: 42, width: 310, height: 18),
                     getter: { [weak self] in self?.config.altF4 ?? true },
                     setter: { [weak self] v in self?.config.altF4 = v })
        _ = checkbox("beh.alwaysTop", NSRect(x: 12, y: 62, width: 310, height: 18),
                     getter: { [weak self] in self?.config.alwaysOnTop ?? false },
                     setter: { [weak self] v in self?.config.alwaysOnTop = v })
        _ = checkbox("beh.fullscr", NSRect(x: 12, y: 82, width: 310, height: 18),
                     getter: { [weak self] in self?.config.fullScreenOnAltEnter ?? false },
                     setter: { [weak self] v in self?.config.fullScreenOnAltEnter = v })
        loadFromConfig()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func loadFromConfig() { refreshChecks() }
}

final class TranslationPanel: ConfigPanel {
    private let combo = WinComboBox(frame: .zero)
    private let pages = ["UTF-8","ISO-8859-1","ISO-8859-2","ISO-8859-9","ISO-8859-15","CP437","CP850","CP1252","CP1254","KOI8-R","GBK","Big5","Shift_JIS","EUC-JP","EUC-KR"]
    override init(config: SessionConfig, frame: NSRect) {
        super.init(config: config, frame: frame)
        group("trans.group", NSRect(x: 0, y: 0, width: 334, height: 200))
        label("trans.remote", NSRect(x: 12, y: 22, width: 310, height: 16))
        combo.frame = NSRect(x: 12, y: 42, width: 250, height: 21)
        combo.items = pages.map { ($0, $0) }
        combo.onChange = { [weak self] i in
            guard let self else { return }
            self.config.lineCodePage = self.pages[i]
        }
        addSubview(combo)
        _ = checkbox("trans.cjk", NSRect(x: 12, y: 74, width: 310, height: 18),
                     getter: { [weak self] in self?.config.cjkAmbiguousWide ?? false },
                     setter: { [weak self] v in self?.config.cjkAmbiguousWide = v })
        _ = checkbox("trans.utf8", NSRect(x: 12, y: 94, width: 310, height: 18),
                     getter: { [weak self] in self?.config.utf8Override ?? true },
                     setter: { [weak self] v in self?.config.utf8Override = v })
        loadFromConfig()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func loadFromConfig() {
        combo.selectedIndex = pages.firstIndex(of: config.lineCodePage) ?? 0
        refreshChecks()
    }
}

final class SelectionPanel: ConfigPanel {
    override init(config: SessionConfig, frame: NSRect) {
        super.init(config: config, frame: frame)
        group("sel.group.mouse", NSRect(x: 0, y: 0, width: 334, height: 220))
        _ = radioGroup(["sel.xterm","sel.windows"],
                       frames: [NSRect(x: 12, y: 22, width: 310, height: 18), NSRect(x: 12, y: 42, width: 310, height: 18)],
                       get: { [weak self] in self?.config.mouseIsXterm ?? 0 },
                       set: { [weak self] v in self?.config.mouseIsXterm = v })
        _ = checkbox("sel.shift", NSRect(x: 12, y: 70, width: 310, height: 18),
                     getter: { [weak self] in self?.config.mouseOverride ?? true },
                     setter: { [weak self] v in self?.config.mouseOverride = v })
        _ = checkbox("sel.rect", NSRect(x: 12, y: 90, width: 310, height: 18),
                     getter: { [weak self] in self?.config.rectSelect ?? false },
                     setter: { [weak self] v in self?.config.rectSelect = v })
        _ = checkbox("sel.auto", NSRect(x: 12, y: 110, width: 310, height: 18),
                     getter: { [weak self] in self?.config.mouseAutocopy ?? true },
                     setter: { [weak self] v in self?.config.mouseAutocopy = v })
        _ = checkbox("sel.paste", NSRect(x: 12, y: 130, width: 310, height: 18),
                     getter: { [weak self] in self?.config.mousePaste ?? true },
                     setter: { [weak self] v in self?.config.mousePaste = v })
        _ = checkbox("sel.rtf", NSRect(x: 12, y: 150, width: 310, height: 18),
                     getter: { [weak self] in self?.config.rtfPaste ?? false },
                     setter: { [weak self] v in self?.config.rtfPaste = v })
        loadFromConfig()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func loadFromConfig() { refreshRadios(); refreshChecks() }
}

final class ColoursPanel: ConfigPanel {
    private let list = WinListBox(frame: .zero)
    private let swatch = WinColorSwatch(frame: .zero)
    private var rF: WinTextField!, gF: WinTextField!, bF: WinTextField!
    override init(config: SessionConfig, frame: NSRect) {
        super.init(config: config, frame: frame)
        group("col.group.general", NSRect(x: 0, y: 0, width: 334, height: 130))
        _ = checkbox("col.ansi", NSRect(x: 12, y: 22, width: 310, height: 18),
                     getter: { [weak self] in self?.config.ansiColour ?? true },
                     setter: { [weak self] v in self?.config.ansiColour = v })
        _ = checkbox("col.xterm", NSRect(x: 12, y: 42, width: 310, height: 18),
                     getter: { [weak self] in self?.config.xterm256Colour ?? true },
                     setter: { [weak self] v in self?.config.xterm256Colour = v })
        _ = checkbox("col.true", NSRect(x: 12, y: 62, width: 310, height: 18),
                     getter: { [weak self] in self?.config.trueColour ?? true },
                     setter: { [weak self] v in self?.config.trueColour = v })
        _ = checkbox("col.bold", NSRect(x: 12, y: 82, width: 310, height: 18),
                     getter: { [weak self] in self?.config.boldAsColour ?? true },
                     setter: { [weak self] v in self?.config.boldAsColour = v })
        _ = checkbox("col.boldfont", NSRect(x: 12, y: 102, width: 310, height: 18),
                     getter: { [weak self] in self?.config.boldAsFont ?? false },
                     setter: { [weak self] v in self?.config.boldAsFont = v })
        label("col.list", NSRect(x: 0, y: 138, width: 200, height: 16))
        list.frame = NSRect(x: 0, y: 156, width: 200, height: 210)
        addSubview(list)
        swatch.frame = NSRect(x: 214, y: 156, width: 110, height: 40)
        addSubview(swatch)
        label("col.r", NSRect(x: 214, y: 204, width: 40, height: 16)); rF = field(NSRect(x: 254, y: 202, width: 70, height: 21))
        label("col.g", NSRect(x: 214, y: 228, width: 40, height: 16)); gF = field(NSRect(x: 254, y: 226, width: 70, height: 21))
        label("col.b", NSRect(x: 214, y: 252, width: 40, height: 16)); bF = field(NSRect(x: 254, y: 250, width: 70, height: 21))
        _ = button("col.modify", NSRect(x: 214, y: 280, width: 110, height: 23), #selector(modify))
        list.onSelect = { [weak self] i in self?.show(i) }
        loadFromConfig()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func loadFromConfig() {
        list.items = (0..<22).map { L.t("col.\($0)") }
        refreshChecks()
        show(list.selectedIndex >= 0 ? list.selectedIndex : 0)
    }
    override func reloadTexts() { super.reloadTexts(); loadFromConfig() }
    private func show(_ i: Int) {
        guard i >= 0, i < config.colours.count else { return }
        let c = config.colours[i]
        swatch.color = c
        rF.stringValue = String(c.r); gF.stringValue = String(c.g); bF.stringValue = String(c.b)
    }
    @objc private func modify() {
        let i = list.selectedIndex
        guard i >= 0, i < config.colours.count else { return }
        let p = NSColorPanel.shared
        p.color = config.colours[i].nsColor
        p.setTarget(self)
        p.setAction(#selector(colorPicked(_:)))
        p.makeKeyAndOrderFront(nil)
    }
    @objc private func colorPicked(_ panel: NSColorPanel) {
        let i = list.selectedIndex
        guard i >= 0, i < config.colours.count else { return }
        let c = panel.color.usingColorSpace(.sRGB) ?? panel.color
        config.colours[i] = RGB8(r: Int(c.redComponent*255), g: Int(c.greenComponent*255), b: Int(c.blueComponent*255))
        show(i)
    }
}

final class ConnectionPanel: ConfigPanel, NSTextFieldDelegate {
    private var ping: WinTextField!, logh: WinTextField!
    override init(config: SessionConfig, frame: NSRect) {
        super.init(config: config, frame: frame)
        group("conn.group", NSRect(x: 0, y: 0, width: 334, height: 180))
        label("conn.ping", NSRect(x: 12, y: 22, width: 250, height: 16))
        ping = field(NSRect(x: 250, y: 20, width: 70, height: 21)); ping.delegate = self
        _ = checkbox("conn.nodelay", NSRect(x: 12, y: 50, width: 310, height: 18),
                     getter: { [weak self] in self?.config.tcpNoDelay ?? true },
                     setter: { [weak self] v in self?.config.tcpNoDelay = v })
        _ = checkbox("conn.keepalive", NSRect(x: 12, y: 70, width: 310, height: 18),
                     getter: { [weak self] in self?.config.tcpKeepalives ?? false },
                     setter: { [weak self] v in self?.config.tcpKeepalives = v })
        label("conn.loghost", NSRect(x: 12, y: 100, width: 310, height: 16))
        logh = field(NSRect(x: 12, y: 118, width: 310, height: 21)); logh.delegate = self
        loadFromConfig()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func loadFromConfig() {
        ping.stringValue = String(config.pingInterval)
        logh.stringValue = config.logHost
        refreshChecks()
    }
    func controlTextDidChange(_ obj: Notification) {
        config.pingInterval = Int(ping.stringValue) ?? 0
        config.logHost = logh.stringValue
    }
}

final class DataPanel: ConfigPanel, NSTextFieldDelegate {
    private var user: WinTextField!, term: WinTextField!, speed: WinTextField!
    private var varF: WinTextField!, valF: WinTextField!
    private let list = WinListBox(frame: .zero)
    override init(config: SessionConfig, frame: NSRect) {
        super.init(config: config, frame: frame)
        group("data.group.login", NSRect(x: 0, y: 0, width: 334, height: 360))
        _ = checkbox("data.autoUser", NSRect(x: 12, y: 22, width: 310, height: 18),
                     getter: { [weak self] in self?.config.usernameFromEnv ?? false },
                     setter: { [weak self] v in self?.config.usernameFromEnv = v })
        label("data.user", NSRect(x: 12, y: 46, width: 310, height: 16))
        user = field(NSRect(x: 12, y: 64, width: 310, height: 21)); user.delegate = self
        label("data.term", NSRect(x: 12, y: 92, width: 310, height: 16))
        term = field(NSRect(x: 12, y: 110, width: 310, height: 21)); term.delegate = self
        label("data.speed", NSRect(x: 12, y: 138, width: 310, height: 16))
        speed = field(NSRect(x: 12, y: 156, width: 310, height: 21)); speed.delegate = self
        label("data.env", NSRect(x: 12, y: 184, width: 310, height: 16))
        list.frame = NSRect(x: 12, y: 202, width: 310, height: 80); addSubview(list)
        label("data.var", NSRect(x: 12, y: 286, width: 140, height: 16))
        varF = field(NSRect(x: 12, y: 304, width: 140, height: 21))
        label("data.val", NSRect(x: 160, y: 286, width: 160, height: 16))
        valF = field(NSRect(x: 160, y: 304, width: 160, height: 21))
        _ = button("data.add", NSRect(x: 12, y: 332, width: 75, height: 23), #selector(addEnv))
        _ = button("data.remove", NSRect(x: 95, y: 332, width: 75, height: 23), #selector(rmEnv))
        loadFromConfig()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func loadFromConfig() {
        user.stringValue = config.username
        term.stringValue = config.termType
        speed.stringValue = config.termSpeed
        list.items = config.environ.map { "\($0.name)=\($0.value)" }
        refreshChecks()
    }
    func controlTextDidChange(_ obj: Notification) {
        config.username = user.stringValue
        config.termType = term.stringValue
        config.termSpeed = speed.stringValue
    }
    @objc private func addEnv() {
        let n = varF.stringValue.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        config.environ.append(EnvVar(name: n, value: valF.stringValue))
        loadFromConfig(); varF.stringValue = ""; valF.stringValue = ""
    }
    @objc private func rmEnv() {
        let i = list.selectedIndex
        guard i >= 0, i < config.environ.count else { return }
        config.environ.remove(at: i)
        loadFromConfig()
    }
}

final class ProxyPanel: ConfigPanel, NSTextFieldDelegate {
    private var host: WinTextField!, port: WinTextField!, user: WinTextField!
    private var pass: WinSecureField!, excl: WinTextField!, cmd: WinTextField!
    override init(config: SessionConfig, frame: NSRect) {
        super.init(config: config, frame: frame)
        group("proxy.group", NSRect(x: 0, y: 0, width: 334, height: 370))
        label("proxy.type", NSRect(x: 12, y: 22, width: 310, height: 16))
        _ = radioGroup(["proxy.none","proxy.socks4","proxy.socks5","proxy.http","proxy.telnet","proxy.local"],
                       frames: (0..<6).map { NSRect(x: 12 + CGFloat($0 % 3) * 105, y: 42 + CGFloat($0 / 3) * 20, width: 100, height: 18) },
                       get: { [weak self] in self?.config.proxyType.rawValue ?? 0 },
                       set: { [weak self] v in self?.config.proxyType = ProxyKind(rawValue: v) ?? .none })
        label("proxy.host", NSRect(x: 12, y: 90, width: 220, height: 16))
        host = field(NSRect(x: 12, y: 108, width: 220, height: 21)); host.delegate = self
        label("proxy.port", NSRect(x: 244, y: 90, width: 70, height: 16))
        port = field(NSRect(x: 244, y: 108, width: 76, height: 21)); port.delegate = self
        label("proxy.user", NSRect(x: 12, y: 136, width: 150, height: 16))
        user = field(NSRect(x: 12, y: 154, width: 150, height: 21)); user.delegate = self
        label("proxy.pass", NSRect(x: 172, y: 136, width: 148, height: 16))
        pass = WinSecureField(frame: NSRect(x: 172, y: 154, width: 148, height: 21)); addSubview(pass)
        pass.delegate = self
        label("proxy.exclude", NSRect(x: 12, y: 182, width: 310, height: 16))
        excl = field(NSRect(x: 12, y: 200, width: 310, height: 21)); excl.delegate = self
        label("proxy.dns", NSRect(x: 12, y: 228, width: 310, height: 16))
        _ = radioGroup(["proxy.localNo","proxy.localYes","proxy.localAuto"],
                       frames: [NSRect(x: 12, y: 246, width: 70, height: 18),
                                NSRect(x: 90, y: 246, width: 70, height: 18),
                                NSRect(x: 170, y: 246, width: 90, height: 18)],
                       get: { [weak self] in self?.config.proxyDNS ?? 0 },
                       set: { [weak self] v in self?.config.proxyDNS = v })
        _ = checkbox("proxy.evenLocal", NSRect(x: 12, y: 270, width: 310, height: 18),
                     getter: { [weak self] in self?.config.evenProxyLocal ?? false },
                     setter: { [weak self] v in self?.config.evenProxyLocal = v })
        label("proxy.telcmd", NSRect(x: 12, y: 294, width: 310, height: 16))
        cmd = field(NSRect(x: 12, y: 312, width: 310, height: 21)); cmd.delegate = self
        loadFromConfig()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func loadFromConfig() {
        host.stringValue = config.proxyHost
        port.stringValue = String(config.proxyPort)
        user.stringValue = config.proxyUsername
        pass.stringValue = config.proxyPassword
        excl.stringValue = config.proxyExclude
        cmd.stringValue = config.proxyTelnetCommand
        refreshRadios(); refreshChecks()
    }
    func controlTextDidChange(_ obj: Notification) {
        config.proxyHost = host.stringValue
        config.proxyPort = Int(port.stringValue) ?? config.proxyPort
        config.proxyUsername = user.stringValue
        config.proxyPassword = pass.stringValue
        config.proxyExclude = excl.stringValue
        config.proxyTelnetCommand = cmd.stringValue
    }
}

final class TelnetPanel: ConfigPanel {
    override init(config: SessionConfig, frame: NSRect) {
        super.init(config: config, frame: frame)
        group("telnet.group", NSRect(x: 0, y: 0, width: 334, height: 140))
        _ = checkbox("telnet.old", NSRect(x: 12, y: 22, width: 310, height: 18),
                     getter: { [weak self] in self?.config.telnetOld ?? false },
                     setter: { [weak self] v in self?.config.telnetOld = v })
        _ = checkbox("telnet.kbd", NSRect(x: 12, y: 42, width: 310, height: 18),
                     getter: { [weak self] in self?.config.telnetKeyboard ?? false },
                     setter: { [weak self] v in self?.config.telnetKeyboard = v })
        _ = checkbox("telnet.passive", NSRect(x: 12, y: 62, width: 310, height: 18),
                     getter: { [weak self] in self?.config.passiveTelnet ?? false },
                     setter: { [weak self] v in self?.config.passiveTelnet = v })
        loadFromConfig()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func loadFromConfig() { refreshChecks() }
}

final class RloginPanel: ConfigPanel, NSTextFieldDelegate {
    private var local: WinTextField!
    override init(config: SessionConfig, frame: NSRect) {
        super.init(config: config, frame: frame)
        label("rlogin.local", NSRect(x: 0, y: 8, width: 330, height: 16))
        local = field(NSRect(x: 0, y: 28, width: 330, height: 21)); local.delegate = self
        loadFromConfig()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func loadFromConfig() { local.stringValue = config.localUsername }
    func controlTextDidChange(_ obj: Notification) { config.localUsername = local.stringValue }
}

final class SSHPanel: ConfigPanel, NSTextFieldDelegate {
    private var cmd: WinTextField!
    override init(config: SessionConfig, frame: NSRect) {
        super.init(config: config, frame: frame)
        group("ssh.group.cmd", NSRect(x: 0, y: 0, width: 334, height: 200))
        label("ssh.cmd", NSRect(x: 12, y: 22, width: 310, height: 16))
        cmd = field(NSRect(x: 12, y: 40, width: 310, height: 21)); cmd.delegate = self
        _ = checkbox("ssh.subsys", NSRect(x: 12, y: 70, width: 310, height: 18),
                     getter: { [weak self] in self?.config.sshSubsys ?? false },
                     setter: { [weak self] v in self?.config.sshSubsys = v })
        _ = checkbox("ssh.nopty", NSRect(x: 12, y: 90, width: 310, height: 18),
                     getter: { [weak self] in self?.config.sshNoPTY ?? false },
                     setter: { [weak self] v in self?.config.sshNoPTY = v })
        _ = checkbox("ssh.comp", NSRect(x: 12, y: 110, width: 310, height: 18),
                     getter: { [weak self] in self?.config.compression ?? false },
                     setter: { [weak self] v in self?.config.compression = v })
        _ = checkbox("ssh.sharing", NSRect(x: 12, y: 130, width: 310, height: 18),
                     getter: { [weak self] in self?.config.sshConnectionSharing ?? false },
                     setter: { [weak self] v in self?.config.sshConnectionSharing = v })
        label("ssh.proto", NSRect(x: 12, y: 158, width: 160, height: 16))
        _ = radioGroup(["ssh.v2"], frames: [NSRect(x: 180, y: 158, width: 50, height: 18)],
                       get: { 0 }, set: { _ in })
        loadFromConfig()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func loadFromConfig() { cmd.stringValue = config.remoteCmd; refreshChecks(); refreshRadios() }
    func controlTextDidChange(_ obj: Notification) { config.remoteCmd = cmd.stringValue }
}

final class AlgoListPanel: ConfigPanel {
    private let list = WinListBox(frame: .zero)
    private var items: [String]
    private let onWrite: ([String]) -> Void
    init(config: SessionConfig, frame: NSRect, titleKey: String, items: [String], onWrite: @escaping ([String]) -> Void) {
        self.items = items
        self.onWrite = onWrite
        super.init(config: config, frame: frame)
        group(titleKey, NSRect(x: 0, y: 0, width: 334, height: 300))
        list.frame = NSRect(x: 12, y: 24, width: 230, height: 250)
        addSubview(list)
        _ = button("kex.up", NSRect(x: 250, y: 24, width: 70, height: 23), #selector(up))
        _ = button("kex.down", NSRect(x: 250, y: 53, width: 70, height: 23), #selector(down))
        reloadList()
    }
    required init?(coder: NSCoder) { fatalError() }
    private func reloadList() { list.items = items }
    @objc private func up() {
        let i = list.selectedIndex
        guard i > 0 else { return }
        items.swapAt(i, i-1); onWrite(items); reloadList(); list.selectedIndex = i-1
    }
    @objc private func down() {
        let i = list.selectedIndex
        guard i >= 0, i < items.count-1 else { return }
        items.swapAt(i, i+1); onWrite(items); reloadList(); list.selectedIndex = i+1
    }
}

final class AuthPanel: ConfigPanel, NSTextFieldDelegate {
    private var key: WinTextField!, cert: WinTextField!
    override init(config: SessionConfig, frame: NSRect) {
        super.init(config: config, frame: frame)
        group("auth.group", NSRect(x: 0, y: 0, width: 334, height: 300))
        _ = checkbox("auth.banner", NSRect(x: 12, y: 22, width: 310, height: 18),
                     getter: { [weak self] in self?.config.sshShowBanner ?? true },
                     setter: { [weak self] v in self?.config.sshShowBanner = v })
        _ = checkbox("auth.bypass", NSRect(x: 12, y: 42, width: 310, height: 18),
                     getter: { [weak self] in self?.config.sshNoUserauth ?? false },
                     setter: { [weak self] v in self?.config.sshNoUserauth = v })
        _ = checkbox("auth.tryagent", NSRect(x: 12, y: 62, width: 310, height: 18),
                     getter: { [weak self] in self?.config.tryAgent ?? true },
                     setter: { [weak self] v in self?.config.tryAgent = v })
        _ = checkbox("auth.agentfwd", NSRect(x: 12, y: 82, width: 310, height: 18),
                     getter: { [weak self] in self?.config.agentFwd ?? false },
                     setter: { [weak self] v in self?.config.agentFwd = v })
        _ = checkbox("auth.ki", NSRect(x: 12, y: 102, width: 310, height: 18),
                     getter: { [weak self] in self?.config.tryKIAuth ?? true },
                     setter: { [weak self] v in self?.config.tryKIAuth = v })
        _ = checkbox("auth.change", NSRect(x: 12, y: 122, width: 310, height: 18),
                     getter: { [weak self] in self?.config.changeUsername ?? false },
                     setter: { [weak self] v in self?.config.changeUsername = v })
        label("auth.key", NSRect(x: 12, y: 150, width: 310, height: 16))
        key = field(NSRect(x: 12, y: 168, width: 230, height: 21)); key.delegate = self
        _ = button("btn.browse", NSRect(x: 248, y: 168, width: 75, height: 23), #selector(browseKey))
        label("auth.cert", NSRect(x: 12, y: 198, width: 310, height: 16))
        cert = field(NSRect(x: 12, y: 216, width: 230, height: 21)); cert.delegate = self
        _ = button("btn.browse", NSRect(x: 248, y: 216, width: 75, height: 23), #selector(browseCert))
        loadFromConfig()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func loadFromConfig() {
        key.stringValue = config.keyFile; cert.stringValue = config.certFile; refreshChecks()
    }
    func controlTextDidChange(_ obj: Notification) {
        config.keyFile = key.stringValue; config.certFile = cert.stringValue
    }
    @objc private func browseKey() { pick { config.keyFile = $0; key.stringValue = $0 } }
    @objc private func browseCert() { pick { config.certFile = $0; cert.stringValue = $0 } }
    private func pick(_ done: (String) -> Void) {
        let p = NSOpenPanel(); p.allowsMultipleSelection = false; p.canChooseDirectories = false
        p.allowedContentTypes = [.item]
        if p.runModal() == .OK, let u = p.url { done(u.path) }
    }
}

final class GSSAPIPanel: ConfigPanel {
    override init(config: SessionConfig, frame: NSRect) {
        super.init(config: config, frame: frame)
        group("gssapi.group", NSRect(x: 0, y: 0, width: 334, height: 120))
        _ = checkbox("gssapi.try", NSRect(x: 12, y: 22, width: 310, height: 18),
                     getter: { [weak self] in self?.config.tryGSSAPI ?? false },
                     setter: { [weak self] v in self?.config.tryGSSAPI = v })
        _ = checkbox("gssapi.fwd", NSRect(x: 12, y: 42, width: 310, height: 18),
                     getter: { [weak self] in self?.config.gssapiFwd ?? false },
                     setter: { [weak self] v in self?.config.gssapiFwd = v })
        label("gssapi.none", NSRect(x: 12, y: 70, width: 310, height: 32))
        loadFromConfig()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func loadFromConfig() { refreshChecks() }
}

final class TTYPanel: ConfigPanel {
    private let list = WinListBox(frame: .zero)
    override init(config: SessionConfig, frame: NSRect) {
        super.init(config: config, frame: frame)
        group("tty.group", NSRect(x: 0, y: 0, width: 334, height: 340))
        list.frame = NSRect(x: 12, y: 24, width: 310, height: 300)
        addSubview(list)
        loadFromConfig()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func loadFromConfig() {
        list.items = config.sshTTYs.map { "\($0.0)  \($0.1 == "A" ? L.t("tty.auto") : ($0.1 == "N" ? L.t("tty.none") : $0.1))" }
    }
}

final class X11Panel: ConfigPanel, NSTextFieldDelegate {
    private var disp: WinTextField!
    override init(config: SessionConfig, frame: NSRect) {
        super.init(config: config, frame: frame)
        group("x11.group", NSRect(x: 0, y: 0, width: 334, height: 160))
        _ = checkbox("x11.enable", NSRect(x: 12, y: 22, width: 310, height: 18),
                     getter: { [weak self] in self?.config.x11Forward ?? false },
                     setter: { [weak self] v in self?.config.x11Forward = v })
        label("x11.display", NSRect(x: 12, y: 48, width: 310, height: 16))
        disp = field(NSRect(x: 12, y: 66, width: 310, height: 21)); disp.delegate = self
        label("x11.auth", NSRect(x: 12, y: 94, width: 310, height: 16))
        _ = radioGroup(["x11.mit","x11.xdm"],
                       frames: [NSRect(x: 12, y: 114, width: 160, height: 18), NSRect(x: 180, y: 114, width: 140, height: 18)],
                       get: { [weak self] in (self?.config.x11AuthType ?? 1) == 1 ? 0 : 1 },
                       set: { [weak self] v in self?.config.x11AuthType = v == 0 ? 1 : 2 })
        loadFromConfig()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func loadFromConfig() { disp.stringValue = config.x11Display; refreshChecks(); refreshRadios() }
    func controlTextDidChange(_ obj: Notification) { config.x11Display = disp.stringValue }
}

final class TunnelsPanel: ConfigPanel {
    private let list = WinListBox(frame: .zero)
    private var src: WinTextField!, dest: WinTextField!
    private var kind = 0
    override init(config: SessionConfig, frame: NSRect) {
        super.init(config: config, frame: frame)
        group("tun.group", NSRect(x: 0, y: 0, width: 334, height: 360))
        list.frame = NSRect(x: 12, y: 22, width: 310, height: 140); addSubview(list)
        _ = radioGroup(["tun.local","tun.remote","tun.dynamic"],
                       frames: [NSRect(x: 12, y: 170, width: 80, height: 18),
                                NSRect(x: 100, y: 170, width: 90, height: 18),
                                NSRect(x: 200, y: 170, width: 90, height: 18)],
                       get: { [weak self] in self?.kind ?? 0 },
                       set: { [weak self] v in self?.kind = v })
        label("tun.src", NSRect(x: 12, y: 196, width: 140, height: 16))
        src = field(NSRect(x: 12, y: 214, width: 140, height: 21))
        label("tun.dest", NSRect(x: 164, y: 196, width: 158, height: 16))
        dest = field(NSRect(x: 164, y: 214, width: 158, height: 21))
        _ = button("tun.add", NSRect(x: 12, y: 244, width: 75, height: 23), #selector(add))
        _ = button("tun.remove", NSRect(x: 95, y: 244, width: 75, height: 23), #selector(rm))
        _ = checkbox("tun.localAccept", NSRect(x: 12, y: 280, width: 310, height: 18),
                     getter: { [weak self] in self?.config.lportAcceptAll ?? false },
                     setter: { [weak self] v in self?.config.lportAcceptAll = v })
        _ = checkbox("tun.remoteAccept", NSRect(x: 12, y: 300, width: 310, height: 18),
                     getter: { [weak self] in self?.config.rportAcceptAll ?? false },
                     setter: { [weak self] v in self?.config.rportAcceptAll = v })
        loadFromConfig()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func loadFromConfig() {
        list.items = config.portFwds.map { "\($0.kind.rawValue.uppercased())\($0.sourcePort) \($0.destination)" }
        refreshChecks(); refreshRadios()
    }
    @objc private func add() {
        let s = src.stringValue.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return }
        let k: PortForward.Kind = kind == 0 ? .local : (kind == 1 ? .remote : .dynamic)
        config.portFwds.append(PortForward(kind: k, sourcePort: s, destination: dest.stringValue))
        src.stringValue = ""; dest.stringValue = ""; loadFromConfig()
    }
    @objc private func rm() {
        let i = list.selectedIndex
        guard i >= 0, i < config.portFwds.count else { return }
        config.portFwds.remove(at: i); loadFromConfig()
    }
}

final class BugsPanel: ConfigPanel {
    private let keys: [(String, ReferenceWritableKeyPath<SessionConfig, Int>)]
    init(config: SessionConfig, frame: NSRect, more: Bool) {
        if more {
            keys = [
                ("bugs.ignore2", \.sshbugIgnore2),
                ("bugs.oldgex2", \.sshbugOldGex2),
                ("bugs.winadj", \.sshbugWinadj),
                ("bugs.chanreq", \.sshbugChanReq),
                ("bugs.dropstart", \.sshbugDropStart),
                ("bugs.filterkex", \.sshbugFilterKex),
                ("bugs.rsa", \.sshbugRSA1),
            ]
        } else {
            keys = [
                ("bugs.ignore1", \.sshbugIgnore1),
                ("bugs.plainpw1", \.sshbugPlainPW1),
                ("bugs.hmac2", \.sshbugHMAC2),
                ("bugs.derivekey2", \.sshbugDeriveKey2),
                ("bugs.rsapad2", \.sshbugRSAPad2),
                ("bugs.pksessid2", \.sshbugPKSessID2),
                ("bugs.rekey2", \.sshbugRekey2),
                ("bugs.maxpkt2", \.sshbugMaxPkt2),
                ("bugs.rsasha2", \.sshbugRSASha2),
            ]
        }
        super.init(config: config, frame: frame)
        group("bugs.group", NSRect(x: 0, y: 0, width: 334, height: 370))
        for (i, k) in keys.enumerated() {
            let y = 22 + CGFloat(i) * 36
            label(k.0, NSRect(x: 12, y: y, width: 310, height: 16))
            let kp = k.1
            _ = radioGroup(["auto.auto","auto.off","auto.on"],
                           frames: [NSRect(x: 12, y: y+16, width: 80, height: 18),
                                    NSRect(x: 100, y: y+16, width: 80, height: 18),
                                    NSRect(x: 188, y: y+16, width: 80, height: 18)],
                           get: { [weak self] in self?.config[keyPath: kp] ?? 0 },
                           set: { [weak self] v in self?.config[keyPath: kp] = v })
        }
        loadFromConfig()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func loadFromConfig() { refreshRadios() }
}

final class SerialPanel: ConfigPanel, NSTextFieldDelegate {
    private var line: WinTextField!
    override init(config: SessionConfig, frame: NSRect) {
        super.init(config: config, frame: frame)
        label("serial.line", NSRect(x: 0, y: 8, width: 330, height: 16))
        line = field(NSRect(x: 0, y: 26, width: 330, height: 21)); line.delegate = self
        label("serial.speed", NSRect(x: 0, y: 56, width: 150, height: 16))
        let sp = WinSpinner(frame: NSRect(x: 160, y: 54, width: 100, height: 21)); sp.value = config.serspeed; sp.range = 50...921600
        sp.onChange = { [weak self] v in self?.config.serspeed = v }; addSubview(sp)
        label("serial.data", NSRect(x: 0, y: 84, width: 150, height: 16))
        let db = WinSpinner(frame: NSRect(x: 160, y: 82, width: 100, height: 21)); db.value = config.serdatabits; db.range = 5...8
        db.onChange = { [weak self] v in self?.config.serdatabits = v }; addSubview(db)
        label("serial.stop", NSRect(x: 0, y: 112, width: 150, height: 16))
        let st = WinSpinner(frame: NSRect(x: 160, y: 110, width: 100, height: 21)); st.value = config.serstopbits; st.range = 1...2
        st.onChange = { [weak self] v in self?.config.serstopbits = v }; addSubview(st)
        label("serial.parity", NSRect(x: 0, y: 148, width: 330, height: 16))
        _ = radioGroup(["serial.parity.none","serial.parity.odd","serial.parity.even","serial.parity.mark","serial.parity.space"],
                       frames: (0..<5).map { NSRect(x: CGFloat($0)*64, y: 166, width: 62, height: 18) },
                       get: { [weak self] in self?.config.serparity ?? 0 },
                       set: { [weak self] v in self?.config.serparity = v })
        label("serial.flow", NSRect(x: 0, y: 196, width: 330, height: 16))
        _ = radioGroup(["serial.flow.none","serial.flow.xon","serial.flow.rts","serial.flow.dsr"],
                       frames: (0..<4).map { NSRect(x: CGFloat($0)*80, y: 214, width: 78, height: 18) },
                       get: { [weak self] in self?.config.serflow ?? 1 },
                       set: { [weak self] v in self?.config.serflow = v })
        loadFromConfig()
    }
    required init?(coder: NSCoder) { fatalError() }
    override func loadFromConfig() { line.stringValue = config.serline; refreshRadios() }
    func controlTextDidChange(_ obj: Notification) { config.serline = line.stringValue }
}

enum PanelFactory {
    static func make(id: String, config: SessionConfig, frame: NSRect) -> ConfigPanel {
        switch id {
        case "session": return SessionPanel(config: config, frame: frame)
        case "logging": return LoggingPanel(config: config, frame: frame)
        case "terminal": return TerminalPanel(config: config, frame: frame)
        case "keyboard": return KeyboardPanel(config: config, frame: frame)
        case "bell": return BellPanel(config: config, frame: frame)
        case "features": return FeaturesPanel(config: config, frame: frame)
        case "window": return WindowPanel(config: config, frame: frame)
        case "appearance": return AppearancePanel(config: config, frame: frame)
        case "behaviour": return BehaviourPanel(config: config, frame: frame)
        case "translation": return TranslationPanel(config: config, frame: frame)
        case "selection": return SelectionPanel(config: config, frame: frame)
        case "colours": return ColoursPanel(config: config, frame: frame)
        case "connection": return ConnectionPanel(config: config, frame: frame)
        case "data": return DataPanel(config: config, frame: frame)
        case "proxy": return ProxyPanel(config: config, frame: frame)
        case "telnet": return TelnetPanel(config: config, frame: frame)
        case "rlogin": return RloginPanel(config: config, frame: frame)
        case "ssh": return SSHPanel(config: config, frame: frame)
        case "kex":
            return AlgoListPanel(config: config, frame: frame, titleKey: "kex.group", items: config.sshKex) { config.sshKex = $0 }
        case "hostkeys":
            return AlgoListPanel(config: config, frame: frame, titleKey: "hk.group", items: config.sshHostKey) { config.sshHostKey = $0 }
        case "cipher":
            return AlgoListPanel(config: config, frame: frame, titleKey: "cipher.group", items: config.sshCipher) { config.sshCipher = $0 }
        case "auth": return AuthPanel(config: config, frame: frame)
        case "gssapi": return GSSAPIPanel(config: config, frame: frame)
        case "tty": return TTYPanel(config: config, frame: frame)
        case "x11": return X11Panel(config: config, frame: frame)
        case "tunnels": return TunnelsPanel(config: config, frame: frame)
        case "bugs": return BugsPanel(config: config, frame: frame, more: false)
        case "morebugs": return BugsPanel(config: config, frame: frame, more: true)
        case "serial": return SerialPanel(config: config, frame: frame)
        default: return SessionPanel(config: config, frame: frame)
        }
    }
}
