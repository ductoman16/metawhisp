import XCTest
import Combine
@testable import MetaWhisp

/// Shared audio-device boundary stub: never opens the user's microphone.
@MainActor
final class StubAudioSource: AudioSource {
    var isRecording = false
    var audioLevel: Float { 0 }
    var audioBars: [Float] { [] }
    var hasPermission: Bool { true }
    func requestPermission() async -> Bool { true }
    func start() throws { isRecording = true }
    func stop() -> [Float] { isRecording = false; return [] }
}

@MainActor
final class TranscriptionReadinessTests: XCTestCase {
    func testPreparationAndFailureLabelsNeverAdvertiseReadiness() {
        for state in [WhisperKitEngine.ModelState.unloaded, .preparing, .failed("Compilation failed")] {
            XCTAssertNotEqual(state.label, "Ready")
            XCTAssertNotNil(state.recordingError)
        }
        XCTAssertEqual(WhisperKitEngine.ModelState.ready.label, "Ready")
        XCTAssertNil(WhisperKitEngine.ModelState.ready.recordingError)
        XCTAssertFalse(WhisperKitEngine.ModelState.preparing.recordingError!.contains("download"))
    }

    func testPreparationUpdatesCoordinatorAndRejectsCapture() async {
        let settings = AppSettings.shared
        let previous = settings.transcriptionEngine
        settings.transcriptionEngine = "ondevice"
        defer { settings.transcriptionEngine = previous }
        let engine = WhisperKitEngine()
        let recorder = StubAudioSource()
        let coordinator = TranscriptionCoordinator(
            recorder: recorder, whisperEngine: engine,
            textInserter: TextInsertionService(), soundService: SoundService(enabled: { false }), settings: settings
        )
        let published = expectation(description: "Engine lifecycle reaches observable UI")
        let observation = coordinator.objectWillChange.prefix(1).sink { published.fulfill() }
        engine.modelState.send(.preparing)
        await fulfillment(of: [published], timeout: 2)
        XCTAssertEqual(coordinator.idleStatusLabel, "Preparing model")
        coordinator.startPTT()
        XCTAssertFalse(recorder.isRecording)
        XCTAssertEqual(coordinator.lastError, WhisperKitEngine.ModelState.preparing.recordingError)
        observation.cancel()
    }

    func testCancelledPreparationReportsFailureAndUnloadResetsState() async {
        let engine = WhisperKitEngine()
        let load = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await engine.loadModel("unused-cancelled-before-loading", progressHandler: nil)
        }
        do {
            try await load.value
            XCTFail("Cancelled load succeeded")
        } catch {
            XCTAssertFalse(engine.isModelLoaded)
            guard case .failed = engine.modelState.value else { return XCTFail("Failure not published") }
        }
        await engine.unloadModel()
        XCTAssertEqual(engine.modelState.value, .unloaded)
    }

    func testUnloadedEngineRejectsEveryRecordingEntryPointBeforeCapture() {
        let settings = AppSettings.shared
        let previous = settings.transcriptionEngine
        settings.transcriptionEngine = "ondevice"
        defer { settings.transcriptionEngine = previous; VoiceQuestionState.shared.dismiss() }

        for entry in 0..<4 {
            let recorder = StubAudioSource()
            let coordinator = TranscriptionCoordinator(
                recorder: recorder, whisperEngine: WhisperKitEngine(),
                textInserter: TextInsertionService(),
                soundService: SoundService(enabled: { false }), settings: settings
            )
            switch entry {
            case 0: coordinator.toggle()
            case 1: coordinator.startPTT()
            case 2: coordinator.toggleWithTranslation()
            default: coordinator.startVoiceQuestion()
            }
            XCTAssertFalse(recorder.isRecording, "Entry point \(entry) captured audio without an engine")
            XCTAssertEqual(coordinator.stage, .idle)
            XCTAssertFalse(coordinator.translateNext)
            XCTAssertFalse(coordinator.voiceQuestionMode)
            XCTAssertNotNil(coordinator.lastError)
        }
    }
}
