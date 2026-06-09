import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct RootView: View {
    @ObservedObject var workspace: Workspace
    @StateObject private var preview = PreviewController()

    var body: some View {
        VStack(spacing: 0) {
            TabBar(workspace: workspace)
            Divider()
            if let doc = workspace.selected {
                EditorArea(workspace: workspace, document: doc, preview: preview)
            } else {
                EmptyState(workspace: workspace)
            }
        }
        .frame(minWidth: 760, minHeight: 480)
        .preferredColorScheme(workspace.theme.colorScheme)
        .toolbar { toolbarContent }
        .focusedSceneValue(\.workspace, workspace)
        .focusedSceneValue(\.preview, preview)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            Picker("View", selection: $workspace.viewMode) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Image(systemName: mode.symbol).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .help("Editor / Split / Preview")

            Spacer()

            Picker("Theme", selection: $workspace.theme) {
                ForEach(AppTheme.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .frame(width: 110)
            .help("Appearance")

            Button { FileService.save(workspace.selected, in: workspace) } label: {
                Image(systemName: "square.and.arrow.down")
            }
            .help("Save (⌘S)")
            .disabled(workspace.selected == nil)

            Menu {
                Button("Export as HTML…") { FileService.exportHTML(preview, doc: workspace.selected) }
                Button("Export as PDF…") { FileService.exportPDF(preview, doc: workspace.selected) }
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .menuIndicator(.hidden)
            .help("Export")
            .disabled(workspace.selected == nil)
        }
    }
}

// MARK: - Editor + Preview area

struct EditorArea: View {
    @ObservedObject var workspace: Workspace
    @ObservedObject var document: MarkdownDocument
    var preview: PreviewController

    var body: some View {
        Group {
            switch workspace.viewMode {
            case .editor:
                EditorView(document: document, isDark: workspace.isPreviewDark)
            case .preview:
                PreviewView(document: document, isDark: workspace.isPreviewDark, controller: preview)
            case .split:
                HStack(spacing: 0) {
                    EditorView(document: document, isDark: workspace.isPreviewDark)
                    Divider()
                    PreviewView(document: document, isDark: workspace.isPreviewDark, controller: preview)
                }
            }
        }
        .id(document.id)
    }
}

// MARK: - Tab bar

struct TabBar: View {
    @ObservedObject var workspace: Workspace

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(workspace.documents) { doc in
                    TabChip(doc: doc, workspace: workspace)
                }
                Button { workspace.newDocument() } label: {
                    Image(systemName: "plus")
                        .frame(width: 30, height: 28)
                }
                .buttonStyle(.plain)
                .help("New tab (⌘T)")
            }
        }
        .frame(height: 30)
        .background(.bar)
    }
}

struct TabChip: View {
    @ObservedObject var doc: MarkdownDocument
    @ObservedObject var workspace: Workspace
    @State private var hovering = false

    var isSelected: Bool { workspace.selectedID == doc.id }

    var body: some View {
        HStack(spacing: 6) {
            Text(doc.displayTitle)
                .lineLimit(1)
                .font(.system(size: 12))
            Button {
                FileService.closeWithPrompt(doc, in: workspace)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .opacity(hovering || isSelected ? 0.7 : 0)
            }
            .buttonStyle(.plain)
            .frame(width: 12)
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
        .overlay(alignment: .trailing) { Divider() }
        .contentShape(Rectangle())
        .onTapGesture { workspace.selectedID = doc.id }
        .onHover { hovering = $0 }
    }
}

// MARK: - Empty state

struct EmptyState: View {
    @ObservedObject var workspace: Workspace

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("No document open")
                .font(.title2).foregroundStyle(.secondary)
            HStack {
                Button("New Document") { workspace.newDocument() }
                Button("Open…") { FileService.openPanel(into: workspace) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}
