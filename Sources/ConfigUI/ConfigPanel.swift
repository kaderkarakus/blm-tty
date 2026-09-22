import AppKit

class ConfigPanel: DialogFaceView {
    var config: SessionConfig
    var locals: [LocalizableUI] = []

    init(config: SessionConfig, frame: NSRect) {
        self.config = config
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError() }

    func bind(_ config: SessionConfig) {
        self.config = config
        loadFromConfig()
    }

    func loadFromConfig() {}
    func saveToConfig() {}

    func reloadTexts() {
        func walk(_ v: NSView) {
            if let l = v as? LocalizableUI { l.reloadTexts() }
            v.subviews.forEach(walk)
        }
        walk(self)
        locals.forEach { $0.reloadTexts() }
    }

    @discardableResult
    func label(_ key: String, _ r: NSRect) -> WinLabel {
        let l = WinLabel(key: key, frame: r)
        addSubview(l)
        return l
    }

    @discardableResult
    func group(_ key: String, _ r: NSRect) -> WinGroupBox {
        let g = WinGroupBox(key: key, frame: r)
        addSubview(g)
        return g
    }

    @discardableResult
    func checkbox(_ key: String, _ r: NSRect, getter: @escaping () -> Bool, setter: @escaping (Bool) -> Void) -> WinCheckbox {
        let c = WinCheckbox(key: key, frame: r)
        c.state = getter() ? .on : .off
        c.target = self
        c.action = #selector(boolChanged(_:))
        c.tag = checkboxes.count
        checkboxes.append((c, getter, setter))
        addSubview(c)
        return c
    }

    private var checkboxes: [(WinCheckbox, () -> Bool, (Bool) -> Void)] = []

    @objc private func boolChanged(_ sender: WinCheckbox) {
        if let item = checkboxes.first(where: { $0.0 === sender }) {
            item.2(sender.state == .on)
        }
    }

    func refreshChecks() {
        for (c, g, _) in checkboxes { c.state = g() ? .on : .off }
    }

    @discardableResult
    func radioGroup(_ keys: [String], frames: [NSRect], get: @escaping () -> Int, set: @escaping (Int) -> Void) -> [WinRadio] {
        var radios: [WinRadio] = []
        for (i, key) in keys.enumerated() {
            let r = WinRadio(key: key, frame: frames[i])
            r.tag = i
            r.state = get() == i ? .on : .off
            r.target = self
            r.action = #selector(radioHit(_:))
            addSubview(r)
            radios.append(r)
        }
        radios.forEach { $0.group = radios }
        radioGroups.append((radios, get, set))
        return radios
    }

    private var radioGroups: [([WinRadio], () -> Int, (Int) -> Void)] = []

    @objc private func radioHit(_ sender: WinRadio) {
        for (radios, _, set) in radioGroups where radios.contains(where: { $0 === sender }) {
            for r in radios { r.state = r === sender ? .on : .off }
            set(sender.tag)
            extraRadioChanged(sender)
        }
    }

    func extraRadioChanged(_ sender: WinRadio) {}

    func refreshRadios() {
        for (radios, get, _) in radioGroups {
            let v = get()
            for r in radios { r.state = r.tag == v ? .on : .off }
        }
    }

    @discardableResult
    func field(_ r: NSRect) -> WinTextField {
        let f = WinTextField(frame: r)
        addSubview(f)
        return f
    }

    @discardableResult
    func button(_ key: String, _ r: NSRect, _ sel: Selector) -> WinButton {
        let b = WinButton(key: key, frame: r)
        b.target = self
        b.action = sel
        addSubview(b)
        return b
    }
}
