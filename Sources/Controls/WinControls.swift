import AppKit

protocol LocalizableUI: AnyObject {
    func reloadTexts()
}

final class WinLabel: NSTextField, LocalizableUI {
    var key: String?

    convenience init(key: String, frame: NSRect) {
        self.init(frame: frame)
        self.key = key
        common()
        reloadTexts()
    }

    convenience init(text: String, frame: NSRect) {
        self.init(frame: frame)
        common()
        stringValue = text
    }

    private func common() {
        isBezeled = false
        drawsBackground = false
        isEditable = false
        isSelectable = false
        font = WinFont.ui()
        textColor = .labelColor
        backgroundColor = .clear
        lineBreakMode = .byTruncatingTail
    }

    func reloadTexts() {
        if let key { stringValue = L.t(key) }
    }
}

final class WinButton: NSButton, LocalizableUI {
    var key: String?
    var isDefaultLook = false

    convenience init(key: String, frame: NSRect, defaultLook: Bool = false) {
        self.init(frame: frame)
        self.key = key
        self.isDefaultLook = defaultLook
        common()
        reloadTexts()
    }

    convenience init(titleText: String, frame: NSRect, defaultLook: Bool = false) {
        self.init(frame: frame)
        self.isDefaultLook = defaultLook
        common()
        title = titleText
    }

    private func common() {
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        controlSize = .small
        font = WinFont.ui()
        focusRingType = .default
        if isDefaultLook {
            keyEquivalent = "\r"
        }
    }

    func reloadTexts() {
        if let key { title = L.t(key) }
    }
}

final class WinRadio: NSButton, LocalizableUI {
    var key: String?
    var group: [WinRadio] = []

    convenience init(key: String, frame: NSRect) {
        self.init(frame: frame)
        self.key = key
        common()
        reloadTexts()
    }

    convenience init(titleText: String, frame: NSRect) {
        self.init(frame: frame)
        common()
        title = titleText
    }

    private func common() {
        setButtonType(.radio)
        bezelStyle = .regularSquare
        isBordered = false
        controlSize = .small
        font = WinFont.ui()
        imagePosition = .imageLeft
        alignment = .left
    }

    func reloadTexts() {
        if let key { title = L.t(key) }
    }
}

final class WinCheckbox: NSButton, LocalizableUI {
    var key: String?

    convenience init(key: String, frame: NSRect) {
        self.init(frame: frame)
        self.key = key
        common()
        reloadTexts()
    }

    private func common() {
        setButtonType(.switch)
        bezelStyle = .regularSquare
        isBordered = false
        controlSize = .small
        font = WinFont.ui()
        imagePosition = .imageLeft
        alignment = .left
    }

    func reloadTexts() {
        if let key { title = L.t(key) }
    }
}

final class WinTextField: NSTextField {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        common()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        common()
    }

    private func common() {
        isBezeled = true
        bezelStyle = .roundedBezel
        drawsBackground = true
        backgroundColor = .textBackgroundColor
        font = WinFont.ui()
        textColor = .labelColor
        focusRingType = .default
        controlSize = .small
        cell?.wraps = false
        cell?.isScrollable = true
        cell?.usesSingleLineMode = true
    }
}

final class WinSecureField: NSSecureTextField {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBezeled = true
        bezelStyle = .roundedBezel
        drawsBackground = true
        backgroundColor = .textBackgroundColor
        font = WinFont.ui()
        textColor = .labelColor
        focusRingType = .default
        controlSize = .small
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }
}

final class WinGroupBox: NSBox, LocalizableUI {
    var key: String?

    convenience init(key: String, frame: NSRect) {
        self.init(frame: frame)
        self.key = key
        boxType = .primary
        titlePosition = .atTop
        contentViewMargins = .zero
        titleFont = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
        reloadTexts()
    }

    func reloadTexts() {
        if let key { title = L.t(key) }
    }
}

final class WinListBox: NSView, NSTableViewDataSource, NSTableViewDelegate {
    let table = NSTableView()
    private let scroll = NSScrollView()
    var items: [String] = [] {
        didSet { table.reloadData() }
    }
    var onSelect: ((Int) -> Void)?
    var onActivate: ((Int) -> Void)?
    var selectedIndex: Int {
        get { table.selectedRow }
        set { table.selectRowIndexes(IndexSet(integer: newValue), byExtendingSelection: false) }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .bezelBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = .textBackgroundColor
        table.headerView = nil
        table.rowHeight = 20
        table.rowSizeStyle = .custom
        table.style = .plain
        table.backgroundColor = .textBackgroundColor
        table.selectionHighlightStyle = .regular
        table.allowsEmptySelection = true
        table.usesAlternatingRowBackgroundColors = false
        table.focusRingType = .none
        table.intercellSpacing = NSSize(width: 0, height: 0)
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("c"))
        col.resizingMask = .autoresizingMask
        table.addTableColumn(col)
        table.dataSource = self
        table.delegate = self
        table.doubleAction = #selector(dbl)
        table.target = self
        scroll.documentView = table
        addSubview(scroll)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        scroll.frame = bounds
        if let col = table.tableColumns.first {
            let scroller = scroll.verticalScroller?.bounds.width ?? 0
            col.width = max(20, bounds.width - 4 - (scroll.hasVerticalScroller ? scroller : 0))
        }
        table.sizeLastColumnToFit()
    }

    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cell")
        let cell: NSTableCellView
        if let e = tableView.makeView(withIdentifier: id, owner: nil) as? NSTableCellView {
            cell = e
        } else {
            cell = NSTableCellView()
            cell.identifier = id
            let tf = NSTextField(labelWithString: "")
            tf.font = WinFont.ui()
            tf.isBezeled = false
            tf.drawsBackground = false
            tf.lineBreakMode = .byTruncatingTail
            tf.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(tf)
            cell.textField = tf
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
                tf.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
                tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }
        cell.textField?.stringValue = items[row]
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        onSelect?(table.selectedRow)
    }

    @objc private func dbl() {
        if table.clickedRow >= 0 { onActivate?(table.clickedRow) }
    }
}

struct WinTreeNode {
    var id: String
    var key: String
    var children: [WinTreeNode] = []
    var expanded = true
}

final class WinTreeView: NSView, NSOutlineViewDataSource, NSOutlineViewDelegate {
    private final class Item: NSObject {
        let id: String
        let key: String
        let children: [Item]
        init(node: WinTreeNode) {
            id = node.id
            key = node.key
            children = node.children.map { Item(node: $0) }
        }
    }

    private var roots: [Item] = []
    private let outline = NSOutlineView()
    private let scroll = NSScrollView()
    private var suppressSelect = false
    var onSelect: ((String) -> Void)?
    var selectedId: String = "session"

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.backgroundColor = .clear
        outline.headerView = nil
        outline.rowHeight = 24
        outline.style = .sourceList
        outline.backgroundColor = .clear
        outline.focusRingType = .none
        outline.allowsEmptySelection = false
        outline.indentationPerLevel = 13
        outline.autoresizesOutlineColumn = false
        outline.floatsGroupRows = false
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("c"))
        col.resizingMask = .autoresizingMask
        outline.addTableColumn(col)
        outline.outlineTableColumn = col
        outline.dataSource = self
        outline.delegate = self
        scroll.documentView = outline
        addSubview(scroll)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        scroll.frame = bounds
    }

    func setRoot(_ nodes: [WinTreeNode]) {
        roots = nodes.map { Item(node: $0) }
        suppressSelect = true
        outline.reloadData()
        outline.expandItem(nil, expandChildren: true)
        selectId(selectedId)
        suppressSelect = false
    }

    func reloadTexts() {
        suppressSelect = true
        outline.reloadData()
        outline.expandItem(nil, expandChildren: true)
        selectId(selectedId)
        suppressSelect = false
    }

    private func find(_ id: String, in items: [Item]) -> Item? {
        for it in items {
            if it.id == id { return it }
            if let x = find(id, in: it.children) { return x }
        }
        return nil
    }

    private func selectId(_ id: String) {
        if let it = find(id, in: roots) {
            let row = outline.row(forItem: it)
            if row >= 0 {
                outline.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                outline.scrollRowToVisible(row)
            }
        } else if outline.numberOfRows > 0 {
            outline.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let item = item as? Item { return item.children.count }
        return roots.count
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let item = item as? Item else { return false }
        return !item.children.isEmpty
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let item = item as? Item { return item.children[index] }
        return roots[index]
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let item = item as? Item else { return nil }
        let id = NSUserInterfaceItemIdentifier("tree")
        let cell: NSTableCellView
        if let e = outlineView.makeView(withIdentifier: id, owner: nil) as? NSTableCellView {
            cell = e
        } else {
            cell = NSTableCellView()
            cell.identifier = id
            let tf = NSTextField(labelWithString: "")
            tf.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
            tf.isBezeled = false
            tf.drawsBackground = false
            tf.lineBreakMode = .byTruncatingTail
            tf.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(tf)
            cell.textField = tf
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                tf.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
                tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }
        cell.textField?.stringValue = L.t(item.key)
        return cell
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard !suppressSelect else { return }
        let row = outline.selectedRow
        guard row >= 0, let item = outline.item(atRow: row) as? Item else { return }
        if item.id == selectedId { return }
        selectedId = item.id
        onSelect?(selectedId)
    }
}

final class WinComboBox: NSPopUpButton, LocalizableUI {
    var items: [(id: String, key: String)] = [] {
        didSet { reloadTexts() }
    }
    var onChange: ((Int) -> Void)?
    private var index = 0

    var selectedIndex: Int {
        get { max(0, indexOfSelectedItem) }
        set {
            index = newValue
            if numberOfItems > 0 {
                selectItem(at: min(max(0, newValue), numberOfItems - 1))
            }
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect, pullsDown: false)
        controlSize = .small
        font = WinFont.ui()
        bezelStyle = .rounded
        target = self
        action = #selector(changed)
    }

    required init?(coder: NSCoder) { fatalError() }

    func reloadTexts() {
        let keep = indexOfSelectedItem >= 0 ? indexOfSelectedItem : index
        removeAllItems()
        for it in items {
            addItem(withTitle: L.t(it.key))
        }
        if !items.isEmpty {
            selectItem(at: min(max(0, keep), items.count - 1))
        }
        index = max(0, indexOfSelectedItem)
    }

    @objc private func changed() {
        index = indexOfSelectedItem
        onChange?(index)
    }
}

final class WinSpinner: NSView, NSTextFieldDelegate {
    let field = WinTextField(frame: .zero)
    private let stepper = NSStepper()
    var onChange: ((Int) -> Void)?
    var range: ClosedRange<Int> = 0...99999 {
        didSet { applyRange() }
    }

    var value: Int {
        get { Int(field.stringValue) ?? stepper.integerValue }
        set {
            let n = min(range.upperBound, max(range.lowerBound, newValue))
            field.stringValue = String(n)
            stepper.integerValue = n
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        stepper.valueWraps = false
        stepper.controlSize = .small
        stepper.target = self
        stepper.action = #selector(stepped)
        field.bezelStyle = .squareBezel
        addSubview(field)
        addSubview(stepper)
        field.delegate = self
        applyRange()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let sw: CGFloat = 19
        stepper.frame = NSRect(x: bounds.width - sw, y: 0, width: sw, height: bounds.height)
        field.frame = NSRect(x: 0, y: 0, width: max(0, bounds.width - sw - 2), height: bounds.height)
    }

    private func applyRange() {
        stepper.minValue = Double(range.lowerBound)
        stepper.maxValue = Double(range.upperBound)
        stepper.increment = 1
        value = value
    }

    @objc private func stepped() {
        value = stepper.integerValue
        onChange?(value)
    }

    func controlTextDidChange(_ obj: Notification) {
        stepper.integerValue = value
        onChange?(value)
    }
}

final class WinColorSwatch: NSView {
    var color: RGB8 = RGB8(r: 0, g: 0, b: 0) {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.masksToBounds = true
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    override func draw(_ dirtyRect: NSRect) {
        color.nsColor.setFill()
        bounds.fill()
        NSColor.separatorColor.setStroke()
        let p = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
        p.lineWidth = 1
        p.stroke()
    }
}

class DialogFaceView: NSView {
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class WinChromeWindow: NSWindow {
    var onHelp: (() -> Void)?
    var titleKey: String = "win.title"

    convenience init(contentSize: NSSize) {
        self.init(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        backgroundColor = .windowBackgroundColor
        titlebarSeparatorStyle = .line
        toolbarStyle = .preference
        title = L.t(titleKey)
        tabbingMode = .disallowed
        standardWindowButton(.zoomButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isEnabled = false
        let client = DialogFaceView(frame: NSRect(origin: .zero, size: contentSize))
        client.autoresizingMask = [.width, .height]
        contentView = client
    }

    var clientView: NSView { contentView! }

    func setTitleKey(_ key: String) {
        titleKey = key
        title = L.t(key)
    }
}
