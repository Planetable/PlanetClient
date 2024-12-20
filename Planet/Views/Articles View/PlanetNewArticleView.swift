import SwiftUI
import PhotosUI

struct PlanetNewArticleView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: PlanetAppViewModel
    
    @AppStorage(.selectedPlanetIndex) private var selectedPlanetIndex: Int = PlanetManager.shared.userDefaults.integer(forKey: .selectedPlanetIndex)
    
    @State private var selectedPlanet: Planet?
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var choosePlanet: Bool = false
    @State private var isPreview: Bool = false
    @State private var previewPath: URL?
    @State private var shouldSaveAsDraft: Bool = false
    
    @State private var uploadedImages: [PlanetArticleAttachment] = []
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    
    private let articleID: UUID
    var articleDraft: PlanetArticle?
    
    init(withDraft draft: PlanetArticle?) {
        if let draft {
            articleID = UUID(uuidString: draft.id)!
            articleDraft = draft
        } else {
            articleID = UUID()
        }
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { g in
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Button(action: {
                            choosePlanet = true
                        }) {
                            if let planet = selectedPlanet {
                                planet.avatarView(.medium)
                            }
                        }
                        
                        TextField("Title", text: $title)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    
                    Divider()
                        .padding(.vertical, 0)
                    
                    WriterView(writerID: articleID, text: $content)
                        .padding(.horizontal, 12)
                    
                    PlanetArticleAttachmentsView(title: $title, attachments: $uploadedImages)
                    
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
            .navigationTitle(isPreview ? "Preview" : "New Post")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $shouldSaveAsDraft) {
                Alert(
                    title: Text("Save as Draft?"),
                    primaryButton: .default(Text("Save")) {
                        saveAsDraftAction()
                        dismissAction()
                    },
                    secondaryButton: .cancel(Text("Discard")) {
                        dismissAction()
                    }
                )
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    if !isPreview {
                        Button {
                            if title.count > 0 || content.count > 0 || uploadedImages.count > 0 {
                                if let draft = articleDraft {
                                    let selectedAttachmentNames: [String] = uploadedImages.map { a in
                                        return a.url.lastPathComponent
                                    }
                                    if title != draft.title || content != draft.content || selectedAttachmentNames != draft.attachments {
                                        shouldSaveAsDraft.toggle()
                                        return
                                    }
                                } else {
                                    shouldSaveAsDraft.toggle()
                                    return
                                }
                            }
                            dismissAction()
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        self.isPreview.toggle()
                        Task(priority: .userInitiated) {
                            if self.isPreview {
                                do {
                                    let url = try PlanetManager.shared.renderArticlePreview(forTitle: self.title, content: self.content, andArticleID: self.articleID.uuidString)
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
                        dismiss()
                        guard let selectedPlanet else { return }
                        Task(priority: .userInitiated) {
                            let isFromDraft: Bool = articleDraft != nil
                            do {
                                try await PlanetManager.shared.createArticle(
                                    title: self.title,
                                    content: self.content,
                                    attachments: self.uploadedImages,
                                    forPlanet: selectedPlanet,
                                    isFromDraft: isFromDraft
                                )
                                Task { @MainActor in
                                    self.appViewModel.selectedTab = .latest
                                    if let articleDraft {
                                        self.appViewModel.removeDraft(articleDraft)
                                    }
                                }
                            } catch {
                                if isFromDraft {
                                    debugPrint("failed to create article from draft: \(error)")
                                } else {
                                    debugPrint("failed to create article: \(error), saved as draft.")
                                }
                            }
                            self.removeAttachments()
                        }
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .disabled(appViewModel.myPlanets.count == 0 || isPreview)
                }
            }
            .task(priority: .utility) {
                if let draft = articleDraft {
                    self.restoreFromDraft(draft)
                } else {
                    if self.appViewModel.myPlanets.count > self.selectedPlanetIndex {
                        self.selectedPlanet = self.appViewModel.myPlanets[self.selectedPlanetIndex]
                    } else {
                        dismiss()
                        Task {
                            try? await Task.sleep(nanoseconds: 1_000_000_000)
                            Task { @MainActor in
                                self.appViewModel.failedToCreateArticle = true
                                self.appViewModel.failedMessage = "No planet found, please create a planet first or write in drafts."
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $choosePlanet) {
                PlanetPickerView(selectedPlanetIndex: $selectedPlanetIndex, selectedPlanet: $selectedPlanet)
                    .environmentObject(appViewModel)
            }
            .sheet(isPresented: $isPreview) {
                if let previewPath {
                    PlanetPreviewArticleView(url: previewPath)
                }
            }
        }
    }
    
    private func saveAsDraftAction() {
        do {
            _ = try PlanetManager.shared.renderArticlePreview(forTitle: title, content: content, andArticleID: articleID.uuidString)
            let attachments = uploadedImages.map { a in
                return a.url.lastPathComponent
            }
            var planetID: UUID?
            if let selectedPlanet, let theID = UUID(uuidString: selectedPlanet.id) {
                planetID = theID
            }
            try PlanetManager.shared.saveArticleDraft(byID: articleID, attachments: attachments, title: title, content: content, planetID: planetID)
        } catch {
            debugPrint("failed to save draft: \(error)")
        }
    }
    
    private func dismissAction() {
        dismiss()
        if articleDraft == nil {
            removeAttachments()
        }
    }
    
    private func removeAttachments() {
        for attachment in uploadedImages {
            try? FileManager.default.removeItem(at: attachment.url)
        }
    }
    
    private func restoreFromDraft(_ draft: PlanetArticle) {
        title = draft.title ?? ""
        content = draft.content ?? ""
        if let planetID = draft.planetID, let planet = Planet.getPlanet(forID: planetID.uuidString) {
            selectedPlanet = planet
            var index: Int = 0
            for myPlanet in PlanetAppViewModel.shared.myPlanets {
                if myPlanet.id == planetID.uuidString {
                    selectedPlanetIndex = index
                }
                index += 1
            }
        }
        let articleDraftPath = PlanetManager.shared.draftsDirectory.appending(path: draft.id)
        if let attachments = draft.attachments {
            for attachment in attachments {
                let attachmentPath = articleDraftPath.appending(path: attachment)
                let tempPath = URL.cachesDirectory.appending(path: attachment)
                try? FileManager.default.copyItem(at: attachmentPath, to: tempPath)
                if let image = UIImage(contentsOfFile: tempPath.path) {
                    let articleAttachment = PlanetArticleAttachment(id: UUID(), created: Date(), image: image, url: tempPath)
                    uploadedImages.append(articleAttachment)
                }
            }
        }
    }
}
