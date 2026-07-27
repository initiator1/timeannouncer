import CryptoKit
import Foundation

enum KokoroError: Error, LocalizedError {
    case scriptNotFound
    case pythonNotFound(path: String)
    case synthesisFailed(status: Int32, message: String)
    case outputNotFound
    case workerProtocol(String)

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

private actor KokoroWorker {
    private var process: Process?
    private var inputHandle: FileHandle?
    private var outputHandle: FileHandle?
    private var outputBuffer = Data()

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
        try ensureStarted(
            pythonURL: pythonURL,
            scriptURL: scriptURL,
            appSupportDirectory: appSupportDirectory
        )

        let request = KokoroWorkerRequest(text: text, voice: voice, output: outputURL.path)
        let requestData = try JSONEncoder().encode(request)

        guard let inputHandle else {
            throw KokoroError.workerProtocol("missing worker stdin")
        }

        inputHandle.write(requestData)
        inputHandle.write(Data([0x0A]))

        let response = try readWorkerResponse()
        guard response.ok == true else {
            throw KokoroError.synthesisFailed(status: -1, message: response.error ?? "Unknown worker error")
        }
    }

    private func ensureStarted(
        pythonURL: URL,
        scriptURL: URL,
        appSupportDirectory: URL
    ) throws {
        if process?.isRunning == true {
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

        try process.run()

        self.process = process
        self.inputHandle = inputPipe.fileHandleForWriting
        self.outputHandle = outputPipe.fileHandleForReading
        self.outputBuffer = Data()

        do {
            let response = try readWorkerResponse()
            guard response.ready == true else {
                throw KokoroError.workerProtocol("worker did not send ready")
            }
        } catch {
            stopWorker()
            throw error
        }
    }

    private func readWorkerResponse() throws -> KokoroWorkerResponse {
        let data = try readWorkerLine()
        do {
            return try JSONDecoder().decode(KokoroWorkerResponse.self, from: data)
        } catch {
            let line = String(data: data, encoding: .utf8) ?? "<non-UTF8 response>"
            throw KokoroError.workerProtocol("unexpected response: \(line)")
        }
    }

    private func readWorkerLine() throws -> Data {
        guard let outputHandle else {
            throw KokoroError.workerProtocol("missing worker stdout")
        }

        while true {
            if let newlineIndex = outputBuffer.firstIndex(of: 0x0A) {
                let line = outputBuffer[..<newlineIndex]
                let removeEnd = outputBuffer.index(after: newlineIndex)
                outputBuffer.removeSubrange(outputBuffer.startIndex..<removeEnd)
                return Data(line)
            }

            let chunk = outputHandle.availableData
            if chunk.isEmpty {
                stopWorker()
                throw KokoroError.workerProtocol("worker exited before responding")
            }

            outputBuffer.append(chunk)
        }
    }

    private func stopWorker() {
        inputHandle = nil
        outputHandle = nil

        if process?.isRunning == true {
            process?.terminate()
        }
        process = nil

        outputBuffer = Data()
    }
}
