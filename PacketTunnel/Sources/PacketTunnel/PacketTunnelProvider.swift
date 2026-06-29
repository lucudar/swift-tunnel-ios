import Foundation
import NetworkExtension

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private var core: TunnelCore?

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        DebugLogger.shared.log(.info, source: "PacketTunnel", "Starting packet tunnel")

        let config = TunnelConfigurationStore.load()
        let singBoxConfig = options?["configContent"] as? String

        guard config.profiles.isEmpty == false else {
            let error = TunnelProviderError.noProfiles
            DebugLogger.shared.log(.error, source: "PacketTunnel", error.localizedDescription)
            completionHandler(error)
            return
        }

        do {
            let core = try makeTunnelCore(config: config, singBoxConfig: singBoxConfig)
            try core.start()
            self.core = core
            DebugLogger.shared.log(.info, source: "PacketTunnel", "Tunnel core started")
            completionHandler(nil)
        } catch {
            DebugLogger.shared.log(.error, source: "PacketTunnel", "Core start failed: \(error.localizedDescription)")
            completionHandler(error)
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        DebugLogger.shared.log(.info, source: "PacketTunnel", "Stopping packet tunnel: \(reason.rawValue)")
        core?.stop()
        core = nil
        completionHandler()
    }

    override func handleAppMessage(
        _ messageData: Data,
        completionHandler: ((Data?) -> Void)?
    ) {
        DebugLogger.shared.log(.debug, source: "PacketTunnel", "Received app message: \(messageData.count) bytes")
        completionHandler?(Data("ok".utf8))
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        core?.sleep()
        completionHandler()
    }

    override func wake() {
        core?.wake()
    }

    func applyTunnelNetworkSettings(_ settings: NEPacketTunnelNetworkSettings?) throws {
        try runBlocking { [weak self] in
            guard let self else {
                return
            }
            try await self.setTunnelNetworkSettingsAsync(settings)
        }
    }

    private func makeTunnelCore(config: TunnelConfiguration, singBoxConfig: String?) throws -> TunnelCore {
        let configContent = try singBoxConfig ?? SingBoxConfigurationBuilder.build(from: config)

        #if canImport(Libbox)
        return LibboxTunnelCore(provider: self, configContent: configContent)
        #else
        return PlaceholderTunnelCore(provider: self, config: config, singBoxConfig: configContent)
        #endif
    }

    fileprivate func makeFallbackNetworkSettings(config: TunnelConfiguration) -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "198.18.0.1")
        settings.mtu = 1280

        let ipv4 = NEIPv4Settings(addresses: ["198.18.0.2"], subnetMasks: ["255.255.255.0"])

        if config.killSwitchEnabled || config.routeMode == .global || config.routeMode == .auto {
            ipv4.includedRoutes = [NEIPv4Route.default()]
        } else {
            ipv4.includedRoutes = []
        }

        ipv4.excludedRoutes = [
            NEIPv4Route(destinationAddress: "10.0.0.0", subnetMask: "255.0.0.0"),
            NEIPv4Route(destinationAddress: "172.16.0.0", subnetMask: "255.240.0.0"),
            NEIPv4Route(destinationAddress: "192.168.0.0", subnetMask: "255.255.0.0")
        ]

        settings.ipv4Settings = ipv4

        if config.dnsProtectionEnabled {
            let dns = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
            dns.matchDomains = [""]
            settings.dnsSettings = dns
        }

        return settings
    }

    private func setTunnelNetworkSettingsAsync(_ settings: NEPacketTunnelNetworkSettings?) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setTunnelNetworkSettings(settings) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

enum TunnelProviderError: LocalizedError {
    case noProfiles
    case coreNotIntegrated
    case missingSingBoxConfig

    var errorDescription: String? {
        switch self {
        case .noProfiles:
            return "No proxy profiles are configured."
        case .coreNotIntegrated:
            return "Tunnel core is not integrated yet."
        case .missingSingBoxConfig:
            return "Missing generated sing-box config."
        }
    }
}

protocol TunnelCore {
    func start() throws
    func stop()
    func sleep()
    func wake()
}

extension TunnelCore {
    func sleep() {}
    func wake() {}
}

private final class PlaceholderTunnelCore: TunnelCore {
    private weak var provider: PacketTunnelProvider?
    private let config: TunnelConfiguration
    private let singBoxConfig: String?

    init(provider: PacketTunnelProvider?, config: TunnelConfiguration, singBoxConfig: String?) {
        self.provider = provider
        self.config = config
        self.singBoxConfig = singBoxConfig
    }

    func start() throws {
        guard let provider else {
            throw TunnelProviderError.coreNotIntegrated
        }

        guard let profile = activeProfile else {
            throw TunnelProviderError.noProfiles
        }

        try provider.applyTunnelNetworkSettings(provider.makeFallbackNetworkSettings(config: config))

        DebugLogger.shared.log(
            .warning,
            source: "TunnelCore",
            "Placeholder core selected for \(profile.proto.rawValue) \(profile.server):\(profile.port). Libbox is not linked in this build."
        )

        if let singBoxConfig {
            DebugLogger.shared.log(
                .info,
                source: "TunnelCore",
                "Generated sing-box config: \(singBoxConfig.count) bytes"
            )
        } else {
            DebugLogger.shared.log(.warning, source: "TunnelCore", "Missing generated sing-box config")
        }
    }

    func stop() {
        DebugLogger.shared.log(.info, source: "TunnelCore", "Placeholder core stopped")
    }

    private var activeProfile: ProxyProfile? {
        if
            let id = config.activeProfileID,
            let profile = config.profiles.first(where: { $0.id == id })
        {
            return profile
        }

        return config.profiles.first
    }
}
