import SwiftUI
import PhotosUI

struct PlanetEditArticleView: View {
    @Environment(\.dismiss) private var dismiss

    static let editAttachment: String = "edit_attachment"

    var planet: Planet
    var article: PlanetArticle

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var initAttachments: [PlanetArticleAttachment] = []
    @State private var uploadedImages: [PlanetArticleAttachment] = []
    @State private var shouldDiscardChanges: Bool = false
    @State private var isPreview: Bool = false
    @State private var previewPath: URL?
    @State private var isDownloading: Bool = false
    @State private var hasUnsupportedAttachments: Bool = false

    var body: some View {
        NavigationStack {
            GeometryReader { g in
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        TextField("Title", text: $title)
                            .textFieldStyle(.plain)
                        Spacer(minLength: 1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)

                    Divider()
                        .padding(.vertical, 0)

                    PlanetTextView(text: $content)
                        .padding(.horizontal, 12)

                    PlanetArticleAttachmentsView(title: $title, attachments: $uploadedImages)
                        .onChange(of: uploadedImages) { _ in
                            self.updateAttachments()
                        }

                    Text(" ")
                        .frame(height: g.safeAreaInsets.bottom)
                        .frame(maxWidth: .infinity)
                        .background {
                            Color.secondary.opacity(0.15)
                        }
                }
                .frame(
                    minWidth: 0,
                    maxWidth: .infinity,
                    minHeight: 0,
                    maxHeight: .infinity,
                    alignment: .leading
                )
                .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle(isPreview ? "Preview" : "Edit Post")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $isDownloading) {
                Alert(
                    title: Text(
                        hasUnsupportedAttachments ? "Failed to Edit Article" : "Article Not Fully Downloaded"
                    ),
                    message: Text(
                        hasUnsupportedAttachments ? "Article has unsupported attachments, please edit on the Mac." :
                            "Please wait for the article and attachments to download and try editing again later."
                    ),
                    dismissButton: .default(Text("Dismiss")) {
                        dismissAction()
                    }
                )
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button {
                        if article.title != title || article.content != content || uploadedImages != initAttachments {
                            self.shouldDiscardChanges.toggle()
                        } else {
                            dismissAction()
                        }
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .disabled(isPreview)
                    .alert(isPresented: $shouldDiscardChanges) {
                        Alert(
                            title: Text("Unsaved Changes"),
                            message: Text("Would you like to save before closing?"),
                            primaryButton: .default(Text("Save")) {
                                saveAction()
                            },
                            secondaryButton: .cancel(Text("Discard")) {
                                dismissAction()
                            }
                        )
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        self.isPreview.toggle()
                        Task(priority: .userInitiated) {
                            if self.isPreview, let articlePath = PlanetManager.shared.getPlanetArticlePath(forID: planet.id, articleID: article.id) {
                                do {
                                    let attachmentsPath = articlePath.appending(path: Self.editAttachment)
                                    let url = try PlanetManager.shared.renderEditArticlePreview(forTitle: self.title, content: self.content, articleID: self.article.id, andAttachmentsPath: attachmentsPath)
                                    debugPrint("got preview article url: \(url)")
                                    Task { @MainActor in
                                        self.previewPath = url
                                    }
                                } catch {
                                    debugPrint("failed to render preview: \(error)")
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "eye.fill")
                    }
                    .disabled(title == "" && content == "")
                    Button {
                        saveAction()
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .disabled(isPreview)
                }
            }
            .task(priority: .utility) {
                title = self.article.title ?? ""
                content = self.article.content ?? ""
                if let attachments = self.article.attachments, let articlePath = PlanetManager.shared.getPlanetArticlePath(forID: self.planet.id, articleID: self.article.id) {
                    var localAttachments: [PlanetArticleAttachment] = []
                    for a in attachments {
                        let attachmentPath = articlePath.appending(path: a)
                        guard FileManager.default.fileExists(atPath: attachmentPath.path) else {
                            continue
                        }
                        guard let image = UIImage(contentsOfFile: attachmentPath.path) else {
                            hasUnsupportedAttachments = true
                            continue
                        }
                        let attachment = PlanetArticleAttachment(id: UUID(), created: Date(), image: image, url: attachmentPath)
                        localAttachments.append(attachment)
                    }
                    let finalLocalAttachments = localAttachments
                    if finalLocalAttachments.count != attachments.count {
                        debugPrint("article attachments not fully downloaded!")
                        Task { @MainActor in
                            self.isDownloading = true
                            if self.hasUnsupportedAttachments {
                                return
                            }
                            Task.detached(priority: .userInitiated) {
                                do {
                                    try await PlanetArticleDownloader.shared
                                        .download(
                                            byArticleID: self.article.id,
                                            andPlanetID: self.planet.id,
                                            forceDownloadAttachments: true
                                        )
                                } catch {
                                    debugPrint("failed to download article \(self.article.id): \(error)")
                                }
                            }
                        }
                    } else {
                        Task { @MainActor in
                            self.uploadedImages = finalLocalAttachments
                            self.initAttachments = finalLocalAttachments
                            Task(priority: .background) {
                                let initPath = articlePath.appending(path: Self.editAttachment)
                                try? FileManager.default.createDirectory(at: initPath, withIntermediateDirectories: true)
                                for a in finalLocalAttachments {
                                    let filename = a.url.lastPathComponent
                                    let initAttachmentPath = initPath.appending(path: filename)
                                    try? FileManager.default.copyItem(at: a.url, to: initAttachmentPath)
                                }
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $isPreview) {
                if let previewPath {
                    PlanetPreviewArticleView(url: previewPath)
                }
            }
        }
    }

    private func saveAction() {
        dismiss()
        Task(priority: .userInitiated) {
            do {
                try await PlanetManager.shared.modifyArticle(id: self.article.id, title: self.title, content: self.content, attachments: self.uploadedImages, planetID: self.planet.id)
            } catch {
                debugPrint("failed to save article: \(error)")
            }
            self.cleanupEditAttachments()
        }
    }

    private func dismissAction() {
        dismiss()
        restoreAttachments()
    }

    private func restoreAttachments() {
        guard let articlePath = PlanetManager.shared.getPlanetArticlePath(forID: planet.id, articleID: article.id) else { return }
        let editPath = articlePath.appending(path: Self.editAttachment)
        defer {
            try? FileManager.default.removeItem(at: editPath)
        }
        guard initAttachments.count > 0, FileManager.default.fileExists(atPath: editPath.path) else { return }
        for attachment in initAttachments {
            let filename = attachment.url.lastPathComponent
            let aPath = editPath.appending(path: filename)
            let previousPath = articlePath.appending(path: filename)
            if !FileManager.default.fileExists(atPath: previousPath.path) {
                try? FileManager.default.copyItem(at: aPath, to: previousPath)
            }
        }
    }

    private func updateAttachments() {
        guard let articlePath = PlanetManager.shared.getPlanetArticlePath(forID: planet.id, articleID: article.id) else { return }
        let tmp = URL.cachesDirectory
        let editPath = articlePath.appending(path: Self.editAttachment)
        let tmpAttachments: [PlanetArticleAttachment] = uploadedImages.filter { a in
            if a.url.deletingLastPathComponent() == tmp {
                return true
            }
            return false
        }
        guard tmpAttachments.count > 0 else { return }
        for a in tmpAttachments {
            let targetPath = editPath.appending(path: a.url.lastPathComponent)
            try? FileManager.default.removeItem(at: targetPath)
            try? FileManager.default.copyItem(at: a.url, to: targetPath)
        }
    }

    private func cleanupEditAttachments() {
        guard let articlePath = PlanetManager.shared.getPlanetArticlePath(forID: planet.id, articleID: article.id) else { return }
        let editPath = articlePath.appending(path: Self.editAttachment)
        try? FileManager.default.removeItem(at: editPath)
    }
}
