import Foundation

enum CLI {
    struct Result {
        var config: SessionConfig
        var openDirect = false
        var error: String?
        var fatal = false
    }

    static func wantsHelp(_ args: [String]) -> Bool {
        args.contains { ["-h", "--help", "-?", "/?"].contains($0) }
    }

    static func parse(_ args: [String]) -> Result {
        let base = SessionStore.shared.load(SessionStore.defaultName) ?? SessionConfig()
        var cfg = base.clone()
        var error: String?
        var fatal = false
        var i = 0

        func takeValue() -> String? {
            i += 1
            guard i < args.count else { return nil }
            return args[i]
        }

        // Pass 1: -load / -session so later flags overlay.
        var j = 0
        while j < args.count {
            let a = args[j]
            if a == "-load" || a == "-session" {
                if j + 1 < args.count {
                    let name = args[j + 1]
                    if let loaded = SessionStore.shared.load(name) {
                        cfg = loaded.clone()
                    } else {
                        error = String(format: L.t("cli.unknown"), name)
                    }
                    j += 2
                    continue
                }
            }
            j += 1
        }

        var positional: [String] = []
        i = 0
        while i < args.count {
            let a = args[i]
            switch a {
            case "-ssh":
                cfg.protocolType = .ssh
                if cfg.port == 0 || cfg.port == 23 || cfg.port == 513 { cfg.port = 22 }
            case "-telnet":
                cfg.protocolType = .telnet
                if cfg.port == 0 || cfg.port == 22 { cfg.port = 23 }
            case "-rlogin":
                cfg.protocolType = .rlogin
                if cfg.port == 0 || cfg.port == 22 { cfg.port = 513 }
            case "-raw":
                cfg.protocolType = .raw
            case "-serial":
                cfg.protocolType = .serial
            case "-P":
                if let v = takeValue(), let p = Int(v) { cfg.port = p }
            case "-l":
                if let v = takeValue() { cfg.username = v }
            case "-pw":
                if let v = takeValue() { cfg.password = v }
            case "-i":
                if let v = takeValue() { cfg.keyFile = v }
            case "-L":
                if let v = takeValue(), let f = parseForward(v) {
                    cfg.portFwds.append(PortForward(kind: .local, sourcePort: f.src, destination: f.dst))
                }
            case "-R":
                if let v = takeValue(), let f = parseForward(v) {
                    cfg.portFwds.append(PortForward(kind: .remote, sourcePort: f.src, destination: f.dst))
                }
            case "-D":
                if let v = takeValue() {
                    cfg.portFwds.append(PortForward(kind: .dynamic, sourcePort: v, destination: ""))
                }
            case "-X":
                cfg.x11Forward = true
            case "-A":
                cfg.agentFwd = true
            case "-a":
                cfg.agentFwd = false
                cfg.tryAgent = false
            case "-C":
                cfg.compression = true
            case "-1":
                cfg.sshProt = 1
            case "-2":
                cfg.sshProt = 3
            case "-log":
                if let v = takeValue() {
                    cfg.logFileName = v
                    if cfg.logType == .none { cfg.logType = .all }
                }
            case "-load", "-session":
                _ = takeValue()
            case "-h", "--help", "-?", "/?":
                break
            default:
                if a.hasPrefix("-") {
                    error = String(format: L.t("cli.unknown"), a)
                    fatal = true
                } else {
                    positional.append(a)
                }
            }
            i += 1
        }

        if let dest = positional.first {
            if cfg.protocolType == .serial {
                cfg.serline = dest
            } else {
                applyDestination(dest, to: cfg)
            }
        }

        var openDirect = false
        if cfg.protocolType == .serial {
            openDirect = !cfg.serline.trimmingCharacters(in: .whitespaces).isEmpty
        } else {
            openDirect = !cfg.host.trimmingCharacters(in: .whitespaces).isEmpty
        }

        return Result(config: cfg, openDirect: openDirect, error: error, fatal: fatal)
    }

    private static func applyDestination(_ dest: String, to cfg: SessionConfig) {
        if dest.hasPrefix("[") {
            if let end = dest.firstIndex(of: "]") {
                cfg.host = String(dest[dest.index(after: dest.startIndex)..<end])
                let rest = dest[dest.index(after: end)...]
                if rest.hasPrefix(":") , let p = Int(rest.dropFirst()) {
                    cfg.port = p
                }
            } else {
                cfg.host = dest
            }
            return
        }
        if let at = dest.firstIndex(of: "@") {
            let user = String(dest[..<at])
            let hostPart = String(dest[dest.index(after: at)...])
            if !user.isEmpty { cfg.username = user }
            applyDestination(hostPart, to: cfg)
            return
        }
        if dest.contains(":") , !dest.contains("::") {
            let parts = dest.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2, let p = Int(parts[1]) {
                cfg.host = String(parts[0])
                cfg.port = p
                return
            }
        }
        cfg.host = dest
    }

    private static func parseForward(_ spec: String) -> (src: String, dst: String)? {
        let parts = spec.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        if parts.count >= 4 {
            let src = parts[0] + ":" + parts[1]
            let dst = parts[2...].joined(separator: ":")
            return (src, dst)
        }
        if parts.count == 3 {
            return (parts[0], parts[1] + ":" + parts[2])
        }
        return nil
    }
}
