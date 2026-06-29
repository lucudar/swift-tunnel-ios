import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var vpn: VPNManager

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
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
        VStack(alignment: .leading, spacing: 8) {
            Text("SwiftTunnel")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("Fast secure proxy tunnel")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var connectionPanel: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(vpn.status.isActive ? STColor.accent.opacity(0.35) : Color.secondary.opacity(0.25), lineWidth: 14)
                    .frame(width: 190, height: 190)

                Circle()
                    .fill(vpn.status.isActive ? STColor.accent : Color.primary)
                    .frame(width: 132, height: 132)
                    .shadow(color: vpn.status.isActive ? STColor.accent.opacity(0.35) : .clear, radius: 22)

                Image(systemName: vpn.status.isActive ? "power.circle.fill" : "power.circle")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(vpn.status.isActive ? .black : Color(uiColor: .systemBackground))
            }
            .contentShape(Circle())
            .onTapGesture {
                if vpn.status.isActive {
                    vpn.disconnect()
                } else {
                    Task { await vpn.connect() }
                }
            }
            .accessibilityLabel(vpn.status.isActive ? "Disconnect" : "Connect")

            VStack(spacing: 6) {
                Text(vpn.status.title)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                Text(activeProfileText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
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

            Toggle("Kill switch", isOn: Binding(
                get: { vpn.config.killSwitchEnabled },
                set: {
                    vpn.config.killSwitchEnabled = $0
                    vpn.saveConfig()
                }
            ))
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
}

