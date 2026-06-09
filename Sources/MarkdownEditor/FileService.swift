import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum FileService {
    static var markdownTypes: [UTType] {
        var types: [UTType] = [.plainText]
        if let md = UTType(filenameExtension: "md") { types.insert(md, at: 0) }
        if let markdown = UTType("net.daringfireball.markdown") { types.insert(markdown, at: 0) }
        return types
    }

    static func openPanel(into workspace: Workspace) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = markdownTypes
        if panel.runModal() == .OK {
            for url in panel.urls { workspace.open(url: url) }
        }
    }

    @discardableResult
    static func save(_ doc: MarkdownDocument?, in workspace: Workspace) -> Bool {
        guard let doc else { return false }
        if let url = doc.url {
            return write(doc, to: url)
        }
        return saveAs(doc, in: workspace)
    }

    @discardableResult
    static func saveAs(_ doc: MarkdownDocument?, in workspace: Workspace) -> Bool {
        guard let doc else { return false }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = doc.url?.lastPathComponent ?? "Untitled.md"
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        let ok = write(doc, to: url)
        if ok { doc.url = url }
        return ok
    }

    private static func write(_ doc: MarkdownDocument, to url: URL) -> Bool {
        do {
            try doc.text.write(to: url, atomically: true, encoding: .utf8)
            doc.isDirty = false
            return true
        } catch {
            NSAlert(error: error).runModal()
            return false
        }
    }

    static func closeWithPrompt(_ doc: MarkdownDocument, in workspace: Workspace) {
        if doc.isDirty {
            let alert = NSAlert()
            alert.messageText = "Save changes to “\(doc.title)” before closing?"
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Don't Save")
            alert.addButton(withTitle: "Cancel")
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                if !save(doc, in: workspace) { return }
            case .alertThirdButtonReturn:
                return
            default:
                break
            }
        }
        workspace.close(doc)
    }

    // MARK: Export

    static func exportPDF(_ controller: PreviewController, doc: MarkdownDocument?) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = (doc?.title as NSString?)?.deletingPathExtension.appending(".pdf") ?? "Document.pdf"
        if panel.runModal() == .OK, let url = panel.url {
            controller.exportPDF(to: url)
        }
    }

    static func exportHTML(_ controller: PreviewController, doc: MarkdownDocument?) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = (doc?.title as NSString?)?.deletingPathExtension.appending(".html") ?? "Document.html"
        if panel.runModal() == .OK, let url = panel.url {
            controller.renderedHTML { html in
                try? html.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}

// MARK: - Focused scene values (let menu commands reach the active window)

private struct WorkspaceKey: FocusedValueKey { typealias Value = Workspace }
private struct PreviewKey: FocusedValueKey { typealias Value = PreviewController }

extension FocusedValues {
    var workspace: Workspace? {
        get { self[WorkspaceKey.self] }
        set { self[WorkspaceKey.self] = newValue }
    }
    var preview: PreviewController? {
        get { self[PreviewKey.self] }
        set { self[PreviewKey.self] = newValue }
    }
}
