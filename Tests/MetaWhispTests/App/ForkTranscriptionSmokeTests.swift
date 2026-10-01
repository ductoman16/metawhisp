import XCTest
@testable import MetaWhisp

final class ForkTranscriptionSmokeTests: XCTestCase {
    func testSmokeCheckIsOptInAndForkOnly() throws {
        XCTAssertNil(try ForkTranscriptionSmoke.request(arguments: ["app"], isFork: true))
        XCTAssertNil(try ForkTranscriptionSmoke.request(arguments: ["app", "--transcription-smoke-test", "/tmp/test.aiff", "hello"], isFork: false))
        let request = try XCTUnwrap(ForkTranscriptionSmoke.request(
            arguments: ["app", "--transcription-smoke-test", "/tmp/test.aiff", "hello"], isFork: true
        ))
        XCTAssertEqual(request.path, "/tmp/test.aiff")
        XCTAssertEqual(request.expectedText, "hello")
    }

    func testMalformedSmokeRequestFailsInsteadOfSilentlySkipping() {
        for arguments in [["--transcription-smoke-test"], ["--transcription-smoke-test", "/tmp/test.aiff"], ["--transcription-smoke-test", "/tmp/test.aiff", " "]] {
            XCTAssertThrowsError(try ForkTranscriptionSmoke.request(arguments: arguments, isFork: true))
        }
    }
}
