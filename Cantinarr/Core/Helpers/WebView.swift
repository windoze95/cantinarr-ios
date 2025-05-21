// File: WebView.swift
// Purpose: Defines WebView component for Cantinarr

import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context _: Context) -> WKWebView {
        let webView = WKWebView()
        // Optional: Configure the webView further if needed
        // webView.navigationDelegate = context.coordinator // If you need to handle navigation events
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context _: Context) {
        let request = URLRequest(url: url)
        uiView.load(request)
    }

    // Optional: Coordinator for handling WKNavigationDelegate methods
    // func makeCoordinator() -> Coordinator {
    //     Coordinator(self)
    // }

    // class Coordinator: NSObject, WKNavigationDelegate {
    //     var parent: WebView
    //     init(_ parent: WebView) {
    //         self.parent = parent
    //     }
    //     // Implement delegate methods here if necessary
    // }
}
