import SwiftUI
import WebKit
import AppKit

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

        if let dir = Bundle.module.url(forResource: "web", withExtension: nil) {
            let index = dir.appendingPathComponent("index.html")
            web.loadFileURL(index, allowingReadAccessTo: dir)
        }
        return web
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
        let config = WKPDFConfiguration()
        web.createPDF(configuration: config) { result in
            if case .success(let data) = result {
                try? data.write(to: url)
            }
        }
    }

    func renderedHTML(completion: @escaping (String) -> Void) {
        guard let web = webView else { completion(""); return }
        web.evaluateJavaScript("document.documentElement.outerHTML") { value, _ in
            completion(value as? String ?? "")
        }
    }
}
