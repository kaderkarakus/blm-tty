import Foundation

final class SessionStore {
    static let shared = SessionStore()

    static let defaultName = "Default Settings"

    private let fm = FileManager.default
    private(set) var sessionsDir: URL
    private(set) var supportDir: URL

    private init() {
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("BLM-TTY", isDirectory: true)
        supportDir = base
        sessionsDir = base.appendingPathComponent("sessions", isDirectory: true)
        try? fm.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
        importLegacyIfNeeded()
        if load(Self.defaultName) == nil {
            save(SessionConfig(), as: Self.defaultName)
        }
    }

    func names() -> [String] {
        let files = (try? fm.contentsOfDirectory(atPath: sessionsDir.path)) ?? []
        var names = files.map { PuTTYSessionFile.decodeName($0) }
            .filter { $0 != Self.defaultName }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        names.insert(Self.defaultName, at: 0)
        return names
    }

    func load(_ name: String) -> SessionConfig? {
        let url = sessionsDir.appendingPathComponent(PuTTYSessionFile.encodeName(name))
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return nil }
        let c = SessionConfig()
        PuTTYSessionFile.parse(text, into: c)
        c.sessionName = name
        return c
    }

    @discardableResult
    func save(_ config: SessionConfig, as name: String) -> Bool {
        let url = sessionsDir.appendingPathComponent(PuTTYSessionFile.encodeName(name))
        let text = PuTTYSessionFile.serialize(config)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            NotificationCenter.default.post(name: .blmSessionsChanged, object: nil)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func delete(_ name: String) -> Bool {
        guard name != Self.defaultName else { return false }
        let url = sessionsDir.appendingPathComponent(PuTTYSessionFile.encodeName(name))
        try? fm.removeItem(at: url)
        NotificationCenter.default.post(name: .blmSessionsChanged, object: nil)
        return true
    }

    func hostKeysURL() -> URL {
        supportDir.appendingPathComponent("sshhostkeys")
    }

    func randomSeedURL() -> URL {
        supportDir.appendingPathComponent("randomseed")
    }

    private func importLegacyIfNeeded() {
        let flag = supportDir.appendingPathComponent(".imported")
        guard !fm.fileExists(atPath: flag.path) else { return }
        let home = fm.homeDirectoryForCurrentUser
        let legacy = home.appendingPathComponent(".putty/sessions")
        if fm.fileExists(atPath: legacy.path) {
            if let files = try? fm.contentsOfDirectory(atPath: legacy.path) {
                for f in files {
                    let src = legacy.appendingPathComponent(f)
                    let dst = sessionsDir.appendingPathComponent(f)
                    if !fm.fileExists(atPath: dst.path) {
                        try? fm.copyItem(at: src, to: dst)
                    }
                }
            }
        }
        try? "1".write(to: flag, atomically: true, encoding: .utf8)
    }
}

final class KnownHostsStore {
    static let shared = KnownHostsStore()
    private var map: [String: String] = [:]
    private let url: URL

    private init() {
        url = SessionStore.shared.hostKeysURL()
        reload()
    }

    func reload() {
        map.removeAll()
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        for line in text.split(whereSeparator: \.isNewline) {
            let s = String(line)
            guard let sp = s.firstIndex(of: " ") else { continue }
            let k = String(s[..<sp])
            let v = String(s[s.index(after: sp)...])
            map[k] = v
        }
    }

    func key(for host: String, port: Int, type: String) -> String? {
        map["\(type)@\(port):\(host)"] ?? map["\(type):\(host)"]
    }

    func store(host: String, port: Int, type: String, blob: String) {
        map["\(type)@\(port):\(host)"] = blob
        persist()
    }

    private func persist() {
        let text = map.keys.sorted().map { "\($0) \(map[$0]!)" }.joined(separator: "\n") + "\n"
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}
