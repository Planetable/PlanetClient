//
//  PlanetArticleWebView.swift
//  Planet
//
//  Created by Kai on 2/20/23.
//

import Foundation
import SwiftUI
import WebKit

private class FullScreenWKWebView: WKWebView {
    override var safeAreaInsets: UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
}

struct PlanetArticleWebView: UIViewRepresentable {
    var url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> some UIView {
        let wv = FullScreenWKWebView()
        wv.scrollView.contentInsetAdjustmentBehavior = .always
        wv.customUserAgent = "Planet Client/" + Bundle.appVersion()
        wv.navigationDelegate = context.coordinator
        wv.isOpaque = false
        wv.backgroundColor = UIColor.clear
        wv.scrollView.backgroundColor = UIColor.clear
        if url.isFileURL {
            let assetsPath = url.deletingLastPathComponent().deletingLastPathComponent()
            wv.loadFileURL(url, allowingReadAccessTo: assetsPath)
        } else {
            wv.load(URLRequest(url: url))
        }
        return wv
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: PlanetArticleWebView

        private var navigationType: WKNavigationType = .other

        init(_ parent: PlanetArticleWebView) {
            self.parent = parent
        }
    }
}
