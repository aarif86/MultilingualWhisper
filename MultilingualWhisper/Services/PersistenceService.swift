import Foundation
import SwiftData

enum PersistenceService {
    static func makeModelContainer() -> ModelContainer {
        let schema = Schema([Transcription.self])

        if let container = try? ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema)]) {
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
}
