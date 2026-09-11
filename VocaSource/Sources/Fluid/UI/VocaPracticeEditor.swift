import AppKit
import SwiftUI

/// Placeholder and insertion point share TextKit's font, container, and origin.
struct VocaPracticeEditor: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var focus: FocusState<Bool>.Binding
    var placeholderColor: Color

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        let editor = VocaPlaceholderTextView()
        editor.font = .systemFont(ofSize: 17)
        editor.isRichText = false
        editor.allowsUndo = true
        editor.drawsBackground = false
        editor.textColor = .labelColor
        editor.insertionPointColor = .controlAccentColor
        editor.textContainerInset = NSSize(width: 5, height: 8)
        editor.textContainer?.lineFragmentPadding = 0
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.containerSize = NSSize(width: scroll.contentSize.width, height: .greatestFiniteMagnitude)
        editor.delegate = context.coordinator
        editor.setAccessibilityLabel("Dictation practice")
        scroll.documentView = editor
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let editor = scroll.documentView as? VocaPlaceholderTextView else { return }
        editor.replaceBoundText(self.text)
        editor.placeholder = self.placeholder
        editor.placeholderColor = NSColor(self.placeholderColor)
        editor.needsDisplay = true
        if self.focus.wrappedValue, let window = editor.window, window.firstResponder !== editor {
            // Wait for SwiftUI to finish updating before changing its FocusState.
            DispatchQueue.main.async { [weak editor, weak coordinator = context.coordinator] in
                guard let editor, let coordinator, coordinator.parent.focus.wrappedValue,
                      let window = editor.window, window.isKeyWindow else { return }
                window.makeFirstResponder(editor)
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: VocaPracticeEditor
        init(_ parent: VocaPracticeEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            self.parent.text = editor.string
            editor.needsDisplay = true
        }
        func textDidBeginEditing(_ notification: Notification) { self.parent.focus.wrappedValue = true }
        func textDidEndEditing(_ notification: Notification) { self.parent.focus.wrappedValue = false }
    }
}

final class VocaPlaceholderTextView: NSTextView {
    var placeholder = ""
    var placeholderColor: NSColor = .placeholderTextColor

    func replaceBoundText(_ text: String) {
        guard self.string != text, !self.hasMarkedText() else { return }
        let selection = self.selectedRange()
        let oldLength = self.string.utf16.count
        self.string = text
        let newLength = text.utf16.count
        // Follow a dictation append when the cursor was at the end; clamp other selections.
        let location = selection.location == oldLength ? newLength : min(selection.location, newLength)
        self.setSelectedRange(NSRange(location: location, length: min(selection.length, newLength - location)))
        self.needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard self.string.isEmpty, !self.placeholder.isEmpty, let font = self.font, let container = self.textContainer else { return }
        let storage = NSTextStorage(string: self.placeholder, attributes: [.font: font, .foregroundColor: self.placeholderColor])
        let layout = NSLayoutManager()
        let placeholderContainer = NSTextContainer(size: container.containerSize)
        placeholderContainer.lineFragmentPadding = container.lineFragmentPadding
        layout.addTextContainer(placeholderContainer)
        storage.addLayoutManager(layout)
        layout.drawGlyphs(forGlyphRange: layout.glyphRange(for: placeholderContainer), at: self.textContainerOrigin)
    }
}
