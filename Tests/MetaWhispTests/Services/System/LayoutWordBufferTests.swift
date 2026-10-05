import XCTest
@testable import MetaWhisp

final class LayoutWordBufferTests: XCTestCase {
    func test_emitsBufferedWordOnlyAfterASingleSeparator() {
        var buffer = LayoutWordBuffer()

        for character in "ghbdtn" {
            XCTAssertNil(buffer.record(String(character), source: .englishUS, mapper: .installedForTests))
        }

        XCTAssertEqual(
            buffer.record(" ", source: .englishUS, mapper: .installedForTests),
            LayoutBufferedToken(
                token: "ghbdtn",
                convertedToken: "привет",
                source: .englishUS,
                trailingText: " "
            )
        )
    }

    func test_sourceChangeAndEditingCharactersDiscardThePendingWord() {
        var buffer = LayoutWordBuffer()
        _ = buffer.record("g", source: .englishUS, mapper: .installedForTests)
        _ = buffer.record("h", source: .englishUS, mapper: .installedForTests)

        XCTAssertNil(buffer.record("б", source: .russian, mapper: .installedForTests))
        XCTAssertNil(buffer.record(" ", source: .russian, mapper: .installedForTests))

        _ = buffer.record("g", source: .englishUS, mapper: .installedForTests)
        XCTAssertNil(buffer.record("1", source: .englishUS, mapper: .installedForTests))
        XCTAssertNil(buffer.record(" ", source: .englishUS, mapper: .installedForTests))
    }

    func test_capsLongWordsAndAcceptsPunctuationAsTheTrailingText() {
        var buffer = LayoutWordBuffer(maxTokenLength: 3)
        _ = buffer.record("g", source: .englishUS, mapper: .installedForTests)
        _ = buffer.record("h", source: .englishUS, mapper: .installedForTests)
        _ = buffer.record("b", source: .englishUS, mapper: .installedForTests)
        XCTAssertNil(buffer.record("d", source: .englishUS, mapper: .installedForTests))
        XCTAssertNil(buffer.record(" ", source: .englishUS, mapper: .installedForTests))

        for character in "gh" {
            XCTAssertNil(buffer.record(String(character), source: .englishUS, mapper: .installedForTests))
        }
        XCTAssertEqual(
            buffer.record("!", source: .englishUS, mapper: .installedForTests),
            LayoutBufferedToken(
                token: "gh",
                convertedToken: "пр",
                source: .englishUS,
                trailingText: "!"
            )
        )
    }

    func test_keepsPhysicalRussianLetterKeysInsideEnglishLayoutToken() {
        var buffer = LayoutWordBuffer()

        for character in "cjj,otybt" {
            XCTAssertNil(buffer.record(String(character), source: .englishUS, mapper: .installedForTests))
        }

        XCTAssertEqual(
            buffer.record(" ", source: .englishUS, mapper: .installedForTests),
            LayoutBufferedToken(
                token: "cjj,otybt",
                convertedToken: "сообщение",
                source: .englishUS,
                trailingText: " "
            )
        )
    }

    func test_keepsAmbiguousTrailingPunctuationUntilWhitespace() {
        var buffer = LayoutWordBuffer()

        for character in "ghbdtn," {
            XCTAssertNil(buffer.record(String(character), source: .englishUS, mapper: .installedForTests))
        }

        XCTAssertEqual(
            buffer.record(" ", source: .englishUS, mapper: .installedForTests),
            LayoutBufferedToken(
                token: "ghbdtn,",
                convertedToken: "приветб",
                source: .englishUS,
                trailingText: " "
            )
        )
    }

    func test_recordsRealPhysicalKeycodesForAppleRussianLetterKeys() throws {
        let mapper = KeyboardLayoutMapper.installedForTests
        guard mapper.isAvailable else {
            throw XCTSkip("The host does not have both US and Russian keyboard layouts enabled.")
        }
        var buffer = LayoutWordBuffer()
        let strokes: [(String, UInt16)] = [
            ("\\", 42), ("k", 40), ("r", 15), ("f", 3)
        ]

        for (text, keyCode) in strokes {
            XCTAssertNil(
                buffer.record(
                    text,
                    keyCode: keyCode,
                    flags: [],
                    source: .englishUS,
                    mapper: mapper
                )
            )
        }

        XCTAssertEqual(
            buffer.record(
                " ",
                keyCode: 49,
                flags: [],
                source: .englishUS,
                mapper: mapper
            ),
            LayoutBufferedToken(
                token: "\\krf",
                convertedToken: "ёлка",
                source: .englishUS,
                trailingText: " "
            )
        )
    }
}
