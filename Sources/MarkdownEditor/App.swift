import SwiftUI
import AppKit

/// Single shared workspace so file-open events (Open With / drag onto icon)
/// and menu commands all act on the same set of tabs.
let sharedWorkspace = Workspace()

@main
struct MarkdownEditorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @FocusedValue(\.workspace) private var focusedWorkspace
    @FocusedValue(\.preview) private var focusedPreview

    var body: some Scene {
        WindowGroup {
            RootView(workspace: sharedWorkspace)
                .onAppear {
                    // Defer so any launch file-open events populate tabs first.
                    DispatchQueue.main.async {
                        if sharedWorkspace.documents.isEmpty { sharedWorkspace.newDocument() }
                    }
                }
        }
        .commands { commands }
    }

    @CommandsBuilder
    private var commands: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New") { sharedWorkspace.newDocument() }
                .keyboardShortcut("n")
            Button("New Tab") { sharedWorkspace.newDocument() }
                .keyboardShortcut("t")
            Button("Open…") { FileService.openPanel(into: sharedWorkspace) }
                .keyboardShortcut("o")
        }
        CommandGroup(replacing: .saveItem) {
            Button("Save") { FileService.save(sharedWorkspace.selected, in: sharedWorkspace) }
                .keyboardShortcut("s")
                .disabled(sharedWorkspace.selected == nil)
            Button("Save As…") { FileService.saveAs(sharedWorkspace.selected, in: sharedWorkspace) }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(sharedWorkspace.selected == nil)

            Divider()
            Menu("Export") {
                Button("Export as HTML…") {
                    if let p = focusedPreview { FileService.exportHTML(p, doc: sharedWorkspace.selected) }
                }
                Button("Export as PDF…") {
                    if let p = focusedPreview { FileService.exportPDF(p, doc: sharedWorkspace.selected) }
                }
            }
            .disabled(sharedWorkspace.selected == nil)

            Divider()
            Button("Close Tab") {
                if let doc = sharedWorkspace.selected {
                    FileService.closeWithPrompt(doc, in: sharedWorkspace)
                }
            }
            .keyboardShortcut("w")
            .disabled(sharedWorkspace.selected == nil)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// Called when the user double-clicks a .md file or chooses "Open With".
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { sharedWorkspace.open(url: url) }
        NSApp.activate(ignoringOtherApps: true)
    }
}
