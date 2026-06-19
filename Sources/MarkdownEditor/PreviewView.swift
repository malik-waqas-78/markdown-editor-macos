import SwiftUI
import WebKit
import AppKit
import PDFKit

/// Renders markdown to HTML in a WKWebView using the bundled marked + highlight.js.
struct PreviewView: NSViewRepresentable {
    @ObservedObject var document: MarkdownDocument
    var isDark: Bool
    /// Shared controller so other UI (export) can reach the live web view.
    var controller: PreviewController

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let web = WKWebView(frame: .zero, configuration: config)
        web.setValue(false, forKey: "drawsBackground")
        web.navigationDelegate = context.coordinator
        controller.webView = web

        if let dir = Self.webResourceDirectory() {
            let index = dir.appendingPathComponent("index.html")
            web.loadFileURL(index, allowingReadAccessTo: dir)
        }
        return web
    }

    /// Locate the bundled `web` resources without using `Bundle.module`,
    /// whose generated accessor calls `fatalError` when the bundle is missing.
    static func webResourceDirectory() -> URL? {
        // 1. Installed .app: web/ copied directly into Contents/Resources/.
        if let dir = Bundle.main.url(forResource: "web", withExtension: nil) {
            return dir
        }
        // 2. SwiftPM resource bundle (e.g. `swift run`): web/ inside the .bundle.
        if let bundleURL = Bundle.main.url(forResource: "MarkdownEditor_MarkdownEditor",
                                           withExtension: "bundle"),
           let bundle = Bundle(url: bundleURL),
           let dir = bundle.url(forResource: "web", withExtension: nil) {
            return dir
        }
        return nil
    }

    func updateNSView(_ web: WKWebView, context: Context) {
        context.coordinator.pending = (document.text, isDark)
        context.coordinator.flushIfReady(web)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loaded = false
        var pending: (String, Bool)?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loaded = true
            flushIfReady(webView)
        }

        /// Open clicked links in the default browser instead of navigating the preview.
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url,
               url.scheme == "http" || url.scheme == "https" || url.scheme == "mailto" {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func flushIfReady(_ web: WKWebView) {
            guard loaded, let (md, dark) = pending else { return }
            pending = nil
            guard let data = try? JSONSerialization.data(withJSONObject: [md]),
                  let json = String(data: data, encoding: .utf8) else { return }
            web.evaluateJavaScript("window.__render(\(json)[0], \(dark));", completionHandler: nil)
        }
    }
}

/// Holds a weak reference to the live preview web view for export.
final class PreviewController: ObservableObject {
    weak var webView: WKWebView?

    func exportPDF(to url: URL) {
        guard let web = webView else { return }
        // Render the whole document to a single tall PDF page, then re-slice it
        // into US-Letter pages so the output paginates properly.
        web.createPDF(configuration: WKPDFConfiguration()) { result in
            guard case .success(let data) = result else { return }
            Self.paginate(pdfData: data, to: url)
        }
    }

    /// Slice a single tall PDF page into multiple US-Letter pages.
    static func paginate(pdfData: Data, to url: URL) {
        guard let src = PDFDocument(data: pdfData),
              let page = src.page(at: 0) else {
            try? pdfData.write(to: url)   // fallback: keep the single-page PDF
            return
        }
        let content = page.bounds(for: .mediaBox)
        guard content.width > 0, content.height > 0 else { try? pdfData.write(to: url); return }

        let pageW: CGFloat = 612, pageH: CGFloat = 792   // US Letter @ 72 dpi
        let margin: CGFloat = 18                          // ¼ inch on all sides
        let contentW = pageW - margin * 2
        let usableH = pageH - margin * 2
        let scale = contentW / content.width                 // fit width to page
        let sliceContentH = usableH / scale                  // content points per page
        let pageCount = max(1, Int(ceil(content.height / sliceContentH)))

        guard let consumer = CGDataConsumer(url: url as CFURL) else { try? pdfData.write(to: url); return }
        var mediaBox = CGRect(x: 0, y: 0, width: pageW, height: pageH)
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            try? pdfData.write(to: url); return
        }

        for i in 0..<pageCount {
            ctx.beginPage(mediaBox: &mediaBox)
            ctx.saveGState()
            ctx.setFillColor(CGColor(gray: 1, alpha: 1))
            ctx.fill(mediaBox)
            // Top of this page's content strip, in source-PDF (bottom-left origin) coords.
            let yTop = content.maxY - CGFloat(i) * sliceContentH
            ctx.clip(to: CGRect(x: margin, y: margin, width: contentW, height: usableH))
            ctx.translateBy(x: margin, y: margin + usableH - yTop * scale)
            ctx.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: ctx)
            ctx.restoreGState()
            ctx.endPage()
        }
        ctx.closePDF()
    }

    func renderedHTML(completion: @escaping (String) -> Void) {
        guard let web = webView else { completion(""); return }
        web.evaluateJavaScript("document.documentElement.outerHTML") { value, _ in
            completion(value as? String ?? "")
        }
    }
}
