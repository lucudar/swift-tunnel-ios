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

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        nodeList
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 116)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
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

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Nodes")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                Text("\(vpn.config.profiles.count) configured")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            MinimalIconButton(systemName: "link.badge.plus", accessibilityLabel: "Import node") {
                isImporting = true
            }

            MinimalIconButton(systemName: "plus", accessibilityLabel: "Add demo node") {
                addDemoProfile()
            }
        }
    }

    private var nodeList: some View {
        VStack(spacing: 10) {
            if vpn.config.profiles.isEmpty {
                EmptyNodeState()
                    .panel()
            } else {
                ForEach(vpn.config.profiles) { profile in
                    ProfileRow(
                        profile: profile,
                        isSelected: selectedID == profile.id,
                        isConnected: vpn.status.isActive && selectedID == profile.id
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        vpn.config.activeProfileID = profile.id
                        vpn.saveConfig()
                    }
                }
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

private struct EmptyNodeState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "server.rack")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("No nodes")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                        .font(.system(.footnote, design: .monospaced))
                        .frame(minHeight: 190)
                        .padding(12)
                        .scrollContentBackground(.hidden)
                        .background(Color.primary.opacity(0.055))
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
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
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
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconBackground)
                    .frame(width: 44, height: 44)
                Image(systemName: protocolIcon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isSelected ? selectedIconColor : Color.secondary)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    Text(profile.name)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .lineLimit(1)
                    if isConnected {
                        StatusDot(isActive: true)
                    }
                }

                Text("\(profile.server):\(profile.port)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                HStack(spacing: 7) {
                    CapsuleBadge(text: profile.proto.rawValue, systemName: "network")
                    CapsuleBadge(text: latencyText, systemName: "timer")
                    if let sni = profile.sni, !sni.isEmpty {
                        CapsuleBadge(text: sni, systemName: "globe")
                    }
                }
            }

            Spacer(minLength: 8)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(isSelected ? STColor.accent : Color.secondary.opacity(0.45))
        }
        .panel()
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? STColor.accent : Color.clear)
                .frame(width: 3)
        }
    }

    private var iconBackground: Color {
        isSelected ? STColor.accent : Color.primary.opacity(0.065)
    }

    private var selectedIconColor: Color {
        .black
    }

    private var latencyText: String {
        guard let latency = profile.latencyMS else {
            return "--"
        }

        return "\(latency) ms"
    }

    private var protocolIcon: String {
        switch profile.proto {
        case .vless:
            return "lock.shield"
        case .hysteria2, .tuic:
            return "bolt"
        case .trojan:
            return "shield.lefthalf.filled"
        case .shadowsocks:
            return "circle.hexagongrid"
        }
    }
}
