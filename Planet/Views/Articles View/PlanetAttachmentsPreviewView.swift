//
//  PlanetAttachmentsPreviewView.swift
//  Planet
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers


struct PlanetAttachmentsPreviewView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    var attachments: [PlanetArticleAttachment]
    @State private var selectedAttachmentIndex: Int
    
    init(attachments: [PlanetArticleAttachment], selectedAttachmentIndex: Int = 0) {
        self.attachments = attachments
        self.selectedAttachmentIndex = selectedAttachmentIndex
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if colorScheme == .dark {
                    Color.black.opacity(0.95)
                        .ignoresSafeArea()
                } else {
                    Color.white.opacity(0.95)
                        .ignoresSafeArea()
                }
                
                GeometryReader { geometry in
                    let attachment = attachments[selectedAttachmentIndex]
                    ScrollView([.horizontal, .vertical], showsIndicators: false) {
                        ZStack {
                            VStack {
                                if let fileUTType = UTType(filenameExtension: attachment.url.pathExtension),
                                   fileUTType.conforms(to: .image) {
                                    Image(uiImage: attachment.image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: geometry.size.width)
                                } else {
                                    Text(attachment.url.lastPathComponent)
                                        .foregroundColor(colorScheme == .dark ? .white : .black)
                                        .padding()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("\(attachments[selectedAttachmentIndex].url.lastPathComponent)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if attachments.count > 1 {
                        Button {
                            withAnimation {
                                selectedAttachmentIndex = selectedAttachmentIndex > 0 ? selectedAttachmentIndex - 1 : attachments.count - 1
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                        }
                        
                        Button {
                            withAnimation {
                                selectedAttachmentIndex = selectedAttachmentIndex < attachments.count - 1 ? selectedAttachmentIndex + 1 : 0
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                        }
                    }
                }
            }
            .tint(.accentColor)
        }
    }
}
