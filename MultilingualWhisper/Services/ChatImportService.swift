import Foundation
import ZIPFoundation

/// Reads the raw chat text out of a file the user picked via `.fileImporter`
/// - WhatsApp's iOS export is a real .zip (containing `_chat.txt` plus any
/// media), so this exists specifically to get past that archive; the actual
/// vocabulary analysis is `ChatExportParser`'s job, not this type's.
///
/// Deliberately stateless and side-effect-free beyond reading: never writes
/// the export anywhere persistent, never keeps the `Archive`/`Data` around
/// after returning the extracted text - `ChatImportReviewView` owns the
/// "delete once you're done reviewing" step, matching how the rest of this
/// app treats anything that isn't the user's own explicit corrections/
/// approvals as not worth keeping.
enum ChatImportService {
    enum ImportError: Error, LocalizedError {
        case cannotAccessFile
        case noChatFileFound
        case cannotReadText

        var errorDescription: String? {
            switch self {
            case .cannotAccessFile: return "Couldn't open that file."
            case .noChatFileFound: return "No chat text file found inside that export."
            case .cannotReadText: return "Couldn't read the chat as text."
            }
        }
    }

    static func extractChatText(from url: URL) throws -> String {
        // Only URLs backed by an actual security-scoped bookmark (e.g. a real
        // .fileImporter pick outside the sandbox) need this - Apple's own
        // docs say it returns false for anything else, which is not a
        // failure, just "nothing to start" (a plain in-sandbox URL, like the
        // ones this file's own tests use, is already directly readable).
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer { if didStartAccessing { url.stopAccessingSecurityScopedResource() } }

        if url.pathExtension.lowercased() == "zip" {
            return try extractFromZip(url)
        }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw ImportError.cannotReadText
        }
        return text
    }

    private static func extractFromZip(_ url: URL) throws -> String {
        // Rewrapped into this type's own error cases rather than letting
        // ZIPFoundation's ArchiveError leak up to the review UI - it's not
        // meant to know or care what library reads the archive.
        let archive: Archive
        do {
            archive = try Archive(url: url, accessMode: .read)
        } catch {
            throw ImportError.cannotAccessFile
        }
        guard let chatEntry = chatEntry(in: archive) else { throw ImportError.noChatFileFound }

        var data = Data()
        _ = try archive.extract(chatEntry) { chunk in data.append(chunk) }
        guard let text = String(data: data, encoding: .utf8) else { throw ImportError.cannotReadText }
        return text
    }

    /// WhatsApp names the chat file "_chat.txt" - falls back to the first
    /// plain .txt entry in case a future export version renames it, rather
    /// than failing outright on an otherwise-readable archive.
    static func chatEntry(in archive: Archive) -> Entry? {
        archive.first { $0.path.hasSuffix("_chat.txt") }
            ?? archive.first { $0.path.lowercased().hasSuffix(".txt") }
    }
}
