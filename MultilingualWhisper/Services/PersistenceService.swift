import Foundation
import SwiftData

enum PersistenceService {
    static func makeModelContainer() -> ModelContainer {
        let schema = Schema([Transcription.self])
        let configuration = ModelConfiguration(schema: schema)

        if let container = try? ModelContainer(for: schema, configurations: [configuration]) {
            protectStoreFiles(at: configuration.url)
            return container
        }

        // Extremely unlikely (corrupt store, disk full) - fall back to in-memory
        // so the app is still usable for this session instead of crashing on launch.
        guard let fallback = try? ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        ) else {
            fatalError("Could not create a SwiftData ModelContainer, even in-memory.")
        }
        return fallback
    }

    /// SwiftData/`ModelConfiguration` has no file-protection parameter of its own -
    /// this has to be applied directly to the underlying SQLite files. Runs on every
    /// launch, not just first creation: setting protection doesn't retroactively cover
    /// files that already existed on an upgrading install. WAL mode means the store is
    /// three files (main + `-wal` + `-shm`), not one - the most recently-written
    /// transcripts can sit in the WAL file rather than the main one, so all three need
    /// covering. `.complete` (not just iOS's own default,
    /// `.completeUntilFirstUserAuthentication`) is safe here because nothing in this
    /// app touches the store from the background - it's only ever read/written while
    /// the user has the app open in the foreground.
    private static func protectStoreFiles(at storeURL: URL) {
        for suffix in ["", "-wal", "-shm"] {
            let path = storeURL.path + suffix
            guard FileManager.default.fileExists(atPath: path) else { continue }
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: path
            )
        }
    }
}
