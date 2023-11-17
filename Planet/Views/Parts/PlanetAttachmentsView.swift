//
//  PlanetAttachmentsView.swift
//  Planet
//
//  Created by Kai on 2/21/23.
//

import SwiftUI
import PhotosUI


struct PlanetAttachmentsView: View {
    @Binding var planet: Planet?

    @State private var isTapped: Bool = false
    @State private var tappedIndex: Int?
    @State private var uploadedImages: [PlanetArticleAttachment] = []
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data? {
        didSet {
            Task(priority: .background) {
                if let selectedPhotoData, let planet {
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
                                debugPrint("inserted image: \(imageName)")
                                NotificationCenter.default.post(name: .addAttachment, object: attachment)
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
}

struct PlanetAttachmentsView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetAttachmentsView(planet: .constant(nil))
    }
}
