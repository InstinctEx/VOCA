import Foundation
import Darwin

nonisolated struct VocaPolishFeature: PrivateAIProviderFeatureProviding {
    #if arch(arm64)
    let isAvailable = true
    #else
    let isAvailable = false
    #endif
    let providerID = "voca-polish"
    let providerName = "VOCA Polish · On this Mac"
    let promptSelectionID = "__VOCA_POLISH__"
    let defaultModelID = VocaPolishFiles.modelID
    let selectedModelDefaultsKey = "voca.polish.model"
    let localModelPathDefaultsKey = "voca.polish.path"
    let prefixCacheDefaultsKey = "voca.polish.keepWarm"
    let boostDefaultsKey = "voca.polish.unusedBoost"
    let modelDirectoryName = "Polish"
    static var model: PrivateAIRegisteredModel {
        .init(displayName: "Qwen 4B · Local", detail: "Private writing cleanup on Apple Silicon. 2.28 GB download. 16 GB memory recommended.", isEnabled: true, parameterCount: "4B", recommendedMemoryGB: 16,
              artifact: .init(identifier: VocaPolishFiles.modelID, filename: VocaPolishFiles.modelID,
                              downloadURL: URL(string: "https://huggingface.co/mlx-community/Qwen3-4B-Instruct-2507-4bit"),
                              sha256: VocaPolishFiles.artifacts.first(where: { $0.name == "model.safetensors" })!.sha256,
                              byteCount: VocaPolishFiles.totalBytes, version: VocaPolishFiles.revision))
    }
    func modelIDs() -> [String] { [defaultModelID] }
    func model(id: String) -> PrivateAIRegisteredModel? { isKnownModelID(id) ? Self.model : nil }
    func canonicalModelID(for value: String) -> String? { isKnownModelID(value) ? defaultModelID : nil }
    func isKnownModelID(_ value: String) -> Bool { value.lowercased() == defaultModelID }
}

nonisolated struct VocaPolishProvider: PrivateAIIntegrationProviding {
    let configuredModelID = VocaPolishFiles.modelID
    var selectedModel: PrivateAIRegisteredModel { VocaPolishFeature.model }
    var configuredLocalModelPath: String? { isLocalRuntimeConfigured ? VocaPolishFiles.directory.path : nil }
    var modelDirectoryURL: URL { VocaPolishFiles.root }
    var isLocalRuntimeConfigured: Bool { VocaPolishFiles.installed() }
    func expectedLocalModelURL(for model: PrivateAIRegisteredModel) -> URL { VocaPolishFiles.directory }
    func localModelPath(for model: PrivateAIRegisteredModel) -> String? { isModelInstalled(model) ? configuredLocalModelPath : nil }
    func isModelInstalled(_ model: PrivateAIRegisteredModel) -> Bool { model.id == configuredModelID && isLocalRuntimeConfigured }
    func prepareModel(_ model: PrivateAIRegisteredModel, progressHandler: PrivateAIModelDownloadProgressHandler?) async throws -> URL {
        guard model.id == configuredModelID else { throw PrivateAIUnavailableError() }
        return try await VocaPolishDownloads.shared.prepare(progress: progressHandler)
    }
    func shouldHandleDictation(model: String) -> Bool { model == configuredModelID || model == VocaPolishFeature().providerID }
    func status(for runtime: PrivateAIIntegrationService.RuntimeConfiguration) async -> PrivateAIStatus {
        .init(state: isLocalRuntimeConfigured ? (await VocaPolishEngine.shared.isLoaded() ? .ready : .configured) : .missingModel)
    }
    func loadedModelState() async -> PrivateAIIntegrationService.LoadedModelState? {
        await VocaPolishEngine.shared.isLoaded() ? .init(modelID: configuredModelID, state: .ready, message: nil) : nil
    }
    func loadModel(_ model: PrivateAIRegisteredModel) async throws -> PrivateAIStatus {
        try await VocaPolishEngine.shared.verify(); return .init(state: .ready)
    }
    func unloadCachedRuntime(reason: String) async { await VocaPolishEngine.shared.unload() }
    func enhanceDictation(_ inputText: String, runtime: PrivateAIIntegrationService.RuntimeConfiguration, context: PrivateAIIntegrationService.AppContext, maxOutputTokens: Int) async throws -> PrivateAIIntegrationService.EnhancementResult {
        try await enhanceDictation(inputText, runtime: runtime, context: context, maxOutputTokens: maxOutputTokens, streamHandler: nil)
    }
    func enhanceDictation(_ inputText: String, runtime: PrivateAIIntegrationService.RuntimeConfiguration, context: PrivateAIIntegrationService.AppContext, maxOutputTokens: Int, streamHandler: PrivateAIStreamHandler?) async throws -> PrivateAIIntegrationService.EnhancementResult {
        try await VocaPolishEngine.shared.generate(inputText, style: runtime.systemPrompt ?? VocaPolishPrompt.defaultStyle, maxTokens: maxOutputTokens, stream: streamHandler)
    }
    func rewrite(_ inputText: String, systemPrompt: String, runtime: PrivateAIIntegrationService.RuntimeConfiguration, context: PrivateAIIntegrationService.AppContext) async throws -> PrivateAIIntegrationService.EnhancementResult {
        try await VocaPolishEngine.shared.generate(inputText, style: systemPrompt)
    }
}

actor VocaPolishDownloads {
    static let shared = VocaPolishDownloads()
    private var downloading = false
    func prepare(progress: PrivateAIModelDownloadProgressHandler?) async throws -> URL {
        guard !downloading else { throw VocaPolishError.message("A model download is already running.") }
        downloading = true; defer { downloading = false }
        return try await VocaPolishFiles.download(progress: progress)
    }
    func delete() async throws {
        guard !downloading else { throw VocaPolishError.message("Pause the download before deleting model files.") }
        let lockURL = VocaPolishFiles.root.appendingPathComponent("download.lock")
        let descriptor = Darwin.open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw VocaPolishError.message("Cannot open the model file lock.") }
        defer { Darwin.close(descriptor) }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else { throw VocaPolishError.message("Another VOCA copy is downloading. Pause it before deleting the model.") }
        defer { flock(descriptor, LOCK_UN) }
        await VocaPolishEngine.shared.unload()
        if FileManager.default.fileExists(atPath: VocaPolishFiles.directory.path) { try FileManager.default.removeItem(at: VocaPolishFiles.directory) }
    }
}
