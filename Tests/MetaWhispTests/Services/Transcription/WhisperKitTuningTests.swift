import XCTest
import WhisperKit
@testable import MetaWhisp

/// Opt-in experiments, not portable performance assertions. Uses local synthetic
/// speech and downloaded models only; never opens the mic or changes app settings.
/// METAWHISP_TUNING=1 swift test -c release --filter WhisperKitTuningTests
final class WhisperKitTuningTests: XCTestCase {
    private let sentences = [
        "Hello, this is a test.",
        "Please move the planning meeting to Thursday afternoon and send the updated agenda before lunch.",
        "The first measurement was twelve point five, the second was eighteen point two, and the final result was thirty point seven.",
        "We should keep the current release available until the new version passes every check. The final sentence must stay in the transcript."
    ]

    func testTimestampExperiment() async throws {
        let kit = try await preparedKit()
        for (index, sentence) in sentences.enumerated() {
            var audio = try makeAudio(sentence)
            if index == 3 {
                audio = [Float](repeating: 0, count: 16_000) + audio + [Float](repeating: 0, count: 24_000)
            }
            for run in 1...3 {
                for disabled in (run % 2 == 0 ? [true, false] : [false, true]) {
                    var options = WhisperKitEngine.decodingOptions(language: "en")
                    options.withoutTimestamps = disabled
                    _ = try await measure(kit, audio: audio, expected: sentence,
                                          label: "timestamps-\(disabled ? "off" : "on")-clip\(index)", run: run, options: options)
                }
            }
        }
        await kit.unloadModels()
    }

    func testWorkerExperiment() async throws {
        let kit = try await preparedKit()
        let sentence = sentences.joined(separator: " ")
        let text = (1...4).map { "Section \($0). " + sentence }.joined(separator: " ")
        let audio = try makeAudio(text)
        XCTAssertGreaterThan(audio.count, 16_000 * 60, "Need multiple model windows to exercise workers")
        for run in 1...2 {
            for workers in (run == 1 ? [16, 1, 4, 2] : [2, 4, 1, 16]) {
                var options = WhisperKitEngine.decodingOptions(language: "en")
                options.concurrentWorkerCount = workers
                _ = try await measure(kit, audio: audio, expected: text,
                                      label: "workers-\(workers)", run: run, options: options)
            }
        }
        await kit.unloadModels()
    }

    func testBackgroundContentionExperiment() async throws {
        let kit = try await preparedKit()
        let foreground = try makeAudio(sentences[0])
        let backgroundText = sentences.joined(separator: " ")
        let background = try makeAudio(backgroundText)
        let options = WhisperKitEngine.decodingOptions(language: "en")
        for run in 1...3 {
            _ = try await measure(kit, audio: foreground, expected: sentences[0],
                                  label: "foreground-alone", run: run, options: options)
            let backgroundTask = Task {
                try await kit.transcribe(audioArray: background, decodeOptions: options)
            }
            // Place the foreground request during background decoding.
            try await Task.sleep(nanoseconds: 500_000_000)
            _ = try await measure(kit, audio: foreground, expected: sentences[0],
                                  label: "foreground-overlap", run: run, options: options)
            let result = try await backgroundTask.value
            XCTAssertFalse(result.isEmpty)
        }
        await kit.unloadModels()
    }

    private func preparedKit() async throws -> WhisperKit {
        guard ProcessInfo.processInfo.environment["METAWHISP_TUNING"] == "1" else {
            throw XCTSkip("Set METAWHISP_TUNING=1 for local hardware experiments")
        }
        let folder = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-large-v3_turbo")
        let kit = try await WhisperKit(WhisperKitConfig(
            modelFolder: folder.path,
            computeOptions: ModelComputeOptions(audioEncoderCompute: .cpuAndNeuralEngine,
                                                textDecoderCompute: .cpuAndNeuralEngine),
            verbose: false, load: true, download: false))
        var options = WhisperKitEngine.decodingOptions(language: "en")
        options.sampleLength = 1
        options.temperatureFallbackCount = 0
        options.usePrefillCache = false
        options.chunkingStrategy = nil
        _ = try await kit.transcribe(audioArray: [Float](repeating: 0, count: 16_000), decodeOptions: options)
        return kit
    }

    private func makeAudio(_ text: String) throws -> [Float] {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("tuning-\(UUID()).aiff")
        defer { try? FileManager.default.removeItem(at: file) }
        let speech = Process()
        speech.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        speech.arguments = ["-v", "Samantha", "-r", "170", "-o", file.path, text]
        try speech.run()
        speech.waitUntilExit()
        XCTAssertEqual(speech.terminationStatus, 0)
        return try AudioProcessor.loadAudioAsFloatArray(fromPath: file.path)
    }

    @discardableResult
    private func measure(_ kit: WhisperKit, audio: [Float], expected: String,
                         label: String, run: Int, options: DecodingOptions) async throws -> Double {
        let start = CFAbsoluteTimeGetCurrent()
        let results = try await kit.transcribe(audioArray: audio, decodeOptions: options)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        let text = results.map(\.text).joined(separator: " ")
        XCTAssertFalse(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        let record: [String: Any] = [
            "label": label, "run": run, "seconds": elapsed,
            "audioSeconds": Double(audio.count) / 16_000,
            "expected": expected, "text": text,
            "timings": try results.map { try JSONSerialization.jsonObject(with: JSONEncoder().encode($0.timings)) }
        ]
        let json = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
        print("TUNING " + String(decoding: json, as: UTF8.self))
        fflush(stdout)
        return elapsed
    }
}
