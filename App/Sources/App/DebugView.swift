import SwiftUI

struct DebugView: View {
    @EnvironmentObject private var vpn: VPNManager
    @State private var entries: [DebugEntry] = []
    @State private var configPreview: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                List {
                    Section {
                        Button {
                            generateConfigPreview()
                        } label: {
                            Label("Preview sing-box config", systemImage: "doc.text.magnifyingglass")
                        }

                        if let configPreview {
                            Text(configPreview)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                                .lineLimit(14)
                        }
                    }

                    Section {
                        ForEach(entries) { entry in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(entry.level.rawValue.uppercased())
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(color(for: entry.level))
                                    Text(entry.source)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(entry.date, style: .time)
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }

                                Text(entry.message)
                                    .font(.footnote)
                                    .textSelection(.enabled)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .overlay {
                    if entries.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "terminal")
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text("No logs")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Debug")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        entries = DebugLogger.shared.recentEntries()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh logs")

                    Button(role: .destructive) {
                        DebugLogger.shared.clear()
                        entries = []
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Clear logs")
                }
            }
            .onAppear {
                entries = DebugLogger.shared.recentEntries()
            }
        }
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
