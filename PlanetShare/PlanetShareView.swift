//
//  PlanetShareView.swift
//  Planet
//

import SwiftUI


struct PlanetShareView: View {
    @State private var content: String
    private var image: UIImage?
    private var imageURL: URL?

    init(content: String, image: UIImage?, imageURL: URL?) {
        self.content = content
        self.image = image
        self.imageURL = imageURL
    }

    var body: some View {
        NavigationStack{
            VStack {
                if let image {
                    HStack {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                    }
                } else if let imageURL {
                    HStack {
                        AsyncImage(url: imageURL) { img in
                            img
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 200)
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 200, height: 200)
                    }
                }
                
                TextField("Content to share", text: $content, axis: .vertical)
                    .lineLimit(3...10)
                    .textFieldStyle(.roundedBorder)

                Button {
                    NotificationCenter.default.post(name: PlanetShareViewController.closeNotification, object: nil)
                    saveAction()
                } label: {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Share on Planet")
            .toolbar {
                Button {
                    NotificationCenter.default.post(name: PlanetShareViewController.closeNotification, object: nil)
                } label: {
                    Text("Cancel")
                }
            }
        }
    }
    
    private func saveAction() {
        // MARK: TODO: share planet core function with extension.
    }
}
