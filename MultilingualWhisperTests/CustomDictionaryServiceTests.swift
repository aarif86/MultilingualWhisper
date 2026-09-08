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
        // "$1"/backslashes in a user-typed replacement must be taken literally, not
        // read as an NSRegularExpression backreference.
        let service = CustomDictionaryService(defaults: defaults)
        service.add(original: "insyaAllah can one", replacement: "In Sha Allah, can do $1")
        XCTAssertEqual(
            service.apply(to: "wah insyaAllah can one lah"),
            "wah In Sha Allah, can do $1 lah"
        )
    }
}
