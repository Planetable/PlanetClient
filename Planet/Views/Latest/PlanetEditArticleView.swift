import SwiftUI
import PhotosUI


struct PlanetEditArticleView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var myPlanetsViewModel: PlanetMyPlanetsViewModel
    
    var planet: Planet
    var article: PlanetArticle
    
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var initAttachments: [PlanetArticleAttachment] = []

    @State private var isTapped: Bool = false
    @State private var tappedIndex: Int?
    @State private var uploadedImages: [PlanetArticleAttachment] = []
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data? {
        didSet {
            Task(priority: .background) {
                if let selectedPhotoData {
                    let planetID = planet.id
                    let imageName = planetID.prefix(4) + "-" + String(UUID().uuidString.prefix(4)) + ".png"
                    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(imageName)
                    do {
                        if FileManager.default.fileExists(atPath: url.path) {
                            try FileManager.default.removeItem(at: url)
                        }
                        try selectedPhotoData.write(to: url)
                        if let image = UIImage(data: selectedPhotoData) {
                            await MainActor.run {
                                let attachment = PlanetArticleAttachment(id: UUID(), created: Date(), image: image, url: url)
                                self.uploadedImages.insert(attachment, at:0)
                            }
                        }
                    } catch {
                        debugPrint("failed to save photo data: \(error)")
                    }
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
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
                
                attachmentsView()
                    .frame(height: 48)
            }
            .frame(
                minWidth: 0,
                maxWidth: .infinity,
                minHeight: 0,
                maxHeight: .infinity,
                alignment: .leading
            )
            .navigationTitle("Edit Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                        restoreAttachments()
                    } label: {
                        Text("Cancel")
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                        Task(priority: .userInitiated) {
                            do {
                                try await PlanetManager.shared.modifyArticle(id: self.article.id, title: self.title, content: self.content, attachments: self.uploadedImages, planetID: self.planet.id)
                            }
                            catch {
                                debugPrint("failed to save article: \(error)")
                            }
                        }
                    } label: {
                        Text("Save")
                    }
                    .disabled(title == "")
                }
            }
            .task(priority: .utility) {
                title = article.title
                content = article.content
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
                        // copy init attachments to [articlePath]/init_attachments for restore when cancel editing.
                        Task(priority: .background) {
                            let initPath = articlePath.appending(path: "init_attachments")
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
    
    @ViewBuilder
    private func attachmentsView() -> some View {
        ScrollView(.horizontal, showsIndicators: true) {
            LazyHStack {
                PhotosPicker(selection: $selectedItem, matching: .any(of: [.images, .not(.livePhotos)])) {
                    Image(systemName: "plus")
                        .resizable()
                        .frame(width: 14, height: 14)
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
            Color.secondary.opacity(0.25)
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
                    NotificationCenter.default.post(name: .addAttachment, object: uploadedImages[tappedIndex])
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
    
    private func restoreAttachments() {
        guard let articlePath = PlanetManager.shared.getPlanetArticlePath(forID: planet.id, articleID: article.id) else { return }
        let initPath = articlePath.appending(path: "init_attachments")
        guard initAttachments.count > 0, FileManager.default.fileExists(atPath: initPath.path) else { return }
        for attachment in initAttachments {
            let filename = attachment.url.lastPathComponent
            let aPath = initPath.appending(path: filename)
            let previousPath = articlePath.appending(path: filename)
            if !FileManager.default.fileExists(atPath: previousPath.path) {
                try? FileManager.default.copyItem(at: aPath, to: previousPath)
            }
        }
        try? FileManager.default.removeItem(at: initPath)
    }
}
