import XCTest
@testable import MultilingualWhisper

@MainActor
final class UserLanguageKeywordsTests: XCTestCase {
    private func makeStore() -> UserLanguageKeywords {
        UserLanguageKeywords(defaults: UserDefaults(suiteName: "UserLanguageKeywordsTests.\(UUID())")!)
    }

    func testAddedWordsArePersistedAcrossInstances() {
        let suiteName = "UserLanguageKeywordsTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suiteName)!
        UserLanguageKeywords(defaults: defaults).addMalay(["sibuk", "kejap"])

        let reloaded = UserLanguageKeywords(defaults: defaults)
        XCTAssertEqual(reloaded.malay, ["sibuk", "kejap"])
    }

    func testAddedWordsAreLowercased() {
        let store = makeStore()
        store.addSinglish(["SYG"])
        XCTAssertEqual(store.singlish, ["syg"])
    }

    func testRemoveDeletesFromWhicheverListActuallyHasIt() {
        let store = makeStore()
        store.addMalay(["dulu"])
        store.addSinglish(["bby"])

        store.remove("dulu")
        store.remove("bby")

        XCTAssertTrue(store.malay.isEmpty)
        XCTAssertTrue(store.singlish.isEmpty)
    }

    func testFeedsDirectlyIntoTheClassifierAsAdditionalKeywords() {
        // The actual point of this store: RuleBasedLanguageClassifier must
        // recognize a user-approved word immediately, the same way it already
        // recognizes the built-in list. Neither "sibuk" nor "kejap" is in the
        // built-in malayKeywords, so this only passes if additionalMalayKeywords
        // is actually reaching the classifier, not coincidentally matching
        // something already there.
        let store = makeStore()
        store.addMalay(["sibuk", "kejap"])

        let classifier = RuleBasedLanguageClassifier(additionalMalayKeywords: store.malay)
        let result = classifier.classify(text: "so sibuk and kejap only")

        XCTAssertEqual(result.recommendedModel, .malay)
    }
}
