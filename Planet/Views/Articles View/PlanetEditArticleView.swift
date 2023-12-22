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

                    PlanetArticleAttachmentsView(attachments: $uploadedImages)

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
            .navigationTitle("Edit Post")
            .navigationBarTitleDisplayMode(.inline)
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
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button {
                        let initAttachmentNames: [String] = initAttachments.map() { a in
                            return a.url.lastPathComponent
                        }
                        if article.title != title || article.content != content || initAttachmentNames != article.attachments {
                            shouldDiscardChanges.toggle()
                        } else {
                            dismissAction()
                        }
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        saveAction()
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                }
            }
            .task(priority: .utility) {
                title = article.title ?? "untitled"
                content = article.content ?? ""
                if let attachments = article.attachments, let articlePath = PlanetManager.shared.getPlanetArticlePath(forID: planet.id, articleID: article.id) {
                    var localAttachments: [PlanetArticleAttachment] = []
                    for a in attachments {
                        let attachmentPath = articlePath.appending(path: a)
                        guard let image = UIImage(contentsOfFile: attachmentPath.path) else { continue }
                        let attachment = PlanetArticleAttachment(id: UUID(), created: Date(), image: image, url: attachmentPath)
                        localAttachments.append(attachment)
                    }
                    let finalLocalAttachments = localAttachments
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
    }

    private func saveAction() {
        dismiss()
        Task(priority: .userInitiated) {
            do {
                try await PlanetManager.shared.modifyArticle(id: self.article.id, title: self.title, content: self.content, attachments: self.uploadedImages, planetID: self.planet.id)
            }
            catch {
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
    
    private func cleanupEditAttachments() {
        guard let articlePath = PlanetManager.shared.getPlanetArticlePath(forID: planet.id, articleID: article.id) else { return }
        let editPath = articlePath.appending(path: Self.editAttachment)
        try? FileManager.default.removeItem(at: editPath)
    }
}
