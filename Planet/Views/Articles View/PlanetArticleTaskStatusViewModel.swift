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

    @Published private(set) var downloadTaskStatus: String = ""
    @Published private(set) var uploadTaskStatus: String = ""

    private init() {
        debugPrint("PlanetArticleTaskStatusViewModel initialized")
    }

    // MARK: - Upload Tasks
    @MainActor
    func updateIsUploadTaskCompleted(_ completed: Bool) {
        isUploadTaskCompleted = completed
        if completed {
            uploadTaskStatus = "Upload tasks completed."
        } else if let uploadTaskURL {
            let progress: String = String(format: "%.f", uploadTaskProgress)
            uploadTaskStatus = "Uploading: \(uploadTaskURL.lastPathComponent), \(progress)% completed."
        } else {
            uploadTaskStatus = ""
        }
    }

    @MainActor
    func updateUploadTaskURL(_ url: URL) {
        uploadTaskURL = url
    }

    @MainActor
    func updateUploadTaskProgress(_ progress: Double) {
        uploadTaskProgress = progress
    }

    // MARK: - Download Tasks
    @MainActor
    func updateDownloadTaskCompleted(_ completed: Bool) {
        isDownloadTaskCompleted = completed
        if completed {
            downloadTaskStatus = "Download tasks completed."
        } else if let downloadTaskURL {
            let progress: String = String(format: "%.f", downloadTaskProgress)
            downloadTaskStatus = "Downloading: \(downloadTaskURL.lastPathComponent), \(progress)% completed."
        } else {
            downloadTaskStatus = ""
        }
    }

    @MainActor
    func updateDownloadTaskURL(_ url: URL) {
        downloadTaskURL = url
    }

    @MainActor
    func updateDownloadTaskProgress(_ progress: Double) {
        downloadTaskProgress = progress
    }
}
