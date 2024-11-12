//
//  PlanetArticleTaskStatusViewModel.swift
//  Planet
//

import Foundation
import SwiftUI


class PlanetArticleTaskStatusViewModel: ObservableObject {
    static let shared = PlanetArticleTaskStatusViewModel()

    @Published private(set) var downloadTaskURL: URL!
    @Published private(set) var isDownloadTaskCompleted: Bool = true
    @Published private(set) var downloadTaskProgress: Double = 0.0
    @Published private(set) var uploadTaskURL: URL!
    @Published private(set) var isUploadTaskCompleted: Bool = true
    @Published private(set) var uploadTaskProgress: Double = 0.0

    private init() {
    }

    @MainActor
    func updateIsUploadTaskCompleted(_ completed: Bool) {
        isUploadTaskCompleted = completed
    }

    @MainActor
    func updateDownloadTaskURL(_ url: URL) {
        downloadTaskURL = url
    }

    @MainActor
    func updateDownloadTaskProgress(_ progress: Double) {
        downloadTaskProgress = progress
    }

    @MainActor
    func updateDownloadTaskCompleted(_ completed: Bool) {
        isDownloadTaskCompleted = completed
    }

    @MainActor
    func updateUploadTaskURL(_ url: URL) {
        uploadTaskURL = url
    }

    @MainActor
    func updateUploadTaskProgress(_ progress: Double) {
        uploadTaskProgress = progress
    }
}
