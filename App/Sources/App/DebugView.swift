import SwiftUI

struct DebugView: View {
    @State private var entries: [DebugEntry] = []

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                List(entries) { entry in
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
}
