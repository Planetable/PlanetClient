//
//  PlanetArticleAttachmentsView.swift
//  Planet
//

import SwiftUI
import PhotosUI


struct PlanetArticleAttachmentsView: View {
    @Binding var selectedItem: PhotosPickerItem?
    @Binding var selectedPhotoData: Data? {
        didSet {
            Task(priority: .utility) {
                if let selectedPhotoData, let image = UIImage(data: selectedPhotoData), let noEXIFImage = image.removeEXIF(), let imageData = noEXIFImage.pngData() {
                    let imageName = String(UUID().uuidString.prefix(4)) + ".png"
                    let url = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: imageName)
                    let attachment = PlanetArticleAttachment(id: UUID(), created: Date(), image: image, url: url)
                    do {
                        if FileManager.default.fileExists(atPath: url.path) {
                            try FileManager.default.removeItem(at: url)
                        }
                        try imageData.write(to: url)
                        Task { @MainActor in
                            self.uploadedImages.insert(attachment, at:0)
                            NotificationCenter.default.post(name: .insertAttachment, object: attachment)
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

    @Binding var uploadedImages: [PlanetArticleAttachment]

    @State private var isTapped: Bool = false
    @State private var tappedIndex: Int?

    var body: some View {
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
        .frame(height: 48)
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
