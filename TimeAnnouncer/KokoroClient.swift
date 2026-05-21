import CryptoKit
import Foundation

enum KokoroError: Error, LocalizedError {
    case scriptNotFound
    case pythonNotFound(path: String)
    case synthesisFailed(status: Int32, message: String)
    case outputNotFound

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
        }
    }
}

struct KokoroClient {
    static let defaultVoice = "af_heart"

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

    static var installCommand: String {
        "./scripts/setup-kokoro.sh"
    }

    static var isInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: pythonURL.path)
    }

    static func fetchSpeech(text: String, voice: String = defaultVoice) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            try synthesizeSpeech(text: text, voice: voice)
        }.value
    }

    private static func synthesizeSpeech(text: String, voice: String) throws -> Data {
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

        let process = Process()
        process.executableURL = pythonURL
        process.arguments = [
            scriptURL.path,
            "--text", text,
            "--voice", voice,
            "--output", tempURL.path
        ]

        var environment = ProcessInfo.processInfo.environment
        environment["PYTORCH_ENABLE_MPS_FALLBACK"] = "1"
        environment["VIRTUAL_ENV"] = appSupportDirectory.appendingPathComponent("venv", isDirectory: true).path
        environment["PATH"] = "\(appSupportDirectory.appendingPathComponent("venv/bin").path):\(environment["PATH"] ?? "/usr/bin:/bin")"
        process.environment = environment

        let errorURL = cacheDirectory.appendingPathComponent("\(UUID().uuidString).stderr")
        FileManager.default.createFile(atPath: errorURL.path, contents: nil)
        let errorHandle = try FileHandle(forWritingTo: errorURL)
        defer {
            try? errorHandle.close()
            try? FileManager.default.removeItem(at: errorURL)
        }

        process.standardError = errorHandle
        process.standardOutput = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()
        try? errorHandle.close()

        guard process.terminationStatus == 0 else {
            let message = (try? String(contentsOf: errorURL, encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "No error output"
            throw KokoroError.synthesisFailed(status: process.terminationStatus, message: message)
        }

        guard FileManager.default.fileExists(atPath: tempURL.path) else {
            throw KokoroError.outputNotFound
        }

        try FileManager.default.moveItem(at: tempURL, to: outputURL)
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
