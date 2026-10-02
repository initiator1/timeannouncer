import XCTest
@testable import TimeAnnouncer

final class KokoroWorkerTests: XCTestCase {
    private var directory: URL!
    private let shell = URL(fileURLWithPath: "/bin/sh")

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeAnnouncerWorkerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    // A model that never loads used to hold the worker actor forever, which
    // prevented system-voice fallback and every later synthesis request.
    func testHungStartupTimesOutAndNextRequestCanRecover() async throws {
        let stalled = try fixture("IFS= read -r unused\n")
        let worker = KokoroWorker(startupTimeout: 0.3, responseTimeout: 1)
        let started = ProcessInfo.processInfo.systemUptime
        do {
            try await worker.prepare(pythonURL: shell, scriptURL: stalled, appSupportDirectory: directory)
            XCTFail("A worker that never sends ready must fail")
        } catch KokoroError.workerTimedOut {
            XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - started, 3)
        } catch {
            XCTFail("Unexpected startup error: \(error)")
        }
        try await verifyRecovery(worker)
    }

    // Startup can succeed while synthesis stalls. A failed exchange must reset
    // the pipe so a late response cannot be mistaken for the next response.
    func testHungSynthesisTimesOutAndNextRequestCanRecover() async throws {
        let stalled = try fixture("""
        printf '{"ready":true}\\n'
        IFS= read -r request
        IFS= read -r unused
        """)
        let worker = KokoroWorker(startupTimeout: 2, responseTimeout: 0.3)
        let started = ProcessInfo.processInfo.systemUptime
        do {
            try await synthesize(worker, script: stalled)
            XCTFail("A worker that never returns audio must fail")
        } catch KokoroError.workerTimedOut {
            XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - started, 3)
        } catch {
            XCTFail("Unexpected synthesis error: \(error)")
        }
        try await verifyRecovery(worker)
    }

    // Pause cancels the calling task. The pipe read must observe cancellation
    // without waiting for the normal deadline or poisoning the next request.
    func testCancellationDuringSynthesisStopsTheExchangeAndAllowsRecovery() async throws {
        let marker = directory.appendingPathComponent("request-received")
        let stalled = try fixture("""
        printf '{"ready":true}\\n'
        IFS= read -r request
        : > '\(marker.path.replacingOccurrences(of: "'", with: "'\\''"))'
        IFS= read -r unused
        """)
        let worker = KokoroWorker(startupTimeout: 2, responseTimeout: 5)
        let task = Task { try await synthesize(worker, script: stalled) }
        let waitDeadline = ProcessInfo.processInfo.systemUptime + 2
        while !FileManager.default.fileExists(atPath: marker.path),
              ProcessInfo.processInfo.systemUptime < waitDeadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path), "Fixture did not receive the request")
        let cancelledAt = ProcessInfo.processInfo.systemUptime
        task.cancel()
        do {
            try await task.value
            XCTFail("A cancelled synthesis must fail")
        } catch is CancellationError {
            XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - cancelledAt, 1)
        } catch {
            XCTFail("Expected cancellation, got \(error)")
        }
        try await verifyRecovery(worker)
    }

    func testMalformedResponseAndWorkerExitBothAllowRecovery() async throws {
        for response in ["printf 'broken-json\\n'", "exit 0"] {
            let broken = try fixture("""
            printf '{"ready":true}\\n'
            IFS= read -r request
            \(response)
            """)
            let worker = KokoroWorker(startupTimeout: 2, responseTimeout: 1)
            do {
                try await synthesize(worker, script: broken)
                XCTFail("A broken response must fail")
            } catch KokoroError.workerProtocol {
                // Both malformed output and EOF are transport failures.
            } catch {
                XCTFail("Unexpected protocol error: \(error)")
            }
            try await verifyRecovery(worker)
        }
    }

    // Application termination must reach the child directly while its actor is
    // blocked on a model response, and no queued task may restart it afterward.
    func testShutdownInterruptsBlockedWorkerAndPreventsRestart() async throws {
        let marker = directory.appendingPathComponent("shutdown-request-received")
        let stalled = try fixture("""
        printf '{"ready":true}\\n'
        IFS= read -r request
        : > '\(marker.path.replacingOccurrences(of: "'", with: "'\\''"))'
        IFS= read -r unused
        """)
        let worker = KokoroWorker(startupTimeout: 2, responseTimeout: 5)
        let task = Task { try await synthesize(worker, script: stalled) }
        let waitDeadline = ProcessInfo.processInfo.systemUptime + 2
        while !FileManager.default.fileExists(atPath: marker.path),
              ProcessInfo.processInfo.systemUptime < waitDeadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path), "Fixture did not receive the request")
        let stoppedAt = ProcessInfo.processInfo.systemUptime
        worker.shutdown()
        do {
            try await task.value
            XCTFail("Shutdown must end the current exchange")
        } catch is KokoroError {
            XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - stoppedAt, 1)
        }
        do {
            try await worker.prepare(pythonURL: shell, scriptURL: stalled, appSupportDirectory: directory)
            XCTFail("Shutdown must prevent queued work from restarting the process")
        } catch is CancellationError {
            // App termination permanently closes this worker instance.
        }
    }

    private func fixture(_ contents: String) throws -> URL {
        let url = directory.appendingPathComponent("\(UUID().uuidString).sh")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func synthesize(_ worker: KokoroWorker, script: URL) async throws {
        try await worker.synthesize(
            text: "It's ten thirty",
            voice: "test-voice",
            outputURL: directory.appendingPathComponent("test.wav"),
            pythonURL: shell,
            scriptURL: script,
            appSupportDirectory: directory
        )
    }

    private func verifyRecovery(_ worker: KokoroWorker) async throws {
        let healthy = try fixture("""
        printf '{"ready":true}\\n'
        while IFS= read -r request; do
            printf '{"ok":true}\\n'
        done
        """)
        do {
            try await synthesize(worker, script: healthy)
            await worker.stopWorker()
        } catch {
            await worker.stopWorker()
            throw error
        }
    }
}
