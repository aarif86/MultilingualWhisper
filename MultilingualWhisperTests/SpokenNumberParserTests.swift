import XCTest
@testable import MultilingualWhisper

final class SpokenNumberParserTests: XCTestCase {
    private func parse(_ words: String) -> SpokenNumberParser.Match? {
        SpokenNumberParser.parse(words.split(separator: " ").map(String.init), from: 0)
    }

    // MARK: - English

    func testSingleWords() {
        XCTAssertEqual(parse("five"), .init(value: 5, tokenCount: 1))
        XCTAssertEqual(parse("zero"), .init(value: 0, tokenCount: 1))
        XCTAssertEqual(parse("fifteen"), .init(value: 15, tokenCount: 1))
        XCTAssertEqual(parse("ninety"), .init(value: 90, tokenCount: 1))
        XCTAssertEqual(parse("hundred"), .init(value: 100, tokenCount: 1))
        XCTAssertEqual(parse("thousand"), .init(value: 1000, tokenCount: 1))
    }

    func testCompounds() {
        XCTAssertEqual(parse("twenty five"), .init(value: 25, tokenCount: 2))
        XCTAssertEqual(parse("three hundred"), .init(value: 300, tokenCount: 2))
        XCTAssertEqual(parse("three hundred and five"), .init(value: 305, tokenCount: 4))
        XCTAssertEqual(parse("one thousand two hundred"), .init(value: 1200, tokenCount: 4))
        XCTAssertEqual(parse("two thousand and twenty six"), .init(value: 2026, tokenCount: 5))
        XCTAssertEqual(parse("one million five hundred thousand"), .init(value: 1_500_000, tokenCount: 5))
        XCTAssertEqual(parse("fourty two"), .init(value: 42, tokenCount: 2))
    }

    func testStopsAtNonNumberWords() {
        XCTAssertEqual(parse("twenty five people"), .init(value: 25, tokenCount: 2))
        XCTAssertNil(parse("people twenty"))
    }

    func testDoesNotMergeOutOfOrderWords() {
        // "five twenty" is a time or two numbers, never 25.
        XCTAssertEqual(parse("five twenty"), .init(value: 5, tokenCount: 1))
        // Two ones digits are two digits (phone numbers).
        XCTAssertEqual(parse("five five"), .init(value: 5, tokenCount: 1))
        XCTAssertEqual(parse("twenty fifteen"), .init(value: 20, tokenCount: 1))
        XCTAssertEqual(parse("hundred hundred"), .init(value: 100, tokenCount: 1))
        XCTAssertEqual(parse("two thousand million"), .init(value: 2000, tokenCount: 2))
    }

    func testDanglingAndIsNotConsumed() {
        XCTAssertEqual(parse("three hundred and cats"), .init(value: 300, tokenCount: 2))
        XCTAssertEqual(parse("five and six"), .init(value: 5, tokenCount: 1))
    }

    func testParsesFromAnOffset() {
        let tokens = ["call", "twenty", "five", "now"]
        XCTAssertEqual(SpokenNumberParser.parse(tokens, from: 1), .init(value: 25, tokenCount: 2))
        XCTAssertNil(SpokenNumberParser.parse(tokens, from: 0))
        XCTAssertNil(SpokenNumberParser.parse(tokens, from: 4))
    }

    // MARK: - Malay

    func testMalaySingleWords() {
        XCTAssertEqual(parse("lima"), .init(value: 5, tokenCount: 1))
        XCTAssertEqual(parse("sepuluh"), .init(value: 10, tokenCount: 1))
        XCTAssertEqual(parse("sebelas"), .init(value: 11, tokenCount: 1))
        XCTAssertEqual(parse("seratus"), .init(value: 100, tokenCount: 1))
        XCTAssertEqual(parse("seribu"), .init(value: 1000, tokenCount: 1))
        XCTAssertEqual(parse("lapan"), .init(value: 8, tokenCount: 1))
        XCTAssertEqual(parse("delapan"), .init(value: 8, tokenCount: 1))
    }

    func testMalayCompounds() {
        XCTAssertEqual(parse("dua belas"), .init(value: 12, tokenCount: 2))
        XCTAssertEqual(parse("dua puluh"), .init(value: 20, tokenCount: 2))
        XCTAssertEqual(parse("dua puluh lima"), .init(value: 25, tokenCount: 3))
        XCTAssertEqual(parse("dua ratus"), .init(value: 200, tokenCount: 2))
        XCTAssertEqual(parse("dua ratus lima puluh"), .init(value: 250, tokenCount: 4))
        XCTAssertEqual(parse("tiga ribu lima ratus"), .init(value: 3500, tokenCount: 4))
        XCTAssertEqual(parse("seribu dua ratus"), .init(value: 1200, tokenCount: 3))
        XCTAssertEqual(parse("lima belas"), .init(value: 15, tokenCount: 2))
        XCTAssertEqual(parse("satu juta"), .init(value: 1_000_000, tokenCount: 2))
    }

    func testMalayStopsCleanly() {
        XCTAssertEqual(parse("lima ringgit"), .init(value: 5, tokenCount: 1))
        XCTAssertEqual(parse("lima lima"), .init(value: 5, tokenCount: 1))
        XCTAssertEqual(parse("dua puluh tiga puluh"), .init(value: 20, tokenCount: 2))
        XCTAssertNil(parse("ringgit lima"))
    }

    func testIsNumberWord() {
        XCTAssertTrue(SpokenNumberParser.isNumberWord("seven"))
        XCTAssertTrue(SpokenNumberParser.isNumberWord("tujuh"))
        XCTAssertTrue(SpokenNumberParser.isNumberWord("sepuluh"))
        XCTAssertFalse(SpokenNumberParser.isNumberWord("seventh"))
        XCTAssertTrue(SpokenNumberParser.isLeadingScaleWord("hundred"))
        XCTAssertFalse(SpokenNumberParser.isLeadingScaleWord("one"))
    }
}
