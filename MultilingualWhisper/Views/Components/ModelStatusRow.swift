import SwiftUI

struct ModelStatusRow: View {
    let model: WhisperModelType
    let state: ModelDownloadService.DownloadState
    let approxSize: String
    let primaryAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(model.displayName)
                    .font(.headline)
                Spacer()
                statusIcon
            }

            statusDetail

            HStack {
                Button(primaryActionTitle, action: primaryAction)
                    .buttonStyle(.bordered)
                    .tint(Brand.goldDeep)
                    .disabled(state == .downloaded || state == .verifying)

                if state == .downloaded {
                    Button("Delete", role: .destructive, action: deleteAction)
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusDetail: some View {
        switch state {
        case .downloading(let progress):
            ProgressView(value: progress)
            Text("\(Int(progress * 100))% of \(approxSize)")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .paused(let progress):
            ProgressView(value: progress)
            Text("Paused at \(Int(progress * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .verifying:
            ProgressView()
            Text("Verifying…")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .failed(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
        case .notDownloaded, .downloaded:
            Text(approxSize)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var primaryActionTitle: String {
        switch state {
        case .notDownloaded, .failed: return "Download"
        case .downloading: return "Pause"
        case .paused: return "Resume"
        case .verifying: return "Verifying…"
        case .downloaded: return "Downloaded"
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch state {
        case .downloaded:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        default:
            Image(systemName: "icloud.and.arrow.down").foregroundStyle(.secondary)
        }
    }
}

#Preview {
    List {
        ModelStatusRow(model: .singlish, state: .downloaded, approxSize: "500 MB", primaryAction: {}, deleteAction: {})
        ModelStatusRow(model: .arabic, state: .downloading(progress: 0.42), approxSize: "500 MB", primaryAction: {}, deleteAction: {})
        ModelStatusRow(model: .english, state: .notDownloaded, approxSize: "500 MB", primaryAction: {}, deleteAction: {})
    }
}
