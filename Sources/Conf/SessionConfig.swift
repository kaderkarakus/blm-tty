import Foundation
import AppKit

enum ProtocolType: Int, CaseIterable, Codable {
    case raw = 0
    case telnet = 1
    case rlogin = 2
    case ssh = 3
    case serial = 4

    var defaultPort: Int {
        switch self {
        case .raw: return 0
        case .telnet: return 23
        case .rlogin: return 513
        case .ssh: return 22
        case .serial: return 0
        }
    }

    var puttyName: String {
        switch self {
        case .raw: return "raw"
        case .telnet: return "telnet"
        case .rlogin: return "rlogin"
        case .ssh: return "ssh"
        case .serial: return "serial"
        }
    }

    static func fromPutty(_ s: String) -> ProtocolType {
        switch s.lowercased() {
        case "raw": return .raw
        case "telnet": return .telnet
        case "rlogin": return .rlogin
        case "serial": return .serial
        default: return .ssh
        }
    }
}

enum CloseOnExit: Int, Codable {
    case always = 0
    case never = 1
    case clean = 2
}

enum ForceTri: Int, Codable {
    case auto = 0
    case forceOn = 1
    case forceOff = 2
}

enum ProxyKind: Int, Codable {
    case none = 0, socks4 = 1, socks5 = 2, http = 3, telnet = 4, local = 5
}

enum LogType: Int, Codable {
    case none = -1
    case printable = 0
    case all = 1
    case sshPackets = 2
    case sshRaw = 3
}

struct RGB8: Codable, Equatable {
    var r: Int
    var g: Int
    var b: Int
    var nsColor: NSColor { NSColor(srgbRed: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: 1) }
}

struct EnvVar: Codable, Equatable {
    var name: String
    var value: String
}

struct PortForward: Codable, Equatable {
    enum Kind: String, Codable { case local, remote, dynamic }
    var kind: Kind
    var sourcePort: String
    var destination: String
}

final class SessionConfig: NSObject, NSCopying {
    var host = ""
    var port = 22
    var protocolType: ProtocolType = .ssh
    var addressFamily = 0
    var closeOnExit: CloseOnExit = .clean
    var sessionName = ""

    var logType: LogType = .none
    var logFileName = "putty.log"
    var logOverlap = 0
    var logFlush = true
    var logHeader = true
    var logOmitPass = true
    var logOmitData = false

    var wrapMode = true
    var decOrigin = false
    var lfHasCR = false
    var crHasLF = false
    var bce = true
    var blinkText = false
    var answerback = "BLM-TTY"
    var localEcho: ForceTri = .auto
    var localEdit: ForceTri = .auto
    var printer = ""

    var bkspIsDelete = true
    var rxvtHomeEnd = false
    var funkyType = 0
    var noApplicC = false
    var noApplicK = false
    var noMouse = false
    var noRemoteResize = false
    var noRemoteWintitle = false
    var noAltScreen = false
    var noRemoteCharset = false
    var noRemoteQTitle = true
    var noDBackspace = false
    var noArabicShaping = false
    var noBidi = false
    var altMetaBit = false
    var composeKey = false
    var ctrlAltKeys = true

    var beep = 2
    var beepInd = 0
    var bellOverload = true
    var bellOverloadN = 5
    var bellOverloadT = 2
    var bellOverloadS = 5
    var bellWaveFile = ""

    var width = 80
    var height = 24
    var resizeAction = 0
    var scrollbar = true
    var scrollbarFull = false
    var scrollOnDisp = false
    var scrollOnKey = false
    var eraseToScrollback = true
    var saveLines = 2000

    var fontName = "Menlo"
    var fontSize: CGFloat = 10
    var fontIsBold = false
    var fontQuality = 0
    var cursorType = 0
    var blinkCur = true
    var windowBorder = 0
    var winTitle = ""
    var separateTitle = false

    var warnOnClose = true
    var altF4 = true
    var alwaysOnTop = false
    var fullScreenOnAltEnter = false

    var lineCodePage = "UTF-8"
    var cjkAmbiguousWide = false
    var utf8Override = true
    var vtMode = 0

    var mouseIsXterm = 0
    var rectSelect = false
    var mouseOverride = true
    var rawCNP = false
    var rtfPaste = false
    var mouseAutocopy = true
    var mousePaste = true
    var wordness = "47,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,48,0,1,2,1,1,1,1,1,1,1,1,1,1,2,2,2,2,2,2,2,2,2,2,2,1,1,1,1,1,1,1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,1,1,1,1,1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,1,1,1,1,1,1"

    var tryPalette = false
    var systemColour = false
    var ansiColour = true
    var xterm256Colour = true
    var trueColour = true
    var boldAsColour = true
    var boldAsFont = false
    var colours: [RGB8] = SessionConfig.defaultPalette

    var pingInterval = 0
    var tcpNoDelay = true
    var tcpKeepalives = false
    var logHost = ""

    var username = ""
    var usernameFromEnv = false
    var termType = "xterm"
    var termSpeed = "38400,38400"
    var environ: [EnvVar] = []

    var proxyType: ProxyKind = .none
    var proxyHost = "proxy"
    var proxyPort = 80
    var proxyUsername = ""
    var proxyPassword = ""
    var proxyExclude = "local, 127.0.0.1, ::1"
    var proxyDNS = 0
    var evenProxyLocal = false
    var proxyTelnetCommand = "connect %host %port\\n"

    var rfcEnviron = false
    var passiveTelnet = false
    var telnetKeyboard = false
    var telnetNewline = true
    var telnetOld = false

    var localUsername = ""

    var remoteCmd = ""
    var sshNoPTY = false
    var compression = false
    var sshProt = 3
    var sshNoShell = false
    var sshSubsys = false
    var sshConnectionSharing = false

    var sshKex = ["curve25519-sha256", "ecdh-sha2-nistp256", "ecdh-sha2-nistp384", "diffie-hellman-group-exchange-sha256", "diffie-hellman-group14-sha256", "diffie-hellman-group14-sha1"]
    var sshRekeyTime = 60
    var sshRekeyData = "1G"

    var sshHostKey = ["ssh-ed25519", "ecdsa-sha2-nistp256", "rsa-sha2-512", "rsa-sha2-256", "ssh-rsa"]

    var sshCipher = ["aes256-gcm@openssh.com", "aes128-gcm@openssh.com", "chacha20-poly1305@openssh.com", "aes256-ctr", "aes192-ctr", "aes128-ctr", "3des-cbc"]
    var ssh2DES = false

    var sshNoUserauth = false
    var tryAgent = true
    var agentFwd = false
    var changeUsername = false
    var tryTISAuth = false
    var tryKIAuth = true
    var sshShowBanner = true
    var keyFile = ""
    var certFile = ""
    var password = ""

    var tryGSSAPI = false
    var gssapiFwd = false

    var sshTTYs: [(String, String)] = [
        ("INTR", "A"), ("QUIT", "A"), ("ERASE", "A"), ("KILL", "A"),
        ("EOF", "A"), ("EOL", "A"), ("EOL2", "A"), ("START", "A"),
        ("STOP", "A"), ("SUSP", "A"), ("DSUSP", "A"), ("REPRINT", "A"),
        ("WERASE", "A"), ("LNEXT", "A"), ("FLUSH", "A"), ("SWTCH", "A"),
        ("STATUS", "A"), ("DISCARD", "A"), ("IGNPAR", "A"), ("PARMRK", "A"),
        ("INPCK", "A"), ("ISTRIP", "A"), ("INLCR", "A"), ("IGNCR", "A"),
        ("ICRNL", "A"), ("IUCLC", "A"), ("IXON", "A"), ("IXANY", "A"),
        ("IXOFF", "A"), ("IMAXBEL", "A"), ("IUTF8", "A"), ("ISIG", "A"),
        ("ICANON", "A"), ("XCASE", "A"), ("ECHO", "A"), ("ECHOE", "A"),
        ("ECHOK", "A"), ("ECHONL", "A"), ("NOFLSH", "A"), ("TOSTOP", "A"),
        ("IEXTEN", "A"), ("ECHOCTL", "A"), ("ECHOKE", "A"), ("PENDIN", "A"),
        ("OPOST", "A"), ("OLCUC", "A"), ("ONLCR", "A"), ("OCRNL", "A"),
        ("ONOCR", "A"), ("ONLRET", "A"), ("CS7", "A"), ("CS8", "A"),
        ("PARENB", "A"), ("PARODD", "A")
    ]

    var x11Forward = false
    var x11Display = ""
    var x11AuthType = 1

    var portFwds: [PortForward] = []
    var lportAcceptAll = false
    var rportAcceptAll = false

    var sshbugIgnore1 = 0
    var sshbugPlainPW1 = 0
    var sshbugRSA1 = 0
    var sshbugHMAC2 = 0
    var sshbugDeriveKey2 = 0
    var sshbugRSAPad2 = 0
    var sshbugPKSessID2 = 0
    var sshbugRekey2 = 0
    var sshbugMaxPkt2 = 0
    var sshbugIgnore2 = 0
    var sshbugOldGex2 = 0
    var sshbugWinadj = 0
    var sshbugChanReq = 0
    var sshbugDropStart = 0
    var sshbugFilterKex = 0
    var sshbugRSASha2 = 0

    var serline = ""
    var serspeed = 9600
    var serdatabits = 8
    var serstopbits = 1
    var serparity = 0
    var serflow = 1

    var extra: [String: String] = [:]

    static let defaultPalette: [RGB8] = [
        RGB8(r: 187, g: 187, b: 187),
        RGB8(r: 255, g: 255, b: 255),
        RGB8(r: 0, g: 0, b: 0),
        RGB8(r: 85, g: 85, b: 85),
        RGB8(r: 0, g: 0, b: 0),
        RGB8(r: 0, g: 255, b: 0),
        RGB8(r: 0, g: 0, b: 0),
        RGB8(r: 85, g: 85, b: 85),
        RGB8(r: 187, g: 0, b: 0),
        RGB8(r: 255, g: 85, b: 85),
        RGB8(r: 0, g: 187, b: 0),
        RGB8(r: 85, g: 255, b: 85),
        RGB8(r: 187, g: 187, b: 0),
        RGB8(r: 255, g: 255, b: 85),
        RGB8(r: 0, g: 0, b: 187),
        RGB8(r: 85, g: 85, b: 255),
        RGB8(r: 187, g: 0, b: 187),
        RGB8(r: 255, g: 85, b: 255),
        RGB8(r: 0, g: 187, b: 187),
        RGB8(r: 85, g: 255, b: 255),
        RGB8(r: 187, g: 187, b: 187),
        RGB8(r: 255, g: 255, b: 255),
    ]

    func copy(with zone: NSZone? = nil) -> Any {
        let c = SessionConfig()
        c.apply(from: self)
        return c
    }

    func clone() -> SessionConfig { copy() as! SessionConfig }

    func apply(from o: SessionConfig) {
        host = o.host; port = o.port; protocolType = o.protocolType
        addressFamily = o.addressFamily; closeOnExit = o.closeOnExit; sessionName = o.sessionName
        logType = o.logType; logFileName = o.logFileName; logOverlap = o.logOverlap
        logFlush = o.logFlush; logHeader = o.logHeader; logOmitPass = o.logOmitPass; logOmitData = o.logOmitData
        wrapMode = o.wrapMode; decOrigin = o.decOrigin; lfHasCR = o.lfHasCR; crHasLF = o.crHasLF
        bce = o.bce; blinkText = o.blinkText; answerback = o.answerback
        localEcho = o.localEcho; localEdit = o.localEdit; printer = o.printer
        bkspIsDelete = o.bkspIsDelete; rxvtHomeEnd = o.rxvtHomeEnd; funkyType = o.funkyType
        noApplicC = o.noApplicC; noApplicK = o.noApplicK; noMouse = o.noMouse
        noRemoteResize = o.noRemoteResize; noRemoteWintitle = o.noRemoteWintitle
        noAltScreen = o.noAltScreen; noRemoteCharset = o.noRemoteCharset; noRemoteQTitle = o.noRemoteQTitle
        noDBackspace = o.noDBackspace; noArabicShaping = o.noArabicShaping; noBidi = o.noBidi
        altMetaBit = o.altMetaBit; composeKey = o.composeKey; ctrlAltKeys = o.ctrlAltKeys
        beep = o.beep; beepInd = o.beepInd; bellOverload = o.bellOverload
        bellOverloadN = o.bellOverloadN; bellOverloadT = o.bellOverloadT; bellOverloadS = o.bellOverloadS
        bellWaveFile = o.bellWaveFile
        width = o.width; height = o.height; resizeAction = o.resizeAction
        scrollbar = o.scrollbar; scrollbarFull = o.scrollbarFull
        scrollOnDisp = o.scrollOnDisp; scrollOnKey = o.scrollOnKey
        eraseToScrollback = o.eraseToScrollback; saveLines = o.saveLines
        fontName = o.fontName; fontSize = o.fontSize; fontIsBold = o.fontIsBold
        fontQuality = o.fontQuality; cursorType = o.cursorType; blinkCur = o.blinkCur
        windowBorder = o.windowBorder; winTitle = o.winTitle; separateTitle = o.separateTitle
        warnOnClose = o.warnOnClose; altF4 = o.altF4; alwaysOnTop = o.alwaysOnTop
        fullScreenOnAltEnter = o.fullScreenOnAltEnter
        lineCodePage = o.lineCodePage; cjkAmbiguousWide = o.cjkAmbiguousWide
        utf8Override = o.utf8Override; vtMode = o.vtMode
        mouseIsXterm = o.mouseIsXterm; rectSelect = o.rectSelect; mouseOverride = o.mouseOverride
        rawCNP = o.rawCNP; rtfPaste = o.rtfPaste; mouseAutocopy = o.mouseAutocopy
        mousePaste = o.mousePaste; wordness = o.wordness
        tryPalette = o.tryPalette; systemColour = o.systemColour; ansiColour = o.ansiColour
        xterm256Colour = o.xterm256Colour; trueColour = o.trueColour
        boldAsColour = o.boldAsColour; boldAsFont = o.boldAsFont; colours = o.colours
        pingInterval = o.pingInterval; tcpNoDelay = o.tcpNoDelay; tcpKeepalives = o.tcpKeepalives
        logHost = o.logHost
        username = o.username; usernameFromEnv = o.usernameFromEnv
        termType = o.termType; termSpeed = o.termSpeed; environ = o.environ
        proxyType = o.proxyType; proxyHost = o.proxyHost; proxyPort = o.proxyPort
        proxyUsername = o.proxyUsername; proxyPassword = o.proxyPassword
        proxyExclude = o.proxyExclude; proxyDNS = o.proxyDNS; evenProxyLocal = o.evenProxyLocal
        proxyTelnetCommand = o.proxyTelnetCommand
        rfcEnviron = o.rfcEnviron; passiveTelnet = o.passiveTelnet
        telnetKeyboard = o.telnetKeyboard; telnetNewline = o.telnetNewline; telnetOld = o.telnetOld
        localUsername = o.localUsername
        remoteCmd = o.remoteCmd; sshNoPTY = o.sshNoPTY; compression = o.compression
        sshProt = o.sshProt; sshNoShell = o.sshNoShell; sshSubsys = o.sshSubsys
        sshConnectionSharing = o.sshConnectionSharing
        sshKex = o.sshKex; sshRekeyTime = o.sshRekeyTime; sshRekeyData = o.sshRekeyData
        sshHostKey = o.sshHostKey; sshCipher = o.sshCipher; ssh2DES = o.ssh2DES
        sshNoUserauth = o.sshNoUserauth; tryAgent = o.tryAgent; agentFwd = o.agentFwd
        changeUsername = o.changeUsername; tryTISAuth = o.tryTISAuth; tryKIAuth = o.tryKIAuth
        sshShowBanner = o.sshShowBanner; keyFile = o.keyFile; certFile = o.certFile
        password = o.password
        tryGSSAPI = o.tryGSSAPI; gssapiFwd = o.gssapiFwd
        sshTTYs = o.sshTTYs
        x11Forward = o.x11Forward; x11Display = o.x11Display; x11AuthType = o.x11AuthType
        portFwds = o.portFwds; lportAcceptAll = o.lportAcceptAll; rportAcceptAll = o.rportAcceptAll
        sshbugIgnore1 = o.sshbugIgnore1; sshbugPlainPW1 = o.sshbugPlainPW1; sshbugRSA1 = o.sshbugRSA1
        sshbugHMAC2 = o.sshbugHMAC2; sshbugDeriveKey2 = o.sshbugDeriveKey2; sshbugRSAPad2 = o.sshbugRSAPad2
        sshbugPKSessID2 = o.sshbugPKSessID2; sshbugRekey2 = o.sshbugRekey2; sshbugMaxPkt2 = o.sshbugMaxPkt2
        sshbugIgnore2 = o.sshbugIgnore2; sshbugOldGex2 = o.sshbugOldGex2; sshbugWinadj = o.sshbugWinadj
        sshbugChanReq = o.sshbugChanReq; sshbugDropStart = o.sshbugDropStart
        sshbugFilterKex = o.sshbugFilterKex; sshbugRSASha2 = o.sshbugRSASha2
        serline = o.serline; serspeed = o.serspeed; serdatabits = o.serdatabits
        serstopbits = o.serstopbits; serparity = o.serparity; serflow = o.serflow
        extra = o.extra
    }

    func displayTitle() -> String {
        if !winTitle.isEmpty { return winTitle }
        if protocolType == .serial { return serline.isEmpty ? "serial" : serline }
        if host.isEmpty { return "BLM-TTY" }
        if !username.isEmpty { return "\(username)@\(host)" }
        return host
    }
}
