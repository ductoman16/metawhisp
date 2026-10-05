import XCTest
import WhisperKit
@testable import MetaWhisp

/// Opt-in real-model regression. The normal unit suite never downloads a model
/// or relies on hardware timings. Run in release mode on the benchmark Mac:
/// METAWHISP_PERF_MODEL=openai_whisper-large-v3_turbo swift test -c release --filter WhisperKitLatencyTests
final class WhisperKitLatencyTests: XCTestCase {
    func testShortEnglishDictationDoesNotPayTheFullGlossaryCost() async throws {
        try await assertLatency(text: "Hello, this is a test.", language: "en", limit: 2)
    }

    func testFirstAndRepeatedAutoDictationsAreReadyWhenModelLoadCompletes() async throws {
        try await assertLatency(
            text: "This is another test of my Meta Whisp voice transcription. I am trying to see if it will be super slow.",
            language: "auto", limit: 2.8
        )
    }

    private func assertLatency(text: String, language: String, limit: Double) async throws {
        guard let model = ProcessInfo.processInfo.environment["METAWHISP_PERF_MODEL"] else {
            throw XCTSkip("Set METAWHISP_PERF_MODEL to a downloaded WhisperKit model to run the hardware benchmark")
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fixture = directory.appendingPathComponent("dictation.aiff")
        let speech = Process()
        speech.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        speech.arguments = ["-v", "Samantha", "-r", "190", "-o", fixture.path, text]
        try speech.run()
        speech.waitUntilExit()
        XCTAssertEqual(speech.terminationStatus, 0)
        let audio = try AudioProcessor.loadAudioAsFloatArray(fromPath: fixture.path)
        let engine = WhisperKitEngine()
        XCTAssertFalse(engine.isModelLoaded)
        try await engine.loadModel(model, progressHandler: nil)
        XCTAssertTrue(engine.isModelLoaded)
        XCTAssertEqual(engine.modelState.value, .ready)
        await MainActor.run {
            let settings = AppSettings.shared
            let previous = settings.transcriptionEngine
            settings.transcriptionEngine = "ondevice"
            defer { settings.transcriptionEngine = previous }
            let recorder = StubAudioSource()
            let coordinator = TranscriptionCoordinator(
                recorder: recorder, whisperEngine: engine,
                textInserter: TextInsertionService(), soundService: SoundService(enabled: { false }), settings: settings
            )
            XCTAssertEqual(coordinator.idleStatusLabel, "Ready")
            XCTAssertTrue(coordinator.canStartRecording)
            coordinator.startPTT()
            XCTAssertTrue(recorder.isRecording)
            XCTAssertEqual(coordinator.stage, .recording)
            coordinator.stopPTT()
        }
        let prompt = TranscriptionLanguageResolver.enginePromptWords(language: "en")
        XCTAssertFalse(prompt.isEmpty, "Exercise the real English glossary input, not a pre-trimmed caller")

        // No test-side warm-up: the first user dictation must already be ready.
        for run in 1...3 {
            let result = try await engine.transcribe(audioSamples: audio, language: language, promptWords: prompt)
            XCTAssertTrue(result.text.lowercased().contains(language == "en" ? "this is a test" : "super slow"), result.text)
            XCTAssertEqual(result.language, "en")
            XCTAssertLessThan(result.processingTime, limit, "Dictation spent \(result.processingTime)s in WhisperKit")
            print("WHISPER_LATENCY language=\(language) run=\(run) seconds=\(result.processingTime) audioSeconds=\(result.duration)")
        }
        await engine.unloadModel()
        XCTAssertFalse(engine.isModelLoaded)
        XCTAssertEqual(engine.modelState.value, .unloaded)
    }
}
