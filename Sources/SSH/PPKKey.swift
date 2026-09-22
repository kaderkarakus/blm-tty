import Foundation
import CryptoKit
import CommonCrypto
import Security

struct PPKKey {
    var type: String
    var comment: String
    var publicBlob: Data
    var privateBlob: Data
    var encrypted: Bool
    var version: Int

    enum PPKError: Error {
        case format
        case passphrase
        case unsupported
        case crypto
    }

    static func load(path: String, passphrase: String?) throws -> PPKKey {
        let text = try String(contentsOfFile: path, encoding: .utf8)
        return try parse(text, passphrase: passphrase)
    }

    static func parse(_ text: String, passphrase: String?) throws -> PPKKey {
        var lines = text.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        lines = lines.map { $0.trimmingCharacters(in: .newlines) }
        guard let first = lines.first else { throw PPKError.format }
        let version: Int
        if first.hasPrefix("PuTTY-User-Key-File-3:") { version = 3 }
        else if first.hasPrefix("PuTTY-User-Key-File-2:") { version = 2 }
        else { throw PPKError.format }
        let type = first.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespaces) ?? ""
        func field(_ name: String) -> String? {
            lines.first(where: { $0.hasPrefix(name + ":") })?
                .split(separator: ":", maxSplits: 1).last?
                .trimmingCharacters(in: .whitespaces)
        }
        func block(_ name: String) throws -> Data {
            guard let n = Int(field(name + "-Lines") ?? "") else { throw PPKError.format }
            guard let start = lines.firstIndex(where: { $0.hasPrefix(name + "-Lines:") }) else { throw PPKError.format }
            let slice = lines[(start+1)..<(start+1+n)].joined()
            guard let d = Data(base64Encoded: slice) else { throw PPKError.format }
            return d
        }
        let encryption = field("Encryption") ?? "none"
        let comment = field("Comment") ?? ""
        let publicBlob = try block("Public")
        var privateBlob = try block("Private")
        let encrypted = encryption != "none"
        if encrypted {
            guard let pass = passphrase, !pass.isEmpty else { throw PPKError.passphrase }
            if version == 2 && encryption == "aes256-cbc" {
                privateBlob = try decryptPPK2(privateBlob, passphrase: pass)
            } else if version == 3 {
                throw PPKError.unsupported
            } else {
                throw PPKError.unsupported
            }
        }
        let key = PPKKey(type: type, comment: comment, publicBlob: publicBlob, privateBlob: privateBlob, encrypted: encrypted, version: version)
        if version == 2 {
            let mac = field("Private-MAC") ?? ""
            if !verifyPPK2MAC(key, encryption: encryption, passphrase: passphrase ?? "", macHex: mac) {
                if encrypted { throw PPKError.passphrase }
            }
        }
        return key
    }

    func writeOpenSSHPrivate(to url: URL) throws {
        let data = try openSSHPrivateFile()
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    func authorizedKeysLine() -> String {
        let b64 = publicBlob.base64EncodedString()
        return "\(openSSHType()) \(b64) \(comment)"
    }

    func fingerprintSHA256() -> String {
        let d = Data(SHA256.hash(data: publicBlob))
        return "SHA256:" + d.base64EncodedString().trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }

    func openSSHType() -> String {
        switch type {
        case "ssh-ed25519": return "ssh-ed25519"
        case "ecdsa-sha2-nistp256": return "ecdsa-sha2-nistp256"
        case "ecdsa-sha2-nistp384": return "ecdsa-sha2-nistp384"
        case "ecdsa-sha2-nistp521": return "ecdsa-sha2-nistp521"
        default: return "ssh-rsa"
        }
    }

    func openSSHPrivateFile() throws -> Data {
        var inner = Data()
        let check = UInt32.random(in: 0..<UInt32.max)
        inner.appendMPInt32(check)
        inner.appendMPInt32(check)
        inner.appendSSH(openSSHType())
        switch type {
        case "ssh-ed25519":
            let pub = try Self.readString(from: publicBlob, offset: {
                var o = 0
                _ = try Self.readString(from: publicBlob, offset: &o)
                return o
            }())
            var off = 0
            let priv = try Self.readString(from: privateBlob, offset: &off)
            inner.appendSSH(pub)
            var secret = Data()
            secret.append(priv)
            if priv.count == 32 { secret.append(pub) }
            inner.appendSSH(secret.count == 64 ? secret : priv)
            inner.appendSSH(comment)
        case "ssh-rsa":
            var po = 0
            _ = try Self.readString(from: publicBlob, offset: &po)
            let e = try Self.readString(from: publicBlob, offset: &po)
            let n = try Self.readString(from: publicBlob, offset: &po)
            var o = 0
            let d = try Self.readString(from: privateBlob, offset: &o)
            let p = try Self.readString(from: privateBlob, offset: &o)
            let q = try Self.readString(from: privateBlob, offset: &o)
            let iqmp = try Self.readString(from: privateBlob, offset: &o)
            inner.appendSSH(n)
            inner.appendSSH(e)
            inner.appendSSH(d)
            inner.appendSSH(iqmp)
            inner.appendSSH(p)
            inner.appendSSH(q)
            inner.appendSSH(comment)
        default:
            throw PPKError.unsupported
        }
        while inner.count % 8 != 0 { inner.append(UInt8(inner.count % 8 + 1)) }
        var file = Data()
        file.append(contentsOf: Array("openssh-key-v1\u{0}".utf8))
        file.appendSSH("none")
        file.appendSSH("none")
        file.appendSSH(Data())
        file.appendMPInt32(1)
        file.appendSSH(publicBlob)
        file.appendSSH(inner)
        return file
    }

    static func generateEd25519(comment: String) -> (PPKKey, String) {
        let priv = Curve25519.Signing.PrivateKey()
        let pub = priv.publicKey.rawRepresentation
        let seed = priv.rawRepresentation
        var pubBlob = Data()
        pubBlob.appendSSH("ssh-ed25519")
        pubBlob.appendSSH(pub)
        var privBlob = Data()
        privBlob.appendSSH(seed)
        let key = PPKKey(type: "ssh-ed25519", comment: comment, publicBlob: pubBlob, privateBlob: privBlob, encrypted: false, version: 2)
        return (key, key.fingerprintSHA256())
    }

    func serializePPK2(passphrase: String?) -> String {
        var priv = privateBlob
        var enc = "none"
        if let p = passphrase, !p.isEmpty {
            enc = "aes256-cbc"
            let pad = 16 - (priv.count % 16)
            priv.append(Data(repeating: UInt8(pad), count: pad))
            priv = (try? encryptPPK2(priv, passphrase: p)) ?? priv
        }
        func lines(_ data: Data) -> (Int, String) {
            let b64 = data.base64EncodedString()
            var out = ""
            var i = b64.startIndex
            var n = 0
            while i < b64.endIndex {
                let j = b64.index(i, offsetBy: 64, limitedBy: b64.endIndex) ?? b64.endIndex
                out += String(b64[i..<j]) + "\n"
                n += 1
                i = j
            }
            return (n, out)
        }
        let (pn, pb) = lines(publicBlob)
        let (vn, vb) = lines(priv)
        let mac = macPPK2(encryption: enc, passphrase: passphrase ?? "", publicBlob: publicBlob, privateBlob: privateBlob, comment: comment, type: type)
        return """
        PuTTY-User-Key-File-2: \(type)
        Encryption: \(enc)
        Comment: \(comment)
        Public-Lines: \(pn)
        \(pb)Private-Lines: \(vn)
        \(vb)Private-MAC: \(mac)
        """
    }
}

private func sha1(_ data: Data) -> Data {
    var out = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
    data.withUnsafeBytes { buf in
        _ = CC_SHA1(buf.baseAddress, CC_LONG(data.count), &out)
    }
    return Data(out)
}

private func decryptPPK2(_ data: Data, passphrase: String) throws -> Data {
    var key = sha1(Data([0,0,0,0]) + Data(passphrase.utf8))
    key.append(sha1(Data([0,0,0,1]) + Data(passphrase.utf8)))
    key = key.prefix(32)
    return try aes256cbc(data, key: Data(key), encrypt: false)
}

private func encryptPPK2(_ data: Data, passphrase: String) throws -> Data {
    var key = sha1(Data([0,0,0,0]) + Data(passphrase.utf8))
    key.append(sha1(Data([0,0,0,1]) + Data(passphrase.utf8)))
    key = key.prefix(32)
    return try aes256cbc(data, key: Data(key), encrypt: true)
}

private func aes256cbc(_ data: Data, key: Data, encrypt: Bool) throws -> Data {
    var out = [UInt8](repeating: 0, count: data.count + kCCBlockSizeAES128)
    var moved = 0
    let iv = [UInt8](repeating: 0, count: 16)
    let status = key.withUnsafeBytes { kbuf in
        data.withUnsafeBytes { dbuf in
            CCCrypt(CCOperation(encrypt ? kCCEncrypt : kCCDecrypt),
                    CCAlgorithm(kCCAlgorithmAES),
                    CCOptions(0),
                    kbuf.baseAddress, key.count,
                    iv,
                    dbuf.baseAddress, data.count,
                    &out, out.count, &moved)
        }
    }
    guard status == kCCSuccess else { throw PPKKey.PPKError.crypto }
    return Data(out.prefix(moved))
}

private func macPPK2(encryption: String, passphrase: String, publicBlob: Data, privateBlob: Data, comment: String, type: String) -> String {
    var macData = Data()
    macData.appendSSH(type)
    macData.appendSSH(encryption)
    macData.appendSSH(comment)
    macData.appendSSH(publicBlob)
    macData.appendSSH(privateBlob)
    let macKey = sha1(Data("putty-private-key-file-mac-key".utf8) + Data(passphrase.utf8))
    var result = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
    macData.withUnsafeBytes { mbuf in
        macKey.withUnsafeBytes { kbuf in
            CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA1), kbuf.baseAddress, macKey.count, mbuf.baseAddress, macData.count, &result)
        }
    }
    return result.map { String(format: "%02x", $0) }.joined()
}

private func verifyPPK2MAC(_ key: PPKKey, encryption: String, passphrase: String, macHex: String) -> Bool {
    macPPK2(encryption: encryption, passphrase: passphrase, publicBlob: key.publicBlob, privateBlob: key.privateBlob, comment: key.comment, type: key.type) == macHex.lowercased()
}

extension Data {
    mutating func appendMPInt32(_ v: UInt32) {
        var be = v.bigEndian
        Swift.withUnsafeBytes(of: &be) { append(contentsOf: $0) }
    }
    mutating func appendSSH(_ s: String) {
        appendSSH(Data(s.utf8))
    }
    mutating func appendSSH(_ d: Data) {
        appendMPInt32(UInt32(d.count))
        append(d)
    }
}

extension PPKKey {
    static func readString(from data: Data, offset: inout Int) throws -> Data {
        guard offset + 4 <= data.count else { throw PPKError.format }
        let n = Int(data[offset]) << 24 | Int(data[offset+1]) << 16 | Int(data[offset+2]) << 8 | Int(data[offset+3])
        offset += 4
        guard offset + n <= data.count else { throw PPKError.format }
        let d = data.subdata(in: offset..<(offset+n))
        offset += n
        return d
    }
    static func readString(from data: Data, offset: Int) throws -> Data {
        var o = offset
        return try readString(from: data, offset: &o)
    }
}
