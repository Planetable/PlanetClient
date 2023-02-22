//
//  PlanetUpdatePlanetView.swift
//  Planet
//
//  Created by Kai on 2/19/23.
//

import SwiftUI
import PhotosUI


struct PlanetNewPlanetView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var serverStatus: Bool = false
    
    @State private var planetName: String = ""
    @State private var planetAbout: String = ""
    @State private var planetAvatarPath: String = ""
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data? {
        didSet {
            if let selectedPhotoData {
                let imageName = String(UUID().uuidString.prefix(4)) + ".png"
                let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(imageName)
                do {
                    if FileManager.default.fileExists(atPath: url.path) {
                        try FileManager.default.removeItem(at: url)
                    }
                    try selectedPhotoData.write(to: url)
                    planetAvatarPath = url.path
                } catch {
                    debugPrint("failed to save photo data: \(error)")
                }
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            avatarView()
            
            HStack {
                PhotosPicker(selection: $selectedItem, matching: .any(of: [.images, .not(.livePhotos)])) {
                    Text("Upload Avatar")
                }
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
                .buttonStyle(.bordered)
                
                Button {
                    Task(priority: .background) {
                        let url = URL(fileURLWithPath: planetAvatarPath)
                        do {
                            try FileManager.default.removeItem(atPath: url.path)
                        } catch {
                            debugPrint("failed to remove avatar: \(url)")
                        }
                        await MainActor.run {
                            self.selectedItem = nil
                            self.selectedPhotoData = nil
                            self.planetAvatarPath = ""
                        }
                    }
                } label: {
                    Text("Remove")
                }
                .buttonStyle(.plain)
            }
            
            formView()
                .navigationTitle("New Planet")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                        }
                    }
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button {
                            dismiss()
                            Task(priority: .userInitiated) {
                                do {
                                    try await PlanetManager.shared.createPlanet(name: planetName, about: planetAbout, avatarPath: planetAvatarPath)
                                } catch {
                                    debugPrint("failed to create planet: \(error)")
                                }
                            }
                        } label: {
                            Text("Save")
                        }
                        .disabled(planetName == "" || !serverStatus)
                    }
                }
                .task(priority: .background) {
                    let status = await PlanetSettingsViewModel.shared.serverIsOnline()
                    await MainActor.run {
                        self.serverStatus = status
                    }
                }
        }
    }
    
    @ViewBuilder
    private func formView() -> some View {
        ScrollView {
            LazyVStack {
                TextField("Name", text: $planetName)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textFieldStyle(.roundedBorder)
                TextField("About", text: $planetAbout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 12)
            .padding(.top, 24)
        }
    }
    
    @ViewBuilder
    private func avatarView() -> some View {
        Group {
            if let selectedPhotoData, let image = UIImage(data: selectedPhotoData) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                if planetAvatarPath != "", let img = UIImage(contentsOfFile: planetAvatarPath) {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
        }
        .frame(width: 96, height: 96, alignment: .center)
        .padding(12)
    }
}

struct PlanetNewPlanetView_Previews: PreviewProvider {
    static var previews: some View {
        PlanetNewPlanetView()
    }
}
