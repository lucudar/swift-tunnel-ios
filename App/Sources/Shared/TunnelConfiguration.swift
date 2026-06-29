import Foundation

enum ProxyProtocol: String, Codable, CaseIterable, Identifiable {
    case vless = "VLESS"
    case hysteria2 = "Hysteria2"
    case tuic = "TUIC"
    case trojan = "Trojan"
    case shadowsocks = "Shadowsocks"

    var id: String { rawValue }
}

enum RouteMode: String, Codable, CaseIterable, Identifiable {
    case auto = "Auto"
    case global = "Global"
    case rule = "Rule"
    case direct = "Direct"

    var id: String { rawValue }
}

struct ProxyProfile: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var server: String
    var port: Int
    var proto: ProxyProtocol
    var latencyMS: Int?
    var lastError: String?

    init(
        id: UUID = UUID(),
        name: String,
        server: String,
        port: Int,
        proto: ProxyProtocol,
        latencyMS: Int? = nil,
        lastError: String? = nil
    ) {
        self.id = id
        self.name = name
        self.server = server
        self.port = port
        self.proto = proto
        self.latencyMS = latencyMS
        self.lastError = lastError
    }
}

struct TunnelConfiguration: Codable, Equatable {
    var activeProfileID: UUID?
    var routeMode: RouteMode
    var dnsProtectionEnabled: Bool
    var killSwitchEnabled: Bool
    var profiles: [ProxyProfile]

    static let demo = TunnelConfiguration(
        activeProfileID: nil,
        routeMode: .auto,
        dnsProtectionEnabled: true,
        killSwitchEnabled: true,
        profiles: [
            ProxyProfile(name: "Auto Fast", server: "example.com", port: 443, proto: .vless, latencyMS: 38),
            ProxyProfile(name: "Mobile QUIC", server: "edge.example.com", port: 443, proto: .hysteria2, latencyMS: 52)
        ]
    )
}

enum TunnelConfigurationStore {
    static func load() -> TunnelConfiguration {
        guard
            let url = configURL(),
            let data = try? Data(contentsOf: url),
            let config = try? JSONDecoder().decode(TunnelConfiguration.self, from: data)
        else {
            return .demo
        }

        return config
    }

    static func save(_ config: TunnelConfiguration) throws {
        guard let url = configURL() else {
            throw CocoaError(.fileNoSuchFile)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: url, options: .atomic)
    }

    private static func configURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupIdentifier)?
            .appendingPathComponent(AppConstants.configFileName)
    }
}

