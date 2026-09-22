import Foundation

enum PuTTYSessionFile {
    static func encodeName(_ name: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: ".-_")
        return name.addingPercentEncoding(withAllowedCharacters: allowed) ?? name
    }

    static func decodeName(_ file: String) -> String {
        file.removingPercentEncoding ?? file
    }

    static func serialize(_ c: SessionConfig) -> String {
        var lines: [String] = []
        func put(_ k: String, _ v: String) { lines.append("\(k)=\(v)") }
        func putI(_ k: String, _ v: Int) { put(k, String(v)) }
        func putB(_ k: String, _ v: Bool) { putI(k, v ? 1 : 0) }

        put("HostName", c.host)
        putI("PortNumber", c.port)
        put("Protocol", c.protocolType.puttyName)
        putI("AddressFamily", c.addressFamily)
        putI("CloseOnExit", c.closeOnExit.rawValue)
        putI("LogType", c.logType.rawValue)
        put("LogFileName", c.logFileName)
        putI("LogFileClash", c.logOverlap)
        putB("LogFlush", c.logFlush)
        putB("LogHeader", c.logHeader)
        putB("LogOmitPasswords", c.logOmitPass)
        putB("LogOmitData", c.logOmitData)
        putB("AutoWrapMode", c.wrapMode)
        putB("DECOriginMode", c.decOrigin)
        putB("LFImpliesCR", c.lfHasCR)
        putB("CRImpliesLF", c.crHasLF)
        putB("BCE", c.bce)
        putB("BlinkText", c.blinkText)
        put("Answerback", c.answerback)
        putI("LocalEcho", c.localEcho.rawValue)
        putI("LocalEdit", c.localEdit.rawValue)
        put("Printer", c.printer)
        putB("BackspaceIsDelete", c.bkspIsDelete)
        putB("RXVTHomeEnd", c.rxvtHomeEnd)
        putI("LinuxFunctionKeys", c.funkyType)
        putB("NoApplicationCursors", c.noApplicC)
        putB("NoApplicationKeys", c.noApplicK)
        putB("NoMouseReporting", c.noMouse)
        putB("NoRemoteResize", c.noRemoteResize)
        putB("NoAltScreen", c.noAltScreen)
        putB("NoRemoteWinTitle", c.noRemoteWintitle)
        putB("NoRemoteCharset", c.noRemoteCharset)
        putB("NoRemoteQTitle", c.noRemoteQTitle)
        putB("NoDBackspace", c.noDBackspace)
        putB("NoArabicShaping", c.noArabicShaping)
        putB("NoBidi", c.noBidi)
        putB("AltIsNotMeta", c.altMetaBit)
        putB("ComposeKey", c.composeKey)
        putB("CtrlAltKeys", c.ctrlAltKeys)
        putI("Beep", c.beep)
        putI("BeepInd", c.beepInd)
        putB("BellOverload", c.bellOverload)
        putI("BellOverloadN", c.bellOverloadN)
        putI("BellOverloadT", c.bellOverloadT)
        putI("BellOverloadS", c.bellOverloadS)
        put("BellWaveFile", c.bellWaveFile)
        putI("TermWidth", c.width)
        putI("TermHeight", c.height)
        putI("WindowState", c.resizeAction)
        putB("ScrollBar", c.scrollbar)
        putB("ScrollBarFullScreen", c.scrollbarFull)
        putB("ScrollOnDisp", c.scrollOnDisp)
        putB("ScrollOnKey", c.scrollOnKey)
        putB("EraseToScrollback", c.eraseToScrollback)
        putI("ScrollbackLines", c.saveLines)
        put("Font", c.fontName)
        putI("FontHeight", Int(c.fontSize))
        putB("FontIsBold", c.fontIsBold)
        putI("FontQuality", c.fontQuality)
        putI("CursorType", c.cursorType)
        putB("BlinkCur", c.blinkCur)
        putI("WindowBorder", c.windowBorder)
        put("WinTitle", c.winTitle)
        putB("SeparateTitle", c.separateTitle)
        putB("WarnOnClose", c.warnOnClose)
        putB("AltF4", c.altF4)
        putB("AlwaysOnTop", c.alwaysOnTop)
        putB("FullScreenOnAltEnter", c.fullScreenOnAltEnter)
        put("LineCodePage", c.lineCodePage)
        putB("CJKAmbigWide", c.cjkAmbiguousWide)
        putB("UTF8Override", c.utf8Override)
        putI("FontVTMode", c.vtMode)
        putI("MouseIsXterm", c.mouseIsXterm)
        putB("RectSelect", c.rectSelect)
        putB("MouseOverride", c.mouseOverride)
        putB("RawCNP", c.rawCNP)
        putB("RTFPaste", c.rtfPaste)
        putB("MouseAutocopy", c.mouseAutocopy)
        putB("MousePaste", c.mousePaste)
        put("Wordness", c.wordness)
        putB("TryPalette", c.tryPalette)
        putB("ANSIColour", c.ansiColour)
        putB("Xterm256Colour", c.xterm256Colour)
        putB("TrueColour", c.trueColour)
        putB("BoldAsColour", c.boldAsColour)
        putI("BoldAsColourMode", (c.boldAsColour ? 1 : 0) | (c.boldAsFont ? 2 : 0))
        for (i, col) in c.colours.enumerated() {
            put("Colour\(i)", "\(col.r),\(col.g),\(col.b)")
        }
        putI("PingInterval", c.pingInterval)
        putB("TCPNoDelay", c.tcpNoDelay)
        putB("TCPKeepalives", c.tcpKeepalives)
        put("LogHost", c.logHost)
        put("UserName", c.username)
        putB("UserNameFromEnvironment", c.usernameFromEnv)
        put("TerminalType", c.termType)
        put("TerminalSpeed", c.termSpeed)
        put("Environment", c.environ.map { "\($0.name)\t\($0.value)" }.joined(separator: ","))
        putI("ProxyMethod", c.proxyType.rawValue)
        put("ProxyHost", c.proxyHost)
        putI("ProxyPort", c.proxyPort)
        put("ProxyUsername", c.proxyUsername)
        put("ProxyPassword", c.proxyPassword)
        put("ProxyExcludeList", c.proxyExclude)
        putI("ProxyDNS", c.proxyDNS)
        putB("ProxyLocalhost", c.evenProxyLocal)
        put("ProxyTelnetCommand", c.proxyTelnetCommand)
        putB("RFCEnviron", c.rfcEnviron)
        putB("PassiveTelnet", c.passiveTelnet)
        putB("TelnetKey", c.telnetKeyboard)
        putB("TelnetRet", c.telnetNewline)
        put("LocalUserName", c.localUsername)
        put("RemoteCommand", c.remoteCmd)
        putB("NoPTY", c.sshNoPTY)
        putB("Compression", c.compression)
        putI("SshProt", c.sshProt)
        putB("SshNoShell", c.sshNoShell)
        putB("SshSubsys", c.sshSubsys)
        put("KEX", c.sshKex.joined(separator: ","))
        putI("RekeyTime", c.sshRekeyTime)
        put("RekeyBytes", c.sshRekeyData)
        put("HostKey", c.sshHostKey.joined(separator: ","))
        put("Cipher", c.sshCipher.joined(separator: ","))
        putB("SSH2DES", c.ssh2DES)
        putB("SshNoAuth", c.sshNoUserauth)
        putB("TryAgent", c.tryAgent)
        putB("AgentFwd", c.agentFwd)
        putB("ChangeUsername", c.changeUsername)
        putB("AuthTIS", c.tryTISAuth)
        putB("AuthKI", c.tryKIAuth)
        putB("SshBanner", c.sshShowBanner)
        put("PublicKeyFile", c.keyFile)
        put("SSHCert", c.certFile)
        putB("AuthGSSAPI", c.tryGSSAPI)
        putB("GSSAPIFwd", c.gssapiFwd)
        put("TerminalModes", c.sshTTYs.map { "\($0.0)=\($0.1)" }.joined(separator: ","))
        putB("X11Forward", c.x11Forward)
        put("X11Display", c.x11Display)
        putI("X11AuthType", c.x11AuthType)
        put("PortForwardings", c.portFwds.map { fwd in
            let p: String
            switch fwd.kind {
            case .local: p = "L"
            case .remote: p = "R"
            case .dynamic: p = "D"
            }
            return "\(p)\(fwd.sourcePort)=\(fwd.destination)"
        }.joined(separator: ","))
        putB("LocalPortAcceptAll", c.lportAcceptAll)
        putB("RemotePortAcceptAll", c.rportAcceptAll)
        putI("BugIgnore1", c.sshbugIgnore1)
        putI("BugPlainPW1", c.sshbugPlainPW1)
        putI("BugRSA1", c.sshbugRSA1)
        putI("BugHMAC2", c.sshbugHMAC2)
        putI("BugDeriveKey2", c.sshbugDeriveKey2)
        putI("BugRSAPad2", c.sshbugRSAPad2)
        putI("BugPKSessID2", c.sshbugPKSessID2)
        putI("BugRekey2", c.sshbugRekey2)
        putI("BugMaxPkt2", c.sshbugMaxPkt2)
        putI("BugIgnore2", c.sshbugIgnore2)
        putI("BugOldGex2", c.sshbugOldGex2)
        putI("BugWinadj", c.sshbugWinadj)
        putI("BugChanReq", c.sshbugChanReq)
        put("SerialLine", c.serline)
        putI("SerialSpeed", c.serspeed)
        putI("SerialDataBits", c.serdatabits)
        putI("SerialStopHalfbits", c.serstopbits * 2)
        putI("SerialParity", c.serparity)
        putI("SerialFlowControl", c.serflow)
        for (k, v) in c.extra.sorted(by: { $0.key < $1.key }) {
            put(k, v)
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func parse(_ text: String, into c: SessionConfig) {
        var map: [String: String] = [:]
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = String(raw)
            if line.isEmpty || line.hasPrefix("#") { continue }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let k = String(line[..<eq])
            let v = String(line[line.index(after: eq)...])
            map[k] = v
        }
        func s(_ k: String, _ d: String = "") -> String { map[k] ?? d }
        func i(_ k: String, _ d: Int = 0) -> Int { Int(s(k)) ?? d }
        func b(_ k: String, _ d: Bool = false) -> Bool { i(k, d ? 1 : 0) != 0 }

        c.host = s("HostName")
        c.port = i("PortNumber", 22)
        c.protocolType = ProtocolType.fromPutty(s("Protocol", "ssh"))
        c.addressFamily = i("AddressFamily")
        c.closeOnExit = CloseOnExit(rawValue: i("CloseOnExit", 2)) ?? .clean
        c.logType = LogType(rawValue: i("LogType", -1)) ?? .none
        c.logFileName = s("LogFileName", "putty.log")
        c.logOverlap = i("LogFileClash")
        c.logFlush = b("LogFlush", true)
        c.logHeader = b("LogHeader", true)
        c.logOmitPass = b("LogOmitPasswords", true)
        c.logOmitData = b("LogOmitData")
        c.wrapMode = b("AutoWrapMode", true)
        c.decOrigin = b("DECOriginMode")
        c.lfHasCR = b("LFImpliesCR")
        c.crHasLF = b("CRImpliesLF")
        c.bce = b("BCE", true)
        c.blinkText = b("BlinkText")
        c.answerback = s("Answerback", "BLM-TTY")
        c.localEcho = ForceTri(rawValue: i("LocalEcho")) ?? .auto
        c.localEdit = ForceTri(rawValue: i("LocalEdit")) ?? .auto
        c.printer = s("Printer")
        c.bkspIsDelete = b("BackspaceIsDelete", true)
        c.rxvtHomeEnd = b("RXVTHomeEnd")
        c.funkyType = i("LinuxFunctionKeys")
        c.noApplicC = b("NoApplicationCursors")
        c.noApplicK = b("NoApplicationKeys")
        c.noMouse = b("NoMouseReporting")
        c.noRemoteResize = b("NoRemoteResize")
        c.noAltScreen = b("NoAltScreen")
        c.noRemoteWintitle = b("NoRemoteWinTitle")
        c.noRemoteCharset = b("NoRemoteCharset")
        c.noRemoteQTitle = b("NoRemoteQTitle", true)
        c.noArabicShaping = b("NoArabicShaping")
        c.noBidi = b("NoBidi")
        c.altMetaBit = b("AltIsNotMeta")
        c.composeKey = b("ComposeKey")
        c.ctrlAltKeys = b("CtrlAltKeys", true)
        c.beep = i("Beep", 2)
        c.beepInd = i("BeepInd")
        c.bellOverload = b("BellOverload", true)
        c.bellOverloadN = i("BellOverloadN", 5)
        c.bellOverloadT = i("BellOverloadT", 2)
        c.bellOverloadS = i("BellOverloadS", 5)
        c.bellWaveFile = s("BellWaveFile")
        c.width = i("TermWidth", 80)
        c.height = i("TermHeight", 24)
        c.resizeAction = i("WindowState")
        c.scrollbar = b("ScrollBar", true)
        c.scrollbarFull = b("ScrollBarFullScreen")
        c.scrollOnDisp = b("ScrollOnDisp", false)
        c.scrollOnKey = b("ScrollOnKey")
        c.eraseToScrollback = b("EraseToScrollback", true)
        c.saveLines = i("ScrollbackLines", 2000)
        if !s("Font").isEmpty { c.fontName = s("Font") }
        if i("FontHeight") > 0 { c.fontSize = CGFloat(i("FontHeight")) }
        c.fontIsBold = b("FontIsBold")
        c.fontQuality = i("FontQuality")
        c.cursorType = i("CursorType")
        c.blinkCur = b("BlinkCur", true)
        c.windowBorder = i("WindowBorder", 0)
        c.winTitle = s("WinTitle")
        c.warnOnClose = b("WarnOnClose", true)
        c.altF4 = b("AltF4", true)
        c.alwaysOnTop = b("AlwaysOnTop")
        c.fullScreenOnAltEnter = b("FullScreenOnAltEnter")
        if !s("LineCodePage").isEmpty { c.lineCodePage = s("LineCodePage") }
        c.cjkAmbiguousWide = b("CJKAmbigWide")
        c.utf8Override = b("UTF8Override", true)
        c.vtMode = i("FontVTMode")
        c.mouseIsXterm = i("MouseIsXterm")
        c.rectSelect = b("RectSelect")
        c.mouseOverride = b("MouseOverride", true)
        c.rawCNP = b("RawCNP")
        c.rtfPaste = b("RTFPaste")
        c.mouseAutocopy = b("MouseAutocopy", true)
        c.mousePaste = b("MousePaste", true)
        if !s("Wordness").isEmpty { c.wordness = s("Wordness") }
        c.tryPalette = b("TryPalette")
        c.ansiColour = b("ANSIColour", true)
        c.xterm256Colour = b("Xterm256Colour", true)
        c.trueColour = b("TrueColour", true)
        c.boldAsColour = b("BoldAsColour", true)
        for i in 0..<c.colours.count {
            if let raw = map["Colour\(i)"] {
                let p = raw.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                if p.count == 3 { c.colours[i] = RGB8(r: p[0], g: p[1], b: p[2]) }
            }
        }
        c.pingInterval = i("PingInterval")
        c.tcpNoDelay = b("TCPNoDelay", true)
        c.tcpKeepalives = b("TCPKeepalives")
        c.logHost = s("LogHost")
        c.username = s("UserName")
        c.usernameFromEnv = b("UserNameFromEnvironment")
        if !s("TerminalType").isEmpty { c.termType = s("TerminalType") }
        if !s("TerminalSpeed").isEmpty { c.termSpeed = s("TerminalSpeed") }
        c.environ = s("Environment").split(separator: ",").compactMap { item in
            let t = item.split(separator: "\t", maxSplits: 1).map(String.init)
            guard t.count == 2 else { return nil }
            return EnvVar(name: t[0], value: t[1])
        }
        c.proxyType = ProxyKind(rawValue: i("ProxyMethod")) ?? .none
        if !s("ProxyHost").isEmpty { c.proxyHost = s("ProxyHost") }
        c.proxyPort = i("ProxyPort", 80)
        c.proxyUsername = s("ProxyUsername")
        c.proxyPassword = s("ProxyPassword")
        if !s("ProxyExcludeList").isEmpty { c.proxyExclude = s("ProxyExcludeList") }
        c.proxyDNS = i("ProxyDNS")
        c.evenProxyLocal = b("ProxyLocalhost")
        if !s("ProxyTelnetCommand").isEmpty { c.proxyTelnetCommand = s("ProxyTelnetCommand") }
        c.rfcEnviron = b("RFCEnviron")
        c.passiveTelnet = b("PassiveTelnet")
        c.telnetKeyboard = b("TelnetKey")
        c.telnetNewline = b("TelnetRet", true)
        c.localUsername = s("LocalUserName")
        c.remoteCmd = s("RemoteCommand")
        c.sshNoPTY = b("NoPTY")
        c.compression = b("Compression")
        c.sshProt = i("SshProt", 3)
        c.sshNoShell = b("SshNoShell")
        c.sshSubsys = b("SshSubsys")
        if !s("KEX").isEmpty { c.sshKex = s("KEX").split(separator: ",").map(String.init) }
        c.sshRekeyTime = i("RekeyTime", 60)
        if !s("RekeyBytes").isEmpty { c.sshRekeyData = s("RekeyBytes") }
        if !s("HostKey").isEmpty { c.sshHostKey = s("HostKey").split(separator: ",").map(String.init) }
        if !s("Cipher").isEmpty { c.sshCipher = s("Cipher").split(separator: ",").map(String.init) }
        c.ssh2DES = b("SSH2DES")
        c.sshNoUserauth = b("SshNoAuth")
        c.tryAgent = b("TryAgent", true)
        c.agentFwd = b("AgentFwd")
        c.changeUsername = b("ChangeUsername")
        c.tryTISAuth = b("AuthTIS")
        c.tryKIAuth = b("AuthKI", true)
        c.sshShowBanner = b("SshBanner", true)
        c.keyFile = s("PublicKeyFile")
        c.certFile = s("SSHCert")
        c.tryGSSAPI = b("AuthGSSAPI")
        c.gssapiFwd = b("GSSAPIFwd")
        if !s("TerminalModes").isEmpty {
            c.sshTTYs = s("TerminalModes").split(separator: ",").compactMap { item in
                let p = item.split(separator: "=", maxSplits: 1).map(String.init)
                guard p.count == 2 else { return nil }
                return (p[0], p[1])
            }
        }
        c.x11Forward = b("X11Forward")
        c.x11Display = s("X11Display")
        c.x11AuthType = i("X11AuthType", 1)
        if !s("PortForwardings").isEmpty {
            c.portFwds = s("PortForwardings").split(separator: ",").compactMap { item in
                let str = String(item)
                guard str.count >= 2, let eq = str.firstIndex(of: "=") else { return nil }
                let kindChar = str[str.startIndex]
                let kind: PortForward.Kind
                switch kindChar {
                case "L": kind = .local
                case "R": kind = .remote
                case "D": kind = .dynamic
                default: return nil
                }
                let src = String(str[str.index(after: str.startIndex)..<eq])
                let dst = String(str[str.index(after: eq)...])
                return PortForward(kind: kind, sourcePort: src, destination: dst)
            }
        }
        c.lportAcceptAll = b("LocalPortAcceptAll")
        c.rportAcceptAll = b("RemotePortAcceptAll")
        c.sshbugIgnore1 = i("BugIgnore1")
        c.sshbugPlainPW1 = i("BugPlainPW1")
        c.sshbugRSA1 = i("BugRSA1")
        c.sshbugHMAC2 = i("BugHMAC2")
        c.sshbugDeriveKey2 = i("BugDeriveKey2")
        c.sshbugRSAPad2 = i("BugRSAPad2")
        c.sshbugPKSessID2 = i("BugPKSessID2")
        c.sshbugRekey2 = i("BugRekey2")
        c.sshbugMaxPkt2 = i("BugMaxPkt2")
        c.sshbugIgnore2 = i("BugIgnore2")
        c.sshbugOldGex2 = i("BugOldGex2")
        c.sshbugWinadj = i("BugWinadj")
        c.sshbugChanReq = i("BugChanReq")
        c.serline = s("SerialLine")
        c.serspeed = i("SerialSpeed", 9600)
        c.serdatabits = i("SerialDataBits", 8)
        let half = i("SerialStopHalfbits", 2)
        c.serstopbits = max(1, half / 2)
        c.serparity = i("SerialParity")
        c.serflow = i("SerialFlowControl", 1)

        let known = Set(map.keys)
        let consumed: Set<String> = [
            "HostName","PortNumber","Protocol","AddressFamily","CloseOnExit","LogType","LogFileName",
            "LogFileClash","LogFlush","LogHeader","LogOmitPasswords","LogOmitData","AutoWrapMode",
            "DECOriginMode","LFImpliesCR","CRImpliesLF","BCE","BlinkText","Answerback","LocalEcho",
            "LocalEdit","Printer","BackspaceIsDelete","RXVTHomeEnd","LinuxFunctionKeys",
            "NoApplicationCursors","NoApplicationKeys","NoMouseReporting","NoRemoteResize","NoAltScreen",
            "NoRemoteWinTitle","NoRemoteCharset","NoRemoteQTitle","NoDBackspace","NoArabicShaping","NoBidi",
            "AltIsNotMeta","ComposeKey","CtrlAltKeys","Beep","BeepInd","BellOverload","BellOverloadN",
            "BellOverloadT","BellOverloadS","BellWaveFile","TermWidth","TermHeight","WindowState",
            "ScrollBar","ScrollBarFullScreen","ScrollOnDisp","ScrollOnKey","EraseToScrollback",
            "ScrollbackLines","Font","FontHeight","FontIsBold","FontQuality","CursorType","BlinkCur",
            "WindowBorder","WinTitle","SeparateTitle","WarnOnClose","AltF4","AlwaysOnTop",
            "FullScreenOnAltEnter","LineCodePage","CJKAmbigWide","UTF8Override","FontVTMode",
            "MouseIsXterm","RectSelect","MouseOverride","RawCNP","RTFPaste","MouseAutocopy","Wordness",
            "TryPalette","ANSIColour","Xterm256Colour","TrueColour","BoldAsColour","BoldAsColourMode",
            "PingInterval","TCPNoDelay","TCPKeepalives","LogHost","UserName","UserNameFromEnvironment",
            "TerminalType","TerminalSpeed","Environment","ProxyMethod","ProxyHost","ProxyPort",
            "ProxyUsername","ProxyPassword","ProxyExcludeList","ProxyDNS","ProxyLocalhost",
            "ProxyTelnetCommand","RFCEnviron","PassiveTelnet","TelnetKey","TelnetRet","LocalUserName",
            "RemoteCommand","NoPTY","Compression","SshProt","SshNoShell","SshSubsys","KEX","RekeyTime",
            "RekeyBytes","HostKey","Cipher","SSH2DES","SshNoAuth","TryAgent","AgentFwd","ChangeUsername",
            "AuthTIS","AuthKI","SshBanner","PublicKeyFile","SSHCert","AuthGSSAPI","GSSAPIFwd",
            "TerminalModes","X11Forward","X11Display","X11AuthType","PortForwardings",
            "LocalPortAcceptAll","RemotePortAcceptAll","BugIgnore1","BugPlainPW1","BugRSA1","BugHMAC2",
            "BugDeriveKey2","BugRSAPad2","BugPKSessID2","BugRekey2","BugMaxPkt2","BugIgnore2",
            "BugOldGex2","BugWinadj","BugChanReq","SerialLine","SerialSpeed","SerialDataBits",
            "SerialStopHalfbits","SerialParity","SerialFlowControl"
        ]
        for k in known where !consumed.contains(k) && !k.hasPrefix("Colour") {
            c.extra[k] = map[k] ?? ""
        }
    }

    static func parseReg(_ text: String) -> [(String, SessionConfig)] {
        var results: [(String, SessionConfig)] = []
        var currentName: String?
        var currentLines: [String] = []
        func flush() {
            guard let name = currentName else { return }
            let cfg = SessionConfig()
            parse(currentLines.joined(separator: "\n"), into: cfg)
            results.append((name, cfg))
        }
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = String(raw).trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") && line.contains("Sessions\\") {
                flush()
                currentLines = []
                if let r = line.range(of: "Sessions\\") {
                    var n = String(line[r.upperBound...])
                    if n.hasSuffix("]") { n.removeLast() }
                    currentName = n.replacingOccurrences(of: "%20", with: " ")
                }
            } else if line.hasPrefix("\"") {
                var s = line
                s = s.replacingOccurrences(of: "\"", with: "")
                if s.contains("=dword:") {
                    let p = s.split(separator: "=", maxSplits: 1)
                    if p.count == 2 {
                        let hex = p[1].replacingOccurrences(of: "dword:", with: "")
                        let val = Int(hex, radix: 16) ?? 0
                        currentLines.append("\(p[0])=\(val)")
                    }
                } else if let eq = s.firstIndex(of: "=") {
                    var v = String(s[s.index(after: eq)...])
                    if v.hasPrefix("\"") { v.removeFirst() }
                    if v.hasSuffix("\"") { v.removeLast() }
                    currentLines.append("\(s[..<eq])=\(v)")
                }
            }
        }
        flush()
        return results
    }
}
