import SwiftUI

struct DebugView: View {
    @EnvironmentObject private var vpn: VPNManager
    @State private var entries: [DebugEntry] = []
    @State private var configPreview: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        actionsPanel
                        configPanel
                        logsPanel
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 116)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                entries = DebugLogger.shared.recentEntries()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Logs")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                Text("\(entries.count) recent entries")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            MinimalIconButton(systemName: "arrow.clockwise", accessibilityLabel: "Refresh logs") {
                entries = DebugLogger.shared.recentEntries()
            }

            MinimalIconButton(systemName: "trash", accessibilityLabel: "Clear logs") {
                DebugLogger.shared.clear()
                entries = []
            }
        }
    }

    private var actionsPanel: some View {
        Button {
            generateConfigPreview()
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.07))
                    .frame(width: 42, height: 42)
                    .overlay {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 17, weight: .semibold))
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Preview sing-box config")
                        .font(.headline)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .panel()
    }

    @ViewBuilder
    private var configPanel: some View {
        if let configPreview {
            VStack(alignment: .leading, spacing: 10) {
                Text("Config preview")
                    .font(.headline)
                Text(configPreview)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .panel()
        }
    }

    private var logsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Runtime")
                .font(.headline)

            if entries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "terminal")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("No logs")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 8) {
                    ForEach(entries) { entry in
                        LogRow(entry: entry)
                    }
                }
            }
        }
        .panel()
    }

    private func generateConfigPreview() {
        do {
            let content = try SingBoxConfigurationBuilder.build(from: vpn.config)
            configPreview = content
            DebugLogger.shared.log(.info, source: "Debug", "Generated sing-box config preview: \(content.count) bytes")
            entries = DebugLogger.shared.recentEntries()
        } catch {
            configPreview = error.localizedDescription
            DebugLogger.shared.log(.error, source: "Debug", "Config preview failed: \(error.localizedDescription)")
            entries = DebugLogger.shared.recentEntries()
        }
    }
}

private struct LogRow: View {
    let entry: DebugEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(entry.level.rawValue.uppercased())
                    .font(.caption2.monospaced())
                    .foregroundStyle(color(for: entry.level))
                Text(entry.source)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Text(entry.date, style: .time)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text(entry.message)
                .font(.footnote)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.primary.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func color(for level: DebugLevel) -> Color {
        switch level {
        case .debug:
            return .secondary
        case .info:
            return STColor.accent
        case .warning:
            return STColor.warning
        case .error:
            return STColor.danger
        }
    }
}
