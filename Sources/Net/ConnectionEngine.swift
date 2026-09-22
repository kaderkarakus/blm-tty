import Foundation
import Network
import Darwin

final class ConnectionEngine {
    let config: SessionConfig
    var onData: ((Data) -> Void)?
    var onLog: ((String) -> Void)?
    var onClose: ((Bool, String?) -> Void)?
    private(set) var isConnected = false
    private var impl: BytePump?
    private var closed = false

    init(config: SessionConfig) {
        self.config = config
    }

    func connect() {
        switch config.protocolType {
        case .raw:
            impl = TCPPump(host: config.host, port: config.port, config: config, telnet: false, rlogin: false)
        case .telnet:
            impl = TCPPump(host: config.host, port: config.port == 0 ? 23 : config.port, config: config, telnet: true, rlogin: false)
        case .rlogin:
            impl = TCPPump(host: config.host, port: config.port == 0 ? 513 : config.port, config: config, telnet: false, rlogin: true)
        case .serial:
            impl = SerialPump(config: config)
        case .ssh:
            impl = SSHPump(config: config)
        }
        impl?.onData = { [weak self] d in self?.onData?(d) }
        impl?.onLog = { [weak self] s in self?.onLog?(s) }
        impl?.onClose = { [weak self] clean, err in
            self?.isConnected = false
            self?.onClose?(clean, err)
        }
        onLog?("Starting \(config.protocolType.puttyName) connection")
        impl?.start()
        isConnected = true
    }

    func send(_ data: Data) { impl?.send(data) }
    func resize(cols: Int, rows: Int) { impl?.resize(cols: cols, rows: rows) }
    func close() {
        guard !closed else { return }
        closed = true
        impl?.stop()
        isConnected = false
    }
}

protocol BytePump: AnyObject {
    var onData: ((Data) -> Void)? { get set }
    var onLog: ((String) -> Void)? { get set }
    var onClose: ((Bool, String?) -> Void)? { get set }
    func start()
    func send(_ data: Data)
    func resize(cols: Int, rows: Int)
    func stop()
}

final class TCPPump: BytePump {
    var onData: ((Data) -> Void)?
    var onLog: ((String) -> Void)?
    var onClose: ((Bool, String?) -> Void)?
    private let host: String
    private let port: Int
    private let config: SessionConfig
    private let telnet: Bool
    private let rlogin: Bool
    private var conn: NWConnection?
    private var telnetState = TelnetState()
    private var queue = DispatchQueue(label: "blm.tcp")

    init(host: String, port: Int, config: SessionConfig, telnet: Bool, rlogin: Bool) {
        self.host = host; self.port = port; self.config = config
        self.telnet = telnet; self.rlogin = rlogin
    }

    func start() {
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = config.tcpNoDelay
        tcp.enableKeepalive = config.tcpKeepalives
        let params = NWParameters(tls: nil, tcp: tcp)
        if config.proxyType != .none {
            onLog?("Proxy \(config.proxyType) \(config.proxyHost):\(config.proxyPort)")
        }
        let (dstHost, dstPort) = proxyTarget()
        let c = NWConnection(host: NWEndpoint.Host(dstHost), port: NWEndpoint.Port(rawValue: UInt16(dstPort))!, using: params)
        conn = c
        c.stateUpdateHandler = { [weak self] st in
            guard let self else { return }
            switch st {
            case .ready:
                self.onLog?("Connected to \(dstHost) port \(dstPort)")
                if self.config.proxyType != .none {
                    ProxyNegotiator.run(connection: c, config: self.config, targetHost: self.host, targetPort: self.port, queue: self.queue) { err in
                        if let err {
                            self.onClose?(false, err)
                        } else {
                            self.afterConnected()
                            self.readLoop()
                        }
                    }
                } else {
                    self.afterConnected()
                    self.readLoop()
                }
            case .failed(let e):
                self.onClose?(false, e.localizedDescription)
            case .cancelled:
                self.onClose?(true, nil)
            default: break
            }
        }
        c.start(queue: queue)
    }

    private func proxyTarget() -> (String, Int) {
        if config.proxyType == .none { return (host, port) }
        return (config.proxyHost, config.proxyPort)
    }

    private func afterConnected() {
        if rlogin {
            let local = config.localUsername.isEmpty ? NSUserName() : config.localUsername
            let remote = config.username.isEmpty ? NSUserName() : config.username
            let term = "\(config.termType)/\(config.termSpeed)"
            var d = Data([0])
            d.append(contentsOf: local.utf8); d.append(0)
            d.append(contentsOf: remote.utf8); d.append(0)
            d.append(contentsOf: term.utf8); d.append(0)
            conn?.send(content: d, completion: .contentProcessed { _ in })
        }
        if telnet && !config.telnetOld {
            telnetState.sendInitial(conn: conn, config: config)
        }
    }

    func send(_ data: Data) {
        var out = data
        if telnet {
            out = TelnetState.escape(data)
            if config.telnetKeyboard, data == Data([0x0D]) {
                out = Data([0x0D, 0x00])
            }
        }
        conn?.send(content: out, completion: .contentProcessed { _ in })
    }

    func resize(cols: Int, rows: Int) {
        if telnet { telnetState.sendNAWS(conn: conn, cols: cols, rows: rows) }
    }

    func stop() {
        conn?.cancel()
    }

    private func readLoop() {
        conn?.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isDone, err in
            guard let self else { return }
            if let data, !data.isEmpty {
                if self.telnet {
                    let (clean, replies) = self.telnetState.feed(data, config: self.config)
                    if !replies.isEmpty {
                        self.conn?.send(content: replies, completion: .contentProcessed { _ in })
                    }
                    if !clean.isEmpty { self.onData?(clean) }
                } else {
                    self.onData?(data)
                }
            }
            if let err {
                self.onClose?(false, err.localizedDescription)
                return
            }
            if isDone {
                self.onClose?(true, nil)
                return
            }
            self.readLoop()
        }
    }
}

struct TelnetState {
    private var iac = false
    private var cmd: UInt8 = 0
    private var sub: [UInt8] = []
    private var inSub = false
    private let IAC: UInt8 = 255
    private let DONT: UInt8 = 254
    private let DO: UInt8 = 253
    private let WONT: UInt8 = 252
    private let WILL: UInt8 = 251
    private let SB: UInt8 = 250
    private let SE: UInt8 = 240
    private let ECHO: UInt8 = 1
    private let SGA: UInt8 = 3
    private let TTYPE: UInt8 = 24
    private let NAWS: UInt8 = 31
    private let NEWENV: UInt8 = 39

    mutating func feed(_ data: Data, config: SessionConfig) -> (Data, Data) {
        var out = Data()
        var reply = Data()
        for b in data {
            if inSub {
                if iac {
                    iac = false
                    if b == SE {
                        inSub = false
                        handleSub(&reply, config: config)
                        sub.removeAll()
                    } else {
                        sub.append(IAC); sub.append(b)
                    }
                } else if b == IAC {
                    iac = true
                } else {
                    sub.append(b)
                }
                continue
            }
            if !iac {
                if b == IAC { iac = true } else { out.append(b) }
                continue
            }
            iac = false
            if b == IAC { out.append(IAC); continue }
            if b == SB { inSub = true; sub.removeAll(); continue }
            if b == WILL || b == WONT || b == DO || b == DONT {
                cmd = b
                iac = true
                continue
            }
            if cmd != 0 {
                negotiate(cmd, opt: b, reply: &reply)
                cmd = 0
                continue
            }
        }
        return (out, reply)
    }

    private func negotiate(_ cmd: UInt8, opt: UInt8, reply: inout Data) {
        switch cmd {
        case 251: // WILL
            if opt == ECHO || opt == SGA || opt == TTYPE || opt == NAWS {
                reply.append(contentsOf: [255, 253, opt])
            } else {
                reply.append(contentsOf: [255, 254, opt])
            }
        case 252: // WONT
            reply.append(contentsOf: [255, 254, opt])
        case 253: // DO
            if opt == TTYPE || opt == NAWS || opt == SGA {
                reply.append(contentsOf: [255, 251, opt])
            } else {
                reply.append(contentsOf: [255, 252, opt])
            }
        case 254:
            reply.append(contentsOf: [255, 252, opt])
        default: break
        }
    }

    private mutating func handleSub(_ reply: inout Data, config: SessionConfig) {
        guard let opt = sub.first else { return }
        if opt == TTYPE && sub.count >= 2 && sub[1] == 1 {
            var r: [UInt8] = [255, 250, TTYPE, 0]
            r.append(contentsOf: Array(config.termType.utf8))
            r.append(contentsOf: [255, 240])
            reply.append(contentsOf: r)
        }
    }

    func sendInitial(conn: NWConnection?, config: SessionConfig) {
        var d = Data([255, 251, 3, 255, 251, 24, 255, 251, 31])
        d.append(naws(cols: config.width, rows: config.height))
        conn?.send(content: d, completion: .contentProcessed { _ in })
    }

    func sendNAWS(conn: NWConnection?, cols: Int, rows: Int) {
        conn?.send(content: naws(cols: cols, rows: rows), completion: .contentProcessed { _ in })
    }

    private func naws(cols: Int, rows: Int) -> Data {
        let c = UInt16(clamping: cols).bigEndian
        let r = UInt16(clamping: rows).bigEndian
        var d = Data([255, 250, 31])
        Swift.withUnsafeBytes(of: c) { d.append(contentsOf: $0) }
        Swift.withUnsafeBytes(of: r) { d.append(contentsOf: $0) }
        d.append(contentsOf: [255, 240])
        return d
    }

    static func escape(_ data: Data) -> Data {
        var o = Data()
        for b in data {
            o.append(b)
            if b == 255 { o.append(255) }
        }
        return o
    }
}

enum ProxyNegotiator {
    static func run(connection: NWConnection, config: SessionConfig, targetHost: String, targetPort: Int, queue: DispatchQueue, done: @escaping (String?) -> Void) {
        switch config.proxyType {
        case .none: done(nil)
        case .http:
            let auth: String
            if !config.proxyUsername.isEmpty {
                let raw = "\(config.proxyUsername):\(config.proxyPassword)"
                auth = "Proxy-Authorization: Basic \(Data(raw.utf8).base64EncodedString())\r\n"
            } else { auth = "" }
            let req = "CONNECT \(targetHost):\(targetPort) HTTP/1.1\r\nHost: \(targetHost):\(targetPort)\r\n\(auth)\r\n"
            connection.send(content: Data(req.utf8), completion: .contentProcessed { err in
                if let err { done(err.localizedDescription); return }
                connection.receive(minimumIncompleteLength: 12, maximumLength: 4096) { data, _, _, err in
                    if let err { done(err.localizedDescription); return }
                    let s = String(data: data ?? Data(), encoding: .utf8) ?? ""
                    if s.contains(" 200 ") { done(nil) } else { done("HTTP proxy: \(s.prefix(80))") }
                }
            })
        case .socks5:
            var hello = Data([0x05, 0x01, config.proxyUsername.isEmpty ? 0x00 : 0x02])
            if !config.proxyUsername.isEmpty { hello = Data([0x05, 0x02, 0x00, 0x02]) }
            connection.send(content: hello, completion: .contentProcessed { _ in
                connection.receive(minimumIncompleteLength: 2, maximumLength: 2) { data, _, _, err in
                    if let err { done(err.localizedDescription); return }
                    guard let data, data.count >= 2 else { done("SOCKS5 hello"); return }
                    func sendConnect() {
                        var req = Data([0x05, 0x01, 0x00, 0x03, UInt8(targetHost.utf8.count)])
                        req.append(contentsOf: targetHost.utf8)
                        var p = UInt16(targetPort).bigEndian
                        Swift.withUnsafeBytes(of: &p) { req.append(contentsOf: $0) }
                        connection.send(content: req, completion: .contentProcessed { _ in
                            connection.receive(minimumIncompleteLength: 10, maximumLength: 256) { data, _, _, err in
                                if let err { done(err.localizedDescription); return }
                                if let data, data.count >= 2, data[1] == 0 { done(nil) }
                                else { done("SOCKS5 connect failed") }
                            }
                        })
                    }
                    if data[1] == 0x02 {
                        var u = Data([0x01, UInt8(config.proxyUsername.utf8.count)])
                        u.append(contentsOf: config.proxyUsername.utf8)
                        u.append(UInt8(config.proxyPassword.utf8.count))
                        u.append(contentsOf: config.proxyPassword.utf8)
                        connection.send(content: u, completion: .contentProcessed { _ in
                            connection.receive(minimumIncompleteLength: 2, maximumLength: 2) { _, _, _, _ in sendConnect() }
                        })
                    } else {
                        sendConnect()
                    }
                }
            })
        case .socks4:
            var req = Data([0x04, 0x01])
            var p = UInt16(targetPort).bigEndian
            Swift.withUnsafeBytes(of: &p) { req.append(contentsOf: $0) }
            req.append(contentsOf: [0, 0, 0, 1])
            req.append(contentsOf: config.proxyUsername.utf8)
            req.append(0)
            req.append(contentsOf: targetHost.utf8)
            req.append(0)
            connection.send(content: req, completion: .contentProcessed { _ in
                connection.receive(minimumIncompleteLength: 8, maximumLength: 8) { data, _, _, err in
                    if let err { done(err.localizedDescription); return }
                    if let data, data.count >= 2, data[1] == 0x5A { done(nil) } else { done("SOCKS4 failed") }
                }
            })
        case .telnet, .local:
            var cmd = config.proxyTelnetCommand
            cmd = cmd.replacingOccurrences(of: "%host", with: targetHost)
            cmd = cmd.replacingOccurrences(of: "%port", with: String(targetPort))
            cmd = cmd.replacingOccurrences(of: "\\n", with: "\n")
            connection.send(content: Data(cmd.utf8), completion: .contentProcessed { err in
                done(err?.localizedDescription)
            })
        }
    }
}

final class SerialPump: BytePump {
    var onData: ((Data) -> Void)?
    var onLog: ((String) -> Void)?
    var onClose: ((Bool, String?) -> Void)?
    private let config: SessionConfig
    private var fd: Int32 = -1
    private var source: DispatchSourceRead?

    init(config: SessionConfig) { self.config = config }

    func start() {
        let path = config.serline
        fd = open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
        if fd < 0 {
            onClose?(false, String(cString: strerror(errno)))
            return
        }
        var t = termios()
        if tcgetattr(fd, &t) == 0 {
            cfmakeraw(&t)
            cfsetspeed(&t, baudToConst(config.serspeed))
            t.c_cflag &= ~tcflag_t(CSIZE)
            switch config.serdatabits {
            case 5: t.c_cflag |= tcflag_t(CS5)
            case 6: t.c_cflag |= tcflag_t(CS6)
            case 7: t.c_cflag |= tcflag_t(CS7)
            default: t.c_cflag |= tcflag_t(CS8)
            }
            if config.serstopbits == 2 { t.c_cflag |= tcflag_t(CSTOPB) } else { t.c_cflag &= ~tcflag_t(CSTOPB) }
            t.c_cflag &= ~tcflag_t(PARENB | PARODD)
            switch config.serparity {
            case 1: t.c_cflag |= tcflag_t(PARENB | PARODD)
            case 2: t.c_cflag |= tcflag_t(PARENB)
            default: break
            }
            t.c_cflag |= tcflag_t(CREAD | CLOCAL)
            _ = tcsetattr(fd, TCSANOW, &t)
        }
        onLog?("Opened serial \(path) \(config.serspeed)")
        let src = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .global())
        src.setEventHandler { [weak self] in
            guard let self, self.fd >= 0 else { return }
            var buf = [UInt8](repeating: 0, count: 4096)
            let n = read(self.fd, &buf, buf.count)
            if n > 0 { self.onData?(Data(buf.prefix(n))) }
            else if n == 0 { self.onClose?(true, nil); self.stop() }
            else if errno != EAGAIN && errno != EWOULDBLOCK {
                self.onClose?(false, String(cString: strerror(errno)))
                self.stop()
            }
        }
        src.resume()
        source = src
    }

    func send(_ data: Data) {
        guard fd >= 0 else { return }
        _ = data.withUnsafeBytes { write(fd, $0.baseAddress, data.count) }
    }
    func resize(cols: Int, rows: Int) {}
    func stop() {
        source?.cancel(); source = nil
        if fd >= 0 { Darwin.close(fd); fd = -1 }
    }

    private func baudToConst(_ b: Int) -> speed_t {
        switch b {
        case 50: return speed_t(B50)
        case 75: return speed_t(B75)
        case 110: return speed_t(B110)
        case 134: return speed_t(B134)
        case 150: return speed_t(B150)
        case 200: return speed_t(B200)
        case 300: return speed_t(B300)
        case 600: return speed_t(B600)
        case 1200: return speed_t(B1200)
        case 1800: return speed_t(B1800)
        case 2400: return speed_t(B2400)
        case 4800: return speed_t(B4800)
        case 9600: return speed_t(B9600)
        case 19200: return speed_t(B19200)
        case 38400: return speed_t(B38400)
        case 57600: return speed_t(B57600)
        case 115200: return speed_t(B115200)
        case 230400: return speed_t(B230400)
        default: return speed_t(B9600)
        }
    }
}

final class SSHPump: BytePump {
    var onData: ((Data) -> Void)?
    var onLog: ((String) -> Void)?
    var onClose: ((Bool, String?) -> Void)?
    private let config: SessionConfig
    private var childPid: pid_t = 0
    private var master: FileHandle?
    private var source: DispatchSourceRead?
    private var tempKey: URL?
    private var phase: Phase = .probing
    private var loginBuffer = Data()
    private var queuedInput = Data()
    private var askFile: URL?
    private var finished = false
    private var termCols: Int
    private var termRows: Int

    private enum Phase { case probing, login, ssh }

    init(config: SessionConfig) {
        self.config = config
        self.termCols = max(2, config.width)
        self.termRows = max(2, config.height)
    }

    func start() {
        phase = .probing
        DispatchQueue.global().async { [weak self] in
            self?.begin()
        }
    }

    private func begin() {
        let port = config.port == 0 ? 22 : config.port
        onData?(Data("Connecting to \(config.host) port \(port)...\r\n".utf8))
        if config.proxyType == .none, let err = probeTCP(host: config.host, port: port) {
            finish(clean: false, message: err)
            return
        }
        onLog?("Connected to \(config.host) port \(port)")
        var user = config.username.trimmingCharacters(in: .whitespacesAndNewlines)
        if user.isEmpty && config.usernameFromEnv { user = NSUserName() }
        if user.isEmpty {
            phase = .login
            onData?(Data(L.t("auth.loginAs").utf8))
            return
        }
        phase = .ssh
        run(user: user)
    }

    private func run(user: String) {
        var args: [String] = ["-tt"]
        args += ["-o", "StrictHostKeyChecking=accept-new"]
        args += ["-o", "UserKnownHostsFile=\(SessionStore.shared.supportDir.appendingPathComponent("openssh_known_hosts").path)"]
        args += ["-o", "UpdateHostKeys=yes"]
        if config.port != 22 && config.port != 0 { args += ["-p", String(config.port)] }
        if config.compression { args.append("-C") }
        if config.agentFwd { args.append("-A") }
        applyAuthOptions(&args)
        if config.x11Forward { args.append("-X") }
        if config.sshNoPTY { args = args.filter { $0 != "-tt" }; args.append("-T") }
        for fwd in config.portFwds {
            switch fwd.kind {
            case .local: args += ["-L", "\(fwd.sourcePort):\(fwd.destination)"]
            case .remote: args += ["-R", "\(fwd.sourcePort):\(fwd.destination)"]
            case .dynamic: args += ["-D", fwd.sourcePort]
            }
        }
        if !config.keyFile.isEmpty {
            if let path = prepareIdentity(config.keyFile) {
                args += ["-i", path]
            }
        }
        args += ["-o", "ServerAliveInterval=\(config.pingInterval)"]
        if config.proxyType != .none {
            let cmd = proxyJump()
            if !cmd.isEmpty { args += ["-o", "ProxyCommand=\(cmd)"] }
        }
        let dest: String
        if !user.isEmpty { dest = "\(user)@\(config.host)" } else { dest = config.host }
        args.append(dest)
        if !config.remoteCmd.isEmpty {
            if config.sshSubsys { args += ["-s", config.remoteCmd] }
            else { args.append(config.remoteCmd) }
        }

        var env = ProcessInfo.processInfo.environment
        env["TERM"] = config.termType
        env["COLUMNS"] = String(termCols)
        env["LINES"] = String(termRows)
        env["LANG"] = env["LANG"] ?? "en_US.UTF-8"
        env.removeValue(forKey: "SSH_ASKPASS")
        env.removeValue(forKey: "SSH_ASKPASS_REQUIRE")
        env.removeValue(forKey: "BLM_ASKPASS")
        env.removeValue(forKey: "BLM_ASKPASS_FILE")
        if let ask = makeAskpass() {
            env["SSH_ASKPASS"] = ask
            env["SSH_ASKPASS_REQUIRE"] = "force"
            env["DISPLAY"] = env["DISPLAY"] ?? ":0"
            if let askFile { env["BLM_ASKPASS_FILE"] = askFile.path }
        }

        guard let spawned = PTY.spawn(
            path: "/usr/bin/ssh",
            arguments: args,
            environment: env,
            cols: termCols,
            rows: termRows
        ) else {
            finish(clean: false, message: "Unable to allocate PTY")
            return
        }
        childPid = spawned.pid
        master = spawned.master
        winsize(cols: termCols, rows: termRows)
        onLog?("ssh \(args.joined(separator: " "))")
        let fd = spawned.master.fileDescriptor
        let src = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .global())
        src.setEventHandler { [weak self] in
            guard let self else { return }
            var buf = [UInt8](repeating: 0, count: 4096)
            while true {
                let n = Darwin.read(fd, &buf, buf.count)
                if n > 0 {
                    self.onData?(Data(buf[0..<n]))
                    if n < buf.count { break }
                    continue
                }
                if n == 0 {
                    let pid = self.childPid
                    self.childPid = 0
                    let (clean, code) = PTY.waitStatus(pid)
                    self.finish(clean: clean, message: clean ? nil : "ssh exited \(code)")
                    return
                }
                if errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR { break }
                let pid = self.childPid
                self.childPid = 0
                let (clean, code) = PTY.waitStatus(pid)
                self.finish(clean: clean, message: clean ? nil : "ssh exited \(code)")
                return
            }
        }
        src.resume()
        source = src
        if !queuedInput.isEmpty {
            writeMaster(queuedInput)
            queuedInput.removeAll()
        }
    }

    func send(_ data: Data) {
        switch phase {
        case .probing:
            return
        case .login:
            collectLogin(data)
        case .ssh:
            writeMaster(data)
        }
    }

    private func writeMaster(_ data: Data) {
        guard !data.isEmpty else { return }
        guard let fd = master?.fileDescriptor else {
            queuedInput.append(data)
            return
        }
        data.withUnsafeBytes { raw in
            guard let ptr = raw.bindMemory(to: UInt8.self).baseAddress else { return }
            var sent = 0
            while sent < raw.count {
                let n = Darwin.write(fd, ptr + sent, raw.count - sent)
                if n > 0 {
                    sent += n
                    continue
                }
                if n < 0 && (errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK) {
                    usleep(1000)
                    continue
                }
                break
            }
        }
    }

    func resize(cols: Int, rows: Int) {
        termCols = max(2, cols)
        termRows = max(2, rows)
        winsize(cols: termCols, rows: termRows)
    }

    func stop() {
        source?.cancel()
        source = nil
        let pid = childPid
        childPid = 0
        if pid > 0 {
            kill(pid, SIGTERM)
            DispatchQueue.global().async {
                var status: Int32 = 0
                waitpid(pid, &status, 0)
            }
        }
        master?.closeFile()
        master = nil
        cleanup()
    }

    private func finish(clean: Bool, message: String?) {
        guard !finished else { return }
        finished = true
        onClose?(clean, message)
        stop()
    }

    private func collectLogin(_ data: Data) {
        for (i, b) in data.enumerated() {
            switch b {
            case 0x0D, 0x0A:
                let user = String(data: loginBuffer, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                loginBuffer.removeAll()
                onData?(Data("\r\n".utf8))
                guard !user.isEmpty else {
                    onData?(Data(L.t("auth.loginAs").utf8))
                    continue
                }
                phase = .ssh
                let rest = data.dropFirst(i + 1)
                if !rest.isEmpty && rest != Data([0x0A]) && rest != Data([0x0D]) {
                    queuedInput.append(contentsOf: rest.filter { $0 != 0x0A && $0 != 0x0D })
                }
                DispatchQueue.global().async { [weak self] in
                    self?.run(user: user)
                }
                return
            case 0x03:
                phase = .ssh
                finish(clean: false, message: L.t("auth.cancelled"))
                return
            case 0x7F, 0x08:
                if !loginBuffer.isEmpty {
                    loginBuffer.removeLast()
                    onData?(Data([0x08, 0x20, 0x08]))
                }
            case 0x15:
                if !loginBuffer.isEmpty {
                    let n = loginBuffer.count
                    loginBuffer.removeAll()
                    var erase = Data()
                    for _ in 0..<n { erase.append(contentsOf: [0x08, 0x20, 0x08]) }
                    onData?(erase)
                }
            default:
                if b >= 0x20 {
                    loginBuffer.append(b)
                    onData?(Data([b]))
                }
            }
        }
    }

    private func winsize(cols: Int, rows: Int) {
        guard let fd = master?.fileDescriptor, fd >= 0 else { return }
        var w = Darwin.winsize()
        w.ws_col = UInt16(clamping: cols)
        w.ws_row = UInt16(clamping: rows)
        _ = ioctl(fd, TIOCSWINSZ, &w)
        let pid = childPid
        if pid > 0 { kill(pid, SIGWINCH) }
    }

    private func prepareIdentity(_ path: String) -> String? {
        if path.lowercased().hasSuffix(".ppk") {
            var pass: String?
            DispatchQueue.main.sync {
                pass = Dialogs.passphrase(comment: path)
            }
            do {
                let key = try PPKKey.load(path: path, passphrase: pass)
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("blm-\(UUID().uuidString).key")
                try key.writeOpenSSHPrivate(to: url)
                tempKey = url
                onLog?("Loaded PPK \(key.type) \(key.fingerprintSHA256())")
                return url.path
            } catch {
                onLog?("PPK load failed: \(error)")
                return nil
            }
        }
        return path
    }

    private func applyAuthOptions(_ args: inout [String]) {
        if config.sshNoUserauth {
            args += ["-o", "PreferredAuthentications=none"]
            args += ["-o", "PubkeyAuthentication=no"]
            args += ["-o", "PasswordAuthentication=no"]
            args += ["-o", "KbdInteractiveAuthentication=no"]
            args += ["-o", "IdentitiesOnly=yes"]
            args += ["-o", "IdentityAgent=none"]
            return
        }

        var methods: [String] = []
        let hasKey = !config.keyFile.isEmpty
        if hasKey {
            methods.append("publickey")
        }
        if config.tryKIAuth { methods.append("keyboard-interactive") }
        methods.append("password")
        if !hasKey && config.tryAgent { methods.append("publickey") }
        if config.tryGSSAPI { methods.append("gssapi-with-mic") }
        args += ["-o", "PreferredAuthentications=\(methods.joined(separator: ","))"]
        args += ["-o", "NumberOfPasswordPrompts=3"]
        args += ["-o", "RequestTTY=force"]
        args += ["-o", "PasswordAuthentication=yes"]

        if hasKey {
            args += ["-o", "IdentitiesOnly=yes"]
        }
        if !config.tryAgent {
            args += ["-o", "IdentityAgent=none"]
        }
        if !hasKey && !config.tryAgent {
            args += ["-o", "PubkeyAuthentication=no"]
        }
        if !config.tryKIAuth {
            args += ["-o", "KbdInteractiveAuthentication=no"]
        }
        if config.tryGSSAPI {
            args += ["-o", "GSSAPIAuthentication=yes"]
            if config.gssapiFwd {
                args += ["-o", "GSSAPIDelegateCredentials=yes"]
            }
        } else {
            args += ["-o", "GSSAPIAuthentication=no"]
        }
    }

    private func probeTCP(host: String, port: Int) -> String? {
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else { return "Invalid port" }
        let tcp = NWProtocolTCP.Options()
        tcp.connectionTimeout = 15
        let params = NWParameters(tls: nil, tcp: tcp)
        let conn = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: params)
        let lock = NSLock()
        var done = false
        var result: String?
        let sem = DispatchSemaphore(value: 0)
        func complete(_ message: String?) {
            lock.lock()
            defer { lock.unlock() }
            guard !done else { return }
            done = true
            result = message
            sem.signal()
        }
        conn.stateUpdateHandler = { st in
            switch st {
            case .ready:
                conn.cancel()
                complete(nil)
            case .failed(let e):
                conn.cancel()
                complete(e.localizedDescription)
            default:
                break
            }
        }
        conn.start(queue: DispatchQueue.global(qos: .userInitiated))
        if sem.wait(timeout: .now() + 20) == .timedOut {
            conn.cancel()
            complete("Connection timed out")
            _ = sem.wait(timeout: .now() + 2)
        }
        return result
    }

    private func makeAskpass() -> String? {
        guard !config.password.isEmpty else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("blm-pw-\(UUID().uuidString)")
        try? config.password.write(to: url, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        askFile = url
        let helper = SessionStore.shared.supportDir.appendingPathComponent("blm-askpass")
        let script = """
        #!/bin/sh
        if [ -n "$BLM_ASKPASS_FILE" ] && [ -f "$BLM_ASKPASS_FILE" ]; then
          tr -d '\\n\\r' < "$BLM_ASKPASS_FILE"
          exit 0
        fi
        exit 1
        """
        do {
            try script.write(to: helper, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helper.path)
            return helper.path
        } catch {
            onLog?("askpass helper failed: \(error)")
            return nil
        }
    }

    private func proxyJump() -> String {
        switch config.proxyType {
        case .none: return ""
        case .http:
            return "nc -X connect -x \(config.proxyHost):\(config.proxyPort) %h %p"
        case .socks5:
            return "nc -X 5 -x \(config.proxyHost):\(config.proxyPort) %h %p"
        case .socks4:
            return "nc -X 4 -x \(config.proxyHost):\(config.proxyPort) %h %p"
        case .local, .telnet:
            return config.proxyTelnetCommand
                .replacingOccurrences(of: "%host", with: "%h")
                .replacingOccurrences(of: "%port", with: "%p")
        }
    }

    private func cleanup() {
        if let t = tempKey { try? FileManager.default.removeItem(at: t) }
        tempKey = nil
        if let a = askFile { try? FileManager.default.removeItem(at: a) }
        askFile = nil
    }
}

enum PTY {
    static func spawn(
        path: String,
        arguments: [String],
        environment: [String: String],
        cols: Int,
        rows: Int
    ) -> (pid: pid_t, master: FileHandle)? {
        var cArgv = ([path] + arguments).map { strdup($0) } + [nil]
        var cEnvp = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer {
            for p in cArgv where p != nil { free(p) }
            for p in cEnvp where p != nil { free(p) }
        }

        var masterFD: Int32 = -1
        var pid: pid_t = 0
        let rc = cArgv.withUnsafeMutableBufferPointer { argvBuf in
            cEnvp.withUnsafeMutableBufferPointer { envBuf in
                blm_pty_spawn(
                    path,
                    argvBuf.baseAddress,
                    envBuf.baseAddress,
                    Int32(cols),
                    Int32(rows),
                    &masterFD,
                    &pid
                )
            }
        }
        if rc != 0 || masterFD < 0 || pid <= 0 {
            if masterFD >= 0 { Darwin.close(masterFD) }
            return nil
        }
        return (pid, FileHandle(fileDescriptor: masterFD, closeOnDealloc: true))
    }

    static func waitStatus(_ pid: pid_t) -> (clean: Bool, code: Int) {
        guard pid > 0 else { return (false, -1) }
        var status: Int32 = 0
        waitpid(pid, &status, 0)
        let sig = status & 0x7f
        if sig == 0 {
            let code = Int((status >> 8) & 0xff)
            return (code == 0, code)
        }
        if sig != 0x7f {
            return (false, 128 + Int(sig))
        }
        return (false, Int(status))
    }
}
