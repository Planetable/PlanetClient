import SwiftUI
import PhotosUI


struct PlanetNewArticleView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: PlanetAppViewModel

    @State private var selectedPlanetIndex: Int = UserDefaults.standard.integer(forKey: .selectedPlanetIndex) {
        didSet {
            UserDefaults.standard.setValue(selectedPlanetIndex, forKey: .selectedPlanetIndex)
        }
    }
    @State private var selectedPlanet: Planet?
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var choosePlanet: Bool = false
    @State private var isPreview: Bool = false
    @State private var previewPath: URL?
    @State private var shouldSaveAsDraft: Bool = false

    @State private var isTapped: Bool = false
    @State private var tappedIndex: Int?
    @State private var uploadedImages: [PlanetArticleAttachment] = []
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data? {
        didSet {
            Task(priority: .utility) {
                if let selectedPhotoData, let image = UIImage(data: selectedPhotoData), let noEXIFImage = image.removeEXIF(), let imageData = noEXIFImage.pngData() {
                    let imageName = String(UUID().uuidString.prefix(4)) + ".png"
                    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: imageName)
                    let attachment = PlanetArticleAttachment(id: UUID(), created: Date(), image: noEXIFImage, url: url)
                    do {
                        if FileManager.default.fileExists(atPath: url.path) {
                            try FileManager.default.removeItem(at: url)
                        }
                        try imageData.write(to: url)
                        Task { @MainActor in
                            self.uploadedImages.insert(attachment, at:0)
                            NotificationCenter.default.post(name: .addAttachment, object: attachment)
                        }
                    } catch {
                        debugPrint("failed to save photo data: \(error)")
                    }
                } else {
                    debugPrint("failed to save photo data.")
                }
            }
        }
    }

    private let articleID: UUID
    var articleDraft: PlanetArticle?

    init(withDraft draft: PlanetArticle?, draftMode: Bool) {
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

                    PlanetTextView(text: $content)
                        .padding(.horizontal, 12)

                    attachmentsView()
                        .frame(height: 48)

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
            .navigationTitle(isPreview ? "Preview" :"New Post")
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
                                    let selectedAttachmentNames: [String] = uploadedImages.map() { a in
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
                        Image(systemName: isPreview ? "xmark" : "eye.fill")
                    }
                    .disabled(title == "" && content == "")
                    if !isPreview {
                        Button {
                            dismiss()
                            guard let selectedPlanet else { return }
                            Task(priority: .userInitiated) {
                                do {
                                    try await PlanetManager.shared.createArticle(
                                        title: self.title,
                                        content: self.content,
                                        attachments: self.uploadedImages,
                                        forPlanet: selectedPlanet
                                    )
                                    self.removeAttachments()
                                    Task { @MainActor in
                                        self.appViewModel.selectedTab = .latest
                                        if let articleDraft {
                                            self.appViewModel.removeDraft(articleDraft)
                                        }
                                    }
                                }
                                catch {
                                    debugPrint("failed to save article: \(error)")
                                }
                            }
                        } label: {
                            Image(systemName: "paperplane.fill")
                        }
                        .disabled(appViewModel.myPlanets.count == 0)
                    }
                }
            }
            .task(priority: .utility) {
                if let draft = articleDraft {
                    self.restoreFromDraft(draft)
                } else {
                    self.selectedPlanet = self.appViewModel.myPlanets[self.selectedPlanetIndex]
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .addAttachment)) { n in
                guard let attachment = n.object as? PlanetArticleAttachment else { return }
                if uploadedImages.first(where: { $0.url == attachment.url }) == nil {
                    Task {
                        await MainActor.run {
                            debugPrint("added attachment: \(attachment.url)")
                            self.uploadedImages.append(attachment)
                        }
                    }
                }
                Task {
                    await MainActor.run {
                        NotificationCenter.default.post(name: .insertAttachment, object: attachment)
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
            let attachments = uploadedImages.map() { a in
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
                let tempPath = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: attachment)
                try? FileManager.default.copyItem(at: attachmentPath, to: tempPath)
                if let image = UIImage(contentsOfFile: tempPath.path) {
                    let articleAttachment = PlanetArticleAttachment(id: UUID(), created: Date(), image: image, url: tempPath)
                    uploadedImages.append(articleAttachment)
                }
            }
        }
    }

    /*
        TODO: PlanetArticleAttachmentsView
     */
    @ViewBuilder
    private func attachmentsView() -> some View {
        ScrollView(.horizontal, showsIndicators: true) {
            LazyHStack {
                PhotosPicker(selection: $selectedItem, matching: .any(of: [.images, .not(.livePhotos)])) {
                    Image(systemName: "plus.circle")
                        .resizable()
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .padding(.leading, 24)
                .padding(.trailing, 8)
                .onChange(of: selectedItem) { newValue in
                    Task(priority: .utility) {
                        do {
                            if let newValue, let data = try await newValue.loadTransferable(type: Data.self) {
                                selectedPhotoData = data
                            } else {
                                selectedItem = nil
                                selectedPhotoData = nil
                            }
                        } catch {
                            selectedItem = nil
                            selectedPhotoData = nil
                        }
                    }
                }

                ForEach(0..<uploadedImages.count, id: \.self) { index in
                    Button {
                        isTapped.toggle()
                        tappedIndex = index
                    } label: {
                        Image(uiImage: uploadedImages[index].image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 48, height: 48)
                    .padding(.horizontal, 8)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background {
            Color.secondary.opacity(0.15)
        }
        .confirmationDialog("", isPresented: $isTapped) {
            Button(role: .cancel) {
                isTapped = false
                tappedIndex = nil
            } label: {
                Text("Cancel")
            }
            Button {
                if let tappedIndex {
                    let attachment = uploadedImages[tappedIndex]
                    Task {
                        await MainActor.run {
                            NotificationCenter.default.post(name: .insertAttachment, object: attachment)
                        }
                    }
                }
            } label: {
                Text("Insert Attachment")
            }
            Button(role: .destructive) {
                if let tappedIndex {
                    let removed = uploadedImages.remove(at: tappedIndex)
                    do {
                        try FileManager.default.removeItem(at: removed.url)
                    } catch {
                        debugPrint("failed to remove attachment at: \(removed.url)")
                    }
                }
            } label: {
                Text("Remove Attachment")
            }
        }
    }
}
