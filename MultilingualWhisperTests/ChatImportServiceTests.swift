import XCTest
import ZIPFoundation
@testable import MultilingualWhisper

final class ChatImportServiceTests: XCTestCase {
    /// Builds a real zip archive on disk (not a mock) so these tests exercise
    /// the actual ZIPFoundation read path `ChatImportService` depends on -
    /// exactly the class of thing worth verifying for real rather than
    /// assuming a third-party API works the way its docs say it does.
    private func makeTestZip(entries: [(path: String, content: String)]) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).zip")
        let archive = try Archive(url: url, accessMode: .create)
        for entry in entries {
            let data = Data(entry.content.utf8)
            try archive.addEntry(with: entry.path, type: .file, uncompressedSize: Int64(data.count)) { position, size in
                data.subdata(in: Int(position)..<(Int(position) + size))
            }
        }
        return url
    }

    func testExtractsChatTextFromARealZipArchive() throws {
        let url = try makeTestZip(entries: [
            ("_chat.txt", "[1/1/24, 9:00:00 AM] Alice: hello"),
            ("00000001.jpg", "not real image data"),
        ])
        defer { try? FileManager.default.removeItem(at: url) }

        let text = try ChatImportService.extractChatText(from: url)
        XCTAssertEqual(text, "[1/1/24, 9:00:00 AM] Alice: hello")
    }

    func testFallsBackToAnyTxtFileIfNamedDifferently() throws {
        // A defensive fallback in case a future WhatsApp export version
        // renames the chat file - shouldn't fail outright on an otherwise
        // perfectly readable archive.
        let url = try makeTestZip(entries: [("chat_export.txt", "some content")])
        defer { try? FileManager.default.removeItem(at: url) }

        let text = try ChatImportService.extractChatText(from: url)
        XCTAssertEqual(text, "some content")
    }

    func testThrowsWhenNoTextFileExistsInTheArchive() throws {
        let url = try makeTestZip(entries: [("photo.jpg", "binary-ish content")])
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try ChatImportService.extractChatText(from: url))
    }

    func testReadsAPlainTxtFileDirectlyWithoutNeedingToUnzip() throws {
        // Covers a user who unzips it themselves before picking a file, or a
        // future export format that isn't zipped at all.
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).txt")
        try "[1/1/24, 9:00:00 AM] Alice: plain text export".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let text = try ChatImportService.extractChatText(from: url)
        XCTAssertEqual(text, "[1/1/24, 9:00:00 AM] Alice: plain text export")
    }
}
