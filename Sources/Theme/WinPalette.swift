import AppKit

enum WinPalette {
    static var dialogFace: NSColor { .windowBackgroundColor }
    static var window: NSColor { .windowBackgroundColor }
    static var titleText: NSColor { .labelColor }
    static var titleBorder: NSColor { .separatorColor }
    static var controlBorder: NSColor { .separatorColor }
    static var editBorder: NSColor { .separatorColor }
    static var sunken: NSColor { .separatorColor }
    static var group: NSColor { .separatorColor }
    static var buttonFace: NSColor { .controlColor }
    static var buttonHover: NSColor { .controlBackgroundColor }
    static var buttonPress: NSColor { .selectedControlColor }
    static var accent: NSColor { .controlAccentColor }
    static var closeHover: NSColor { .systemRed }
    static var disabledText: NSColor { .disabledControlTextColor }
    static var text: NSColor { .labelColor }
    static var selectionText: NSColor { .selectedMenuItemTextColor }
    static var treeGlyph: NSColor { .secondaryLabelColor }
    static var shadow: NSColor { NSColor.black.withAlphaComponent(0.18) }

    static let titleBarHeight: CGFloat = 0
    static let windowWidth: CGFloat = 548
    static let windowHeight: CGFloat = 498
    static let clientHeight: CGFloat = 448
    static let sidebarWidth: CGFloat = 180
    static let panelWidth: CGFloat = 334
    static let bottomBarHeight: CGFloat = 48
    static let buttonW: CGFloat = 88
    static let buttonH: CGFloat = 24
}

enum WinFont {
    static func ui(_ size: CGFloat = NSFont.smallSystemFontSize) -> NSFont {
        NSFont.systemFont(ofSize: size)
    }

    static func uiBold(_ size: CGFloat = NSFont.smallSystemFontSize) -> NSFont {
        NSFont.boldSystemFont(ofSize: size)
    }

    static func title() -> NSFont {
        NSFont.systemFont(ofSize: 13, weight: .semibold)
    }

    static func mono(_ size: CGFloat = 11) -> NSFont {
        NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }
}
