import AppKit

enum AppMenu {
    private static var savedMenu: NSMenu?

    static func install() {
        let main = NSMenu()
        main.addItem(appMenu())
        main.addItem(fileMenu())
        main.addItem(editMenu())
        main.addItem(windowMenu())
        main.addItem(toolsMenu())
        main.addItem(helpMenu())
        NSApp.mainMenu = main
        refreshSavedSessions()
    }

    static func refreshSavedSessions() {
        guard let menu = savedMenu else { return }
        menu.removeAllItems()
        let names = SessionStore.shared.names()
        if names.isEmpty {
            let empty = NSMenuItem(title: "—", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return
        }
        for name in names {
            let title = name == SessionStore.defaultName ? L.t("session.default") : name
            let item = NSMenuItem(title: title, action: #selector(AppDelegate.openSavedSession(_:)), keyEquivalent: "")
            item.target = AppDelegate.shared
            item.representedObject = name
            menu.addItem(item)
        }
    }

    private static func appMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: L.t("app.name"))
        menu.addItem(action(L.t("menu.about"), #selector(AppDelegate.showAbout(_:))))
        menu.addItem(.separator())
        menu.addItem(action(L.t("menu.prefs"), #selector(AppDelegate.showPreferences(_:)), ","))
        let lang = NSMenuItem(title: L.t("menu.language"), action: nil, keyEquivalent: "")
        let langMenu = NSMenu(title: L.t("menu.language"))
        let en = NSMenuItem(title: L.t("lang.english"), action: #selector(AppDelegate.setLanguageEnglish(_:)), keyEquivalent: "")
        en.target = AppDelegate.shared
        en.state = L.language == .en ? .on : .off
        let tr = NSMenuItem(title: L.t("lang.turkish"), action: #selector(AppDelegate.setLanguageTurkish(_:)), keyEquivalent: "")
        tr.target = AppDelegate.shared
        tr.state = L.language == .tr ? .on : .off
        langMenu.addItem(en)
        langMenu.addItem(tr)
        lang.submenu = langMenu
        menu.addItem(lang)
        menu.addItem(.separator())
        menu.addItem(action(L.t("menu.services"), nil))
        menu.addItem(.separator())
        menu.addItem(sys(L.t("menu.hide"), #selector(NSApplication.hide(_:)), "h"))
        let hideOthers = NSMenuItem(title: L.t("menu.hideOthers"), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        hideOthers.target = NSApp
        menu.addItem(hideOthers)
        menu.addItem(sys(L.t("menu.showAll"), #selector(NSApplication.unhideAllApplications(_:))))
        menu.addItem(.separator())
        menu.addItem(action(L.t("menu.quit"), #selector(NSApplication.terminate(_:)), "q"))
        item.submenu = menu
        return item
    }

    private static func fileMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: L.t("menu.file"))
        menu.addItem(action(L.t("menu.new"), #selector(AppDelegate.newSession(_:)), "n"))
        menu.addItem(action(L.t("menu.dup"), #selector(AppDelegate.duplicateSession(_:))))
        let saved = NSMenuItem(title: L.t("menu.saved"), action: nil, keyEquivalent: "")
        let savedSub = NSMenu(title: L.t("menu.saved"))
        saved.submenu = savedSub
        savedMenu = savedSub
        menu.addItem(saved)
        menu.addItem(action(L.t("menu.change"), #selector(AppDelegate.changeSettings(_:))))
        menu.addItem(.separator())
        menu.addItem(action(L.t("menu.close"), #selector(AppDelegate.closeWindow(_:)), "w"))
        item.submenu = menu
        return item
    }

    private static func editMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: L.t("menu.edit"))
        menu.addItem(sys(L.t("menu.undo"), Selector(("undo:")), "z"))
        menu.addItem(sys(L.t("menu.redo"), Selector(("redo:")), "Z"))
        menu.addItem(.separator())
        menu.addItem(sys(L.t("menu.cut"), #selector(NSText.cut(_:)), "x"))
        menu.addItem(action(L.t("menu.copy"), #selector(AppDelegate.copySel(_:)), "c"))
        menu.addItem(action(L.t("menu.paste"), #selector(AppDelegate.pasteSel(_:)), "v"))
        menu.addItem(action(L.t("menu.selectAll"), #selector(AppDelegate.selectAllText(_:)), "a"))
        menu.addItem(.separator())
        menu.addItem(action(L.t("menu.find"), #selector(AppDelegate.findText(_:)), "f"))
        menu.addItem(action(L.t("menu.clear"), #selector(AppDelegate.clearScrollback(_:))))
        item.submenu = menu
        return item
    }

    private static func windowMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: L.t("menu.window"))
        menu.addItem(sys(L.t("menu.minimize"), #selector(NSWindow.performMiniaturize(_:)), "m"))
        menu.addItem(action(L.t("menu.fullscreen"), #selector(AppDelegate.toggleFullScreen(_:)), "f", [.command, .control]))
        menu.addItem(.separator())
        menu.addItem(action(L.t("menu.eventLog"), #selector(AppDelegate.showEventLog(_:))))
        menu.addItem(action(L.t("menu.reset"), #selector(AppDelegate.resetTerminal(_:))))
        menu.addItem(action(L.t("menu.restart"), #selector(AppDelegate.restartSession(_:))))
        menu.addItem(.separator())
        menu.addItem(sys(L.t("menu.bringAll"), #selector(NSApplication.arrangeInFront(_:))))
        NSApp.windowsMenu = menu
        item.submenu = menu
        return item
    }

    private static func toolsMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: L.t("menu.tools"))
        menu.addItem(action(L.t("menu.puttygen"), #selector(AppDelegate.showPuttygen(_:))))
        item.submenu = menu
        return item
    }

    private static func helpMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: L.t("menu.help"))
        let help = action(L.t("menu.helpItem"), #selector(AppDelegate.showHelp(_:)), "?")
        menu.addItem(help)
        NSApp.helpMenu = menu
        item.submenu = menu
        return item
    }

    private static func action(_ title: String, _ sel: Selector?, _ key: String = "", _ mask: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let m = NSMenuItem(title: title, action: sel, keyEquivalent: key)
        if !key.isEmpty { m.keyEquivalentModifierMask = mask }
        m.target = sel == nil ? nil : AppDelegate.shared
        return m
    }

    private static func sys(_ title: String, _ sel: Selector?, _ key: String = "") -> NSMenuItem {
        let m = NSMenuItem(title: title, action: sel, keyEquivalent: key)
        return m
    }
}
