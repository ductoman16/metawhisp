import Foundation
import WhisperKit

/// Explicit packaged-app diagnostic, never used by ordinary launches. Runs
/// after normal startup preparation; no clipboard, history, or cloud writes.
enum ForkTranscriptionSmoke {
    struct Request {
        let path: String
        let expectedText: String
    }

    static func request(arguments: [String], isFork: Bool) throws -> Request? {
        guard isFork, let index = arguments.firstIndex(of: "--transcription-smoke-test") else { return nil }
        guard arguments.count > index + 2,
              !arguments[index + 1].isEmpty,
              !arguments[index + 2].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranscriptionError.transcriptionFailed("Smoke check requires an audio path and expected text")
        }
        return Request(path: arguments[index + 1], expectedText: arguments[index + 2])
    }

    @MainActor
    static func runIfRequested(coordinator: TranscriptionCoordinator) async {
        do {
            guard let request = try request(
                arguments: CommandLine.arguments,
                isFork: Bundle.main.object(forInfoDictionaryKey: "MetaWhispDisableUpdates") as? Bool == true
            ) else { return }
            guard coordinator.canStartRecording, coordinator.idleStatusLabel == "Ready",
                  let engine = coordinator.whisperEngine, engine.isModelLoaded else {
                throw TranscriptionError.transcriptionFailed("Packaged app coordinator is not ready")
            }
            let samples = try AudioProcessor.loadAudioAsFloatArray(fromPath: request.path)
            for run in 1...2 {
                let result = try await engine.transcribe(
                    audioSamples: samples, language: AppSettings.shared.transcriptionLanguage
                )
                guard result.text.localizedCaseInsensitiveContains(request.expectedText) else {
                    throw TranscriptionError.transcriptionFailed("Packaged app transcript did not match fixture")
                }
                NSLog("[ForkSmoke] PASS run=%d model=%@ language=%@ audio=%.3fs transcription=%.3fs coordinator=%@",
                      run, coordinator.loadedWhisperModelId ?? "none", result.language ?? "unknown",
                      result.duration, result.processingTime, coordinator.idleStatusLabel)
            }
        } catch {
            NSLog("[ForkSmoke] FAIL: %@", error.localizedDescription)
        }
    }
}
