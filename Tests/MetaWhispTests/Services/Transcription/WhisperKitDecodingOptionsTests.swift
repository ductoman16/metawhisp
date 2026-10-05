import XCTest
@testable import MetaWhisp

final class WhisperKitDecodingOptionsTests: XCTestCase {
    func testPinnedLanguagesUseCachedPrefillWithoutGlossaryTokens() {
        for language in ["en", "ru", " es "] {
            let options = WhisperKitEngine.decodingOptions(language: language)
            XCTAssertEqual(options.language, language.trimmingCharacters(in: .whitespaces))
            XCTAssertTrue(options.usePrefillCache)
            XCTAssertFalse(options.detectLanguage)
            XCTAssertNil(options.promptTokens)
        }
    }

    func testAutoStillDetectsLanguageWithPrefillEnabled() {
        for language: String? in [nil, "", "  ", "auto", " AUTO "] {
            let options = WhisperKitEngine.decodingOptions(language: language)
            XCTAssertNil(options.language)
            XCTAssertTrue(options.detectLanguage)
            XCTAssertTrue(options.usePrefillPrompt)
            XCTAssertFalse(options.usePrefillCache)
            XCTAssertNil(options.promptTokens)
        }
    }

    func testLatencyFixPreservesRecognitionSafeguards() {
        let options = WhisperKitEngine.decodingOptions(language: "en")
        XCTAssertEqual(options.task, .transcribe)
        XCTAssertEqual(options.temperature, 0)
        XCTAssertEqual(options.temperatureFallbackCount, 2)
        XCTAssertTrue(options.usePrefillPrompt)
        XCTAssertTrue(options.skipSpecialTokens)
        XCTAssertFalse(options.wordTimestamps)
        XCTAssertEqual(options.noSpeechThreshold, 0.6)
        XCTAssertEqual(options.chunkingStrategy, .vad)
    }
}
