import SwiftUI

struct ProfilesView: View {
    @EnvironmentObject private var vpn: VPNManager
    @State private var isImporting = false
    @State private var importText = ""
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                List {
                    Section {
                        ForEach(vpn.config.profiles) { profile in
                            ProfileRow(
                                profile: profile,
                                isSelected: selectedID == profile.id
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                vpn.config.activeProfileID = profile.id
                                vpn.saveConfig()
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Nodes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            isImporting = true
                        } label: {
                            Label("Import link", systemImage: "link.badge.plus")
                        }

                        Button {
                            addDemoProfile()
                        } label: {
                            Label("Add demo", systemImage: "plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add node")
                }
            }
            .sheet(isPresented: $isImporting) {
                ImportProfileSheet(
                    text: $importText,
                    error: importError,
                    onCancel: {
                        isImporting = false
                        importError = nil
                    },
                    onImport: importProfile
                )
            }
        }
    }

    private var selectedID: UUID? {
        vpn.config.activeProfileID ?? vpn.config.profiles.first?.id
    }

    private func addDemoProfile() {
        let profile = ProxyProfile(
            name: "New Node",
            server: "server.example.com",
            port: 443,
            proto: .vless,
            credential: "00000000-0000-0000-0000-000000000000"
        )
        vpn.config.profiles.append(profile)
        vpn.config.activeProfileID = profile.id
        vpn.saveConfig()
    }

    private func importProfile() {
        do {
            let profile = try ProxyLinkParser.parse(importText)
            vpn.config.profiles.append(profile)
            vpn.config.activeProfileID = profile.id
            vpn.saveConfig()
            DebugLogger.shared.log(.info, source: "Profiles", "Imported \(profile.proto.rawValue) profile \(profile.name)")
            importText = ""
            importError = nil
            isImporting = false
        } catch {
            importError = error.localizedDescription
            DebugLogger.shared.log(.error, source: "Profiles", "Import failed: \(error.localizedDescription)")
        }
    }
}

private struct ImportProfileSheet: View {
    @Binding var text: String
    let error: String?
    let onCancel: () -> Void
    let onImport: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(alignment: .leading, spacing: 14) {
                    TextEditor(text: $text)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 180)
                        .padding(10)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if let error {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(STColor.warning)
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Import")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import", action: onImport)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct ProfileRow: View {
    let profile: ProxyProfile
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isSelected ? STColor.accent : Color.secondary.opacity(0.2))
                    .frame(width: 34, height: 34)
                Image(systemName: protocolIcon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? .black : .secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                Text("\(profile.proto.rawValue)  \(profile.server):\(profile.port)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer()

            if let latency = profile.latencyMS {
                Text("\(latency) ms")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(latency < 80 ? STColor.accent : STColor.warning)
            }
        }
        .padding(.vertical, 6)
    }

    private var protocolIcon: String {
        switch profile.proto {
        case .vless:
            return "lock.shield"
        case .hysteria2, .tuic:
            return "bolt.fill"
        case .trojan:
            return "shield.lefthalf.filled"
        case .shadowsocks:
            return "circle.hexagongrid.fill"
        }
    }
}
