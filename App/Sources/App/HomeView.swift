import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var vpn: VPNManager

    var body: some View {
        ZStack {
            AnimatedTunnelBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    connectionPanel
                    metrics
                    modePanel
                    errorPanel
                }
                .padding(20)
                .padding(.bottom, 24)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.primary)
                    .frame(width: 44, height: 44)
                Image(systemName: "bolt.horizontal.fill")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(Color(uiColor: .systemBackground))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("SwiftTunnel")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text(vpn.status.isActive ? "encrypted route is live" : "ready for fast route")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            Spacer()

            Circle()
                .fill(vpn.status.isActive ? STColor.accent : Color.secondary.opacity(0.32))
                .frame(width: 10, height: 10)
                .shadow(color: vpn.status.isActive ? STColor.accent.opacity(0.8) : .clear, radius: 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var connectionPanel: some View {
        VStack(spacing: 18) {
            ConnectOrb(isActive: vpn.status.isActive) {
                if vpn.status.isActive {
                    vpn.disconnect()
                } else {
                    Task { await vpn.connect() }
                }
            }
            .accessibilityLabel(vpn.status.isActive ? "Disconnect" : "Connect")

            VStack(spacing: 6) {
                Text(vpn.status.title)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text(activeProfileText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            ThroughputStrip(isActive: vpn.status.isActive)

            HStack(spacing: 10) {
                MetricPill(title: "Up", value: vpn.status.isActive ? "3.8 MB/s" : "--")
                MetricPill(title: "Down", value: vpn.status.isActive ? "24.2 MB/s" : "--")
                MetricPill(title: "Ping", value: activeLatencyText)
            }
        }
        .frame(maxWidth: .infinity)
        .panel()
    }

    private var metrics: some View {
        HStack(spacing: 10) {
            MetricPill(title: "Mode", value: vpn.config.routeMode.rawValue)
            MetricPill(title: "DNS", value: vpn.config.dnsProtectionEnabled ? "Protected" : "Off")
            MetricPill(title: "Kill", value: vpn.config.killSwitchEnabled ? "On" : "Off")
        }
    }

    private var modePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
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

            Toggle("DNS protection", isOn: Binding(
                get: { vpn.config.dnsProtectionEnabled },
                set: {
                    vpn.config.dnsProtectionEnabled = $0
                    vpn.saveConfig()
                }
            ))
            .tint(STColor.accent)

            Toggle("Kill switch", isOn: Binding(
                get: { vpn.config.killSwitchEnabled },
                set: {
                    vpn.config.killSwitchEnabled = $0
                    vpn.saveConfig()
                }
            ))
            .tint(STColor.accent)
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
            }
            .panel()
        }
    }

    private var activeProfileText: String {
        guard
            let id = vpn.config.activeProfileID,
            let profile = vpn.config.profiles.first(where: { $0.id == id })
        else {
            return vpn.config.profiles.first?.name ?? "No profile"
        }

        return profile.name
    }

    private var activeLatencyText: String {
        let profile: ProxyProfile?
        if let id = vpn.config.activeProfileID {
            profile = vpn.config.profiles.first(where: { $0.id == id }) ?? vpn.config.profiles.first
        } else {
            profile = vpn.config.profiles.first
        }

        guard let latency = profile?.latencyMS else {
            return "--"
        }

        return "\(latency) ms"
    }
}
