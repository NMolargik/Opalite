//
//  WebSnapshotter.swift
//  OpaliteServices
//
//  Renders a page in an offscreen, non-persistent `WKWebView` and returns a snapshot for
//  color extraction. Cross-host top-level navigations are refused so the view stays on the
//  site the user entered. Gives up after the timeout and returns nil (declared colors still work).
//

#if os(iOS) || os(visionOS)
import UIKit
import WebKit
import OpaliteCore
import os

@MainActor
final class WebSnapshotter: NSObject, WKNavigationDelegate {
    private let url: URL
    private let webView: WKWebView
    private var continuation: CheckedContinuation<CGImage?, Never>?

    static func snapshot(of url: URL, timeout: TimeInterval) async -> CGImage? {
        let snapshotter = WebSnapshotter(url: url)
        return await snapshotter.run(timeout: timeout)
    }

    private init(url: URL) {
        self.url = url
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.allowsInlineMediaPlayback = false
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.isUserInteractionEnabled = false
    }

    private func run(timeout: TimeInterval) async -> CGImage? {
        attachOffscreen()
        defer { webView.removeFromSuperview() }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            webView.load(URLRequest(url: url, timeoutInterval: timeout))
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(timeout))
                self?.finish(nil)
            }
        }
    }

    /// WebKit only paints views that are in a window, so park it far off-screen.
    private func attachOffscreen() {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        webView.frame.origin = CGPoint(x: -10_000, y: 0)
        window?.addSubview(webView)
    }

    private func finish(_ image: CGImage?) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: image)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
        guard isMainFrame, let target = navigationAction.request.url else { return .allow }
        if target.scheme?.lowercased() == "about" { return .allow }
        let isWeb = ["http", "https"].contains(target.scheme?.lowercased() ?? "")
        return isWeb && WebPaletteScanner.displayHost(of: target) == WebPaletteScanner.displayHost(of: url) ? .allow : .cancel
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            // Give late layout, fonts and lazy images a moment to settle before capturing.
            try? await Task.sleep(for: .seconds(1.2))
            guard self.continuation != nil else { return }
            let configuration = WKSnapshotConfiguration()
            configuration.snapshotWidth = 390
            do {
                let image = try await webView.takeSnapshot(configuration: configuration)
                self.finish(image.cgImage)
            } catch {
                Log.app.error("Website snapshot failed: \(error.localizedDescription)")
                self.finish(nil)
            }
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        Task { @MainActor in self.finish(nil) }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        Task { @MainActor in self.finish(nil) }
    }
}
#endif
