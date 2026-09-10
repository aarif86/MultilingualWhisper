import UIKit
import XCTest
@testable import MultilingualWhisper

final class DictationStyleTests: XCTestCase {

    // MARK: - Field hints from text-input traits

    private func hint(
        returnKey: UIReturnKeyType = .default,
        keyboard: UIKeyboardType = .default,
        autocapitalization: UITextAutocapitalizationType = .sentences,
        isSecure: Bool = false
    ) -> HostFieldHint {
        HostFieldHint(returnKey: returnKey, keyboard: keyboard, autocapitalization: autocapitalization, isSecure: isSecure)
    }

    func testSendKeyMeansMessaging() {
        XCTAssertEqual(hint(returnKey: .send), .messaging)
    }

    func testSearchAndGoKeysMeanSearch() {
        XCTAssertEqual(hint(returnKey: .search), .search)
        XCTAssertEqual(hint(returnKey: .go), .search)
        XCTAssertEqual(hint(keyboard: .webSearch), .search)
    }

    func testAddressKeyboardsWinOverTheReturnKey() {
        XCTAssertEqual(hint(returnKey: .send, keyboard: .emailAddress), .address)
        XCTAssertEqual(hint(returnKey: .go, keyboard: .URL), .address)
        XCTAssertEqual(hint(keyboard: .phonePad), .address)
        XCTAssertEqual(hint(keyboard: .numberPad), .address)
        XCTAssertEqual(hint(returnKey: .send, isSecure: true), .address)
    }

    func testNoAutoCapitalisationMeansCode() {
        XCTAssertEqual(hint(autocapitalization: .none), .code)
        XCTAssertEqual(hint(returnKey: .send, autocapitalization: .none), .messaging, "a chat composer with autocap off is still a chat")
    }

    func testPlainFieldIsGeneral() {
        XCTAssertEqual(hint(), .general)
        XCTAssertEqual(hint(returnKey: .done, keyboard: .twitter), .general)
    }

    // MARK: - Resolution

    func testAutoResolvesFromTheField() {
        XCTAssertEqual(DictationStyle.resolve(.auto, hint: .messaging), .messaging)
        XCTAssertEqual(DictationStyle.resolve(.auto, hint: .search), .messaging)
        XCTAssertEqual(DictationStyle.resolve(.auto, hint: .address), .exact)
        XCTAssertEqual(DictationStyle.resolve(.auto, hint: .code), .exact)
        XCTAssertEqual(DictationStyle.resolve(.auto, hint: .general), .notes)
    }

    func testExplicitPickIgnoresTheField() {
        XCTAssertEqual(DictationStyle.resolve(.email, hint: .messaging), .email)
        XCTAssertEqual(DictationStyle.resolve(.messaging, hint: .address), .messaging)
    }

    func testCycleWrapsAround() {
        var style = DictationStyle.auto
        var seen: [DictationStyle] = []
        for _ in DictationStyle.allCases {
            seen.append(style)
            style = style.next
        }
        XCTAssertEqual(seen, DictationStyle.allCases)
        XCTAssertEqual(style, .auto)
    }

    // MARK: - Profiles

    func testNotesIsTheStandardProfile() {
        XCTAssertEqual(DictationStyle.notes.profile(hint: .messaging), .standard)
        XCTAssertEqual(DictationStyle.auto.profile(hint: .general), .standard)
    }

    func testMessagingOnlyDropsTheTrailingPeriod() {
        let profile = DictationStyle.messaging.profile(hint: .general)
        XCTAssertEqual(profile.numbers, .inherit)
        XCTAssertEqual(profile.capitalise, .inherit)
        XCTAssertEqual(profile.trailingPeriod, .drop)
        XCTAssertFalse(profile.stripWhitespace)
    }

    func testEmailForcesTidyText() {
        let profile = DictationStyle.email.profile(hint: .general)
        XCTAssertEqual(profile.numbers, .force)
        XCTAssertEqual(profile.capitalise, .force)
        XCTAssertEqual(profile.trailingPeriod, .ensure)
    }

    func testExactStripsSpacesOnlyInAddressFields() {
        XCTAssertTrue(DictationStyle.exact.profile(hint: .address).stripWhitespace)
        XCTAssertFalse(DictationStyle.exact.profile(hint: .code).stripWhitespace)
        XCTAssertFalse(DictationStyle.auto.profile(hint: .search).stripWhitespace)
        XCTAssertEqual(DictationStyle.exact.profile(hint: .code).capitalise, .suppress)
    }

    // MARK: - Shared state

    func testPickedStyleSurvivesSessionClearAndResolvesWithTheHint() {
        let previousStyle = FlowSessionState.dictationStyle
        let previousHint = FlowSessionState.hostFieldHint
        defer {
            FlowSessionState.dictationStyle = previousStyle
            FlowSessionState.hostFieldHint = previousHint
        }

        FlowSessionState.dictationStyle = .auto
        FlowSessionState.hostFieldHint = .messaging
        XCTAssertEqual(FlowSessionState.resolvedStyle, .messaging)
        XCTAssertEqual(FlowSessionState.resolvedStyleProfile().trailingPeriod, .drop)

        FlowSessionState.dictationStyle = .email
        FlowSessionState.clear()
        XCTAssertEqual(FlowSessionState.dictationStyle, .email, "a style pick is a preference, not session state")
        XCTAssertEqual(FlowSessionState.resolvedStyle, .email)
    }
}
