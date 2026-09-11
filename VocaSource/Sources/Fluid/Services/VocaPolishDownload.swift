import Foundation
import CryptoKit
import Darwin

nonisolated struct VocaPolishArtifact: Sendable {
    let name: String
    let size: Int64
    let sha256: String
}

nonisolated enum VocaPolishError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

/// One streamed transfer at a time; partial files survive cancellation. A resumed
/// response must start at precisely the requested byte, otherwise it is rejected.
nonisolated final class VocaPolishTransfer: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionDataTask?
    private var canceled = false
    private var continuation: CheckedContinuation<Void, Error>?
    private var handle: FileHandle?
    private var offset: Int64 = 0
    private var expected: Int64 = 0
    private var progress: (@Sendable (Int64) -> Void)?
    private var failure: Error?
    private var lastProgressTime = 0.0

    static func acceptsResponse(status: Int, range: String?, offset: Int64) -> Bool {
        if status == 200 { return true } // Server declined Range: safely restart.
        guard status == 206, let range else { return false }
        return range.hasPrefix("bytes \(offset)-")
    }

    func run(url: URL, partial: URL, expected: Int64, progress: @escaping @Sendable (Int64) -> Void) async throws {
        self.expected = expected
        self.progress = progress
        if !FileManager.default.fileExists(atPath: partial.path) { FileManager.default.createFile(atPath: partial.path, contents: nil) }
        self.handle = try FileHandle(forUpdating: partial)
        self.offset = Int64(try self.handle!.seekToEnd())
        defer { try? self.handle?.close(); self.handle = nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        if self.offset > 0 { request.setValue("bytes=\(self.offset)-", forHTTPHeaderField: "Range") }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForResource = 3600
        let queue = OperationQueue(); queue.maxConcurrentOperationCount = 1
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
        defer { session.invalidateAndCancel() }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.lock.lock()
                self.continuation = continuation
                let task = session.dataTask(with: request)
                self.task = task
                let canceled = self.canceled
                self.lock.unlock()
                task.resume()
                if canceled { task.cancel() }
            }
        } onCancel: { self.cancel() }
    }

    func cancel() {
        self.lock.lock(); self.canceled = true; let task = self.task; self.lock.unlock()
        task?.cancel()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let http = response as? HTTPURLResponse,
              Self.acceptsResponse(status: http.statusCode, range: http.value(forHTTPHeaderField: "Content-Range"), offset: self.offset) else {
            self.failure = VocaPolishError.message("Download server returned an unexpected response. Retry to resume.")
            completionHandler(.cancel); return
        }
        do {
            if http.statusCode == 200 { try self.handle?.truncate(atOffset: 0); try self.handle?.seek(toOffset: 0); self.offset = 0 }
            completionHandler(.allow)
        } catch { self.failure = error; completionHandler(.cancel) }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        do {
            guard self.offset + Int64(data.count) <= self.expected else { throw VocaPolishError.message("The downloaded file is larger than the pinned model manifest.") }
            try self.handle?.write(contentsOf: data)
            self.offset += Int64(data.count)
            let now = ProcessInfo.processInfo.systemUptime
            if now - lastProgressTime >= 0.15 || self.offset == self.expected { lastProgressTime = now; self.progress?(self.offset) }
        } catch { self.failure = error; dataTask.cancel() }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        self.lock.lock(); let continuation = self.continuation; self.continuation = nil; self.task = nil; self.lock.unlock()
        if let error = self.failure ?? error { continuation?.resume(throwing: error) }
        else if self.offset != self.expected { continuation?.resume(throwing: VocaPolishError.message("The download is incomplete. Retry to resume.")) }
        else { continuation?.resume() }
    }
}

nonisolated enum VocaPolishFiles {
    static let revision = "50d427756c6b1b2fe0c0a10f67fbda1fc8e82c1b"
    static let modelID = "qwen3-4b-instruct-2507-4bit"
    static let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("VOCA/Polish", isDirectory: true)
    static let directory = root.appendingPathComponent(modelID, isDirectory: true)
    static var totalBytes: Int64 { artifacts.reduce(0) { $0 + $1.size } }
    static func installed(at directory: URL = directory) -> Bool {
        guard (try? String(contentsOf: directory.appendingPathComponent("verified.txt"), encoding: .utf8)) == revision else { return false }
        return artifacts.allSatisfy { item in
            (try? directory.appendingPathComponent(item.name).resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) == item.size } ?? false
        }
    }
    static func verify(_ file: URL, artifact: VocaPolishArtifact) throws -> Bool {
        let handle = try FileHandle(forReadingFrom: file); defer { try? handle.close() }
        // URL resource values cache file size. A resumed file has grown since
        // the preflight check, so query the open file rather than cached metadata.
        guard try handle.seekToEnd() == UInt64(artifact.size) else { return false }
        try handle.seek(toOffset: 0)
        var hash = SHA256()
        while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty {
            try Task.checkCancellation(); hash.update(data: data)
        }
        return hash.finalize().map { String(format: "%02x", $0) }.joined() == artifact.sha256
    }

    static func download(progress: PrivateAIModelDownloadProgressHandler?) async throws -> URL {
        #if !arch(arm64)
        throw VocaPolishError.message("VOCA Polish requires an Apple Silicon Mac. Use an API or local server on this Mac.")
        #else
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let lockURL = root.appendingPathComponent("download.lock")
        let descriptor = Darwin.open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw VocaPolishError.message("Cannot open the model download lock.") }
        defer { Darwin.close(descriptor) }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else { throw VocaPolishError.message("Another VOCA copy is downloading this model. Let it finish or pause it first.") }
        defer { flock(descriptor, LOCK_UN) }
        let existing = artifacts.reduce(Int64(0)) { sum, artifact in
            let final = directory.appendingPathComponent(artifact.name)
            let partial = directory.appendingPathComponent(artifact.name + ".partial")
            let bytes = (try? final.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? (try? partial.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return sum + min(Int64(bytes), artifact.size)
        }
        if let available = try? directory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage,
           available < max(0, totalBytes - existing) + 256 * 1_048_576 {
            throw VocaPolishError.message("There is not enough free storage for VOCA Polish. Free space and resume the download.")
        }
        var completed: Int64 = 0
        for artifact in artifacts {
            try Task.checkCancellation()
            let final = directory.appendingPathComponent(artifact.name)
            if (try? verify(final, artifact: artifact)) == true { completed += artifact.size; continue }
            let partial = directory.appendingPathComponent(artifact.name + ".partial")
            if (try? verify(partial, artifact: artifact)) != true {
                if let size = try? partial.resourceValues(forKeys: [.fileSizeKey]).fileSize, Int64(size) >= artifact.size { try FileManager.default.removeItem(at: partial) }
                let base = completed
                let transfer = VocaPolishTransfer()
                let url = URL(string: "https://huggingface.co/mlx-community/Qwen3-4B-Instruct-2507-4bit/resolve/\(revision)/\(artifact.name)")!
                try await transfer.run(url: url, partial: partial, expected: artifact.size) { bytes in
                    if let progress { Task { await progress(.init(bytesWritten: 0, totalBytesWritten: base + bytes, totalBytesExpected: totalBytes)) } }
                }
                guard try verify(partial, artifact: artifact) else {
                    try? FileManager.default.removeItem(at: partial)
                    throw VocaPolishError.message("Integrity check failed for \(artifact.name). Retry to download a clean copy.")
                }
            }
            if FileManager.default.fileExists(atPath: final.path) { try FileManager.default.removeItem(at: final) }
            try FileManager.default.moveItem(at: partial, to: final)
            completed += artifact.size
            await progress?(.init(bytesWritten: artifact.size, totalBytesWritten: completed, totalBytesExpected: totalBytes))
        }
        try revision.write(to: directory.appendingPathComponent("verified.txt"), atomically: true, encoding: .utf8)
        return directory
        #endif
    }
    static let artifacts: [VocaPolishArtifact] = [
        .init(name: "added_tokens.json", size: 707, sha256: "c0284b582e14987fbd3d5a2cb2bd139084371ed9acbae488829a1c900833c680"),
        .init(name: "chat_template.jinja", size: 4040, sha256: "40c21f34cf67d8c760ef72f8ad3ae5afad514299d4b06e91dd9a8d705af7b541"),
        .init(name: "config.json", size: 938, sha256: "574349e5a343236546fda55e4744a76e181f534182d7dc60ff1bad7e7a502849"),
        .init(name: "generation_config.json", size: 238, sha256: "835fffe355c9438e7a25be099b3fccaa98350b83451f9fd2d99512e74f1ade48"),
        .init(name: "merges.txt", size: 1671853, sha256: "8831e4f1a044471340f7c0a83d7bd71306a5b867e95fd870f74d0c5308a904d5"),
        .init(name: "model.safetensors", size: 2263022417, sha256: "2a73c6c248601ab904e035548abd8e6abb65ea27dcb5f342fb0a8910eb44173f"),
        .init(name: "model.safetensors.index.json", size: 63964, sha256: "388d811b8b7c2608dd04cce1bcb04a8bf715d19b42790894e6d3427ff429a777"),
        .init(name: "special_tokens_map.json", size: 613, sha256: "76862e765266b85aa9459767e33cbaf13970f327a0e88d1c65846c2ddd3a1ecd"),
        .init(name: "tokenizer.json", size: 11422654, sha256: "aeb13307a71acd8fe81861d94ad54ab689df773318809eed3cbe794b4492dae4"),
        .init(name: "tokenizer_config.json", size: 5440, sha256: "4397cc477eb6d79715ccd2000accd6b3531928f30029665832fa1b255f24d2b9"),
        .init(name: "vocab.json", size: 2776833, sha256: "ca10d7e9fb3ed18575dd1e277a2579c16d108e32f27439684afa0e10b1440910"),
    ]
}
