import SwiftUI
import WebKit

#if os(macOS)
struct PlayerWebView: NSViewRepresentable {
    let bridge: PlayerBridge
    func makeNSView(context: Context) -> WKWebView { bridge.webView }
    func updateNSView(_ view: WKWebView, context: Context) {}
}
#else
struct PlayerWebView: UIViewRepresentable {
    let bridge: PlayerBridge
    func makeUIView(context: Context) -> WKWebView { bridge.webView }
    func updateUIView(_ view: WKWebView, context: Context) {}
}
#endif
