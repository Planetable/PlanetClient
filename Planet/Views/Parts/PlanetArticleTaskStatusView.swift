//
//  PlanetArticleTaskStatusView.swift
//  Planet
//

import Foundation
import SwiftUI


struct PlanetArticleTaskStatusView: View {
    @State private var opacity: Double = 0.0
    @State private var uploadOpacity: Double = 1.0
    @State private var downloadOpacity: Double = 1.0
    @State private var isUploading: Bool = false
    @State private var isDownloading: Bool = false
    
    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: -1) {
            // Upload arrow
            Image(systemName: "arrow.up")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(.accentColor)
                .opacity(uploadOpacity)
                .animation(isUploading ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: uploadOpacity)
                .frame(width: 14, height: 14)
            
            // Download arrow
            Image(systemName: "arrow.down")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(.accentColor)
                .opacity(downloadOpacity)
                .animation(isDownloading ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: downloadOpacity)
                .frame(width: 14, height: 14)
        }
        .frame(width: 44, height: 44, alignment: .center)
        .opacity(opacity)
        .onReceive(timer) { _ in
            Task.detached(priority: .background) {
                let status = await PlanetStatus.shared.articleTaskStatus()
                await MainActor.run {
                    self.isUploading = status.uploadStatus
                    self.isDownloading = status.downloadStatus
                    self.uploadOpacity = self.isUploading ? 1.0 : 0.3
                    self.downloadOpacity = self.isDownloading ? 1.0 : 0.3
                    if !self.isUploading && !self.isDownloading {
                        self.opacity = 0.0
                    } else {
                        self.opacity = 1.0
                    }
                }
            }
        }
        .task {
            let status = await PlanetStatus.shared.articleTaskStatus()
            isUploading = status.uploadStatus
            isDownloading = status.downloadStatus
            uploadOpacity = isUploading ? 1.0 : 0.3
            downloadOpacity = isDownloading ? 1.0 : 0.3
            if !isUploading && !isDownloading {
                opacity = 0.0
            } else {
                opacity = 1.0
            }
        }
    }
}
