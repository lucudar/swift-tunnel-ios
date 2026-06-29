import Foundation

enum SingBoxConfigurationError: LocalizedError {
    case missingProfile
    case unsupportedProtocol(ProxyProtocol)

    var errorDescription: String? {
        switch self {
        case .missingProfile:
            return "No active proxy profile is available."
        case let .unsupportedProtocol(proto):
            return "\(proto.rawValue) is not implemented in the sing-box generator yet."
        }
    }
}

enum SingBoxConfigurationBuilder {
    static func build(from config: TunnelConfiguration) throws -> String {
        guard let profile = activeProfile(in: config) else {
            throw SingBoxConfigurationError.missingProfile
        }

        let root: [String: Any] = [
            "log": [
                "level": "warn",
                "timestamp": true
            ],
            "dns": dns(config: config),
            "inbounds": [
                tunInbound(config: config)
            ],
            "outbounds": [
                try outbound(profile: profile),
                [
                    "type": "direct",
                    "tag": "direct"
                ],
                [
                    "type": "block",
                    "tag": "block"
                ]
            ],
            "route": route(config: config)
        ]

        let data = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        return String(decoding: data, as: UTF8.self)
    }

    private static func activeProfile(in config: TunnelConfiguration) -> ProxyProfile? {
        if
            let id = config.activeProfileID,
            let profile = config.profiles.first(where: { $0.id == id })
        {
            return profile
        }

        return config.profiles.first
    }

    private static func dns(config: TunnelConfiguration) -> [String: Any] {
        [
            "servers": [
                [
                    "type": "https",
                    "tag": "remote",
                    "server": "1.1.1.1",
                    "server_port": 443,
                    "path": "/dns-query",
                    "detour": "proxy"
                ],
                [
                    "type": "local",
                    "tag": "local",
                    "detour": "direct"
                ]
            ],
            "rules": [
                [
                    "domain_suffix": [
                        "local"
                    ],
                    "server": "local"
                ]
            ],
            "final": config.dnsProtectionEnabled ? "remote" : "local",
            "strategy": "prefer_ipv4"
        ]
    }

    private static func tunInbound(config: TunnelConfiguration) -> [String: Any] {
        [
            "type": "tun",
            "tag": "tun-in",
            "address": [
                "172.19.0.1/30",
                "fdfe:dcba:9876::1/126"
            ],
            "mtu": 1280,
            "auto_route": true,
            "strict_route": config.killSwitchEnabled,
            "stack": "gvisor"
        ]
    }

    private static func outbound(profile: ProxyProfile) throws -> [String: Any] {
        switch profile.proto {
        case .vless:
            return vless(profile: profile)
        case .trojan:
            return trojan(profile: profile)
        case .shadowsocks:
            return shadowsocks(profile: profile)
        case .hysteria2, .tuic:
            throw SingBoxConfigurationError.unsupportedProtocol(profile.proto)
        }
    }

    private static func vless(profile: ProxyProfile) -> [String: Any] {
        var outbound: [String: Any] = [
            "type": "vless",
            "tag": "proxy",
            "server": profile.server,
            "server_port": profile.port,
            "uuid": profile.credential,
            "packet_encoding": "xudp"
        ]
        outbound.merge(dialerOptions()) { current, _ in current }

        outbound["tls"] = [
            "enabled": true,
            "server_name": profile.sni ?? profile.server,
            "utls": [
                "enabled": true,
                "fingerprint": "chrome"
            ]
        ]

        if let flow = profile.flow, !flow.isEmpty {
            outbound["flow"] = flow
        }

        return outbound
    }

    private static func trojan(profile: ProxyProfile) -> [String: Any] {
        var outbound: [String: Any] = [
            "type": "trojan",
            "tag": "proxy",
            "server": profile.server,
            "server_port": profile.port,
            "password": profile.credential,
            "tls": [
                "enabled": true,
                "server_name": profile.sni ?? profile.server,
                "utls": [
                    "enabled": true,
                    "fingerprint": "chrome"
                ]
            ]
        ]
        outbound.merge(dialerOptions()) { current, _ in current }
        return outbound
    }

    private static func shadowsocks(profile: ProxyProfile) -> [String: Any] {
        var outbound: [String: Any] = [
            "type": "shadowsocks",
            "tag": "proxy",
            "server": profile.server,
            "server_port": profile.port,
            "method": profile.method ?? "2022-blake3-aes-128-gcm",
            "password": profile.credential
        ]
        outbound.merge(dialerOptions()) { current, _ in current }
        return outbound
    }

    private static func dialerOptions() -> [String: Any] {
        [
            "connect_timeout": "8s",
            "tcp_fast_open": true,
            "tcp_multi_path": true,
            "udp_fragment": false,
            "domain_resolver": [
                "server": "local",
                "strategy": "prefer_ipv4"
            ],
            "network_strategy": "hybrid",
            "fallback_delay": "300ms"
        ]
    }

    private static func route(config: TunnelConfiguration) -> [String: Any] {
        var rules: [[String: Any]] = [
            [
                "action": "sniff",
                "sniffer": [
                    "tls",
                    "http",
                    "quic"
                ],
                "timeout": "300ms"
            ],
            [
                "protocol": "dns",
                "action": "hijack-dns"
            ],
            [
                "ip_is_private": true,
                "outbound": config.routeMode == .global ? "proxy" : "direct"
            ]
        ]

        if config.routeMode == .direct {
            rules.append([
                "network": "udp",
                "port": 443,
                "outbound": "direct"
            ])
        }

        return [
            "rules": rules,
            "auto_detect_interface": true,
            "default_domain_resolver": [
                "server": "local",
                "strategy": "prefer_ipv4"
            ],
            "default_network_strategy": "hybrid",
            "default_fallback_delay": "300ms",
            "final": config.routeMode == .direct ? "direct" : "proxy"
        ]
    }
}
