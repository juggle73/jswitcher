import AppKit
import JswitcherCore
import UniformTypeIdentifiers

/// Settings window: the list of excluded apps with "add app…", "add running app" and "remove".
@MainActor
final class ExclusionsWindow: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private var list: ExclusionList
    private let onChange: (ExclusionList) -> Void

    private var window: NSWindow?
    private let table = NSTableView()
    private let removeButton = NSButton(title: "−", target: nil, action: nil)

    init(list: ExclusionList, onChange: @escaping (ExclusionList) -> Void) {
        self.list = list
        self.onChange = onChange
        super.init()
    }

    func show() {
        if window == nil { window = makeWindow() }
        table.reloadData()
        updateButtons()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Layout

    private func makeWindow() -> NSWindow {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 380),
                         styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        w.title = "Исключения jswitcher"
        w.isReleasedWhenClosed = false
        w.minSize = NSSize(width: 360, height: 260)
        w.center()

        let hint = NSTextField(wrappingLabelWithString:
            "В этих программах слова не исправляются автоматически. Левый Control работает как обычно.")
        hint.textColor = .secondaryLabelColor

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = 36
        table.dataSource = self
        table.delegate = self
        table.allowsMultipleSelection = true
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        let addApp = NSButton(title: "Добавить приложение…", target: self, action: #selector(addFromFile))
        let addRunning = NSButton(title: "Из запущенных ▾", target: self, action: #selector(addFromRunning(_:)))
        removeButton.target = self
        removeButton.action = #selector(removeSelected)
        let buttons = NSStackView(views: [addApp, addRunning, NSView(), removeButton])
        buttons.orientation = .horizontal

        let stack = NSStackView(views: [hint, scroll, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        w.contentView = NSView()
        w.contentView?.addSubview(stack)
        if let content = w.contentView {
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
                stack.topAnchor.constraint(equalTo: content.topAnchor),
                stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
                scroll.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32),
                buttons.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32),
                hint.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -32),
            ])
        }
        return w
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int { list.bundleIDs.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = list.bundleIDs[row]
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
        let name = url.map { $0.deletingPathExtension().lastPathComponent }
        let cell = NSTableCellView()
        let icon = NSImageView(image: url.map { NSWorkspace.shared.icon(forFile: $0.path) }
            ?? NSImage(systemSymbolName: "questionmark.app", accessibilityDescription: nil) ?? NSImage())
        icon.imageScaling = .scaleProportionallyUpOrDown
        let title = NSTextField(labelWithString: name ?? id)
        let subtitle = NSTextField(labelWithString: name == nil ? "не установлено" : id)
        subtitle.textColor = .secondaryLabelColor
        subtitle.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        let text = NSStackView(views: [title, subtitle])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 0
        let row = NSStackView(views: [icon, text])
        row.orientation = .horizontal
        row.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(row)
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 28), icon.heightAnchor.constraint(equalToConstant: 28),
            row.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            row.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) { updateButtons() }

    private func updateButtons() {
        removeButton.isEnabled = !table.selectedRowIndexes.isEmpty
    }

    // MARK: - Actions

    @objc private func addFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Добавить"
        guard let window else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK else { return }
            let ids = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
            MainActor.assumeIsolated { self?.add(ids) }
        }
    }

    @objc private func addFromRunning(_ sender: NSButton) {
        let menu = NSMenu()
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .filter { !list.contains($0.bundleIdentifier) && $0.bundleIdentifier != nil }
            .sorted { ($0.localizedName ?? "").localizedCaseInsensitiveCompare($1.localizedName ?? "") == .orderedAscending }
        for app in apps {
            let item = NSMenuItem(title: app.localizedName ?? app.bundleIdentifier ?? "?", action: #selector(addRunningItem(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = app.bundleIdentifier
            if let icon = app.icon {
                icon.size = NSSize(width: 16, height: 16)
                item.image = icon
            }
            menu.addItem(item)
        }
        if apps.isEmpty {
            menu.addItem(NSMenuItem(title: "Все запущенные программы уже в списке", action: nil, keyEquivalent: ""))
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
    }

    @objc private func addRunningItem(_ item: NSMenuItem) {
        if let id = item.representedObject as? String { add([id]) }
    }

    @objc private func removeSelected() {
        let ids = table.selectedRowIndexes.map { list.bundleIDs[$0] }
        ids.forEach { list.remove($0) }
        changed()
    }

    private func add(_ ids: [String]) {
        var any = false
        for id in ids where list.add(id) { any = true }
        if any { changed() }
    }

    private func changed() {
        table.reloadData()
        table.deselectAll(nil)
        updateButtons()
        onChange(list)
    }
}
