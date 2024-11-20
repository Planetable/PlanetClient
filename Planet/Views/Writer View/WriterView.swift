//
//  WriterView.swift
//  Planet
//


import SwiftUI
import UIKit


class WriterEditorTextView: UITextView {
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        let container = textContainer ?? NSTextContainer(size: CGSize(width: frame.width, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        
        let layoutManager = NSLayoutManager()
        let storage = NSTextStorage()
        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(container)
        
        super.init(frame: frame, textContainer: container)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        backgroundColor = .systemBackground
        isScrollEnabled = true
        isEditable = true
        isUserInteractionEnabled = true
        textContainerInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
        autocorrectionType = .yes
        autocapitalizationType = .sentences
    }
    
    override func insertText(_ text: String) {
        super.insertText(text)
        if text == "\n" {
            processEnterOrReturnEvent()
        }
    }
    
    private func processEnterOrReturnEvent() {
        do {
            try handleListContinuation()
        } catch {
            debugPrint("Failed to process enter/return event: \(error)")
        }
    }
    
    private func handleListContinuation() throws {
        let selectedRange = self.selectedRange
        let content = text as NSString
        
        let location = selectedRange.location - 1
        guard location >= 0 else { return }
        
        let start = getLocationOfFirstNewline(fromString: content, beforeLocation: UInt(location))
        let end = UInt(location)
        let range = NSRange(location: Int(start), length: Int(end - start))
        let line = content.substring(with: range) as NSString
        
        let regex = try NSRegularExpression(pattern: "^(\\s*)((?:(?:\\*|\\+|-|)\\s+)?)((?:\\d+\\.\\s+)?)(\\S)?", options: .anchorsMatchLines)
        guard let result = regex.firstMatch(in: line as String, range: NSRange(location: 0, length: line.length)) else { return }
        
        let indent = line.substring(with: result.range(at: 1)) as NSString
        let prefix = getPrefix(result: result, line: line, start: start, indent: indent, selectedRange: selectedRange, range: range)
        
        guard prefix.length > 0 else { return }
        
        var targetRange = selectedRange
        targetRange.length = 0
        
        let extendedContent = "\(indent)\(prefix) " as NSString
        let finalContent = getExtendedContent(line: line, indent: indent, prefix: prefix, extendedContent: extendedContent, range: range)
        
        if finalContent.length > 0 {
            if let textRange = convertToTextRange(from: targetRange) {
                replace(textRange, withText: finalContent as String)
            }
        }
    }
    
    private func convertToTextRange(from nsRange: NSRange) -> UITextRange? {
        guard let fromPosition = position(from: beginningOfDocument, offset: nsRange.location),
              let toPosition = position(from: fromPosition, offset: nsRange.length)
        else {
            return nil
        }
        return textRange(from: fromPosition, to: toPosition)
    }
    
    private func getLocationOfFirstNewline(fromString string: NSString, beforeLocation loc: UInt) -> UInt {
        let location = min(UInt(string.length), loc)
        var start: UInt = 0
        
        let searchRange = NSRange(location: 0, length: Int(location))
        let range = string.rangeOfCharacter(from: .newlines,
                                          options: .backwards,
                                          range: searchRange)
        if range.location != NSNotFound {
            start = UInt(range.location + 1)
        }
        
        return start
    }
    
    private func replaceText(in nsRange: NSRange, with text: String) {
        if let textRange = convertToTextRange(from: nsRange) {
            replace(textRange, withText: text)
        }
    }
    
    private func getPrefix(result: NSTextCheckingResult, line: NSString, start: UInt, indent: NSString, selectedRange: NSRange, range: NSRange) -> NSString {
        let isUnordered = result.range(at: 2).length != 0
        let isOrdered = result.range(at: 3).length != 0
        let isPreviousLineEmpty = result.range(at: 4).length == 0
        
        if isPreviousLineEmpty {
            var replaceRange = NSRange(location: NSNotFound, length: 0)
            if isUnordered {
                replaceRange = result.range(at: 2)
            } else if isOrdered {
                replaceRange = result.range(at: 3)
            }
            
            if replaceRange.length > 0 {
                replaceRange.location += Int(start)
                if indent.length > 0 {
                    var targetRange = selectedRange
                    targetRange.length = 0
                    replaceText(in: targetRange, with: indent as String)
                }
                replaceText(in: range, with: "")
            }
            return ""
        }
        
        if isUnordered {
            var theRange = result.range(at: 2)
            theRange.length -= 1
            return line.substring(with: theRange) as NSString
        }
        
        if isOrdered {
            var theRange = result.range(at: 3)
            theRange.length -= 1
            let capturedIndex = (line.substring(with: theRange) as NSString).integerValue
            return "\(capturedIndex + 1)." as NSString
        }
        
        return ""
    }
    
    private func getExtendedContent(line: NSString, indent: NSString, prefix: NSString, extendedContent: NSString, range: NSRange) -> NSString {
        if line.hasPrefix("- [ ] ") || line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") {
            if line.length == "- [ ] ".count {
                replaceText(in: range, with: "")
                return ""
            } else {
                return "\(indent)\(prefix) [ ] " as NSString
            }
        }
        return extendedContent
    }
}


struct WriterView: UIViewRepresentable {
    let writerID: UUID

    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WriterEditorTextView {
        debugPrint("Writer view init: \(writerID)")
        let frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        let textView = WriterEditorTextView(frame: frame, textContainer: nil)
        textView.delegate = context.coordinator
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.text = text
        NotificationCenter.default.addObserver(forName: .insertAttachment, object: nil, queue: .main) { n in
            guard let attachment = n.object as? PlanetArticleAttachment else { return }
            var markdown = attachment.markdownImageValue()
            if let theRange: UITextRange = textView.selectedTextRange {
                let cursorPosition = textView.offset(from: textView.beginningOfDocument, to: theRange.start)
                if cursorPosition == 0, markdown.hasPrefix("\n") {
                    markdown.removeFirst(1)
                }
            }
            textView.insertText(markdown)
        }
        NotificationCenter.default.addObserver(forName: .removeAttachment, object: nil, queue: .main) { n in
            guard let attachment = n.object as? PlanetArticleAttachment else { return }
            let markdown: String = {
                let m = attachment.markdownImageValue()
                if m.hasPrefix("\n") {
                    if m.hasSuffix("\n") {
                        return String(m.dropFirst().dropLast())
                    } else {
                        return String(m.dropFirst())
                    }
                }
                return m
            }()
            textView.text = textView.text.replacingOccurrences(of: markdown, with: "")
            context.coordinator.parent.text = textView.text
        }
        return textView
    }
    
    func updateUIView(_ uiView: WriterEditorTextView, context: Context) {
        if uiView.text != text {
            let selectedRange = uiView.selectedRange
            uiView.text = text
            uiView.selectedRange = selectedRange
        }
    }
}


extension WriterView {
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: WriterView
        
        init(_ parent: WriterView) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.text = textView.text
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
}
