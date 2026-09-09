import XCTest
@testable import MultilingualWhisper

@MainActor
final class CustomDictionaryServiceTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "CustomDictionaryServiceTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - v1 behaviour preserved

    func testStartsEmpty() {
        let service = CustomDictionaryService(defaults: defaults)
        XCTAssertTrue(service.entries.isEmpty)
    }

    func testAddAppendsATrimmedEntry() {
        let service = CustomDictionaryService(defaults: defaults)
        service.add(original: "  Nassar  ", replacement: " Nasar ")
        XCTAssertEqual(service.entries.count, 1)
        XCTAssertEqual(service.entries.first?.original, "Nassar")
        XCTAssertEqual(service.entries.first?.replacement, "Nasar")
    }

    func testAddIgnoresBlankInput() {
        let service = CustomDictionaryService(defaults: defaults)
        service.add(original: "   ", replacement: "Nasar")
        service.add(original: "Nassar", replacement: "   ")
        XCTAssertTrue(service.entries.isEmpty)
    }

    func testRemoveDeletesAtOffset() {
        let service = CustomDictionaryService(defaults: defaults)
        service.add(original: "Nassar", replacement: "Nasar")
        service.add(original: "shiok", replacement: "shiok")
        service.remove(at: IndexSet(integer: 0))
        XCTAssertEqual(service.entries.count, 1)
        XCTAssertEqual(service.entries.first?.original, "shiok")
    }

    func testEntriesPersistAcrossInstances() {
        let first = CustomDictionaryService(defaults: defaults)
        first.add(original: "Nassar", replacement: "Nasar")

        let second = CustomDictionaryService(defaults: defaults)
        XCTAssertEqual(second.entries.count, 1)
        XCTAssertEqual(second.entries.first?.original, "Nassar")
    }

    func testApplyReplacesWholeWordCaseInsensitively() {
        let service = CustomDictionaryService(defaults: defaults)
        service.add(original: "Nassar", replacement: "Nasar")
        XCTAssertEqual(service.apply(to: "call NASSAR back"), "call Nasar back")
    }

    func testApplyDoesNotMatchInsideALongerWord() {
        let service = CustomDictionaryService(defaults: defaults)
        service.add(original: "shiok", replacement: "shiok!")
        XCTAssertEqual(service.apply(to: "shiokness levels are high"), "shiokness levels are high")
    }

    func testApplyWithNoEntriesReturnsTextUnchanged() {
        let service = CustomDictionaryService(defaults: defaults)
        XCTAssertEqual(service.apply(to: "wallah jalan jalan cari makan lah"), "wallah jalan jalan cari makan lah")
    }

    func testApplyMatchesAMultiWordPhraseAndEscapesReplacementTemplateCharacters() {
        let service = CustomDictionaryService(defaults: defaults)
        service.add(original: "insyaAllah can one", replacement: "In Sha Allah, can do $1")
        XCTAssertEqual(
            service.apply(to: "wah insyaAllah can one lah"),
            "wah In Sha Allah, can do $1 lah"
        )
    }

    // MARK: - Migration

    func testLoadsV1OnDiskFormat() throws {
        let legacy: [[String: String]] = [
            ["id": UUID().uuidString, "original": "Nassar", "replacement": "Nasar"],
            ["id": UUID().uuidString, "original": "shiok", "replacement": "shiok!"],
        ]
        defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: "customDictionary.entries")

        let service = CustomDictionaryService(defaults: defaults)
        XCTAssertEqual(service.entries.count, 2)
        XCTAssertEqual(service.entries[0].spokenForms, ["Nassar"])
        XCTAssertEqual(service.entries[0].replacement, "Nasar")
        XCTAssertTrue(service.entries[0].matchWholeWord)
        XCTAssertFalse(service.entries[0].matchCase)
        XCTAssertEqual(service.entries[0].source, .manual)
        XCTAssertEqual(service.apply(to: "nassar so shiok"), "Nasar so shiok!")
    }

    func testOneUnreadableEntryDoesNotDropTheRest() throws {
        let mixed: [[String: Any]] = [
            ["id": UUID().uuidString, "original": "Nassar", "replacement": "Nasar"],
            ["id": "not-a-uuid", "original": "bad", "replacement": "bad"],
            ["id": UUID().uuidString, "replacement": "orphan"],
        ]
        defaults.set(try JSONSerialization.data(withJSONObject: mixed), forKey: "customDictionary.entries")

        let service = CustomDictionaryService(defaults: defaults)
        XCTAssertEqual(service.entries.map(\.replacement), ["Nasar"])
    }

    func testV2FieldsRoundTripThroughPersistence() {
        let first = CustomDictionaryService(defaults: defaults)
        first.add(DictionaryEntry(replacement: "lah", spokenForms: ["la", "lar"], matchWholeWord: false, matchCase: true, source: .imported))

        let second = CustomDictionaryService(defaults: defaults)
        guard let entry = second.entries.first else { return XCTFail("entry was not persisted") }
        XCTAssertEqual(entry.spokenForms, ["la", "lar"])
        XCTAssertFalse(entry.matchWholeWord)
        XCTAssertTrue(entry.matchCase)
        XCTAssertEqual(entry.source, .imported)
    }

    // MARK: - Merging rules

    func testAddingTheSameReplacementMergesSpokenForms() {
        let service = CustomDictionaryService(defaults: defaults)
        service.add(original: "Nassar", replacement: "Nasar")
        service.add(original: "Nasser", replacement: "Nasar")
        service.add(original: "nassar", replacement: "Nasar")
        XCTAssertEqual(service.entries.count, 1)
        XCTAssertEqual(service.entries.first?.spokenForms, ["Nassar", "Nasser"])
    }

    func testReplacementMergeIsCaseSensitive() {
        let service = CustomDictionaryService(defaults: defaults)
        service.add(original: "mrt", replacement: "MRT")
        service.add(original: "m r t", replacement: "Mrt")
        XCTAssertEqual(service.entries.count, 2)
    }

    func testASpokenFormCanOnlyBelongToOneEntry() {
        let service = CustomDictionaryService(defaults: defaults)
        service.add(original: "Nassar", replacement: "Nasar")
        let result = service.add(DictionaryEntry(replacement: "Nazar", spokenForms: ["Nassar"]))
        XCTAssertNil(result)
        XCTAssertEqual(service.entries.count, 1)
        XCTAssertEqual(service.apply(to: "Nassar"), "Nasar")
    }

    func testAddKeepsTheFreeSpokenFormsWhenSomeAreTaken() {
        let service = CustomDictionaryService(defaults: defaults)
        service.add(original: "Nassar", replacement: "Nasar")
        let stored = service.add(DictionaryEntry(replacement: "Nazar", spokenForms: ["Nassar", "Nazzar"]))
        XCTAssertEqual(stored?.spokenForms, ["Nazzar"])
        XCTAssertEqual(service.entries.count, 2)
    }

    func testUpdateReplacesFieldsAndRebuildsMatching() {
        let service = CustomDictionaryService(defaults: defaults)
        service.add(original: "Nassar", replacement: "Nasar")
        var entry = service.entries[0]
        entry.spokenForms = ["Nasser"]
        entry.matchCase = true
        service.update(entry)
        XCTAssertEqual(service.entries[0].spokenForms, ["Nasser"])
        XCTAssertEqual(service.apply(to: "Nassar Nasser nasser"), "Nassar Nasar nasser")
    }

    func testUpdateDropsSpokenFormsOwnedByAnotherEntry() {
        let service = CustomDictionaryService(defaults: defaults)
        service.add(original: "Nassar", replacement: "Nasar")
        service.add(original: "Tampinis", replacement: "Tampines")
        var second = service.entries[1]
        second.spokenForms = ["Nassar", "Tampinis"]
        service.update(second)
        XCTAssertEqual(service.entries[1].spokenForms, ["Tampinis"])
    }

    func testUpdateWithNothingUsableRemovesTheEntry() {
        let service = CustomDictionaryService(defaults: defaults)
        service.add(original: "Nassar", replacement: "Nasar")
        var entry = service.entries[0]
        entry.spokenForms = ["   "]
        service.update(entry)
        XCTAssertTrue(service.entries.isEmpty)
    }

    func testRemoveByID() {
        let service = CustomDictionaryService(defaults: defaults)
        service.add(original: "Nassar", replacement: "Nasar")
        service.add(original: "Tampinis", replacement: "Tampines")
        service.remove(id: service.entries[0].id)
        XCTAssertEqual(service.entries.map(\.replacement), ["Tampines"])
    }

    func testOwnerLookupIsCaseInsensitive() {
        let service = CustomDictionaryService(defaults: defaults)
        service.add(original: "Nassar", replacement: "Nasar")
        XCTAssertEqual(service.owner(ofSpokenForm: "NASSAR")?.replacement, "Nasar")
        XCTAssertNil(service.owner(ofSpokenForm: "Nasser"))
    }

    // MARK: - Import / export

    func testImportTextAddsMergesAndSkips() {
        let service = CustomDictionaryService(defaults: defaults)
        service.add(original: "Nassar", replacement: "Nasar")

        let summary = service.importText("""
        original,replacement
        Nasser,Nasar
        Nassar,Nasar
        Tampinis,Tampines
        garbage ->
        """)

        XCTAssertEqual(summary, .init(added: 1, updated: 1, skipped: 1, invalid: 1))
        XCTAssertEqual(service.entries.count, 2)
        XCTAssertEqual(service.entries[0].spokenForms, ["Nassar", "Nasser"])
        XCTAssertEqual(service.entries[1].replacement, "Tampines")
        XCTAssertEqual(service.entries[1].source, .imported)
    }

    func testImportedWordListTeachesSpelling() {
        let service = CustomDictionaryService(defaults: defaults)
        let summary = service.importText("Nasar\nTampines\nInsyaAllah")
        XCTAssertEqual(summary.added, 3)
        XCTAssertEqual(service.apply(to: "nasar went to TAMPINES insyaallah"), "Nasar went to Tampines InsyaAllah")
    }

    func testImportHonoursFlagColumnsAndKeepsExistingFlagsOtherwise() {
        let service = CustomDictionaryService(defaults: defaults)
        service.add(DictionaryEntry(replacement: "lah", spokenForms: ["la"], matchWholeWord: false))
        _ = service.importText("original,replacement\nlar,lah")
        XCTAssertFalse(service.entries[0].matchWholeWord, "merge keeps the existing entry's flags")

        _ = service.importText("original,replacement,whole_word,match_case\nleh,leh,true,true")
        XCTAssertTrue(service.entries[1].matchWholeWord)
        XCTAssertTrue(service.entries[1].matchCase)
    }

    func testImportOfASpokenFormOwnedElsewhereIsSkipped() {
        let service = CustomDictionaryService(defaults: defaults)
        service.add(original: "Nassar", replacement: "Nasar")
        let summary = service.importText("Nassar,Nazar")
        XCTAssertEqual(summary.skipped, 1)
        XCTAssertEqual(summary.added, 0)
        XCTAssertEqual(service.entries.count, 1)
    }

    func testExportThenImportIntoAFreshServiceReproducesTheDictionary() {
        let source = CustomDictionaryService(defaults: defaults)
        source.add(DictionaryEntry(replacement: "Nasar", spokenForms: ["Nassar", "Nasser"]))
        source.add(DictionaryEntry(replacement: "lah", spokenForms: ["la"], matchWholeWord: false, matchCase: true))

        let otherSuite = "CustomDictionaryServiceTests.export.\(UUID().uuidString)"
        let otherDefaults = UserDefaults(suiteName: otherSuite)!
        defer { otherDefaults.removePersistentDomain(forName: otherSuite) }

        let target = CustomDictionaryService(defaults: otherDefaults)
        let summary = target.importText(source.exportCSV())
        XCTAssertEqual(summary.invalid, 0)
        XCTAssertEqual(target.entries.map(\.replacement), ["Nasar", "lah"])
        XCTAssertEqual(target.entries[0].spokenForms, ["Nassar", "Nasser"])
        XCTAssertFalse(target.entries[1].matchWholeWord)
        XCTAssertTrue(target.entries[1].matchCase)
        XCTAssertEqual(target.apply(to: "nasser so la"), "Nasar so lah")
        XCTAssertEqual(target.apply(to: "nasser so La"), "Nasar so La", "match case survived the round trip")
    }
}
