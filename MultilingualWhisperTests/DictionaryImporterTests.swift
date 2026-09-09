import XCTest
@testable import MultilingualWhisper

final class DictionaryImporterTests: XCTestCase {
    private func parse(_ text: String) -> DictionaryImporter.ParseResult {
        DictionaryImporter.parse(text)
    }

    private func forms(_ result: DictionaryImporter.ParseResult) -> [(String, [String])] {
        result.entries.map { ($0.replacement, $0.spokenForms) }
    }

    // MARK: - CSV

    func testTwoColumnCSVWithHeader() {
        let result = parse("original,replacement\nNassar,Nasar\nshiok,shiok!\n")
        XCTAssertEqual(result.invalidLineCount, 0)
        XCTAssertEqual(result.entries, [
            .init(spokenForms: ["Nassar"], replacement: "Nasar", matchWholeWord: nil, matchCase: nil),
            .init(spokenForms: ["shiok"], replacement: "shiok!", matchWholeWord: nil, matchCase: nil),
        ])
    }

    func testTwoColumnCSVWithoutHeader() {
        let result = parse("Nassar,Nasar\nNasser,Nasar")
        XCTAssertEqual(result.entries.count, 2)
        XCTAssertEqual(result.entries[0].spokenForms, ["Nassar"])
        XCTAssertEqual(result.entries[1].spokenForms, ["Nasser"])
        XCTAssertEqual(result.entries[0].replacement, "Nasar")
    }

    func testHeaderNamesFromOtherAppsAreRecognised() {
        let variants = [
            "word,correction\nNassar,Nasar",
            "Misspelling,Correct\nNassar,Nasar",
            "heard,say\nNassar,Nasar",
            "from,to\nNassar,Nasar",
            "Phrase,Replacement\nNassar,Nasar",
        ]
        for text in variants {
            let result = parse(text)
            XCTAssertEqual(result.entries.count, 1, text)
            XCTAssertEqual(result.entries.first?.spokenForms, ["Nassar"], text)
            XCTAssertEqual(result.entries.first?.replacement, "Nasar", text)
        }
    }

    func testReversedHeaderColumnsAreMapped() {
        let result = parse("replacement,original\nNasar,Nassar")
        XCTAssertEqual(result.entries.first?.spokenForms, ["Nassar"])
        XCTAssertEqual(result.entries.first?.replacement, "Nasar")
    }

    func testUnknownHeaderIsTreatedAsData() {
        let result = parse("foo,bar\nNassar,Nasar")
        XCTAssertEqual(result.entries.count, 2)
        XCTAssertEqual(result.entries[0].spokenForms, ["foo"])
        XCTAssertEqual(result.entries[0].replacement, "bar")
    }

    func testQuotedFieldsWithCommasAndEscapedQuotes() {
        let result = parse("original,replacement\n\"hello, world\",\"say \"\"hi\"\"\"\n")
        XCTAssertEqual(result.entries.first?.spokenForms, ["hello, world"])
        XCTAssertEqual(result.entries.first?.replacement, "say \"hi\"")
    }

    func testBOMAndCRLFAreHandled() {
        let result = parse("\u{FEFF}original,replacement\r\nNassar,Nasar\r\n")
        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.entries.first?.spokenForms, ["Nassar"])
    }

    func testTabSeparated() {
        let result = parse("original\treplacement\nNassar\tNasar\nNasser\tNasar")
        XCTAssertEqual(result.entries.count, 2)
        XCTAssertEqual(result.entries[1].spokenForms, ["Nasser"])
    }

    func testFlagColumnsAreRead() {
        let result = parse("original,replacement,whole_word,match_case\nla,lah,false,yes\nMRT,MRT,true,no")
        XCTAssertEqual(result.entries[0].matchWholeWord, false)
        XCTAssertEqual(result.entries[0].matchCase, true)
        XCTAssertEqual(result.entries[1].matchWholeWord, true)
        XCTAssertEqual(result.entries[1].matchCase, false)
    }

    func testEmptyReplacementCellBecomesSelfMapping() {
        let result = parse("original,replacement\nNasar,\n")
        XCTAssertEqual(result.entries.first?.replacement, "Nasar")
        XCTAssertEqual(result.entries.first?.spokenForms, ["Nasar"])
    }

    // MARK: - Multiple spoken forms in one cell

    func testPipeAndSemicolonSeparateSpokenForms() {
        let result = parse("Nassar|Nasser;Nazar,Nasar")
        XCTAssertEqual(result.entries.first?.spokenForms, ["Nassar", "Nasser", "Nazar"])
        XCTAssertEqual(result.entries.first?.replacement, "Nasar")
    }

    func testDuplicateSpokenFormsWithinACellAreCollapsed() {
        let result = parse("Nassar|nassar|Nasser,Nasar")
        XCTAssertEqual(result.entries.first?.spokenForms, ["Nassar", "Nasser"])
    }

    // MARK: - Word lists and arrows

    func testOneTermPerLineBecomesSelfMappings() {
        let result = parse("Nasar\nTampines\nAlhamdulillah\n")
        XCTAssertEqual(forms(result).map(\.0), ["Nasar", "Tampines", "Alhamdulillah"])
        XCTAssertEqual(result.entries.map(\.spokenForms), [["Nasar"], ["Tampines"], ["Alhamdulillah"]])
    }

    func testSingleColumnWithHeaderIsAWordList() {
        let result = parse("word\nNasar\nTampines")
        XCTAssertEqual(result.entries.count, 2)
        XCTAssertEqual(result.entries.first?.replacement, "Nasar")
    }

    func testArrowLinesInAllStyles() {
        let result = parse("Nassar -> Nasar\nNasser => Nasar\nNazar → Nasar\nNassa ⇒ Nasar")
        XCTAssertEqual(result.entries.count, 4)
        XCTAssertTrue(result.entries.allSatisfy { $0.replacement == "Nasar" })
        XCTAssertEqual(result.entries.map(\.spokenForms), [["Nassar"], ["Nasser"], ["Nazar"], ["Nassa"]])
    }

    func testArrowLinesCanCarryMultipleSpokenForms() {
        let result = parse("Nassar|Nasser -> Nasar")
        XCTAssertEqual(result.entries.first?.spokenForms, ["Nassar", "Nasser"])
    }

    func testArrowLineWithACommaInTheReplacementIsNotSplitAsCSV() {
        let result = parse("insyaAllah can one -> In Sha Allah, can do")
        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.entries.first?.replacement, "In Sha Allah, can do")
    }

    func testMixedShapesInOneFile() {
        let result = parse("# my words\nNassar -> Nasar\nTampines\nshiok,shiok!\n\n")
        XCTAssertEqual(result.entries.count, 3)
        XCTAssertEqual(result.invalidLineCount, 0)
    }

    // MARK: - Invalid input

    func testBlankAndCommentLinesAreIgnored() {
        let result = parse("\n\n# comment\n   \n")
        XCTAssertTrue(result.entries.isEmpty)
        XCTAssertEqual(result.invalidLineCount, 0)
    }

    func testArrowWithMissingSideIsInvalid() {
        let result = parse("Nassar ->\n-> Nasar")
        XCTAssertTrue(result.entries.isEmpty)
        XCTAssertEqual(result.invalidLineCount, 2)
    }

    func testDuplicateRowsAreCollapsed() {
        let result = parse("Nassar,Nasar\nnassar,Nasar\nNassar,Nasar")
        XCTAssertEqual(result.entries.count, 1)
    }

    // MARK: - Export

    func testExportWritesHeaderAndOneRowPerSpokenForm() {
        let entries = [
            DictionaryEntry(replacement: "Nasar", spokenForms: ["Nassar", "Nasser"]),
            DictionaryEntry(replacement: "lah", spokenForms: ["la"], matchWholeWord: false, matchCase: true),
        ]
        let csv = DictionaryImporter.exportCSV(entries)
        XCTAssertEqual(csv, """
        original,replacement,whole_word,match_case
        Nassar,Nasar,true,false
        Nasser,Nasar,true,false
        la,lah,false,true

        """)
    }

    func testExportQuotesFieldsThatNeedIt() {
        let entries = [DictionaryEntry(replacement: "say \"hi\", now", spokenForms: ["hello, world"])]
        let csv = DictionaryImporter.exportCSV(entries)
        XCTAssertTrue(csv.contains("\"hello, world\",\"say \"\"hi\"\", now\",true,false"))
    }

    func testExportRoundTripsThroughParse() {
        let entries = [
            DictionaryEntry(replacement: "Nasar", spokenForms: ["Nassar", "Nasser"]),
            DictionaryEntry(replacement: "In Sha Allah, can", spokenForms: ["insyaAllah can one"], matchWholeWord: false, matchCase: true),
        ]
        let result = DictionaryImporter.parse(DictionaryImporter.exportCSV(entries))
        XCTAssertEqual(result.invalidLineCount, 0)
        XCTAssertEqual(result.entries, [
            .init(spokenForms: ["Nassar"], replacement: "Nasar", matchWholeWord: true, matchCase: false),
            .init(spokenForms: ["Nasser"], replacement: "Nasar", matchWholeWord: true, matchCase: false),
            .init(spokenForms: ["insyaAllah can one"], replacement: "In Sha Allah, can", matchWholeWord: false, matchCase: true),
        ])
    }

    // MARK: - Field splitter

    func testSplitFieldsHandlesQuotesAndDelimiters() {
        XCTAssertEqual(DictionaryImporter.splitFields("a,b,c", delimiter: ","), ["a", "b", "c"])
        XCTAssertEqual(DictionaryImporter.splitFields("\"a,b\",c", delimiter: ","), ["a,b", "c"])
        XCTAssertEqual(DictionaryImporter.splitFields("\"say \"\"hi\"\"\",x", delimiter: ","), ["say \"hi\"", "x"])
        XCTAssertEqual(DictionaryImporter.splitFields("a\tb", delimiter: "\t"), ["a", "b"])
        XCTAssertEqual(DictionaryImporter.splitFields("only", delimiter: ","), ["only"])
        XCTAssertEqual(DictionaryImporter.splitFields("a,", delimiter: ","), ["a", ""])
    }
}
