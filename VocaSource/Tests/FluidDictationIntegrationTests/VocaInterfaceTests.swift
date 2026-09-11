import AppKit
import ApplicationServices
@testable import FluidVoice_Debug
import XCTest

@MainActor
final class VocaInterfaceTests: XCTestCase {
    func testBoundDictationAppendFollowsEndInUTF16() {
        let editor = VocaPlaceholderTextView()
        editor.string = "Hi 👋"
        editor.setSelectedRange(NSRange(location: editor.string.utf16.count, length: 0))
        editor.replaceBoundText("Hi 👋 welcome")
        XCTAssertEqual(editor.string, "Hi 👋 welcome")
        XCTAssertEqual(editor.selectedRange().location, editor.string.utf16.count)
    }

    func testBoundUpdatePreservesAnInteriorSelection() {
        let editor = VocaPlaceholderTextView()
        editor.string = "Hello world"
        editor.setSelectedRange(NSRange(location: 2, length: 3))
        editor.replaceBoundText("Hello world again")
        XCTAssertEqual(editor.selectedRange(), NSRange(location: 2, length: 3))
    }

    func testClearingBoundTextClampsSelection() {
        let editor = VocaPlaceholderTextView()
        editor.string = "A long sentence"
        editor.setSelectedRange(NSRange(location: 8, length: 4))
        editor.replaceBoundText("")
        XCTAssertEqual(editor.selectedRange(), NSRange(location: 0, length: 0))
    }

    func testBoundUpdateDoesNotOverwriteMarkedComposition() {
        let editor = VocaPlaceholderTextView()
        editor.setMarkedText("に", selectedRange: NSRange(location: 1, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertTrue(editor.hasMarkedText())
        editor.replaceBoundText("unrelated update")
        XCTAssertEqual(editor.string, "に")
    }

    func testVOCAHasNoInheritedAnalyticsConfiguration() {
        XCTAssertTrue(Bundle.main.bundleIdentifier?.hasPrefix("com.voca.") == true)
        XCTAssertFalse(AnalyticsConfig.fromBundle().isConfigured)
    }

    func testReleaseNotesCannotFetchUpstreamForVOCA() async {
        do {
            _ = try await SimpleUpdater.shared.fetchRecentReleaseNotes(owner: "altic-dev", repo: "Fluid-oss", limit: 1, includePrerelease: false)
            XCTFail("A VOCA preview must not fetch another product’s release feed")
        } catch SimpleUpdateError.vocaChannelNotConfigured {
            // Expected before any network request.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testUndoRestoresReplacedTextAndPreservesLaterAppend() throws {
        let plan = try XCTUnwrap(VocaInsertionRecovery.undoPlan(before: "Dear team,", selection: NSRange(location: 5, length: 4),
            inserted: "Alex", current: "Dear Alex, See you Friday."))
        XCTAssertEqual(("Dear Alex, See you Friday." as NSString).replacingCharacters(in: plan.range, with: plan.replacement), "Dear team, See you Friday.")
    }

    func testUndoDoesNotDeleteAnEditInsideTheRecordedDocument() {
        XCTAssertNil(VocaInsertionRecovery.undoPlan(before: "Hello world", selection: NSRange(location: 6, length: 5),
            inserted: "there", current: "Goodbye there"))
        XCTAssertNil(VocaInsertionRecovery.undoPlan(before: "Hello world", selection: NSRange(location: 6, length: 5),
            inserted: "there", current: "Hello everyone"))
    }

    func testUndoRefusesMissingOrTruncatedInsertion() {
        XCTAssertNil(VocaInsertionRecovery.undoPlan(before: "Draft: ", selection: NSRange(location: 7, length: 0), inserted: "hello", current: "Draft: hel"))
    }

    func testUndoUsesUTF16OffsetsWithEmoji() throws {
        let plan = try XCTUnwrap(VocaInsertionRecovery.undoPlan(before: "👋 name", selection: NSRange(location: 3, length: 4),
            inserted: "Zoë 👩🏽‍💻", current: "👋 Zoë 👩🏽‍💻!"))
        XCTAssertEqual(("👋 Zoë 👩🏽‍💻!" as NSString).replacingCharacters(in: plan.range, with: plan.replacement), "👋 name!")
    }

    func testUndoRejectsCanonicallyEquivalentButDifferentUTF16Document() {
        XCTAssertNil(VocaInsertionRecovery.undoPlan(before: "é", selection: NSRange(location: 1, length: 0),
            inserted: " hello", current: "e\u{301} hello"))
    }

    func testUndoRejectsInvalidSelectionsWithoutOverflow() {
        for range in [NSRange(location: NSNotFound, length: 0), NSRange(location: 1, length: Int.max), NSRange(location: 20, length: 1)] {
            XCTAssertNil(VocaInsertionRecovery.undoPlan(before: "draft", selection: range, inserted: "word", current: "draftword"))
        }
    }

    func testEmptyInsertionCannotCreateAnUndoPlan() {
        XCTAssertNil(VocaInsertionRecovery.undoPlan(before: "draft", selection: NSRange(location: 5, length: 0), inserted: "", current: "draft"))
    }

    func testPillPrefersAboveTheCaretWhenItFits() {
        let caret = CGRect(x: 450, y: 350, width: 1, height: 20)
        let frame = VocaDestination.pillFrame(caret: caret, size: CGSize(width: 200, height: 80), visible: CGRect(x: 0, y: 0, width: 1000, height: 800))
        XCTAssertGreaterThan(frame.minY, caret.maxY)
        XCTAssertFalse(frame.intersects(caret))
    }

    func testPillMovesBelowAtTheTopEdge() {
        let caret = CGRect(x: 450, y: 775, width: 1, height: 20)
        let frame = VocaDestination.pillFrame(caret: caret, size: CGSize(width: 200, height: 80), visible: CGRect(x: 0, y: 0, width: 1000, height: 800))
        XCTAssertLessThan(frame.maxY, caret.minY)
    }

    func testPillUsesTheSideWhenVerticalSpaceIsLimited() {
        let caret = CGRect(x: 400, y: 50, width: 1, height: 20)
        let visible = CGRect(x: 0, y: 0, width: 1000, height: 140)
        let frame = VocaDestination.pillFrame(caret: caret, size: CGSize(width: 200, height: 80), visible: visible)
        XCTAssertGreaterThan(frame.minX, caret.maxX)
        XCTAssertTrue(visible.contains(frame))
    }

    func testPillStaysOnExternalDisplayWithNegativeCoordinates() {
        let visible = CGRect(x: -1440, y: -200, width: 1440, height: 900)
        let caret = CGRect(x: -1430, y: 300, width: 1, height: 18)
        let frame = VocaDestination.pillFrame(caret: caret, size: CGSize(width: 200, height: 80), visible: visible)
        XCTAssertTrue(visible.contains(frame))
        XCTAssertFalse(frame.intersects(caret))
    }

    func testCaretPositionRoundTripsWithExistingPositions() throws {
        for position in SettingsStore.OverlayPosition.allCases {
            let data = try JSONEncoder().encode(position)
            XCTAssertEqual(try JSONDecoder().decode(SettingsStore.OverlayPosition.self, from: data), position)
        }
        XCTAssertEqual(SettingsStore.OverlayPosition(rawValue: "top"), .top)
        XCTAssertEqual(SettingsStore.OverlayPosition(rawValue: "bottom"), .bottom)
    }

    func testOlderReceiptCannotOverwriteNewerRecovery() {
        let recovery = VocaInsertionRecovery()
        let older = UUID(), newer = UUID()
        recovery.begin(older)
        recovery.begin(newer)
        recovery.unavailable(text: "new words", message: "new", id: newer)
        recovery.record(before: nil, inserted: "old words", verified: false, id: older)
        XCTAssertEqual(recovery.recoveryText, "new words")
        XCTAssertEqual(recovery.message, "new")
        XCTAssertNil(recovery.receipt)
    }

    func testModelAdviceKeepsIntelOnUniversalProvidersAndLowMemoryOnLightModels() {
        for throughput in [5.0, 25, 200] {
            XCTAssertEqual(VocaModelAdvisor.recommend(appleSilicon: true, memoryGB: 4, gigaFlops: throughput).provider, .openai)
            XCTAssertEqual(VocaModelAdvisor.recommend(appleSilicon: false, memoryGB: 32, gigaFlops: throughput).provider, .openai)
        }
    }

    func testModelBenchmarkShipsItsLocalSample() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "voca_benchmark", withExtension: "wav"))
        XCTAssertGreaterThan(try Data(contentsOf: url).count, 1000)
    }
}

extension VocaInterfaceTests {
    private func spokenPauseDetector() -> VocaPauseDetector {
        var detector = VocaPauseDetector()
        for step in 0...10 { detector.hear(level: 0.4, at: Double(step) / 10) }
        return detector
    }

    func testAutomaticFinishDoesNotEndBeforeAnySpeech() {
        var detector = VocaPauseDetector()
        detector.hear(level: 0, at: 40)
        XCTAssertNil(detector.remaining(at: 40, pause: 3, text: ""))
    }
    func testAutomaticFinishShowsCountdownThenFinishes() {
        var detector = spokenPauseDetector()
        detector.hear(level: 0, at: 13)
        XCTAssertEqual(detector.remaining(at: 13, pause: 12, text: "A complete thought."), 3)
        detector.hear(level: 0, at: 16)
        XCTAssertEqual(detector.remaining(at: 16, pause: 12, text: "A complete thought."), 0)
    }
    func testResumingSpeechCancelsCountdown() {
        var detector = spokenPauseDetector()
        detector.hear(level: 0.4, at: 14)
        XCTAssertNil(detector.remaining(at: 14, pause: 12, text: "More thoughts"))
    }
    func testMissingAudioFramesNeverTriggerFinish() {
        let detector = spokenPauseDetector()
        XCTAssertNil(detector.remaining(at: 40, pause: 3, text: "Finished."))
    }
    func testUnfinishedPhraseGetsThinkingTime() {
        var detector = spokenPauseDetector()
        detector.hear(level: 0, at: 10)
        XCTAssertNil(detector.remaining(at: 10, pause: 3, text: "I think because"))
        detector.hear(level: 0, at: 21)
        XCTAssertEqual(detector.remaining(at: 21, pause: 3, text: "I think because"), 3)
    }
    func testKeepListeningSuspendsAutomaticFinish() {
        var detector = spokenPauseDetector()
        detector.paused = true
        detector.hear(level: 0, at: 50)
        XCTAssertNil(detector.remaining(at: 50, pause: 3, text: "Done."))
    }
    func testShortNoiseBurstDoesNotArmAutomaticFinish() {
        var detector = VocaPauseDetector()
        detector.hear(level: 0.8, at: 0)
        detector.hear(level: 0.8, at: 0.1)
        detector.hear(level: 0, at: 30)
        XCTAssertNil(detector.remaining(at: 30, pause: 3, text: ""))
    }
    func testPersonalStyleRequiresEnoughWriting() {
        XCTAssertNil(VocaPersonalStyle.analyze("A short sample."))
    }
    func testPersonalStyleNeverCopiesPrivateSampleContentToPrompt() {
        let sample = Array(repeating: "secret-project-amber is something I write about in my notes.", count: 12).joined(separator: "\n\n")
        let analysis = VocaPersonalStyle.analyze(sample)
        XCTAssertNotNil(analysis)
        XCTAssertFalse(analysis?.prompt.contains("secret-project-amber") ?? true)
        XCTAssertTrue(analysis?.traits.contains("Use short paragraphs with clear breaks between ideas.") ?? false)
    }
    func testWritingTemplatesAreDistinctAndComplete() {
        XCTAssertEqual(VocaWritingTemplate.allCases.count, 12)
        XCTAssertEqual(Set(VocaWritingTemplate.allCases.map(\.prompt)).count, 12)
        XCTAssertTrue(VocaWritingTemplate.allCases.allSatisfy { !$0.detail.isEmpty && !$0.symbol.isEmpty })
    }
    func testSlowCleanupTimesOutWithoutWaitingForLateProvider() async {
        let monitor = VocaCleanupMonitor()
        do {
            let _: String = try await monitor.run(id: UUID(), label: "Slow test", warningAfter: 0.005, deadline: 0.02) {
                try? await Task.sleep(for: .milliseconds(100))
                return "Late result"
            }
            XCTFail("Expected timeout")
        } catch { XCTAssertTrue(error is VocaCleanupError) }
        XCTAssertFalse(monitor.running)
        let value = try? await monitor.run(id: UUID(), label: "Fast test") { "New result" }
        XCTAssertEqual(value, "New result")
        try? await Task.sleep(for: .milliseconds(120))
        XCTAssertTrue(monitor.lastResult.hasPrefix("Fast test finished"))
    }
    func testUserCanBypassCleanupWithoutWaitingForProvider() async {
        let monitor = VocaCleanupMonitor()
        let task = Task { @MainActor in
            try await monitor.run(id: UUID(), label: "Test") {
                try await Task.sleep(for: .seconds(5))
                return "Too late"
            }
        }
        while !monitor.running { await Task.yield() }
        monitor.useOriginal()
        do { _ = try await task.value; XCTFail("Expected skipped cleanup") }
        catch { XCTAssertTrue(error is VocaCleanupError) }
        XCTAssertFalse(monitor.running)
    }
}

extension VocaInterfaceTests {
    func testDiagnosticLoggingRequiresNewExplicitOptIn() {
        let name = "VOCA.Diagnostics.Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(true, forKey: "EnableDebugLogs")
        XCTAssertFalse(DebugLogger.diagnosticsEnabled(in: defaults))
        defaults.set(true, forKey: "voca.diagnostics.enabled")
        XCTAssertTrue(DebugLogger.diagnosticsEnabled(in: defaults))
    }
    func testDiagnosticCredentialRedaction() {
        let message = "Authorization: Bearer abcdef12345 x-api-key: secret12345 sk-abcdefghijklmnop"
        let redacted = DebugLogger.redactCredentials(message)
        XCTAssertFalse(redacted.contains("abcdef12345"))
        XCTAssertFalse(redacted.contains("secret12345"))
        XCTAssertFalse(redacted.contains("sk-abcdefghijklmnop"))
    }
}
