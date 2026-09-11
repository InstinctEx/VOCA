import AppKit
import ApplicationServices
import Combine

/// Accessibility snapshots stay in memory. We never log a destination's document text.
enum VocaDestination {
    struct Snapshot {
        let target: TypingService.CapturedFocusTarget
        let value: String
        let selection: NSRange
    }

    static func exactPrefix(_ value: String, _ prefix: String) -> Bool {
        value.utf16.starts(with: prefix.utf16)
    }

    static func exactEqual(_ first: String?, _ second: String) -> Bool {
        guard let first else { return false }
        return first.utf16.elementsEqual(second.utf16)
    }

    static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    static func range(_ element: AXUIElement) -> NSRange? {
        guard let value = attribute(element, kAXSelectedTextRangeAttribute), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        guard AXValueGetValue(unsafeBitCast(value, to: AXValue.self), .cfRange, &range), range.location >= 0, range.length >= 0 else { return nil }
        return NSRange(location: range.location, length: range.length)
    }

    static func snapshot(_ target: TypingService.CapturedFocusTarget) -> Snapshot? {
        AXUIElementSetMessagingTimeout(target.element, 0.15)
        guard !target.isSecureTextField,
              let value = attribute(target.element, kAXValueAttribute) as? String,
              value.utf16.count <= 1_000_000,
              let range = range(target.element), range.location <= value.utf16.count,
              range.length <= value.utf16.count - range.location else { return nil }
        return Snapshot(target: target, value: value, selection: range)
    }

    static func canReplaceSelection(_ element: AXUIElement) -> Bool {
        var textSettable = DarwinBoolean(false)
        var rangeSettable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &textSettable) == .success
            && AXUIElementIsAttributeSettable(element, kAXSelectedTextRangeAttribute as CFString, &rangeSettable) == .success
            && textSettable.boolValue && rangeSettable.boolValue
    }

    static func setRange(_ range: NSRange, on element: AXUIElement) -> Bool {
        var value = CFRange(location: range.location, length: range.length)
        guard let axValue = AXValueCreate(.cfRange, &value) else { return false }
        return AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, axValue) == .success
    }

    /// AX uses a top-left origin on the primary display; AppKit uses bottom-left.
    @MainActor static func caretRect(for target: TypingService.CapturedFocusTarget) -> NSRect? {
        AXUIElementSetMessagingTimeout(target.element, 0.15)
        guard !target.isSecureTextField, let range = range(target.element), let primary = NSScreen.screens.first else { return nil }
        var cfRange = CFRange(location: range.location + range.length, length: 0)
        guard let parameter = AXValueCreate(.cfRange, &cfRange) else { return nil }
        var result: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(target.element, kAXBoundsForRangeParameterizedAttribute as CFString, parameter, &result) == .success,
              let result, CFGetTypeID(result) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(unsafeBitCast(result, to: AXValue.self), .cgRect, &rect),
              rect.height > 0, rect.height < 200, rect.width < 100,
              rect.minX.isFinite, rect.minY.isFinite else { return nil }
        return NSRect(x: rect.minX, y: primary.frame.maxY - rect.maxY, width: max(1, rect.width), height: rect.height)
    }

    static func pillFrame(caret: CGRect, size: CGSize, visible: CGRect) -> CGRect {
        let safe = visible.insetBy(dx: 12, dy: 12)
        let gap: CGFloat = 12
        let candidates = [
            CGRect(x: caret.midX - size.width / 2, y: caret.maxY + gap, width: size.width, height: size.height),
            CGRect(x: caret.midX - size.width / 2, y: caret.minY - gap - size.height, width: size.width, height: size.height),
            CGRect(x: caret.maxX + gap, y: caret.midY - size.height / 2, width: size.width, height: size.height),
            CGRect(x: caret.minX - gap - size.width, y: caret.midY - size.height / 2, width: size.width, height: size.height),
        ]
        // Prefer above the line, then below. Side placements win when vertical space is limited.
        if let fit = candidates.first(where: { safe.contains($0) }) { return fit }
        let clamped = candidates.map { rect in
            CGRect(x: max(safe.minX, min(rect.minX, safe.maxX - size.width)),
                   y: max(safe.minY, min(rect.minY, safe.maxY - size.height)), width: size.width, height: size.height)
        }
        return clamped.first(where: { !$0.intersects(caret.insetBy(dx: -4, dy: -4)) }) ?? clamped[0]
    }
}

/// One receipt, with conservative optimistic validation. Never sends a blind Command-Z.
@MainActor final class VocaInsertionRecovery: ObservableObject {
    static let shared = VocaInsertionRecovery()
    struct Receipt {
        let before: VocaDestination.Snapshot
        let inserted: String
        let expected: String
    }
    @Published private(set) var receipt: Receipt?
    @Published private(set) var message = "Your next verified insertion will be available here."
    @Published private(set) var recoveryText = ""

    private var generation = UUID()
    func begin(_ id: UUID) {
        self.generation = id
        self.receipt = nil
        self.recoveryText = ""
        self.message = "Checking the latest insertion…"
    }

    func unavailable(text: String, message: String, id: UUID) {
        guard self.generation == id else { return }
        self.receipt = nil
        self.recoveryText = text
        self.message = message
    }

    func record(before: VocaDestination.Snapshot?, inserted: String, verified: Bool, id: UUID) {
        guard id == self.generation else { return }
        self.receipt = nil
        self.recoveryText = inserted
        guard let before, verified else {
            self.message = "This app did not expose enough text to verify undo. Your words are available to copy."
            return
        }
        let expected = (before.value as NSString).replacingCharacters(in: before.selection, with: inserted)
        self.receipt = Receipt(before: before, inserted: inserted, expected: expected)
        self.message = "Inserted into \(NSRunningApplication(processIdentifier: before.target.pid)?.localizedName ?? "your app"). Undo checks the field before changing it."
    }

    /// Later appends are preserved; edits within the recorded document require manual recovery.
    nonisolated static func undoPlan(before: String, selection: NSRange, inserted: String, current: String) -> (range: NSRange, replacement: String)? {
        guard selection.location >= 0, selection.length >= 0, selection.location <= before.utf16.count,
              selection.length <= before.utf16.count - selection.location, !inserted.isEmpty else { return nil }
        let expected = (before as NSString).replacingCharacters(in: selection, with: inserted)
        guard VocaDestination.exactPrefix(current, expected) else { return nil }
        return (NSRange(location: selection.location, length: inserted.utf16.count), (before as NSString).substring(with: selection))
    }

    func undo() {
        guard AXIsProcessTrusted(), let receipt, let current = VocaDestination.snapshot(receipt.before.target),
              VocaDestination.canReplaceSelection(current.target.element),
              let plan = Self.undoPlan(before: receipt.before.value, selection: receipt.before.selection,
                                       inserted: receipt.inserted, current: current.value) else {
            self.message = "Undo stopped: the field changed, closed, or does not support precise edits. Use the saved words below to recover manually."
            return
        }
        let element = current.target.element
        guard VocaDestination.setRange(plan.range, on: element) else {
            self.message = "This app does not allow VOCA to select the inserted words. Nothing was deleted."
            return
        }
        // Re-read after selecting: document changes or a redirected selection invalidate the operation.
        guard VocaDestination.exactEqual(VocaDestination.attribute(element, kAXValueAttribute) as? String, current.value),
              VocaDestination.range(element) == plan.range else {
            self.message = "The document changed during undo. Nothing was deleted."
            return
        }
        let result = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, plan.replacement as CFString)
        let expected = (current.value as NSString).replacingCharacters(in: plan.range, with: plan.replacement)
        guard result == .success, VocaDestination.exactEqual(VocaDestination.attribute(element, kAXValueAttribute) as? String, expected) else {
            self.receipt = nil
            self.message = "The app could not confirm the undo. Check your document; the original dictation is still available below."
            return
        }
        let newCaret = min(expected.utf16.count, current.selection.location >= NSMaxRange(plan.range)
            ? current.selection.location - plan.range.length + plan.replacement.utf16.count : plan.range.location + plan.replacement.utf16.count)
        _ = VocaDestination.setRange(NSRange(location: newCaret, length: 0), on: element)
        self.receipt = nil
        self.message = "Undone. Any text appended afterward was kept."
    }
}
