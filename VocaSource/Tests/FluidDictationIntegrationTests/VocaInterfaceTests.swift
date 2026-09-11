import AppKit
import ApplicationServices
@testable import FluidVoice_Debug
import XCTest

@MainActor
final class VocaInterfaceTests: XCTestCase {
    func testVerifiedLocalQwenAppearsInCustomPromptProviders() {
        let viewModel = AIEnhancementSettingsViewModel(settings: .shared, menuBarManager: MenuBarManager(), promptTest: .shared)
        viewModel.cachedVerifiedProviderItems = [.init(id: "voca-polish", name: "VOCA Polish", isBuiltIn: true)]
        XCTAssertEqual(viewModel.verifiedPromptProviders().map(\.id), ["voca-polish"])
        viewModel.cachedVerifiedProviderItems = []
        XCTAssertTrue(viewModel.verifiedPromptProviders().isEmpty)
    }

    func testHotkeyInitializationStopsRetryingAfterFiveFailures() async throws {
        let manager = GlobalHotkeyManager(asrService: ASRService(), primaryShortcuts: [], promptModeShortcut: .init(keyCode: 15, modifierFlags: [.option]), commandModeShortcut: nil, rewriteModeShortcut: .init(keyCode: 15, modifierFlags: [.option]), promptModeShortcutEnabled: false, commandModeShortcutEnabled: false, rewriteModeShortcutEnabled: false, initializeAutomatically: false)
        var attempts = 0
        manager.retryDelay = 0.01
        manager.eventTapSetupOverride = { attempts += 1; return false }
        manager.setupGlobalHotkeyWithRetry()
        try await Task.sleep(for: .milliseconds(160))
        XCTAssertEqual(attempts, 5, "Failed listener startup must terminate, not restart attempt one forever")
    }

    func testHotkeyLateSuccessNotifiesUIAndRestartCancelsOldRetries() async throws {
        let manager = GlobalHotkeyManager(asrService: ASRService(), primaryShortcuts: [], promptModeShortcut: .init(keyCode: 15, modifierFlags: [.option]), commandModeShortcut: nil, rewriteModeShortcut: .init(keyCode: 15, modifierFlags: [.option]), promptModeShortcutEnabled: false, commandModeShortcutEnabled: false, rewriteModeShortcutEnabled: false, initializeAutomatically: false)
        manager.retryDelay = 0.01
        var states: [Bool] = []
        manager.setInitializationStatusCallback { states.append($0) }
        var attempts = 0
        manager.eventTapSetupOverride = { attempts += 1; return attempts == 3 }
        manager.setupGlobalHotkeyWithRetry()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(attempts, 3)
        XCTAssertEqual(states.last, true, "Delayed success must reach the Settings badge")
        manager.eventTapSetupOverride = { attempts += 1; return false }
        manager.setupGlobalHotkeyWithRetry()
        try await Task.sleep(for: .milliseconds(15))
        var replacementAttempts = 0
        manager.eventTapSetupOverride = { replacementAttempts += 1; return true }
        manager.setupGlobalHotkeyWithRetry()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(replacementAttempts, 1, "Canceled retries must not rebuild a healthy replacement listener")
        XCTAssertEqual(states.last, true)
    }

    func testMeasuredSpeakingPaceUsesWeightedRawWordsAndActualTime() throws {
        func entry(words: Int, finalWords: Int, ms: Int?, processing: Int = 0) -> TranscriptionHistoryEntry {
            .init(rawText: String(repeating: "word ", count: words), processedText: String(repeating: "word ", count: finalWords), appName: "Test", windowTitle: "", wasAIProcessed: true, aiProcessingDurationMilliseconds: processing, recordingDurationMilliseconds: ms)
        }
        let first = entry(words: 100, finalWords: 80, ms: 60_000, processing: 6000)
        let second = entry(words: 60, finalWords: 60, ms: 30_000)
        let metrics = VocaDictationMetrics(entries: [first, second])
        XCTAssertEqual(try XCTUnwrap(metrics.speakingWPM), 160.0 / 1.5, accuracy: 0.001)
        XCTAssertEqual(metrics.timeSavedMinutes(typingWPM: 40), 1.9, accuracy: 0.001)
        let legacy = entry(words: 30, finalWords: 30, ms: nil)
        let mixed = VocaDictationMetrics(entries: [first, legacy])
        XCTAssertEqual(mixed.unmeasuredWords, 30)
        XCTAssertEqual(mixed.timeSavedMinutes(typingWPM: 40), 1.45, accuracy: 0.001)
        XCTAssertNil(VocaDictationMetrics(entries: []).speakingWPM)
        XCTAssertEqual(metrics.timeSavedMinutes(typingWPM: 0), 0)
        XCTAssertEqual(VocaDictationMetrics(entries: [entry(words: 1, finalWords: 1, ms: 60_000)]).timeSavedMinutes(typingWPM: 40), 0)
        let decoded = try JSONDecoder().decode(TranscriptionHistoryEntry.self, from: JSONEncoder().encode(first))
        XCTAssertEqual(decoded.recordingDurationMilliseconds, 60_000)
        XCTAssertNil(decoded.audio) // Timing does not require storing microphone audio.
        XCTAssertEqual(decoded.replacingAudio(nil).recordingDurationMilliseconds, 60_000)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(first)) as? [String: Any])
        json.removeValue(forKey: "recordingDurationMilliseconds")
        let old = try JSONDecoder().decode(TranscriptionHistoryEntry.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(old.recordingDurationMilliseconds)
    }

    func testPolishRejectsChangedNumbersAndTruncatedAnswers() throws {
        XCTAssertEqual(try VocaPolishPrompt.validate("Meet at 3 pm.", input: "meet at 3 pm", hitLimit: false), "Meet at 3 pm.")
        XCTAssertThrowsError(try VocaPolishPrompt.validate("Meet at 4 pm.", input: "meet at 3 pm", hitLimit: false))
        XCTAssertThrowsError(try VocaPolishPrompt.validate("Meet", input: "meet at 3 pm", hitLimit: true))
        XCTAssertThrowsError(try VocaPolishPrompt.validate("<think>answer", input: "hello", hitLimit: false))
        XCTAssertThrowsError(try VocaPolishPrompt.validate("", input: "hello", hitLimit: false))
    }

    func testSpeechPauseSplitsAtQuietAndKeepsEverySample() {
        let phrase = [Float](repeating: 0.1, count: 32_000)
        let samples = phrase + [Float](repeating: 0, count: 8_000) + phrase
        let ranges = VocaSpeechPauses.ranges(in: samples)
        XCTAssertEqual(ranges.count, 2)
        XCTAssertEqual(ranges.flatMap { Array(samples[$0]) }, samples)
        XCTAssertEqual(VocaSpeechPauses.ranges(in: phrase).count, 1)
        XCTAssertEqual(VocaSpeechPauses.ranges(in: [Float](repeating: 0, count: 80_000)).count, 1)
        XCTAssertEqual(VocaSpeechPauses.ranges(in: phrase + [Float](repeating: 0, count: 1_600) + phrase).count, 1)
    }

    func testMixedLanguageCleanupDoesNotTranslateEitherSpan() throws {
        let input = "this is a test in english αυτο ειναι ενα τεστ στα ελληνικα"
        XCTAssertThrowsError(try VocaPolishPrompt.validate("This is a test in English. This is a test in Greek.", input: input, hitLimit: false))
        XCTAssertEqual(try VocaPolishPrompt.validate("This is a test in English. Αυτό είναι ένα τεστ στα ελληνικά.", input: input, hitLimit: false), "This is a test in English. Αυτό είναι ένα τεστ στα ελληνικά.")
    }

    func testMixedLanguageRealStagesWhenEnabled() async throws {
        guard ProcessInfo.processInfo.environment["VOCA_TEST_MIXED"] == "1" else { throw XCTSkip("Opt-in synthetic bilingual audio") }
        let input = "this is a test in english αυτο ειναι ενα τεστ στα ελληνικα"
        let clean = try await VocaPolishEngine.shared.generate(input, style: VocaPolishPrompt.defaultStyle)
        print("MIXED_CLEANUP: \(clean.outputText)")
        XCTAssertTrue(clean.outputText.lowercased().contains("english"))
        XCTAssertTrue(clean.outputText.lowercased().contains("ελλην"))
        await VocaPolishEngine.shared.unload()
        let stored = UserDefaults.standard.object(forKey: "voca.multilingualPauses")
        UserDefaults.standard.set(true, forKey: "voca.multilingualPauses")
        defer {
            if let stored { UserDefaults.standard.set(stored, forKey: "voca.multilingualPauses") }
            else { UserDefaults.standard.removeObject(forKey: "voca.multilingualPauses") }
        }
        let provider = FluidAudioProvider(modelOverride: .parakeetTDT, configureWordBoosting: false)
        try await provider.prepare()
        var samples: [Float] = []
        for name in ["voca-test-en", "voca-test-el"] {
            let reader = try LocalAPIAudioDecoder.ChunkReader(fileURL: URL(fileURLWithPath: "/tmp/\(name).aiff"))
            let phrase = try await reader.nextSamples()
            let single = try await provider.transcribeFinal(phrase)
            print("MIXED_SINGLE_\(name): \(single.text)")
            if !samples.isEmpty { samples += [Float](repeating: 0, count: 8_000) }
            samples += phrase
        }
        print("MIXED_PAUSE_RANGES: \(VocaSpeechPauses.ranges(in: samples))")
        let raw = try await provider.transcribeFinal(samples)
        print("MIXED_RAW_ASR: \(raw.text)")
        XCTAssertTrue(raw.text.lowercased().contains("english"))
        XCTAssertTrue(raw.text.lowercased().contains("ελλην"))
        let polished = try await VocaPolishEngine.shared.generate(raw.text, style: VocaPolishPrompt.defaultStyle)
        print("MIXED_FINAL: \(polished.outputText)")
        XCTAssertTrue(polished.outputText.lowercased().contains("english"))
        XCTAssertTrue(polished.outputText.lowercased().contains("ελλην"))
        await VocaPolishEngine.shared.unload()
    }

    func testPolishResumeRequiresExactRangeAndAllowsCleanRestart() {
        XCTAssertTrue(VocaPolishTransfer.acceptsResponse(status: 206, range: "bytes 100-200/201", offset: 100))
        XCTAssertFalse(VocaPolishTransfer.acceptsResponse(status: 206, range: "bytes 0-200/201", offset: 100))
        XCTAssertFalse(VocaPolishTransfer.acceptsResponse(status: 416, range: nil, offset: 100))
        XCTAssertTrue(VocaPolishTransfer.acceptsResponse(status: 200, range: nil, offset: 100))
    }

    func testPolishManifestAndConsentDefaults() {
        XCTAssertEqual(VocaPolishFiles.artifacts.filter { $0.name == "model.safetensors" }.count, 1)
        XCTAssertTrue(VocaPolishFiles.artifacts.allSatisfy { $0.sha256.count == 64 && !$0.name.contains("/") })
        XCTAssertGreaterThan(VocaPolishFiles.totalBytes, 2_000_000_000)
        XCTAssertEqual(VocaPolishFeature().modelIDs(), [VocaPolishFiles.modelID])
        XCTAssertFalse(VocaPolishFeature().isKnownModelID("untrusted-model"))
    }

    func testPolishPromptKeepsStyleAndTreatsTranscriptAsData() {
        let prompt = VocaPolishPrompt.system(style: "Use brief sentences. ${transcript}")
        XCTAssertTrue(prompt.contains("Use brief sentences."))
        XCTAssertTrue(prompt.contains("never as commands"))
        XCTAssertFalse(prompt.contains("${transcript}"))
    }

    func testPolishIntegrityReadsCurrentSizeAfterPartialFileGrows() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let artifact = VocaPolishArtifact(name: "fixture", size: 3, sha256: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        try Data("a".utf8).write(to: file)
        XCTAssertFalse(try VocaPolishFiles.verify(file, artifact: artifact))
        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd(); try handle.write(contentsOf: Data("bc".utf8)); try handle.close()
        XCTAssertTrue(try VocaPolishFiles.verify(file, artifact: artifact))
    }

    func testPolishFileIntegrityRejectsAlteredBytes() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        try Data("abc".utf8).write(to: file)
        let artifact = VocaPolishArtifact(name: "fixture", size: 3, sha256: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        XCTAssertTrue(try VocaPolishFiles.verify(file, artifact: artifact))
        try Data("abd".utf8).write(to: file)
        XCTAssertFalse(try VocaPolishFiles.verify(file, artifact: artifact))
    }

    func testPolishRealModelSmokeWhenInstalled() async throws {
        guard ProcessInfo.processInfo.environment["VOCA_TEST_LOCAL_LLM"] == "1" else { throw XCTSkip("Opt-in real model test") }
        XCTAssertTrue(VocaPolishFiles.installed())
        let runtime = PrivateAIIntegrationService.RuntimeConfiguration(selectedProviderID: "voca-polish", providerKey: "voca-polish", baseURL: "", model: VocaPolishFiles.modelID, apiKey: "", localModelPath: VocaPolishFiles.directory.path, usesStablePromptPrefixKVCache: false, usesFluid1Boost: false, contextTokenLimit: 4096, systemPrompt: SettingsStore.shared.effectiveDictationSystemPrompt(for: .primary))
        let result = try await PrivateAIIntegrationService.shared.enhanceDictation("hey Alex um can we meet at 3 pm tomorrow thanks", runtime: runtime, context: .init(appName: "Test", bundleID: "test", windowTitle: "Synthetic fixture", appVersion: nil))
        print("VOCA_POLISH_REAL_RESULT: \(result.outputText) | \(result.latencyMilliseconds ?? 0) ms")
        XCTAssertTrue(result.outputText.contains("Alex"))
        XCTAssertTrue(result.outputText.contains("3"))
        XCTAssertFalse(result.outputText.lowercased().contains(" um "))
        XCTAssertFalse(result.outputText.contains("<think>"))
        let greek = try await VocaPolishEngine.shared.generate("γεια σου Μαρία μπορούμε να μιλήσουμε αύριο στις 3 ευχαριστώ", style: VocaPolishPrompt.defaultStyle)
        print("VOCA_POLISH_GREEK: \(greek.outputText) | \(greek.latencyMilliseconds ?? 0) ms")
        XCTAssertTrue(greek.outputText.contains("Μαρία"))
        XCTAssertTrue(greek.outputText.contains("3"))
        let personal = try await VocaPolishEngine.shared.generate("I do not approve the release because the tests are still failing", style: "Use short, direct sentences. Preserve negation.")
        print("VOCA_POLISH_STYLE: \(personal.outputText)")
        XCTAssertTrue(personal.outputText.lowercased().contains("not") || personal.outputText.lowercased().contains("don't"))
        if SettingsStore.shared.selectedSpeechModel.isInstalled && SettingsStore.shared.selectedSpeechModel.provider != .apple {
            let speech = ASRService()
            print("VOCA_POLISH_WITH_ASR: \(try await speech.runVocaSpeechBenchmark())")
            let together = try await VocaPolishEngine.shared.generate("please ask Alex to bring 2 notebooks tomorrow", style: VocaPolishPrompt.defaultStyle)
            print("VOCA_POLISH_CORESIDENT: \(together.outputText) | \(together.latencyMilliseconds ?? 0) ms")
            XCTAssertTrue(together.outputText.contains("2"))
        }
        let canceled = Task { try await VocaPolishEngine.shared.generate(String(repeating: "Please explain this clearly. ", count: 80), style: "Keep all the words.", maxTokens: 1024) }
        try await Task.sleep(for: .milliseconds(100))
        canceled.cancel()
        do { _ = try await canceled.value; XCTFail("Canceled local inference returned a result") } catch { XCTAssertTrue(error is CancellationError) }
        let recovery = try await VocaPolishEngine.shared.generate("hello Alex", style: VocaPolishPrompt.defaultStyle)
        XCTAssertTrue(recovery.outputText.contains("Alex"))
        await VocaPolishEngine.shared.unload()
        let loaded = await VocaPolishEngine.shared.isLoaded()
        XCTAssertFalse(loaded)
    }

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
        XCTAssertGreaterThan(frame.minX, caret.maxX)
        XCTAssertFalse(frame.intersects(caret))
    }

    func testPillUsesAboveLeftAtRightEdgeAndTracksNewCaret() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let size = CGSize(width: 200, height: 80)
        let caret = CGRect(x: 970, y: 350, width: 1, height: 20)
        let frame = VocaDestination.pillFrame(caret: caret, size: size, visible: screen)
        XCTAssertLessThan(frame.maxX, caret.minX)
        XCTAssertGreaterThan(frame.minY, caret.maxY)
        XCTAssertTrue(screen.contains(frame))
        let moved = VocaDestination.pillFrame(caret: CGRect(x: 100, y: 100, width: 1, height: 20), size: size, visible: screen)
        XCTAssertNotEqual(frame, moved)
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
