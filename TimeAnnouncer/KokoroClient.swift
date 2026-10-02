import CryptoKit
import Darwin
import Foundation

enum KokoroError: Error, LocalizedError {
    case scriptNotFound
    case pythonNotFound(path: String)
    case synthesisFailed(status: Int32, message: String)
    case outputNotFound
    case workerProtocol(String)
    case workerTimedOut

    var errorDescription: String? {
        switch self {
        case .scriptNotFound:
            return "KokoroSynth.py was not found in the app bundle."
        case .pythonNotFound(let path):
            return "Kokoro Python environment is not installed at \(path)."
        case .synthesisFailed(let status, let message):
            return "Kokoro synthesis failed with status \(status): \(message)"
        case .outputNotFound:
            return "Kokoro did not produce an audio file."
        case .workerProtocol(let message):
            return "Kokoro worker protocol error: \(message)"
        case .workerTimedOut:
            return "Kokoro did not respond in time. Try Kokoro again or rebuild its environment."
        }
    }
}

struct KokoroClient {
    static let defaultVoice = "af_heart"
    private static let worker = KokoroWorker()

    private static let appSupportDirectory = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/TimeAnnouncer/Kokoro", isDirectory: true)

    private static let cacheDirectory = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Caches/TimeAnnouncer/Kokoro", isDirectory: true)

    private static var pythonURL: URL {
        appSupportDirectory
            .appendingPathComponent("venv", isDirectory: true)
            .appendingPathComponent("bin/python")
    }

    /// Path to the bundled setup script, quoted so it survives the space in
    /// "Application Support" and in any app path containing spaces.
    ///
    /// Was hardcoded to "./scripts/setup-kokoro.sh" until 2026-07-26 — a
    /// repo-relative path that does not exist for anyone who installed from the
    /// DMG, which is everyone. The dialog told real users to run a script from
    /// a "project directory" they had never had.
    static var installCommand: String {
        if let bundled = Bundle.main.url(forResource: "setup-kokoro", withExtension: "sh") {
            return "bash \"\(bundled.path)\""
        }
        return "./scripts/setup-kokoro.sh"   // running from the checkout
    }

    static var isInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: pythonURL.path)
    }

    /// App termination cannot wait for a model load to finish on the worker actor.
    static func shutdown() {
        worker.shutdown()
    }

    static func prepareForSpeech() {
        guard isInstalled else { return }

        Task.detached(priority: .utility) {
            do {
                let scriptURL = try bundledScriptURL()
                try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
                try await worker.prepare(
                    pythonURL: pythonURL,
                    scriptURL: scriptURL,
                    appSupportDirectory: appSupportDirectory
                )
            } catch {
                print("Kokoro prepare error: \(error)")
            }
        }
    }

    static func fetchSpeech(text: String, voice: String = defaultVoice) async throws -> Data {
        guard FileManager.default.isExecutableFile(atPath: pythonURL.path) else {
            throw KokoroError.pythonNotFound(path: pythonURL.path)
        }

        let scriptURL = try bundledScriptURL()
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        let outputURL = cacheDirectory.appendingPathComponent("\(cacheKey(text: text, voice: voice)).wav")
        if let cachedAudio = try? Data(contentsOf: outputURL) {
            return cachedAudio
        }

        let tempURL = cacheDirectory.appendingPathComponent("\(UUID().uuidString).wav")
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        try await worker.synthesize(
            text: text,
            voice: voice,
            outputURL: tempURL,
            pythonURL: pythonURL,
            scriptURL: scriptURL,
            appSupportDirectory: appSupportDirectory
        )

        guard FileManager.default.fileExists(atPath: tempURL.path) else {
            throw KokoroError.outputNotFound
        }

        do {
            try FileManager.default.moveItem(at: tempURL, to: outputURL)
        } catch {
            if let cachedAudio = try? Data(contentsOf: outputURL) {
                return cachedAudio
            }
            throw error
        }

        return try Data(contentsOf: outputURL)
    }

    private static func bundledScriptURL() throws -> URL {
        if let url = Bundle.main.url(forResource: "KokoroSynth", withExtension: "py") {
            return url
        }

        #if DEBUG
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("KokoroSynth.py")
        if FileManager.default.fileExists(atPath: sourceURL.path) {
            return sourceURL
        }
        #endif

        throw KokoroError.scriptNotFound
    }

    private static func cacheKey(text: String, voice: String) -> String {
        let input = "kokoro-v1|\(voice)|\(text)"
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private struct KokoroWorkerRequest: Encodable {
    let text: String
    let voice: String
    let output: String
}

private struct KokoroWorkerResponse: Decodable {
    let ready: Bool?
    let ok: Bool?
    let error: String?
}

/// The actor owns the protocol. This small locked owner lets app termination
/// stop its process even while the actor is waiting for a reply.
private final class KokoroWorkerProcess: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var isShuttingDown = false

    var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return process?.isRunning == true
    }

    func start(_ process: Process) throws {
        lock.lock()
        defer { lock.unlock() }
        guard !isShuttingDown else { throw CancellationError() }
        try process.run()
        self.process = process
    }

    func stop(shuttingDown: Bool = false) {
        lock.lock()
        defer { lock.unlock() }
        if shuttingDown { isShuttingDown = true }
        let stoppedProcess = process
        process = nil

        guard let stoppedProcess, stoppedProcess.isRunning else { return }
        // The worker owns only disposable synthesis state. Force termination
        // after a failed exchange so an unresponsive model cannot remain alive
        // alongside its replacement or survive app termination.
        kill(stoppedProcess.processIdentifier, SIGKILL)
    }
}

actor KokoroWorker {
    private let processOwner = KokoroWorkerProcess()
    private var inputHandle: FileHandle?
    private var outputHandle: FileHandle?
    private var outputBuffer = Data()
    private let startupTimeout: TimeInterval
    private let responseTimeout: TimeInterval

    init(startupTimeout: TimeInterval = 15, responseTimeout: TimeInterval = 10) {
        self.startupTimeout = startupTimeout
        self.responseTimeout = responseTimeout
    }

    nonisolated func shutdown() {
        processOwner.stop(shuttingDown: true)
    }

    func prepare(
        pythonURL: URL,
        scriptURL: URL,
        appSupportDirectory: URL
    ) throws {
        try ensureStarted(
            pythonURL: pythonURL,
            scriptURL: scriptURL,
            appSupportDirectory: appSupportDirectory
        )
    }

    func synthesize(
        text: String,
        voice: String,
        outputURL: URL,
        pythonURL: URL,
        scriptURL: URL,
        appSupportDirectory: URL
    ) throws {
        do {
            try ensureStarted(
                pythonURL: pythonURL,
                scriptURL: scriptURL,
                appSupportDirectory: appSupportDirectory
            )
            try Task.checkCancellation()

            let request = KokoroWorkerRequest(text: text, voice: voice, output: outputURL.path)
            var requestData = try JSONEncoder().encode(request)
            requestData.append(0x0A)

            guard let inputHandle else {
                throw KokoroError.workerProtocol("missing worker stdin")
            }

            try inputHandle.write(contentsOf: requestData)

            let response = try readWorkerResponse(timeout: responseTimeout)
            guard response.ok == true else {
                throw KokoroError.synthesisFailed(status: -1, message: response.error ?? "Unknown worker error")
            }
        } catch {
            // A timed-out or cancelled response must never become the next
            // request's response. Restart the worker after every failed exchange.
            stopWorker()
            throw error
        }
    }

    private func ensureStarted(
        pythonURL: URL,
        scriptURL: URL,
        appSupportDirectory: URL
    ) throws {
        try Task.checkCancellation()
        if processOwner.isRunning {
            return
        }

        stopWorker()

        let process = Process()
        process.executableURL = pythonURL
        process.arguments = [
            scriptURL.path,
            "--server",
            "--voice", KokoroClient.defaultVoice
        ]

        var environment = ProcessInfo.processInfo.environment
        environment["PYTORCH_ENABLE_MPS_FALLBACK"] = "1"
        environment["VIRTUAL_ENV"] = appSupportDirectory.appendingPathComponent("venv", isDirectory: true).path
        environment["PATH"] = "\(appSupportDirectory.appendingPathComponent("venv/bin").path):\(environment["PATH"] ?? "/usr/bin:/bin")"
        process.environment = environment

        let inputPipe = Pipe()
        let outputPipe = Pipe()

        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        try processOwner.start(process)

        self.inputHandle = inputPipe.fileHandleForWriting
        self.outputHandle = outputPipe.fileHandleForReading
        self.outputBuffer = Data()

        do {
            let response = try readWorkerResponse(timeout: startupTimeout)
            guard response.ready == true else {
                throw KokoroError.workerProtocol("worker did not send ready")
            }
        } catch {
            stopWorker()
            throw error
        }
    }

    private func readWorkerResponse(timeout: TimeInterval) throws -> KokoroWorkerResponse {
        let data = try readWorkerLine(timeout: timeout)
        do {
            return try JSONDecoder().decode(KokoroWorkerResponse.self, from: data)
        } catch {
            let line = String(data: data, encoding: .utf8) ?? "<non-UTF8 response>"
            throw KokoroError.workerProtocol("unexpected response: \(line)")
        }
    }

    private func readWorkerLine(timeout: TimeInterval) throws -> Data {
        guard let outputHandle else {
            throw KokoroError.workerProtocol("missing worker stdout")
        }

        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        while true {
            try Task.checkCancellation()
            if let newlineIndex = outputBuffer.firstIndex(of: 0x0A) {
                let line = outputBuffer[..<newlineIndex]
                let removeEnd = outputBuffer.index(after: newlineIndex)
                outputBuffer.removeSubrange(outputBuffer.startIndex..<removeEnd)
                return Data(line)
            }

            let remaining = deadline - ProcessInfo.processInfo.systemUptime
            guard remaining > 0 else {
                throw KokoroError.workerTimedOut
            }
            guard outputBuffer.count < 65_536 else {
                throw KokoroError.workerProtocol("response exceeds 64 KB")
            }

            // availableData can block forever. Poll in short slices so a stuck
            // model cannot prevent fallback or cancellation of pending speech.
            var descriptor = pollfd(fd: outputHandle.fileDescriptor, events: Int16(POLLIN), revents: 0)
            let waitMilliseconds = Int32(min(remaining * 1_000, 100).rounded(.up))
            let pollResult = poll(&descriptor, 1, waitMilliseconds)
            if pollResult == 0 { continue }
            if pollResult < 0 {
                if errno == EINTR { continue }
                throw KokoroError.workerProtocol("could not wait for worker output")
            }

            var bytes = [UInt8](repeating: 0, count: 4_096)
            let count = bytes.withUnsafeMutableBytes { buffer in
                Darwin.read(outputHandle.fileDescriptor, buffer.baseAddress, buffer.count)
            }
            if count < 0 {
                if errno == EINTR { continue }
                throw KokoroError.workerProtocol("could not read worker output")
            }
            if count == 0 {
                throw KokoroError.workerProtocol("worker exited before responding")
            }
            outputBuffer.append(contentsOf: bytes.prefix(count))
        }
    }

    func stopWorker() {
        try? inputHandle?.close()
        try? outputHandle?.close()
        inputHandle = nil
        outputHandle = nil

        processOwner.stop()

        outputBuffer = Data()
    }
}
