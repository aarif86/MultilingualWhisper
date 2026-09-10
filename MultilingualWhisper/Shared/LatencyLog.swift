import Foundation

/// One dictation's stage timings: how long the user spoke, how long the decoder
/// took, how long the dictionary + formatter took, and (keyboard dictations only)
/// how long the result sat in the App Group before the keyboard inserted it.
///
/// The playbook's rule (`docs/DICTATION-PLAYBOOK.md` §3.5) is a hard 1 s budget
/// for anything after the decode, instrumented from day one - the documented
/// builder lesson being an LLM polish pass that silently ate 19 of 20 seconds
/// while whisper took 0.74 s. These numbers make that class of regression
/// visible in the debug log instead of in reviews.
struct StageTimings: Codable, Equatable {
    var recordedAt: Date
    /// "flow" (keyboard session) or "app" (in-app recording).
    var source: String
    /// Seconds of speech captured.
    var capture: TimeInterval
    /// Seconds in `WhisperService` minus the format share: model load, routing,
    /// every decode pass.
    var decode: TimeInterval
    /// Seconds in the Custom Dictionary and `TranscriptFormatter`.
    var format: TimeInterval
    /// Seconds from the app publishing the text to the keyboard inserting it.
    /// Nil until the keyboard reports it, and always nil for in-app recordings.
    var handoff: TimeInterval?

    /// "capture 3.2s · decode 0.74s · format 3ms · handoff 0.21s"
    var line: String {
        var parts = [
            "capture \(LatencyLog.format(capture))",
            "decode \(LatencyLog.format(decode))",
            "format \(LatencyLog.format(format))",
        ]
        if let handoff { parts.append("handoff \(LatencyLog.format(handoff))") }
        return parts.joined(separator: " \u{00B7} ")
    }
}

/// The last `maxEntries` dictations' timings, in the App Group so the keyboard's
/// insert stage lands on the same record as the app's decode. Summarised as
/// p50 / p95 per stage in the debug log after every dictation and in Settings.
final class LatencyLog {
    static let shared = LatencyLog(defaults: UserDefaults(suiteName: DictationHandoff.appGroupID) ?? .standard)
    static let maxEntries = 50
    /// A hand-off older than this is not the one being inserted now.
    static let maxHandoffAge: TimeInterval = 5 * 60

    private let defaults: UserDefaults
    private let key = "latency.entries"

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func record(_ timings: StageTimings) {
        var all = entries()
        all.append(timings)
        if all.count > Self.maxEntries { all.removeFirst(all.count - Self.maxEntries) }
        save(all)
    }

    /// Called by the keyboard when it inserts a published result: attaches the
    /// hand-off time to the newest keyboard dictation that has none yet.
    func recordHandoff(_ seconds: TimeInterval, now: Date = Date()) {
        var all = entries()
        guard let index = all.lastIndex(where: { $0.source == "flow" && $0.handoff == nil }),
              now.timeIntervalSince(all[index].recordedAt) <= Self.maxHandoffAge else { return }
        all[index].handoff = max(0, seconds)
        save(all)
    }

    func entries() -> [StageTimings] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([StageTimings].self, from: data) else { return [] }
        return decoded
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }

    /// "12 dictations · decode p50 0.74s p95 1.9s · format p50 3ms p95 8ms ·
    /// handoff p50 0.21s p95 0.60s" - nil when nothing has been recorded.
    func summary() -> String? {
        let all = entries()
        guard !all.isEmpty else { return nil }
        var parts = ["\(all.count) dictation\(all.count == 1 ? "" : "s")"]
        parts.append(Self.stageSummary("capture", all.map(\.capture)))
        parts.append(Self.stageSummary("decode", all.map(\.decode)))
        parts.append(Self.stageSummary("format", all.map(\.format)))
        let handoffs = all.compactMap(\.handoff)
        if !handoffs.isEmpty { parts.append(Self.stageSummary("handoff", handoffs)) }
        return parts.joined(separator: " \u{00B7} ")
    }

    private static func stageSummary(_ name: String, _ values: [TimeInterval]) -> String {
        let p50 = percentile(values, 0.5).map(format) ?? "-"
        let p95 = percentile(values, 0.95).map(format) ?? "-"
        return "\(name) p50 \(p50) p95 \(p95)"
    }

    /// Nearest-rank percentile: the smallest value at or above the requested share
    /// of the sorted sample. Nil for an empty sample.
    static func percentile(_ values: [TimeInterval], _ p: Double) -> TimeInterval? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let rank = Int((p * Double(sorted.count)).rounded(.up))
        return sorted[max(0, min(sorted.count - 1, rank - 1))]
    }

    /// "12ms" under a tenth of a second, "0.74s" otherwise.
    static func format(_ seconds: TimeInterval) -> String {
        seconds < 0.1 ? "\(Int((seconds * 1000).rounded()))ms" : String(format: "%.2fs", seconds)
    }

    private func save(_ all: [StageTimings]) {
        guard let data = try? JSONEncoder().encode(all) else { return }
        defaults.set(data, forKey: key)
    }
}
