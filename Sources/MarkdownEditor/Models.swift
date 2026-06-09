import SwiftUI
import Combine

/// A single open markdown document (one tab).
final class MarkdownDocument: ObservableObject, Identifiable {
    let id = UUID()
    @Published var text: String {
        didSet { if text != oldValue { isDirty = true } }
    }
    @Published var url: URL?
    @Published var isDirty: Bool = false

    init(text: String = "", url: URL? = nil) {
        self.text = text
        self.url = url
    }

    var title: String {
        url?.lastPathComponent ?? "Untitled"
    }

    var displayTitle: String {
        (isDirty ? "• " : "") + title
    }
}

enum ViewMode: String, CaseIterable {
    case editor, split, preview

    var symbol: String {
        switch self {
        case .editor: return "doc.plaintext"
        case .split: return "rectangle.split.2x1"
        case .preview: return "eye"
        }
    }
    var label: String { rawValue.capitalized }
}

enum AppTheme: String, CaseIterable {
    case system, light, dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    var label: String { rawValue.capitalized }
}

/// Holds all open documents and global UI state for a window.
final class Workspace: ObservableObject {
    @Published var documents: [MarkdownDocument] = []
    @Published var selectedID: UUID?
    @Published var viewMode: ViewMode = .split
    @Published var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "theme") }
    }
    @Published var showFindBar: Bool = false

    init() {
        let saved = UserDefaults.standard.string(forKey: "theme") ?? AppTheme.system.rawValue
        self.theme = AppTheme(rawValue: saved) ?? .system
    }

    var selected: MarkdownDocument? {
        documents.first { $0.id == selectedID }
    }

    var isPreviewDark: Bool {
        switch theme {
        case .light: return false
        case .dark: return true
        case .system:
            return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
    }

    @discardableResult
    func newDocument() -> MarkdownDocument {
        let doc = MarkdownDocument(text: "")
        documents.append(doc)
        selectedID = doc.id
        return doc
    }

    func open(url: URL) {
        // Focus an already-open tab for the same file.
        if let existing = documents.first(where: { $0.url == url }) {
            selectedID = existing.id
            return
        }
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let doc = MarkdownDocument(text: text, url: url)
        doc.isDirty = false
        documents.append(doc)
        selectedID = doc.id
    }

    func close(_ doc: MarkdownDocument) {
        guard let idx = documents.firstIndex(where: { $0.id == doc.id }) else { return }
        documents.remove(at: idx)
        if selectedID == doc.id {
            selectedID = documents[safe: idx]?.id ?? documents.last?.id
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
