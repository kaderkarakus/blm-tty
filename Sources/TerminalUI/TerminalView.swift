import AppKit

final class TerminalView: NSView {
    let emulator: TerminalEmulator
    let config: SessionConfig
    var onInput: ((Data) -> Void)?
    private var cellW: CGFloat = 8
    private var cellH: CGFloat = 16
    private var font: NSFont
    private var blinkOn = true
    private var blinkTimer: Timer?
    private var selStart: (Int, Int)?
    private var selEnd: (Int, Int)?
    private var selecting = false
    private let scroller = NSScroller()
    private var wheelRemain: CGFloat = 0
    var scrollOffset = 0 {
        didSet {
            let clamped = min(emulator.scrollbackCount, max(0, scrollOffset))
            if clamped != scrollOffset {
                scrollOffset = clamped
                return
            }
            needsDisplay = true
            refreshScroller()
        }
    }

    init(emulator: TerminalEmulator, config: SessionConfig) {
        self.emulator = emulator
        self.config = config
        self.font = NSFont(name: config.fontName, size: config.fontSize) ?? WinFont.mono(config.fontSize)
        super.init(frame: .zero)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layer?.backgroundColor = config.colours[2].nsColor.cgColor
        autoresizingMask = [.width, .height]
        scroller.controlSize = .regular
        scroller.scrollerStyle = .legacy
        scroller.knobStyle = .default
        scroller.target = self
        scroller.action = #selector(scrollerAction(_:))
        addSubview(scroller)
        measure()
        if config.blinkCur {
            blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.53, repeats: true) { [weak self] _ in
                self?.blinkOn.toggle()
                self?.needsDisplay = true
            }
        }
        emulator.onBell = { [weak self] in self?.bell() }
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit { blinkTimer?.invalidate() }

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func menu(for event: NSEvent) -> NSMenu? { nil }

    func measure() {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let z = NSAttributedString(string: "M", attributes: attrs).size()
        cellW = max(6, ceil(z.width))
        cellH = max(12, ceil(font.ascender - font.descender + font.leading + 2))
    }

    var cellSize: NSSize { NSSize(width: cellW, height: cellH) }

    /// Terminal.app: metin titlebar/kenar/köşe yarıçapına yapışmaz; zemin köşeyi doldurur.
    private var chromePad: CGFloat { 6 }

    private var edgeInset: CGFloat {
        chromePad + CGFloat(max(0, config.windowBorder))
    }

    private var scrollGutter: CGFloat {
        guard config.scrollbar else { return 0 }
        return NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
    }

    func intrinsicTerminalSize() -> NSSize {
        let b = edgeInset
        return NSSize(
            width: cellW * CGFloat(emulator.cols) + b * 2 + scrollGutter,
            height: cellH * CGFloat(emulator.rows) + b * 2
        )
    }

    override func layout() {
        super.layout()
        applyResize(to: bounds.size)
        placeScroller()
    }

    func applyResize(to size: NSSize) {
        let b = edgeInset
        let gutter = scrollGutter
        guard size.width >= cellW * 2 + b * 2 + gutter, size.height >= cellH * 2 + b * 2 else { return }
        let cols = max(2, Int((size.width - b * 2 - gutter) / cellW))
        let rows = max(2, Int((size.height - b * 2) / cellH))
        if cols != emulator.cols || rows != emulator.rows {
            emulator.resize(cols: cols, rows: rows)
        }
        if scrollOffset > emulator.scrollbackCount {
            scrollOffset = emulator.scrollbackCount
        }
        needsDisplay = true
        refreshScroller()
    }

    /// Düz hücre ızgarası; kalan piksel inset/zemin olarak kalır (köşe kırpılmaz).
    private func cellRect(x: Int, y: Int) -> NSRect {
        let b = edgeInset
        return NSRect(
            x: b + CGFloat(x) * cellW,
            y: b + CGFloat(y) * cellH,
            width: cellW,
            height: cellH
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        config.colours[2].nsColor.setFill()
        bounds.fill()
        for y in 0..<emulator.rows {
            for x in 0..<emulator.cols {
                let cell = emulator.cell(at: x, y: y, scrollOffset: scrollOffset)
                let r = cellRect(x: x, y: y)
                var fg = colorFor(cell.attr, fg: true)
                var bg = colorFor(cell.attr, fg: false)
                if cell.attr.inverse { swap(&fg, &bg) }
                if isSelected(x, y) {
                    fg = .white; bg = WinPalette.accent
                }
                bg.setFill()
                r.fill()
                let ch = String(Character(cell.scalar))
                if ch != " " {
                    var f = font
                    if cell.attr.bold && config.boldAsFont {
                        f = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
                    }
                    let para = NSMutableParagraphStyle()
                    para.alignment = .left
                    ch.draw(in: NSRect(x: r.minX, y: r.minY - font.descender + 1, width: cellW + 2, height: cellH),
                            withAttributes: [.font: f, .foregroundColor: fg, .paragraphStyle: para])
                    if cell.attr.underline {
                        fg.setStroke()
                        let p = NSBezierPath()
                        p.move(to: NSPoint(x: r.minX, y: r.maxY - 2))
                        p.line(to: NSPoint(x: r.maxX, y: r.maxY - 2))
                        p.lineWidth = 1
                        p.stroke()
                    }
                }
            }
        }
        if emulator.cursorVisible && blinkOn && scrollOffset == 0 {
            let r = cellRect(x: emulator.cursorX, y: emulator.cursorY)
            let cc = config.colours[5].nsColor
            switch config.cursorType {
            case 1:
                cc.setFill()
                NSRect(x: r.minX, y: r.maxY - 2, width: r.width, height: 2).fill()
            case 2:
                cc.setFill()
                NSRect(x: r.minX, y: r.minY, width: 2, height: r.height).fill()
            default:
                cc.setFill()
                r.fill()
                let ch = String(Character(emulator.cell(at: emulator.cursorX, y: emulator.cursorY, scrollOffset: 0).scalar))
                ch.draw(in: NSRect(x: r.minX, y: r.minY - font.descender + 1, width: cellW, height: cellH),
                        withAttributes: [.font: font, .foregroundColor: config.colours[4].nsColor])
            }
        }
    }

    private func colorFor(_ a: CellAttr, fg: Bool) -> NSColor {
        if fg {
            if let rgb = a.fgRGB { return rgb.nsColor }
            if a.fg < 0 { return config.colours[a.bold && config.boldAsColour ? 1 : 0].nsColor }
            return indexed(a.fg, bold: a.bold && config.boldAsColour)
        } else {
            if let rgb = a.bgRGB { return rgb.nsColor }
            if a.bg < 0 { return config.colours[2].nsColor }
            return indexed(a.bg, bold: false)
        }
    }

    private func indexed(_ i: Int, bold: Bool) -> NSColor {
        var idx = i
        if bold && idx < 8 { idx += 8 }
        if idx < 16 {
            return config.colours[6 + idx].nsColor
        }
        if idx < 232 {
            let n = idx - 16
            let r = n / 36, g = (n / 6) % 6, b = n % 6
            let v: (Int) -> Int = { $0 == 0 ? 0 : 55 + $0 * 40 }
            return RGB8(r: v(r), g: v(g), b: v(b)).nsColor
        }
        let g = 8 + (idx - 232) * 10
        return RGB8(r: g, g: g, b: g).nsColor
    }

    private var hasSelection: Bool {
        guard let a = selStart, let b = selEnd else { return false }
        return a != b
    }

    private func clearSelection() {
        guard selStart != nil || selEnd != nil else { return }
        selStart = nil
        selEnd = nil
        selecting = false
        needsDisplay = true
    }

    private func isSelected(_ x: Int, _ y: Int) -> Bool {
        guard hasSelection, let a = selStart, let b = selEnd else { return false }
        let p1 = a.1 * emulator.cols + a.0
        let p2 = b.1 * emulator.cols + b.0
        let lo = min(p1, p2), hi = max(p1, p2)
        let p = y * emulator.cols + x
        return p >= lo && p <= hi
    }

    override func keyDown(with event: NSEvent) {
        if handleHistoryKeys(event) { return }
        clearSelection()
        if let data = emulator.keyDown(event, config: config) {
            onInput?(data)
            if config.scrollOnKey { scrollOffset = 0 }
        }
    }

    override func scrollWheel(with event: NSEvent) {
        let raw: CGFloat
        if event.hasPreciseScrollingDeltas {
            raw = event.scrollingDeltaY
        } else {
            raw = event.scrollingDeltaY * cellH
        }
        wheelRemain += raw
        let lines = Int(wheelRemain / cellH)
        guard lines != 0 else { return }
        wheelRemain -= CGFloat(lines) * cellH
        if emulator.altScreen {
            let seq = lines > 0 ? "\u{1b}[A" : "\u{1b}[B"
            onInput?(Data(String(repeating: seq, count: abs(lines)).utf8))
            return
        }
        scrollOffset += lines
    }

    private func handleHistoryKeys(_ event: NSEvent) -> Bool {
        if emulator.altScreen { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) || flags.contains(.control) { return false }
        let shift = flags.contains(.shift)
        switch event.keyCode {
        case 116:
            scrollOffset += emulator.rows
            return true
        case 121:
            scrollOffset -= emulator.rows
            return true
        case 115 where shift:
            scrollOffset = emulator.scrollbackCount
            return true
        case 119 where shift:
            scrollOffset = 0
            return true
        default:
            return false
        }
    }

    private func placeScroller() {
        if !config.scrollbar {
            scroller.isHidden = true
            return
        }
        scroller.isHidden = false
        let w = scrollGutter
        scroller.frame = NSRect(x: bounds.maxX - w, y: 0, width: w, height: bounds.height)
    }

    private func refreshScroller() {
        guard config.scrollbar else { return }
        let maxOff = emulator.scrollbackCount
        let total = max(1, maxOff + emulator.rows)
        scroller.knobProportion = max(0.05, CGFloat(emulator.rows) / CGFloat(total))
        if maxOff <= 0 {
            scroller.doubleValue = 1
            scroller.isEnabled = false
        } else {
            scroller.isEnabled = true
            scroller.doubleValue = 1.0 - Double(scrollOffset) / Double(maxOff)
        }
    }

    @objc private func scrollerAction(_ sender: NSScroller) {
        let maxOff = emulator.scrollbackCount
        switch sender.hitPart {
        case .decrementPage:
            scrollOffset += emulator.rows
        case .incrementPage:
            scrollOffset -= emulator.rows
        case .decrementLine:
            scrollOffset += 1
        case .incrementLine:
            scrollOffset -= 1
        case .knob, .knobSlot:
            if maxOff <= 0 {
                scrollOffset = 0
            } else {
                scrollOffset = Int((1.0 - sender.doubleValue) * Double(maxOff) + 0.5)
            }
        default:
            break
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let p = convert(event.locationInWindow, from: nil)
        selecting = true
        selStart = hit(p)
        selEnd = selStart
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard selecting else { return }
        let p = convert(event.locationInWindow, from: nil)
        selEnd = hit(p)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        selecting = false
        if !hasSelection {
            clearSelection()
            return
        }
        if config.mouseAutocopy { copySelection() }
    }

    override func rightMouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if config.mousePaste { pasteClipboard(nil) }
    }

    override func rightMouseUp(with event: NSEvent) {}

    override func otherMouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if config.mouseIsXterm != 0 { pasteClipboard(nil) }
    }

    private func hit(_ p: NSPoint) -> (Int, Int) {
        let b = edgeInset
        let x = min(emulator.cols - 1, max(0, Int((p.x - b) / cellW)))
        let y = min(emulator.rows - 1, max(0, Int((p.y - b) / cellH)))
        return (x, y)
    }

    func copySelection() {
        guard hasSelection, let a = selStart, let b = selEnd else { return }
        let x0 = min(a.0, b.0), x1 = max(a.0, b.0)
        let y0 = min(a.1, b.1), y1 = max(a.1, b.1)
        guard x0 <= x1, y0 <= y1 else { return }
        var s = ""
        for y in y0...y1 {
            var line = ""
            for x in x0...x1 {
                line.append(Character(emulator.cell(at: x, y: y, scrollOffset: scrollOffset).scalar))
            }
            s += line.trimmingCharacters(in: .whitespaces) + "\n"
        }
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }

    @objc func paste(_ sender: Any?) { pasteClipboard(sender) }

    @objc func pasteClipboard(_ sender: Any?) {
        clearSelection()
        guard let raw = blm_clipboard_string() else { return }
        let s = String(raw)
        guard !s.isEmpty else { return }
        var text = s.replacingOccurrences(of: "\r\n", with: "\r")
        text = text.replacingOccurrences(of: "\n", with: "\r")
        guard let payload = text.data(using: .utf8), !payload.isEmpty else { return }
        var data = payload
        if emulator.bracketPaste {
            var d = Data("\u{1b}[200~".utf8)
            d.append(data)
            d.append(Data("\u{1b}[201~".utf8))
            data = d
        }
        onInput?(data)
        if config.scrollOnKey { scrollOffset = 0 }
    }

    @objc func copyClipboard(_ sender: Any?) { copySelection() }

    @objc func selectAllCells(_ sender: Any?) {
        selStart = (0, 0)
        selEnd = (emulator.cols - 1, emulator.rows - 1)
        needsDisplay = true
    }

    private func bell() {
        switch config.beep {
        case 0: break
        case 1:
            let old = alphaValue
            animator().alphaValue = 0.3
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { self.animator().alphaValue = old }
        default:
            NSSound.beep()
        }
    }

    func feed(_ data: Data) {
        emulator.feed(data)
        if config.scrollOnDisp {
            scrollOffset = 0
        } else if scrollOffset > 0 {
            scrollOffset = min(emulator.scrollbackCount, scrollOffset + emulator.lastScrollbackPushed)
        }
        needsDisplay = true
        refreshScroller()
    }
}
