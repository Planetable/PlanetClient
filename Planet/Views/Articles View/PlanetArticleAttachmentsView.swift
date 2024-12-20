//
//  PlanetArticleAttachmentsView.swift
//  Planet
//

import UIKit
import SwiftUI
import PhotosUI
#if !targetEnvironment(simulator)
import JournalingSuggestions
import MapKit
#endif


struct PlanetArticleAttachmentsView: View {
    @Binding var title: String
    @Binding var attachments: [PlanetArticleAttachment]

    @State private var isKeyboardVisible: Bool = false
    @State private var isReorderingAttachments: Bool = false
    @State private var isPreviewingAttachments: Bool = false
    @State private var isShowingPayloadSizeWarning: Bool = false
    @State private var payloadSizeWarningMessage: String = ""

    @State private var isTapped: Bool = false
    @State private var tappedIndex: Int?
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data? {
        didSet {
            Task(priority: .utility) {
                if let selectedPhotoData, let image = UIImage(data: selectedPhotoData) {
                    do {
                        try self.processAndInsertImage(image)
                    } catch {
                        debugPrint("failed to process and insert image: \(error)")
                    }
                } else {
                    debugPrint("failed to save photo data.")
                }
            }
        }
    }

    private func processAndInsertImage(_ image: UIImage) throws {
        if let processed = image.processForMobile() {
            let imageName = String(UUID().uuidString.prefix(4)) + ".jpg"
            let url = URL.cachesDirectory.appending(path: imageName)
            let attachment = PlanetArticleAttachment(id: UUID(), created: Date(), image: processed.image, url: url)

            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
            try processed.data.write(to: url)
            Task { @MainActor in
                self.attachments.insert(attachment, at: 0)
            }
        } else {
            throw PlanetError.InternalError
        }
    }

#if !targetEnvironment(simulator)
    private func generateImageFromLocation(_ location: CLLocation) async throws -> UIImage {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
        let size = UIScreen.main.bounds.size
        let minWidth = min(size.width, size.height)
        options.size = CGSize(width: minWidth, height: minWidth)
        options.scale = UIScreen.main.scale
        let mapSnapshotter = MKMapSnapshotter(options: options)
        return try await withCheckedThrowingContinuation { continuation in
            mapSnapshotter.start { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let snapshot = snapshot {
                    let pinImage = UIImage(systemName: "mappin.and.ellipse.circle.fill")
                    let tintedPinImage = pinImage?.withTintColor(.systemPurple, renderingMode: .alwaysOriginal)
                    let imageRect = CGRect(origin: .zero, size: options.size)
                    UIGraphicsBeginImageContextWithOptions(imageRect.size, true, 0)
                    snapshot.image.draw(at: .zero)
                    let point = snapshot.point(for: location.coordinate)
                    if let tintedPinImage = tintedPinImage {
                        let pinPoint = CGPoint(x: point.x - tintedPinImage.size.width / 2.0,
                                               y: point.y - tintedPinImage.size.height / 2.0)
                        tintedPinImage.draw(at: pinPoint)
                    } else {
                        continuation.resume(throwing: PlanetError.InternalError)
                        return
                    }
                    let finalImage = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()
                    if let finalImage = finalImage {
                        continuation.resume(returning: finalImage)
                    } else {
                        continuation.resume(throwing: PlanetError.InternalError)
                    }
                } else {
                    continuation.resume(throwing: PlanetError.InternalError)
                }
            }
        }
    }
#endif

    var body: some View {
        ZStack {
            ScrollView(.horizontal, showsIndicators: true) {
                LazyHStack {
                    if #available(iOS 17.2, *) {
#if !targetEnvironment(simulator)
                        JournalingSuggestionsPicker {
                            Image(systemName: "wand.and.stars")
                        } onCompletion: { suggestion in
                            self.title = suggestion.title
                            let images: [UIImage] = await suggestion.content(forType: UIImage.self)
                            for image in images {
                                do {
                                    try processAndInsertImage(image)
                                } catch {
                                    debugPrint("failed to process and insert image: \(error)")
                                }
                            }
                            for suggestedLocation in suggestion.items.filter({ item in
                                return item.hasContent(ofType: JournalingSuggestion.Location.self)
                            }) {
                                do {
                                    if let location: CLLocation = try await suggestedLocation.content(forType: JournalingSuggestion.Location.self)?.location {
                                        let locationSnapshot = try await self.generateImageFromLocation(location)
                                        try processAndInsertImage(locationSnapshot)
                                    }
                                } catch {
                                    debugPrint("failed to parse location: \(error)")
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 22)
                        .padding(.trailing, 10)
#else
                        Text("")
                            .frame(width: 12)
#endif
                    } else {
                        Text("")
                            .frame(width: 12)
                    }
                    PhotosPicker(selection: $selectedItem, matching: .any(of: [.images, .not(.livePhotos)])) {
                        Image(systemName: "plus.circle")
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
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
                    ForEach(0..<attachments.count, id: \.self) { index in
                        Button {
                            isTapped.toggle()
                            tappedIndex = index
                        } label: {
                            Image(uiImage: attachments[index].image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 48, height: 48)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 48, height: 48)
                        .padding(.horizontal, 8)
                    }
                    // extra trailing padding for keyboard dismiss button
                    if attachments.count > 0 {
                        Text("")
                            .frame(width: 48, height: 48)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background {
                Color.secondary.opacity(0.15)
            }
            .sheet(
                isPresented: $isReorderingAttachments,
                content: {
                    PlanetAttachmentsReorderView(attachments: $attachments)
                }
            )
            .sheet(
                isPresented: $isPreviewingAttachments,
                content: {
                    PlanetAttachmentsPreviewView(
                        attachments: attachments,
                        selectedAttachmentIndex: tappedIndex ?? 0
                    )
                }
            )
            .confirmationDialog("", isPresented: $isTapped) {
                Button(role: .cancel) {
                    isTapped = false
                    tappedIndex = nil
                } label: {
                    Text("Cancel")
                }
                Button {
                    isPreviewingAttachments = true
                } label: {
                    Text("Preview")
                }
                Button {
                    if let tappedIndex {
                        let attachment = attachments[tappedIndex]
                        Task {
                            await MainActor.run {
                                NotificationCenter.default.post(name: .insertAttachment, object: attachment)
                            }
                        }
                    }
                } label: {
                    Text("Insert")
                }
                if attachments.count > 0 {
                    Button {
                        isReorderingAttachments = true
                    } label: {
                        Text("Reorder")
                    }
                }
                Button(role: .destructive) {
                    if let tappedIndex {
                        let removed = attachments.remove(at: tappedIndex)
                        do {
                            try FileManager.default.removeItem(at: removed.url)
                            Task { @MainActor in
                                NotificationCenter.default.post(name: .removeAttachment, object: removed)
                            }
                        } catch {
                            debugPrint("failed to remove attachment at: \(removed.url)")
                        }
                    }
                } label: {
                    Text("Remove")
                }
            }
            if isKeyboardVisible {
                HStack {
                    Spacer()
                    Button {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil,
                            from: nil,
                            for: nil
                        )
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                    .tint(.primary)
                    .buttonBorderShape(.roundedRectangle)
                }
                .padding(.trailing, 16)
            }
        }
        .frame(maxWidth: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { notification in
            Task { @MainActor in
                withAnimation {
                    self.isKeyboardVisible = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notification in
            Task { @MainActor in
                withAnimation {
                    self.isKeyboardVisible = false
                }
            }
        }
        .onChange(of: attachments) { newValue in
            let (valid, message) = PlanetManager.shared.validatePayloadSize(newValue)
            if !valid, let message {
                Task { @MainActor in
                    self.isShowingPayloadSizeWarning = true
                    self.payloadSizeWarningMessage = message
                }
            }
            debugPrint("validating attachments: \(valid) -> \(String(describing: message))")
        }
        .alert("Attachments Too Large", isPresented: $isShowingPayloadSizeWarning) {
            Button("Dismiss") { }
        } message: {
            Text(payloadSizeWarningMessage)
        }
    }
}
