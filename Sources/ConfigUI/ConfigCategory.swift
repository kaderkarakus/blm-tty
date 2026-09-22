import Foundation

enum ConfigCategory: String, CaseIterable {
    case session, logging
    case terminal, keyboard, bell, features
    case window, appearance, behaviour, translation, selection, colours
    case connection, data, proxy, telnet, rlogin
    case ssh, kex, hostkeys, cipher, auth, gssapi, tty, x11, tunnels, bugs, morebugs
    case serial

    var key: String { "cat.\(rawValue)" }

    static func tree() -> [WinTreeNode] {
        [
            WinTreeNode(id: "session", key: "cat.session", children: [
                WinTreeNode(id: "logging", key: "cat.logging")
            ]),
            WinTreeNode(id: "terminal", key: "cat.terminal", children: [
                WinTreeNode(id: "keyboard", key: "cat.keyboard"),
                WinTreeNode(id: "bell", key: "cat.bell"),
                WinTreeNode(id: "features", key: "cat.features"),
            ]),
            WinTreeNode(id: "window", key: "cat.window", children: [
                WinTreeNode(id: "appearance", key: "cat.appearance"),
                WinTreeNode(id: "behaviour", key: "cat.behaviour"),
                WinTreeNode(id: "translation", key: "cat.translation"),
                WinTreeNode(id: "selection", key: "cat.selection"),
                WinTreeNode(id: "colours", key: "cat.colours"),
            ]),
            WinTreeNode(id: "connection", key: "cat.connection", children: [
                WinTreeNode(id: "data", key: "cat.data"),
                WinTreeNode(id: "proxy", key: "cat.proxy"),
                WinTreeNode(id: "telnet", key: "cat.telnet"),
                WinTreeNode(id: "rlogin", key: "cat.rlogin"),
                WinTreeNode(id: "ssh", key: "cat.ssh", children: [
                    WinTreeNode(id: "kex", key: "cat.kex"),
                    WinTreeNode(id: "hostkeys", key: "cat.hostkeys"),
                    WinTreeNode(id: "cipher", key: "cat.cipher"),
                    WinTreeNode(id: "auth", key: "cat.auth", children: [
                        WinTreeNode(id: "gssapi", key: "cat.gssapi"),
                    ]),
                    WinTreeNode(id: "tty", key: "cat.tty"),
                    WinTreeNode(id: "x11", key: "cat.x11"),
                    WinTreeNode(id: "tunnels", key: "cat.tunnels"),
                    WinTreeNode(id: "bugs", key: "cat.bugs"),
                    WinTreeNode(id: "morebugs", key: "cat.morebugs"),
                ]),
                WinTreeNode(id: "serial", key: "cat.serial"),
            ]),
        ]
    }
}
