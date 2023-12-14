//
//  PlanetPreviewArticleView.swift
//  Planet
//

import SwiftUI


struct PlanetPreviewArticleView: View {
    @Environment(\.dismiss) private var dismiss

    var url: URL

    var body: some View {
        NavigationStack {
            PlanetArticleWebView(url: url)
                .ignoresSafeArea(edges: .bottom)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                }
        }
    }
}
