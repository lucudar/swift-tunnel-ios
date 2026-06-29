import SwiftUI

struct ProfilesView: View {
    @EnvironmentObject private var vpn: VPNManager

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
                    Button {
                        addDemoProfile()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add node")
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
            proto: .vless
        )
        vpn.config.profiles.append(profile)
        vpn.config.activeProfileID = profile.id
        vpn.saveConfig()
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
