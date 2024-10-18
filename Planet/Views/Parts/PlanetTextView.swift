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

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            let cursorPosition = textView.selectedRange.location
            let content = textView.text as NSString
            let currentLineRange = content.lineRange(for: NSRange(location: cursorPosition == 0 ? 0 : cursorPosition - 1, length: 0))
            let currentLine = content.substring(with: currentLineRange)
            if text == "\n" {
                // Add first-level auto completion for list items and checkboxs:
                var symbol = ""
                if currentLine.hasPrefix("* ") {
                    symbol = "* "
                } else if currentLine.hasPrefix("- [ ] ") {
                    symbol = "- [ ] "
                } else if currentLine.hasPrefix("- [x] ") {
                    symbol = "- [ ] "
                } else if currentLine.hasPrefix("- [X] ") {
                    symbol = "- [ ] "
                } else if currentLine.hasPrefix("- ") {
                    symbol = "- "
                } else if let match = currentLine.range(of: "^\\d+\\. ", options: .regularExpression), !match.isEmpty {
                    if let number = Int(currentLine.trimmingCharacters(in: CharacterSet.decimalDigits.inverted)) {
                        symbol = "\(number + 1). "
                        // Should remove previous auto completed list symbol if empty content returns
                        if String(number) + ". " == currentLine || String(number) + ". " == currentLine + "\n" {
                            textView.text = content.replacingCharacters(in: currentLineRange, with: "\n")
                            return false
                        }
                    }
                }
                if currentLine.hasSuffix("\n") {
                    // Should skip this symbol
                    textView.text = content.replacingCharacters(in: range, with: "\n")
                    textView.selectedRange = NSRange(location: cursorPosition + 1, length: 0)
                    return false
                } else if symbol == currentLine || symbol == currentLine + "\n" {
                    // Should remove previous auto completed list symbol if empty content returns
                    textView.text = content.replacingCharacters(in: currentLineRange, with: "\n")
                    return false
                } else {
                    if !symbol.isEmpty {
                        if currentLine.trimmingCharacters(in: .whitespacesAndNewlines).count == symbol.count {
                            // If the current line is an empty list item or checkbox, remove the list symbol or checkbox
                            let newContent = content.replacingCharacters(in: currentLineRange, with: "\n")
                            textView.text = newContent
                            textView.selectedRange = NSRange(location: currentLineRange.location + 1, length: 0)
                        } else {
                            // Otherwise, insert the appropriate symbol at the start of the new line
                            textView.text = content.replacingCharacters(in: range, with: "\n" + symbol)
                            textView.selectedRange = NSRange(location: cursorPosition + symbol.count + 1, length: 0)
                        }
                        return false
                    }
                }
            } else if text.isEmpty {
                // Check if the current line is empty after deletion
                if currentLine.trimmingCharacters(in: .whitespacesAndNewlines).count == 1 {
                    let previousLineRange = (content as NSString).lineRange(for: NSRange(location: max(currentLineRange.location - 1, 0), length: 0))
                    let newCursorPosition = previousLineRange.location + previousLineRange.length - 1
                    let newContent = content.replacingCharacters(in: currentLineRange, with: "")
                    textView.text = newContent
                    textView.selectedRange = NSRange(location: newCursorPosition, length: 0)
                    return false
                }
            }
            return true
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
