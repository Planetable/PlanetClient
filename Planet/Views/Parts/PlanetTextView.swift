//
//  PlanetTextView.swift
//  Planet
//
//  Created by Kai on 2/21/23.
//

import Foundation
import SwiftUI
import UIKit


struct PlanetTextView: UIViewRepresentable {
    @Binding var text: String
    
    class Coordinator: NSObject, UITextViewDelegate {
        let parent: PlanetTextView
        
        init(_ parent: PlanetTextView) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isScrollEnabled = true
        view.isEditable = true
        view.isUserInteractionEnabled = true
        view.font = UIFont.preferredFont(forTextStyle: .body)
        view.autocorrectionType = .no
        view.autocapitalizationType = .none
        view.delegate = context.coordinator
        NotificationCenter.default.addObserver(forName: .insertAttachment, object: nil, queue: .main) { n in
            guard let attachment = n.object as? PlanetArticleAttachment else { return }
            var markdown = attachment.markdownImageValue()
            if let theRange: UITextRange = view.selectedTextRange {
                let cursorPosition = view.offset(from: view.beginningOfDocument, to: theRange.start)
                if cursorPosition == 0, markdown.hasPrefix("\n") {
                    markdown.removeFirst(1)
                }
            }
            view.insertText(markdown)
        }
        return view
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
    }
}
