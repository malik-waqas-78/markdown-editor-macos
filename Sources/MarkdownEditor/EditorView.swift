import SwiftUI
import AppKit

/// SwiftUI wrapper around an NSTextView that edits plain markdown text
/// and applies lightweight syntax highlighting as you type.
struct EditorView: NSViewRepresentable {
    @ObservedObject var document: MarkdownDocument
    var isDark: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        let textView = scroll.documentView as! NSTextView
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = Coordinator.bodyFont
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.string = document.text
        context.coordinator.textView = textView
        context.coordinator.apply(theme: isDark, to: textView)
        context.coordinator.highlight(textView)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? NSTextView else { return }
        // Sync external text changes (e.g. opening a file into this tab).
        if textView.string != document.text {
            let sel = textView.selectedRange()
            textView.string = document.text
            textView.setSelectedRange(NSRange(location: min(sel.location, document.text.count), length: 0))
            context.coordinator.highlight(textView)
        }
        context.coordinator.apply(theme: isDark, to: textView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let parent: EditorView
        weak var textView: NSTextView?

        static let bodyFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)

        init(_ parent: EditorView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.document.text = tv.string
            highlight(tv)
        }

        func apply(theme dark: Bool, to tv: NSTextView) {
            tv.backgroundColor = dark ? NSColor(white: 0.12, alpha: 1) : NSColor(white: 1.0, alpha: 1)
            tv.insertionPointColor = dark ? .white : .black
            highlight(tv)
        }

        // MARK: Syntax highlighting

        private func color(_ light: NSColor, _ dark: NSColor) -> NSColor {
            parent.isDark ? dark : light
        }

        func highlight(_ tv: NSTextView) {
            guard let storage = tv.textStorage else { return }
            let text = tv.string
            let full = NSRange(location: 0, length: (text as NSString).length)
            let base = parent.isDark ? NSColor(white: 0.88, alpha: 1) : NSColor(white: 0.1, alpha: 1)

            storage.beginEditing()
            storage.setAttributes([.font: Self.bodyFont, .foregroundColor: base], range: full)

            let ns = text as NSString
            for rule in Self.rules {
                rule.regex.enumerateMatches(in: text, range: full) { match, _, _ in
                    guard let m = match else { return }
                    let range = rule.captureGroup >= 0 && m.numberOfRanges > rule.captureGroup
                        ? m.range(at: rule.captureGroup) : m.range
                    guard range.location != NSNotFound, range.length > 0 else { return }
                    var attrs: [NSAttributedString.Key: Any] = [
                        .foregroundColor: rule.color(self.parent.isDark)
                    ]
                    if let font = rule.font(ns.substring(with: range)) { attrs[.font] = font }
                    storage.addAttributes(attrs, range: range)
                }
            }
            storage.endEditing()
        }

        struct Rule {
            let regex: NSRegularExpression
            let captureGroup: Int
            let color: (Bool) -> NSColor
            let font: (String) -> NSFont?

            init(_ pattern: String, options: NSRegularExpression.Options = [.anchorsMatchLines],
                 group: Int = -1,
                 color: @escaping (Bool) -> NSColor,
                 font: @escaping (String) -> NSFont? = { _ in nil }) {
                self.regex = try! NSRegularExpression(pattern: pattern, options: options)
                self.captureGroup = group
                self.color = color
                self.font = font
            }
        }

        static let rules: [Rule] = {
            let heading = Rule("^#{1,6}\\s.*$",
                color: { $0 ? NSColor(red: 0.45, green: 0.72, blue: 1, alpha: 1)
                             : NSColor(red: 0.0, green: 0.32, blue: 0.78, alpha: 1) },
                font: { _ in NSFont.monospacedSystemFont(ofSize: 16, weight: .bold) })
            let bold = Rule("(\\*\\*|__)(?=\\S)(.+?)(?<=\\S)\\1",
                color: { $0 ? NSColor(white: 0.95, alpha: 1) : NSColor(white: 0.05, alpha: 1) },
                font: { _ in NSFont.monospacedSystemFont(ofSize: 14, weight: .bold) })
            let italic = Rule("(?<![\\*_])([\\*_])(?=\\S)(.+?)(?<=\\S)\\1(?![\\*_])",
                color: { _ in NSColor.systemTeal },
                font: { _ in NSFontManager.shared.convert(bodyFont, toHaveTrait: .italicFontMask) })
            let code = Rule("`[^`\\n]+`",
                color: { _ in NSColor.systemPink })
            let fence = Rule("^```[\\s\\S]*?^```",
                options: [.anchorsMatchLines],
                color: { $0 ? NSColor(white: 0.6, alpha: 1) : NSColor(white: 0.4, alpha: 1) })
            let link = Rule("\\[[^\\]]+\\]\\([^\\)]+\\)",
                color: { _ in NSColor.systemBlue })
            let quote = Rule("^>\\s.*$",
                color: { _ in NSColor.systemGreen })
            let listMarker = Rule("^\\s*([-\\*\\+]|\\d+\\.)\\s", group: 1,
                color: { _ in NSColor.systemOrange },
                font: { _ in NSFont.monospacedSystemFont(ofSize: 14, weight: .bold) })
            let rule = Rule("^(---|\\*\\*\\*|___)\\s*$",
                color: { _ in NSColor.systemGray })
            return [fence, heading, quote, listMarker, rule, bold, italic, code, link]
        }()
    }
}
