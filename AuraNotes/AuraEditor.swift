import SwiftUI
import AppKit

enum EditorAction: Equatable {
    case bold
    case italic
    case heading(CGFloat)
    case body
    case list
    case table
}

struct AuraEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var action: EditorAction?
    @Binding var isTextSelected: Bool
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        
        let textView = NSTextView()
        textView.isRichText = true
        textView.allowsUndo = true
        textView.drawsBackground = false
        
        // Estilo Hacker
        textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = .white
        textView.insertionPointColor = .white
        textView.selectedTextAttributes = [.backgroundColor: NSColor.white.withAlphaComponent(0.2)]
        
        // Márgenes
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 0, height: 20)
        
        textView.delegate = context.coordinator
        
        scrollView.documentView = textView
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        // 1. ACCIONES
        if let currentAction = action {
            DispatchQueue.main.async {
                context.coordinator.perform(action: currentAction, on: textView)
                self.action = nil
            }
            return
        }
        
        // 2. ACTUALIZAR TEXTO
        if !context.coordinator.isEditing {
            if let data = Data(base64Encoded: text),
               let newAttrib = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
                
                if textView.textStorage?.string != newAttrib.string {
                    textView.textStorage?.setAttributedString(newAttrib)
                    textView.textColor = .white
                    textView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AuraEditor
        var isEditing = false
        
        init(_ parent: AuraEditor) {
            self.parent = parent
        }
        
        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let hasSelection = textView.selectedRange().length > 0
            
            if parent.isTextSelected != hasSelection {
                DispatchQueue.main.async {
                    self.parent.isTextSelected = hasSelection
                }
            }
        }
        
        func perform(action: EditorAction, on textView: NSTextView) {
            self.isEditing = true
            let range = textView.selectedRange()
            guard let storage = textView.textStorage else { return }
            
            switch action {
            case .bold:
                toggleTrait(.boldFontMask, on: textView, range: range)
            case .italic:
                toggleTrait(.italicFontMask, on: textView, range: range)
            case .heading(let size):
                let paraRange = (storage.string as NSString).paragraphRange(for: range)
                let font = NSFont.monospacedSystemFont(ofSize: size, weight: .bold)
                storage.addAttribute(.font, value: font, range: paraRange)
                
            case .body:
                let paraRange = (storage.string as NSString).paragraphRange(for: range)
                let font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
                storage.addAttribute(.font, value: font, range: paraRange)
                
            case .list:
                applyListStyle(to: textView, range: range)
                
            case .table:
                textView.orderFrontTablePanel(textView)
            }
            
            parent.saveText(from: textView)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isEditing = false
            }
        }
        
        private func toggleTrait(_ trait: NSFontTraitMask, on textView: NSTextView, range: NSRange) {
            let fontManager = NSFontManager.shared
            guard let storage = textView.textStorage else { return }
            
            if range.length > 0 {
                storage.enumerateAttribute(.font, in: range, options: []) { (value, subRange, stop) in
                    if let font = value as? NSFont {
                        let newFont = fontManager.traits(of: font).contains(trait)
                            ? fontManager.convert(font, toNotHaveTrait: trait)
                            : fontManager.convert(font, toHaveTrait: trait)
                        storage.addAttribute(.font, value: newFont, range: subRange)
                    }
                }
            } else {
                let currentFont = textView.typingAttributes[.font] as? NSFont ?? textView.font ?? NSFont.systemFont(ofSize: 14)
                let newFont = fontManager.traits(of: currentFont).contains(trait)
                    ? fontManager.convert(currentFont, toNotHaveTrait: trait)
                    : fontManager.convert(currentFont, toHaveTrait: trait)
                
                var newAttributes = textView.typingAttributes
                newAttributes[.font] = newFont
                textView.typingAttributes = newAttributes
            }
        }
        
        private func applyListStyle(to textView: NSTextView, range: NSRange) {
            guard let storage = textView.textStorage else { return }
            
            // Detectar el párrafo completo
            let paragraphRange = (storage.string as NSString).paragraphRange(for: range)
            
            // CORREGIDO: Usamos .disc (círculo relleno) o .circle (círculo vacío)
            let marker = NSTextList.MarkerFormat.disc
            let textList = NSTextList(markerFormat: marker, options: 0)
            
            let currentStyle = (storage.attribute(.paragraphStyle, at: paragraphRange.location, effectiveRange: nil) as? NSParagraphStyle) ?? NSParagraphStyle.default
            
            guard let mutableStyle = currentStyle.mutableCopy() as? NSMutableParagraphStyle else { return }
            
            let lists = mutableStyle.textLists
            if lists.contains(where: { $0.markerFormat == marker }) {
                mutableStyle.textLists = []
                mutableStyle.headIndent = 0
                mutableStyle.firstLineHeadIndent = 0
            } else {
                mutableStyle.textLists = [textList]
                mutableStyle.headIndent = 20
                mutableStyle.firstLineHeadIndent = 0
            }
            
            storage.addAttribute(.paragraphStyle, value: mutableStyle, range: paragraphRange)
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            isEditing = true
            parent.saveText(from: textView)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isEditing = false
            }
        }
    }
    
    func saveText(from textView: NSTextView) {
        if let rtfData = textView.attributedString().rtf(from: NSRange(location: 0, length: textView.string.count), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
            self.text = rtfData.base64EncodedString()
        }
    }
}
