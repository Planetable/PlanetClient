//
//  PlanetArticleWebView.swift
//  Planet
//
//  Created by Kai on 2/20/23.
//

import Foundation
import SwiftUI
import WebKit


struct PlanetArticleWebView: UIViewRepresentable {
    var url: URL
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> some UIView {
        let wv = WKWebView()
        wv.customUserAgent = "Planet"
        wv.navigationDelegate = context.coordinator
        wv.load(URLRequest(url: url))
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
        
        func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            debugPrint("web view did receive challenge: \(challenge)")
            // MARK: TODO: Basic Authentication
        }
    }
}
