//
//  PlanetAttachmentsReorderView.swift
//  Planet
//

import Foundation
import SwiftUI


struct PlanetAttachmentsReorderView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var attachments: [PlanetArticleAttachment]
    
    @State private var initAttachments: [PlanetArticleAttachment] = []
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(initAttachments, id: \.id) { attachment in
                    HStack {
                        Image(uiImage: attachment.image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)
                        Spacer()
                        Text(attachment.url.lastPathComponent)
                    }
                }
                .onMove(perform: move)
            }
            .environment(\.editMode, .constant(.active))
            .animation(.default, value: attachments)
            .navigationTitle("Reorder Attachments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        self.cancelReorder()
                    } label: {
                        Text("Cancel")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        self.saveReorder()
                    } label: {
                        Text("Save")
                    }
                    .disabled(self.initAttachments == self.attachments)
                }
            }
        }
        .task {
            self.initAttachments = attachments
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        initAttachments.move(fromOffsets: source, toOffset: destination)
    }
    
    private func cancelReorder() {
        self.dismiss()
    }
    
    private func saveReorder() {
        self.dismiss()
        Task { @MainActor in
            self.attachments = self.initAttachments
        }
    }
}
