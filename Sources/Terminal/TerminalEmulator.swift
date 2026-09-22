import AppKit
import Foundation

struct CellAttr: Equatable {
    var fg: Int = -1
    var bg: Int = -1
    var fgRGB: RGB8? = nil
    var bgRGB: RGB8? = nil
    var bold = false
    var underline = false
    var inverse = false
    var blink = false
}

struct TermCell {
    var scalar: UnicodeScalar = " "
    var attr: CellAttr = CellAttr()
}

final class TerminalEmulator {
    var cols: Int
    var rows: Int
    var saveLines: Int
    var wrap: Bool
    var cursorX = 0
    var cursorY = 0
    var originMode = false
    var insertMode = false
    var cursorVisible = true
    var altScreen = false
    var applicationCursor = false
    var applicationKeypad = false
    var bracketPaste = false
    var mouseMode = 0
    var title = ""
    var scrollTop = 0
    var scrollBottom = 0
    var attr = CellAttr()
    var onBell: (() -> Void)?
    var onTitle: ((String) -> Void)?
    var onResize: ((Int, Int) -> Void)?
    var onWrite: ((Data) -> Void)?

    private var primary: [[TermCell]]
    private var alternate: [[TermCell]]
    private var scrollback: [[TermCell]] = []
    private(set) var lastScrollbackPushed = 0
    private var savedX = 0, savedY = 0
    private var savedAttr = CellAttr()
    private var parser = EscapeParser()
    private var g0 = "B"
    private var utf8 = UTF8()

    var screen: [[TermCell]] {
        get { altScreen ? alternate : primary }
        set { if altScreen { alternate = newValue } else { primary = newValue } }
    }

    init(config: SessionConfig) {
        cols = max(2, config.width)
        rows = max(2, config.height)
        saveLines = config.saveLines
        wrap = config.wrapMode
        originMode = config.decOrigin
        primary = TerminalEmulator.blank(cols: config.width, rows: config.height)
        alternate = TerminalEmulator.blank(cols: config.width, rows: config.height)
        scrollBottom = rows - 1
        parser.onPrint = { [weak self] s in self?.printChar(s) }
        parser.onC0 = { [weak self] b in self?.c0(b) }
        parser.onCSI = { [weak self] p, i, f in self?.csi(p, i, f) }
        parser.onOSC = { [weak self] n, s in self?.osc(n, s) }
        parser.onESC = { [weak self] c, i in self?.esc(c, i) }
    }

    static func blank(cols: Int, rows: Int) -> [[TermCell]] {
        Array(repeating: Array(repeating: TermCell(), count: cols), count: rows)
    }

    func feed(_ data: Data) {
        lastScrollbackPushed = 0
        parser.feed(data)
    }

    func cell(at x: Int, y: Int, scrollOffset: Int) -> TermCell {
        if scrollOffset > 0 {
            let idx = scrollback.count - scrollOffset + y
            if idx >= 0 && idx < scrollback.count {
                let row = scrollback[idx]
                if x < row.count { return row[x] }
                return TermCell()
            }
            let sy = y - scrollOffset
            if sy >= 0 && sy < rows && x < cols { return screen[sy][x] }
            return TermCell()
        }
        if y >= 0 && y < rows && x >= 0 && x < cols { return screen[y][x] }
        return TermCell()
    }

    var scrollbackCount: Int { scrollback.count }

    func resize(cols newCols: Int, rows newRows: Int) {
        let c = max(2, newCols), r = max(2, newRows)
        func fit(_ grid: inout [[TermCell]]) {
            if grid.count > r { grid = Array(grid.suffix(r)) }
            while grid.count < r { grid.append(Array(repeating: TermCell(), count: c)) }
            for i in grid.indices {
                if grid[i].count > c { grid[i] = Array(grid[i].prefix(c)) }
                while grid[i].count < c { grid[i].append(TermCell()) }
            }
        }
        fit(&primary); fit(&alternate)
        cols = c; rows = r
        scrollBottom = rows - 1
        scrollTop = 0
        cursorX = min(cursorX, cols - 1)
        cursorY = min(cursorY, rows - 1)
        onResize?(cols, rows)
    }

    func textIn(rect: NSRect, cellW: CGFloat, cellH: CGFloat, scrollOffset: Int) -> String {
        let x0 = max(0, Int(rect.minX / cellW))
        let y0 = max(0, Int(rect.minY / cellH))
        let x1 = min(cols - 1, Int((rect.maxX - 1) / cellW))
        let y1 = min(rows - 1, Int((rect.maxY - 1) / cellH))
        var out = ""
        for y in y0...y1 {
            var line = ""
            for x in x0...x1 {
                line.append(Character(cell(at: x, y: y, scrollOffset: scrollOffset).scalar))
            }
            out += line.trimmingCharacters(in: .whitespaces) + "\n"
        }
        return out
    }

    func allText() -> String {
        var lines: [String] = []
        for row in scrollback {
            lines.append(String(row.map { Character($0.scalar) }).trimmingCharacters(in: .whitespaces))
        }
        for row in screen {
            lines.append(String(row.map { Character($0.scalar) }).trimmingCharacters(in: .whitespaces))
        }
        return lines.joined(separator: "\n")
    }

    func reset() {
        attr = CellAttr()
        cursorX = 0; cursorY = 0
        altScreen = false
        applicationCursor = false
        wrap = true
        primary = TerminalEmulator.blank(cols: cols, rows: rows)
        alternate = TerminalEmulator.blank(cols: cols, rows: rows)
        scrollTop = 0; scrollBottom = rows - 1
    }

    func clearScrollback() {
        scrollback.removeAll()
        lastScrollbackPushed = 0
    }

    // MARK: - Input from keyboard

    func keyDown(_ event: NSEvent, config: SessionConfig) -> Data? {
        if event.modifierFlags.contains(.function) { }
        guard let chars = event.charactersIgnoringModifiers else { return nil }
        let flags = event.modifierFlags
        let key = event.keyCode
        if key == 51 { // backspace
            return Data([config.bkspIsDelete ? 0x7F : 0x08])
        }
        if key == 36 { return Data([0x0D]) }
        if key == 48 { return Data([0x09]) }
        if key == 53 { return Data([0x1B]) }
        if flags.contains(.control), let c = chars.utf8.first {
            let u = c >= 97 ? c - 96 : (c >= 65 ? c - 64 : c)
            return Data([u])
        }
        let arrows: [UInt16: String] = [
            126: applicationCursor ? "\u{1b}OA" : "\u{1b}[A",
            125: applicationCursor ? "\u{1b}OB" : "\u{1b}[B",
            124: applicationCursor ? "\u{1b}OC" : "\u{1b}[C",
            123: applicationCursor ? "\u{1b}OD" : "\u{1b}[D",
        ]
        if let s = arrows[key] { return s.data(using: .utf8) }
        if key == 115 { return (config.rxvtHomeEnd ? "\u{1b}[7~" : "\u{1b}[H").data(using: .utf8) }
        if key == 119 { return (config.rxvtHomeEnd ? "\u{1b}[8~" : "\u{1b}[F").data(using: .utf8) }
        if key == 116 { return "\u{1b}[5~".data(using: .utf8) }
        if key == 121 { return "\u{1b}[6~".data(using: .utf8) }
        if key == 117 { return "\u{1b}[3~".data(using: .utf8) }
        let fn: [UInt16: String] = [
            122: "\u{1b}OP", 120: "\u{1b}OQ", 99: "\u{1b}OR", 118: "\u{1b}OS",
            96: "\u{1b}[15~", 97: "\u{1b}[17~", 98: "\u{1b}[18~", 100: "\u{1b}[19~",
            101: "\u{1b}[20~", 109: "\u{1b}[21~", 103: "\u{1b}[23~", 111: "\u{1b}[24~",
        ]
        if let s = fn[key] { return s.data(using: .utf8) }
        return event.characters?.data(using: .utf8)
    }

    // MARK: - Private

    private func printChar(_ s: UnicodeScalar) {
        if cursorX >= cols {
            if wrap {
                cursorX = 0
                lineFeed()
            } else {
                cursorX = cols - 1
            }
        }
        if insertMode { insertBlanks(1) }
        if cursorY < rows && cursorX < cols {
            screen[cursorY][cursorX] = TermCell(scalar: s, attr: attr)
            cursorX += 1
        }
    }

    private func c0(_ b: UInt8) {
        switch b {
        case 0x07: onBell?()
        case 0x08:
            if cursorX > 0 { cursorX -= 1 }
            else if wrap && cursorY > 0 { cursorY -= 1; cursorX = cols - 1 }
        case 0x09:
            cursorX = min(cols - 1, ((cursorX / 8) + 1) * 8)
        case 0x0A, 0x0B, 0x0C: lineFeed()
        case 0x0D: cursorX = 0
        case 0x0E, 0x0F: break
        default: break
        }
    }

    private func lineFeed() {
        if cursorY == scrollBottom {
            scrollUp()
        } else if cursorY < rows - 1 {
            cursorY += 1
        }
    }

    private func scrollUp() {
        let row = screen[scrollTop]
        if !altScreen {
            scrollback.append(row)
            lastScrollbackPushed += 1
            if scrollback.count > saveLines {
                scrollback.removeFirst(scrollback.count - saveLines)
            }
        }
        var g = screen
        g.remove(at: scrollTop)
        g.insert(Array(repeating: TermCell(scalar: " ", attr: attr), count: cols), at: scrollBottom)
        screen = g
    }

    private func scrollDown() {
        var g = screen
        g.remove(at: scrollBottom)
        g.insert(Array(repeating: TermCell(), count: cols), at: scrollTop)
        screen = g
    }

    private func insertBlanks(_ n: Int) {
        guard cursorY < rows else { return }
        var row = screen[cursorY]
        for _ in 0..<n {
            if cursorX < row.count { row.insert(TermCell(), at: cursorX) }
        }
        if row.count > cols { row = Array(row.prefix(cols)) }
        screen[cursorY] = row
    }

    private func csi(_ params: [Int], _ inter: String, _ final: UInt8) {
        let p = { (i: Int, d: Int) -> Int in params.indices.contains(i) && params[i] != 0 ? params[i] : d }
        switch final {
        case 0x41: cursorY = max(originMode ? scrollTop : 0, cursorY - p(0, 1))
        case 0x42: cursorY = min(originMode ? scrollBottom : rows - 1, cursorY + p(0, 1))
        case 0x43: cursorX = min(cols - 1, cursorX + p(0, 1))
        case 0x44: cursorX = max(0, cursorX - p(0, 1))
        case 0x48, 0x66:
            let y = p(0, 1) - 1 + (originMode ? scrollTop : 0)
            let x = p(1, 1) - 1
            cursorY = min(max(y, 0), rows - 1)
            cursorX = min(max(x, 0), cols - 1)
        case 0x4A:
            switch params.first ?? 0 {
            case 0: eraseInDisplay(from: cursorY, x: cursorX, toEnd: true)
            case 1: eraseInDisplay(from: 0, x: 0, toEnd: false)
            case 2, 3:
                for y in 0..<rows { screen[y] = Array(repeating: TermCell(scalar: " ", attr: attr), count: cols) }
            default: break
            }
        case 0x4B:
            guard cursorY < rows else { return }
            switch params.first ?? 0 {
            case 0:
                for x in cursorX..<cols { screen[cursorY][x] = TermCell(scalar: " ", attr: attr) }
            case 1:
                for x in 0...cursorX where x < cols { screen[cursorY][x] = TermCell(scalar: " ", attr: attr) }
            case 2:
                screen[cursorY] = Array(repeating: TermCell(scalar: " ", attr: attr), count: cols)
            default: break
            }
        case 0x6D: sgr(params)
        case 0x6E:
            if (params.first ?? 0) == 6 {
                let r = "\u{1b}[\(cursorY+1);\(cursorX+1)R"
                onWrite?(r.data(using: .utf8)!)
            }
        case 0x72:
            scrollTop = max(0, p(0, 1) - 1)
            scrollBottom = min(rows - 1, (params.indices.contains(1) ? params[1] : rows) - 1)
            if scrollBottom <= scrollTop { scrollBottom = rows - 1 }
            cursorX = 0; cursorY = scrollTop
        case 0x68, 0x6C:
            let set = final == 0x68
            if inter.contains("?") { decPrivate(params, set) }
            else if params.contains(4) { insertMode = set }
        case 0x40: insertBlanks(p(0, 1))
        case 0x50:
            guard cursorY < rows else { return }
            var row = screen[cursorY]
            let n = p(0, 1)
            for _ in 0..<n where cursorX < row.count { row.remove(at: cursorX) }
            while row.count < cols { row.append(TermCell()) }
            screen[cursorY] = row
        case 0x4C:
            for _ in 0..<p(0, 1) { scrollDown() }
        case 0x4D:
            for _ in 0..<p(0, 1) { scrollUp() }
        case 0x47: cursorX = min(cols - 1, max(0, p(0, 1) - 1))
        case 0x64: cursorY = min(rows - 1, max(0, p(0, 1) - 1))
        case 0x58:
            for i in 0..<p(0, 1) {
                let x = cursorX + i
                if cursorY < rows && x < cols { screen[cursorY][x] = TermCell(scalar: " ", attr: attr) }
            }
        case 0x53: for _ in 0..<p(0, 1) { scrollUp() }
        case 0x54: for _ in 0..<p(0, 1) { scrollDown() }
        default: break
        }
    }

    private func eraseInDisplay(from y0: Int, x: Int, toEnd: Bool) {
        if toEnd {
            if y0 < rows {
                for x0 in x..<cols { screen[y0][x0] = TermCell(scalar: " ", attr: attr) }
            }
            for y in (y0+1)..<rows { screen[y] = Array(repeating: TermCell(scalar: " ", attr: attr), count: cols) }
        } else {
            for y in 0..<y0 { screen[y] = Array(repeating: TermCell(scalar: " ", attr: attr), count: cols) }
            if y0 < rows {
                for x0 in 0...min(x, cols-1) { screen[y0][x0] = TermCell(scalar: " ", attr: attr) }
            }
        }
    }

    private func sgr(_ params: [Int]) {
        let ps = params.isEmpty ? [0] : params
        var i = 0
        while i < ps.count {
            let n = ps[i]
            switch n {
            case 0: attr = CellAttr()
            case 1: attr.bold = true
            case 4: attr.underline = true
            case 5: attr.blink = true
            case 7: attr.inverse = true
            case 22: attr.bold = false
            case 24: attr.underline = false
            case 25: attr.blink = false
            case 27: attr.inverse = false
            case 30...37: attr.fg = n - 30; attr.fgRGB = nil
            case 39: attr.fg = -1; attr.fgRGB = nil
            case 40...47: attr.bg = n - 40; attr.bgRGB = nil
            case 49: attr.bg = -1; attr.bgRGB = nil
            case 90...97: attr.fg = n - 90 + 8; attr.fgRGB = nil
            case 100...107: attr.bg = n - 100 + 8; attr.bgRGB = nil
            case 38, 48:
                let isFg = n == 38
                if i + 1 < ps.count && ps[i+1] == 5, i + 2 < ps.count {
                    let idx = ps[i+2]
                    if isFg { attr.fg = idx; attr.fgRGB = nil } else { attr.bg = idx; attr.bgRGB = nil }
                    i += 2
                } else if i + 1 < ps.count && ps[i+1] == 2, i + 4 < ps.count {
                    let rgb = RGB8(r: ps[i+2], g: ps[i+3], b: ps[i+4])
                    if isFg { attr.fgRGB = rgb; attr.fg = -2 } else { attr.bgRGB = rgb; attr.bg = -2 }
                    i += 4
                }
            default: break
            }
            i += 1
        }
    }

    private func decPrivate(_ params: [Int], _ set: Bool) {
        for n in params {
            switch n {
            case 1: applicationCursor = set
            case 7: wrap = set
            case 12, 13: break
            case 25: cursorVisible = set
            case 47, 1047, 1049:
                if set {
                    if n == 1049 { savedX = cursorX; savedY = cursorY; savedAttr = attr }
                    altScreen = true
                    if n == 1049 { alternate = TerminalEmulator.blank(cols: cols, rows: rows) }
                } else {
                    altScreen = false
                    if n == 1049 { cursorX = savedX; cursorY = savedY; attr = savedAttr }
                }
            case 2004: bracketPaste = set
            case 1000: mouseMode = set ? 1000 : 0
            case 1002: mouseMode = set ? 1002 : 0
            case 1006: break
            default: break
            }
        }
    }

    private func osc(_ n: Int, _ s: String) {
        if n == 0 || n == 2 {
            title = s
            onTitle?(s)
        }
    }

    private func esc(_ c: UInt8, _ inter: String) {
        switch c {
        case 0x37: savedX = cursorX; savedY = cursorY; savedAttr = attr
        case 0x38: cursorX = savedX; cursorY = savedY; attr = savedAttr
        case 0x4D:
            if cursorY == scrollTop { scrollDown() } else if cursorY > 0 { cursorY -= 1 }
        case 0x45: cursorX = 0; lineFeed()
        case 0x44: lineFeed()
        case 0x63: reset()
        default: break
        }
    }
}

final class EscapeParser {
    enum State { case ground, esc, csi, osc, oscEsc, charset }
    var onPrint: ((UnicodeScalar) -> Void)?
    var onC0: ((UInt8) -> Void)?
    var onCSI: (([Int], String, UInt8) -> Void)?
    var onOSC: ((Int, String) -> Void)?
    var onESC: ((UInt8, String) -> Void)?
    private var state: State = .ground
    private var params = ""
    private var inter = ""
    private var osc = ""
    private var utf: [UInt8] = []

    func feed(_ data: Data) {
        for b in data { consume(b) }
    }

    private func consume(_ b: UInt8) {
        switch state {
        case .ground:
            if b == 0x1B { state = .esc; inter = ""; return }
            if b < 0x20 { onC0?(b); return }
            utf.append(b)
            flushUTF()
        case .esc:
            if b == 0x5B { state = .csi; params = ""; inter = ""; return }
            if b == 0x5D { state = .osc; osc = ""; return }
            if b == 0x28 || b == 0x29 || b == 0x2A || b == 0x2B { state = .charset; return }
            if b >= 0x20 && b <= 0x2F { inter.append(Character(UnicodeScalar(b))); return }
            onESC?(b, inter)
            state = .ground
        case .csi:
            if b >= 0x30 && b <= 0x3F { params.append(Character(UnicodeScalar(b))); return }
            if b >= 0x20 && b <= 0x2F { inter.append(Character(UnicodeScalar(b))); return }
            if b >= 0x40 && b <= 0x7E {
                onCSI?(parseParams(params), inter, b)
                state = .ground
                return
            }
            state = .ground
        case .osc:
            if b == 0x07 { finishOSC(); return }
            if b == 0x1B { state = .oscEsc; return }
            if b == 0x9C { finishOSC(); return }
            osc.append(Character(UnicodeScalar(b)))
        case .oscEsc:
            if b == 0x5C { finishOSC() } else { osc.append("\u{1b}"); osc.append(Character(UnicodeScalar(b))); state = .osc }
        case .charset:
            state = .ground
        }
    }

    private func finishOSC() {
        let parts = osc.split(separator: ";", maxSplits: 1).map(String.init)
        let n = Int(parts.first ?? "0") ?? 0
        onOSC?(n, parts.count > 1 ? parts[1] : "")
        osc = ""; state = .ground
    }

    private func parseParams(_ s: String) -> [Int] {
        if s.isEmpty { return [] }
        return s.split(separator: ";", omittingEmptySubsequences: false).map { Int($0) ?? 0 }
    }

    private func flushUTF() {
        while !utf.isEmpty {
            let need: Int
            let b0 = utf[0]
            if b0 < 0x80 { need = 1 }
            else if b0 < 0xE0 { need = 2 }
            else if b0 < 0xF0 { need = 3 }
            else { need = 4 }
            if utf.count < need { return }
            var trans = UTF8()
            var gen = utf.prefix(need).makeIterator()
            switch trans.decode(&gen) {
            case .scalarValue(let s):
                onPrint?(s)
                utf.removeFirst(need)
            case .emptyInput, .error:
                onPrint?(UnicodeScalar(0xFFFD)!)
                utf.removeFirst()
            }
        }
    }
}
