import XCTest
@testable import MultilingualWhisper

final class VoiceCommandParserTests: XCTestCase {
    private func parse(_ text: String) -> VoiceCommand? { VoiceCommandParser.parse(text) }

    // MARK: - English

    func testEnglishCommands() {
        XCTAssertEqual(parse("new line"), .newLine)
        XCTAssertEqual(parse("New paragraph."), .newParagraph)
        XCTAssertEqual(parse("Delete that"), .deleteThat)
        XCTAssertEqual(parse("scratch that!"), .deleteThat)
        XCTAssertEqual(parse("Undo"), .deleteThat)
        XCTAssertEqual(parse("delete last word"), .deleteWord)
        XCTAssertEqual(parse("delete line"), .deleteLine)
        XCTAssertEqual(parse("Full stop."), .period)
        XCTAssertEqual(parse("period"), .period)
        XCTAssertEqual(parse("Comma"), .comma)
        XCTAssertEqual(parse("question mark?"), .questionMark)
        XCTAssertEqual(parse("exclamation mark"), .exclamationMark)
        XCTAssertEqual(parse("Capitalize that"), .capitaliseThat)
        XCTAssertEqual(parse("all caps"), .allCapsThat)
        XCTAssertEqual(parse("lower case that"), .lowercaseThat)
    }

    func testWhisperPunctuationAndCasingAreTolerated() {
        XCTAssertEqual(parse("  New Line.  "), .newLine)
        XCTAssertEqual(parse("Delete, that."), .deleteThat)
        XCTAssertEqual(parse("NEW   PARAGRAPH"), .newParagraph)
    }

    // MARK: - Malay and Arabic

    func testMalayCommands() {
        XCTAssertEqual(parse("baris baru"), .newLine)
        XCTAssertEqual(parse("Perenggan baru."), .newParagraph)
        XCTAssertEqual(parse("padam itu"), .deleteThat)
        XCTAssertEqual(parse("padam perkataan"), .deleteWord)
        XCTAssertEqual(parse("noktah"), .period)
        XCTAssertEqual(parse("koma"), .comma)
        XCTAssertEqual(parse("tanda soal"), .questionMark)
        XCTAssertEqual(parse("huruf besar"), .capitaliseThat)
    }

    func testArabicCommandsWithDiacriticsAndAlefVariants() {
        XCTAssertEqual(parse("سطر جديد"), .newLine)
        XCTAssertEqual(parse("سَطر جَديد."), .newLine)
        XCTAssertEqual(parse("فقرة جديدة"), .newParagraph)
        XCTAssertEqual(parse("إحذف ذلك"), .deleteThat)
        XCTAssertEqual(parse("نقطة"), .period)
        XCTAssertEqual(parse("فاصلة"), .comma)
        XCTAssertEqual(parse("علامة استفهام؟"), .questionMark)
    }

    // MARK: - Literal escape hatch

    func testLiteralPrefixInsertsTheRestAsText() {
        XCTAssertEqual(parse("literally new line"), .literal("new line"))
        XCTAssertEqual(parse("Type delete that."), .literal("delete that"))
        XCTAssertEqual(parse("insert Nasar Flow"), .literal("Nasar Flow"))
        XCTAssertEqual(parse("tulis baris baru"), .literal("baris baru"))
        XCTAssertEqual(parse("اكتب سطر جديد"), .literal("سطر جديد"))
    }

    func testLiteralPrefixAloneIsNotACommand() {
        XCTAssertNil(parse("literally"))
        XCTAssertNil(parse("type"))
    }

    func testLiteralKeepsOriginalCasing() {
        XCTAssertEqual(parse("type Tampines MRT"), .literal("Tampines MRT"))
    }

    // MARK: - Not commands

    func testOrdinaryDictationIsNotACommand() {
        XCTAssertNil(parse("we go makan at three"))
        XCTAssertNil(parse("delete that file please"))
        XCTAssertNil(parse("a new line of shoes"))
        XCTAssertNil(parse(""))
        XCTAssertNil(parse("   "))
    }

    // MARK: - Transport

    func testPayloadRoundTripsEveryCommand() throws {
        let commands: [VoiceCommand] = [
            .newLine, .newParagraph, .deleteThat, .deleteWord, .deleteLine, .period, .comma,
            .questionMark, .exclamationMark, .capitaliseThat, .allCapsThat, .lowercaseThat, .literal("hi there"),
        ]
        for command in commands {
            let data = try JSONEncoder().encode(command.payload)
            let payload = try JSONDecoder().decode(VoiceCommand.Payload.self, from: data)
            XCTAssertEqual(VoiceCommand(payload: payload), command)
        }
        XCTAssertNil(VoiceCommand(payload: .unrecognized("what")))
        XCTAssertTrue(VoiceCommand.Payload.unrecognized("what").isUnrecognized)
    }

    func testEveryTablePhraseParsesToItsCommand() {
        for (command, variants) in VoiceCommandParser.phrases {
            for phrase in variants {
                XCTAssertEqual(parse(phrase), command, "'\(phrase)' should parse to \(command)")
            }
        }
    }

    func testHandoffRoundTrip() {
        DictationHandoff.clearPendingCommand()
        XCTAssertNil(DictationHandoff.pendingCommand())
        DictationHandoff.publishCommand(VoiceCommand.newParagraph.payload)
        XCTAssertEqual(DictationHandoff.pendingCommand().flatMap(VoiceCommand.init(payload:)), .newParagraph)
        DictationHandoff.clearPendingCommand()
        XCTAssertNil(DictationHandoff.pendingCommand())
    }
}
