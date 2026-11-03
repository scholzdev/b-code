//
//  BCSymbols.swift
//  BCSymbols
//

import SwiftUI
import AppKit

/// The icons b-code uses that Apple's SF Symbols do not provide under a name of their own.
///
/// Each of them is currently drawn with an SF Symbol stand-in, so this package ships no artwork. To give one of them
/// its own artwork later, add a symbol set to the package's asset catalog and look it up in ``image(named:)`` before
/// falling back to ``standIns``.
public enum BCSymbols {
    /// The names the app asks for and the SF Symbol that stands in for each of them.
    public static let standIns: [String: String] = [
        "branch": "arrow.triangle.branch",
        "checkout": "arrow.triangle.swap",
        "commit": "circle.circle",
        "vault": "archivebox",
        "vault.fill": "archivebox.fill",
        "breakpoint": "diamond",
        "breakpoint.fill": "diamond.fill",
        "chevron.up.chevron.down": "chevron.up.chevron.down",
        "github": "link.circle",
        "doc.java": "doc.text",
        "doc.javascript": "chevron.left.forwardslash.chevron.right",
        "doc.json": "curlybraces",
        "doc.python": "chevron.left.forwardslash.chevron.right",
        "doc.ruby": "doc.text",
        "square.split.horizontal.plus": "rectangle.split.2x1",
        "square.split.vertical.plus": "rectangle.split.1x2"
    ]

    /// Whether b-code defines an icon with this name.
    /// - Parameter name: The icon name, e.g. `branch`.
    public static func contains(_ name: String) -> Bool {
        standIns[name] != nil
    }

    /// The icon with the given name as an `NSImage`.
    /// - Parameter name: The icon name, e.g. `branch`.
    /// - Returns: The image, or `nil` if b-code defines no icon with that name. Names that are plain SF Symbols
    ///   are not defined here, so callers can use `nil` to fall back to the system symbol.
    public static func image(named name: String) -> NSImage? {
        guard let systemName = standIns[name] else {
            return nil
        }
        return NSImage(systemSymbolName: systemName, accessibilityDescription: nil)
    }
}

public extension Image {
    /// Creates an image for a b-code icon.
    /// - Parameter symbol: The icon name, e.g. `branch`. A name b-code does not define is looked up as an SF Symbol.
    init(symbol: String) {
        self.init(systemName: BCSymbols.standIns[symbol] ?? symbol)
    }

    /// The `vault` icon (a repository).
    static let vault: Image = .init(symbol: "vault")
    /// The filled `vault` icon.
    static let vaultFill: Image = .init(symbol: "vault.fill")
    /// The `commit` icon.
    static let commit: Image = .init(symbol: "commit")
    /// The `checkout` icon.
    static let checkout: Image = .init(symbol: "checkout")
    /// The `branch` icon.
    static let branch: Image = .init(symbol: "branch")
    /// The `breakpoint` icon.
    static let breakpoint: Image = .init(symbol: "breakpoint")
    /// The filled `breakpoint` icon.
    static let breakpointFill: Image = .init(symbol: "breakpoint.fill")
    /// The up-and-down chevron icon.
    static let chevronUpChevronDown: Image = .init(symbol: "chevron.up.chevron.down")
    /// The GitHub icon.
    static let github: Image = .init(symbol: "github")
    /// The Java file icon.
    static let docJava: Image = .init(symbol: "doc.java")
    /// The JavaScript file icon.
    static let docJavascript: Image = .init(symbol: "doc.javascript")
    /// The JSON file icon.
    static let docJson: Image = .init(symbol: "doc.json")
    /// The Python file icon.
    static let docPython: Image = .init(symbol: "doc.python")
    /// The Ruby file icon.
    static let docRuby: Image = .init(symbol: "doc.ruby")
    /// The icon for splitting the editor horizontally.
    static let squareSplitHorizontalPlus: Image = .init(symbol: "square.split.horizontal.plus")
    /// The icon for splitting the editor vertically.
    static let squareSplitVerticalPlus: Image = .init(symbol: "square.split.vertical.plus")
}

public extension NSImage {
    /// Returns the b-code icon with the given name.
    /// - Parameter named: The icon name, e.g. `branch`.
    /// - Returns: The image, or `nil` if b-code defines no icon with that name.
    static func symbol(named: String) -> NSImage? {
        BCSymbols.image(named: named)
    }

    /// The `vault` icon (a repository).
    static let vault: NSImage? = .symbol(named: "vault")
    /// The filled `vault` icon.
    static let vaultFill: NSImage? = .symbol(named: "vault.fill")
    /// The `commit` icon.
    static let commit: NSImage? = .symbol(named: "commit")
    /// The `checkout` icon.
    static let checkout: NSImage? = .symbol(named: "checkout")
    /// The `branch` icon.
    static let branch: NSImage? = .symbol(named: "branch")
    /// The `breakpoint` icon.
    static let breakpoint: NSImage? = .symbol(named: "breakpoint")
    /// The filled `breakpoint` icon.
    static let breakpointFill: NSImage? = .symbol(named: "breakpoint.fill")
    /// The up-and-down chevron icon.
    static let chevronUpChevronDown: NSImage? = .symbol(named: "chevron.up.chevron.down")
    /// The GitHub icon.
    static let github: NSImage? = .symbol(named: "github")
    /// The Java file icon.
    static let docJava: NSImage? = .symbol(named: "doc.java")
    /// The JavaScript file icon.
    static let docJavascript: NSImage? = .symbol(named: "doc.javascript")
    /// The JSON file icon.
    static let docJson: NSImage? = .symbol(named: "doc.json")
    /// The Python file icon.
    static let docPython: NSImage? = .symbol(named: "doc.python")
    /// The Ruby file icon.
    static let docRuby: NSImage? = .symbol(named: "doc.ruby")
    /// The icon for splitting the editor horizontally.
    static let squareSplitHorizontalPlus: NSImage? = .symbol(named: "square.split.horizontal.plus")
    /// The icon for splitting the editor vertically.
    static let squareSplitVerticalPlus: NSImage? = .symbol(named: "square.split.vertical.plus")
}
