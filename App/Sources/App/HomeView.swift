import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var vpn: VPNManager

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    header
                    connectSurface
                    activeNodePanel
                    modePanel
                    errorPanel
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 116)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("SwiftTunnel")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                HStack(spacing: 7) {
                    StatusDot(isActive: vpn.status.isActive)
                    Text(statusSubtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            MinimalIconButton(systemName: "arrow.clockwise", accessibilityLabel: "Reload VPN profile") {
                Task { await vpn.reload() }
            }
        }
    }

    private var connectSurface: some View {
        VStack(spacing: 18) {
            PowerControl(isActive: vpn.status.isActive, isBusy: isBusy) {
                if vpn.status.isActive {
                    vpn.disconnect()
                } else {
                    Task { await vpn.connect() }
                }
            }

            VStack(spacing: 6) {
                Text(vpn.status.title)
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                Text(activeProfile?.name ?? "No active node")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            TrafficLine(isActive: vpn.status.isActive)

            HStack(spacing: 10) {
                MetricTile(title: "Latency", value: latencyText, systemName: "timer")
                MetricTile(title: "Protocol", value: activeProfile?.proto.rawValue ?? "--", systemName: "shield")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var activeNodePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Active node")
                    .font(.headline)
                Spacer()
                CapsuleBadge(text: vpn.config.profiles.isEmpty ? "empty" : "\(vpn.config.profiles.count) nodes")
            }

            if let profile = activeProfile {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(vpn.status.isActive ? STColor.accent : Color.primary.opacity(0.08))
                            .frame(width: 42, height: 42)
                            .overlay {
                                Image(systemName: protocolIcon(for: profile.proto))
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(vpn.status.isActive ? Color.black : Color.secondary)
                            }

                        VStack(alignment: .leading, spacing: 5) {
                            Text(profile.name)
                                .font(.system(.headline, design: .rounded, weight: .semibold))
                                .lineLimit(1)
                            Text("\(profile.server):\(profile.port)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }

                        Spacer()
                    }

                    HStack(spacing: 8) {
                        CapsuleBadge(text: profile.proto.rawValue, systemName: "network")
                        CapsuleBadge(text: vpn.config.routeMode.rawValue, systemName: "point.topleft.down.curvedto.point.bottomright.up")
                        if let sni = profile.sni, !sni.isEmpty {
                            CapsuleBadge(text: sni, systemName: "globe")
                        }
                    }
                }
            } else {
                Text("No active node")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .panel()
    }

    private var modePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Routing")
                .font(.headline)

            Picker("Route", selection: Binding(
                get: { vpn.config.routeMode },
                set: {
                    vpn.config.routeMode = $0
                    vpn.saveConfig()
                }
            )) {
                ForEach(RouteMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            VStack(spacing: 12) {
                ToggleRow(
                    title: "DNS protection",
                    isOn: Binding(
                        get: { vpn.config.dnsProtectionEnabled },
                        set: {
                            vpn.config.dnsProtectionEnabled = $0
                            vpn.saveConfig()
                        }
                    )
                )

                ToggleRow(
                    title: "Kill switch",
                    isOn: Binding(
                        get: { vpn.config.killSwitchEnabled },
                        set: {
                            vpn.config.killSwitchEnabled = $0
                            vpn.saveConfig()
                        }
                    )
                )
            }
        }
        .panel()
    }

    @ViewBuilder
    private var errorPanel: some View {
        if let lastError = vpn.lastError {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(STColor.warning)
                Text(lastError)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .panel()
        }
    }

    private var activeProfile: ProxyProfile? {
        if let id = vpn.config.activeProfileID {
            return vpn.config.profiles.first(where: { $0.id == id }) ?? vpn.config.profiles.first
        }

        return vpn.config.profiles.first
    }

    private var latencyText: String {
        guard let latency = activeProfile?.latencyMS else {
            return "--"
        }

        return "\(latency) ms"
    }

    private var statusSubtitle: String {
        switch vpn.status {
        case .connected:
            return "secure route enabled"
        case .connecting:
            return "starting tunnel"
        case .reasserting:
            return "restoring tunnel"
        case .disconnecting:
            return "stopping tunnel"
        case .invalid:
            return "profile requires attention"
        case .disconnected, .unknown:
            return "ready"
        }
    }

    private var isBusy: Bool {
        vpn.status == .connecting || vpn.status == .disconnecting || vpn.status == .reasserting
    }

    private func protocolIcon(for proto: ProxyProtocol) -> String {
        switch proto {
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

private struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
        .tint(STColor.accent)
    }
}
