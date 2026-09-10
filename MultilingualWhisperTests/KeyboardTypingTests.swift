import UIKit
import XCTest
@testable import MultilingualWhisper

final class KeyboardTypingTests: XCTestCase {

    func testRowsAreCompleteAndDistinct() {
        let letters = KeyboardTyping.letterRows.flatMap { $0 }
        XCTAssertEqual(letters.count, 26)
        XCTAssertEqual(Set(letters).count, 26)
        XCTAssertEqual(Set(letters), Set("abcdefghijklmnopqrstuvwxyz".map(String.init)))

        let symbols = KeyboardTyping.symbolRows.flatMap { $0 }
        XCTAssertEqual(Set(symbols).count, symbols.count)
        XCTAssertTrue(symbols.contains("@"))
        XCTAssertTrue(symbols.contains("$"))
        XCTAssertTrue(symbols.allSatisfy { $0.count == 1 })
    }

    func testShiftAlwaysWins() {
        XCTAssertTrue(KeyboardTyping.shouldCapitalise(shiftOn: true, contextBefore: "mid sentence", autocapitalization: .none))
    }

    func testSentencesRule() {
        XCTAssertTrue(KeyboardTyping.shouldCapitalise(shiftOn: false, contextBefore: nil, autocapitalization: .sentences))
        XCTAssertTrue(KeyboardTyping.shouldCapitalise(shiftOn: false, contextBefore: "Done. ", autocapitalization: .sentences))
        XCTAssertTrue(KeyboardTyping.shouldCapitalise(shiftOn: false, contextBefore: "line one\n", autocapitalization: .sentences))
        XCTAssertFalse(KeyboardTyping.shouldCapitalise(shiftOn: false, contextBefore: "we go ", autocapitalization: .sentences))
        XCTAssertFalse(KeyboardTyping.shouldCapitalise(shiftOn: false, contextBefore: "we g", autocapitalization: .sentences))
    }

    func testWordsAndAllCharactersAndNone() {
        XCTAssertTrue(KeyboardTyping.shouldCapitalise(shiftOn: false, contextBefore: "hello ", autocapitalization: .words))
        XCTAssertFalse(KeyboardTyping.shouldCapitalise(shiftOn: false, contextBefore: "hel", autocapitalization: .words))
        XCTAssertTrue(KeyboardTyping.shouldCapitalise(shiftOn: false, contextBefore: "hel", autocapitalization: .allCharacters))
        XCTAssertFalse(KeyboardTyping.shouldCapitalise(shiftOn: false, contextBefore: "", autocapitalization: .none))
    }
}

final class ClipboardFallbackTests: XCTestCase {
    func testPlacesTheTextOnTheClipboard() {
        ClipboardFallback.place("kopi c kosong")
        XCTAssertEqual(UIPasteboard.general.string, "kopi c kosong")
        XCTAssertTrue(UIPasteboard.general.hasStrings)
    }

    func testEmptyTextIsNotPlaced() {
        ClipboardFallback.place("sentinel")
        ClipboardFallback.place("")
        XCTAssertEqual(UIPasteboard.general.string, "sentinel")
    }
}
