import Combine
import Foundation
import NetworkExtension

@MainActor
final class VPNManager: ObservableObject {
    @Published private(set) var status: TunnelStatus = .unknown
    @Published private(set) var lastError: String?
    @Published var config: TunnelConfiguration = TunnelConfigurationStore.load()

    private var manager: NETunnelProviderManager?

    init() {
        Task {
            await reload()
        }

        NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshStatus()
            }
        }
    }

    func reload() async {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            if let existing = managers.first {
                manager = existing
                DebugLogger.shared.log(.info, source: "VPNManager", "Loaded existing tunnel profile")
            } else {
                manager = makeManager()
                try await manager?.saveToPreferences()
                DebugLogger.shared.log(.info, source: "VPNManager", "Created tunnel profile")
            }

            refreshStatus()
        } catch {
            lastError = error.localizedDescription
            DebugLogger.shared.log(.error, source: "VPNManager", "Reload failed: \(error.localizedDescription)")
        }
    }

    func connect() async {
        do {
            try TunnelConfigurationStore.save(config)
            let manager = try await loadedManager()
            manager.isEnabled = true
            try await manager.saveToPreferences()
            try await manager.loadFromPreferences()
            try manager.connection.startVPNTunnel()
            DebugLogger.shared.log(.info, source: "VPNManager", "Requested VPN start")
            refreshStatus()
        } catch {
            lastError = error.localizedDescription
            DebugLogger.shared.log(.error, source: "VPNManager", "Connect failed: \(error.localizedDescription)")
        }
    }

    func disconnect() {
        manager?.connection.stopVPNTunnel()
        DebugLogger.shared.log(.info, source: "VPNManager", "Requested VPN stop")
        refreshStatus()
    }

    func saveConfig() {
        do {
            try TunnelConfigurationStore.save(config)
            DebugLogger.shared.log(.info, source: "VPNManager", "Saved tunnel configuration")
        } catch {
            lastError = error.localizedDescription
            DebugLogger.shared.log(.error, source: "VPNManager", "Save config failed: \(error.localizedDescription)")
        }
    }

    private func loadedManager() async throws -> NETunnelProviderManager {
        if let manager {
            return manager
        }

        await reload()

        if let manager {
            return manager
        }

        throw CocoaError(.userCancelled)
    }

    private func makeManager() -> NETunnelProviderManager {
        let manager = NETunnelProviderManager()
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = AppConstants.tunnelBundleIdentifier
        proto.serverAddress = AppConstants.displayName
        proto.providerConfiguration = [
            "configFileName": AppConstants.configFileName
        ]

        manager.localizedDescription = AppConstants.displayName
        manager.protocolConfiguration = proto
        manager.isEnabled = true
        return manager
    }

    private func refreshStatus() {
        guard let status = manager?.connection.status else {
            self.status = .unknown
            return
        }

        switch status {
        case .invalid:
            self.status = .invalid
        case .disconnected:
            self.status = .disconnected
        case .connecting:
            self.status = .connecting
        case .connected:
            self.status = .connected
        case .reasserting:
            self.status = .reasserting
        case .disconnecting:
            self.status = .disconnecting
        @unknown default:
            self.status = .unknown
        }
    }
}
