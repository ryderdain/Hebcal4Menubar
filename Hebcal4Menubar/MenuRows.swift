//
//  MenuRows.swift
//  Hebcal4Menubar
//
//  Menu rows that the app draws itself, for informational lines.
//
//  A native NSMenuItem without an action is disabled, and macOS draws it in
//  the faint disabled color. It ignores a foreground color in the item's
//  attributedTitle (tested on macOS 27). A custom view has full contrast, no
//  hover highlight, and a click does not close the menu.
//

import AppKit

/// The view of an informational row: one line of text, aligned with the
/// titles of the native items.
final class InfoRowView: NSView {
    static let height: CGFloat = 24   // native item height on macOS 27
    /// Space after the text, like the native items.
    private static let trailing: CGFloat = 14

    /// Leading inset that aligns the text with native item titles. Measured on
    /// macOS 27: 14 pt, or 27 pt when the menu shows a state (check mark)
    /// column, which it does when an item has a state other than off.
    static func inset(for menu: NSMenu) -> CGFloat {
        menu.items.contains { $0.state != .off } ? 27 : 14
    }

    private let label = NSTextField(labelWithString: "")

    var inset: CGFloat = 14 { didSet { if inset != oldValue { resize() } } }

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 100, height: Self.height))
        autoresizingMask = [.width]
        label.lineBreakMode = .byClipping
        label.maximumNumberOfLines = 1
        label.textColor = .labelColor
        label.font = .menuFont(ofSize: 0)
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func set(_ text: NSAttributedString) {
        label.attributedStringValue = text
        resize()
    }

    private func resize() {
        label.sizeToFit()
        label.frame.origin = NSPoint(x: inset, y: ((Self.height - label.frame.height) / 2).rounded())
        setFrameSize(NSSize(width: ceil(label.frame.width + inset + Self.trailing), height: Self.height))
    }
}

/// A menu item whose title is drawn by an `InfoRowView`. Setting `title`
/// shows plain text; `attributedText` shows styled text (tabs, weights).
final class InfoMenuItem: NSMenuItem {
    let row = InfoRowView()

    /// Menu font with monospaced digits, so that times line up.
    static let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuFont(ofSize: 0).pointSize, weight: .regular)
    static let boldFont = NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuFont(ofSize: 0).pointSize, weight: .semibold)

    init(_ text: String = "") {
        super.init(title: text, action: nil, keyEquivalent: "")
        view = row
        row.set(NSAttributedString(string: text, attributes: Self.attributes()))
    }

    required init(coder: NSCoder) { fatalError("not used") }

    override var title: String {
        didSet { row.set(NSAttributedString(string: title, attributes: Self.attributes())) }
    }

    var attributedText: NSAttributedString {
        get { row.subviews.compactMap { ($0 as? NSTextField)?.attributedStringValue }.first ?? NSAttributedString() }
        set {
            super.title = newValue.string
            row.set(newValue)
        }
    }

    static func attributes(bold: Bool = false, color: NSColor = .labelColor,
                           tabStop: CGFloat? = nil) -> [NSAttributedString.Key: Any] {
        var a: [NSAttributedString.Key: Any] = [.font: bold ? boldFont : font, .foregroundColor: color]
        if let tabStop {
            let p = NSMutableParagraphStyle()
            p.tabStops = [NSTextTab(textAlignment: .left, location: tabStop)]
            a[.paragraphStyle] = p
        }
        return a
    }

    /// Align every informational row in `menu` with its native items.
    static func align(in menu: NSMenu) {
        let inset = InfoRowView.inset(for: menu)
        for case let item as InfoMenuItem in menu.items { item.row.inset = inset }
    }
}
