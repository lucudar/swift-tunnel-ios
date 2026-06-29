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
    var credential: String
    var sni: String?
    var flow: String?
    var method: String?
    var latencyMS: Int?
    var lastError: String?

    init(
        id: UUID = UUID(),
        name: String,
        server: String,
        port: Int,
        proto: ProxyProtocol,
        credential: String = "",
        sni: String? = nil,
        flow: String? = nil,
        method: String? = nil,
        latencyMS: Int? = nil,
        lastError: String? = nil
    ) {
        self.id = id
        self.name = name
        self.server = server
        self.port = port
        self.proto = proto
        self.credential = credential
        self.sni = sni
        self.flow = flow
        self.method = method
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
            ProxyProfile(
                name: "Demo VLESS",
                server: "example.com",
                port: 443,
                proto: .vless,
                credential: "00000000-0000-0000-0000-000000000000",
                sni: "example.com",
                latencyMS: 38
            )
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
