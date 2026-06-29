import Foundation

enum ProxyLinkParserError: LocalizedError {
    case unsupportedScheme(String)
    case invalidURL
    case missingHost
    case missingCredential
    case invalidPort
    case invalidShadowsocksPayload

    var errorDescription: String? {
        switch self {
        case let .unsupportedScheme(scheme):
            return "Unsupported proxy link scheme: \(scheme)."
        case .invalidURL:
            return "Proxy link is not a valid URL."
        case .missingHost:
            return "Proxy link is missing a server host."
        case .missingCredential:
            return "Proxy link is missing a credential."
        case .invalidPort:
            return "Proxy link has an invalid port."
        case .invalidShadowsocksPayload:
            return "Shadowsocks link payload is invalid."
        }
    }
}

enum ProxyLinkParser {
    static func parse(_ rawValue: String) throws -> ProxyProfile {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed), let scheme = components.scheme?.lowercased() else {
            throw ProxyLinkParserError.invalidURL
        }

        switch scheme {
        case "vless":
            return try parseVLESS(components, raw: trimmed)
        case "trojan":
            return try parseTrojan(components)
        case "ss":
            return try parseShadowsocks(trimmed)
        default:
            throw ProxyLinkParserError.unsupportedScheme(scheme)
        }
    }

    private static func parseVLESS(_ components: URLComponents, raw: String) throws -> ProxyProfile {
        guard let host = components.host, host.isEmpty == false else {
            throw ProxyLinkParserError.missingHost
        }
        guard let port = components.port else {
            throw ProxyLinkParserError.invalidPort
        }

        let credential = username(from: raw, scheme: "vless")
        guard credential.isEmpty == false else {
            throw ProxyLinkParserError.missingCredential
        }

        let query = queryItems(components)
        return ProxyProfile(
            name: displayName(components, fallback: host),
            server: host,
            port: port,
            proto: .vless,
            credential: credential,
            sni: query["sni"] ?? query["peer"] ?? query["host"],
            flow: query["flow"]
        )
    }

    private static func parseTrojan(_ components: URLComponents) throws -> ProxyProfile {
        guard let host = components.host, host.isEmpty == false else {
            throw ProxyLinkParserError.missingHost
        }
        guard let port = components.port else {
            throw ProxyLinkParserError.invalidPort
        }
        guard let credential = components.user, credential.isEmpty == false else {
            throw ProxyLinkParserError.missingCredential
        }

        let query = queryItems(components)
        return ProxyProfile(
            name: displayName(components, fallback: host),
            server: host,
            port: port,
            proto: .trojan,
            credential: credential,
            sni: query["sni"] ?? query["peer"] ?? query["host"]
        )
    }

    private static func parseShadowsocks(_ raw: String) throws -> ProxyProfile {
        let withoutScheme = String(raw.dropFirst("ss://".count))
        let splitFragment = withoutScheme.split(separator: "#", maxSplits: 1).map(String.init)
        let main = splitFragment[0]
        let name = splitFragment.count > 1 ? percentDecoded(splitFragment[1]) : nil

        let splitQuery = main.split(separator: "?", maxSplits: 1).map(String.init)
        let authority = splitQuery[0]

        let decodedAuthority: String
        if authority.contains("@") {
            decodedAuthority = authority
        } else if let decoded = base64URLDecode(authority) {
            decodedAuthority = decoded
        } else {
            throw ProxyLinkParserError.invalidShadowsocksPayload
        }

        let credentialAndServer = decodedAuthority.split(separator: "@", maxSplits: 1).map(String.init)
        guard credentialAndServer.count == 2 else {
            throw ProxyLinkParserError.invalidShadowsocksPayload
        }

        let methodAndPassword = credentialAndServer[0].split(separator: ":", maxSplits: 1).map(String.init)
        guard methodAndPassword.count == 2 else {
            throw ProxyLinkParserError.missingCredential
        }

        let serverAndPort = credentialAndServer[1].split(separator: ":", maxSplits: 1).map(String.init)
        guard serverAndPort.count == 2 else {
            throw ProxyLinkParserError.missingHost
        }
        guard let port = Int(serverAndPort[1]) else {
            throw ProxyLinkParserError.invalidPort
        }

        return ProxyProfile(
            name: name?.isEmpty == false ? name! : serverAndPort[0],
            server: serverAndPort[0],
            port: port,
            proto: .shadowsocks,
            credential: methodAndPassword[1],
            method: methodAndPassword[0]
        )
    }

    private static func queryItems(_ components: URLComponents) -> [String: String] {
        Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            guard let value = item.value else {
                return nil
            }
            return (item.name.lowercased(), value)
        })
    }

    private static func displayName(_ components: URLComponents, fallback: String) -> String {
        guard let fragment = components.fragment?.removingPercentEncoding, fragment.isEmpty == false else {
            return fallback
        }

        return fragment
    }

    private static func username(from raw: String, scheme: String) -> String {
        let prefix = "\(scheme)://"
        guard raw.lowercased().hasPrefix(prefix) else {
            return ""
        }

        let rest = raw.dropFirst(prefix.count)
        guard let atIndex = rest.firstIndex(of: "@") else {
            return ""
        }

        return String(rest[..<atIndex]).removingPercentEncoding ?? String(rest[..<atIndex])
    }

    private static func percentDecoded(_ value: String) -> String {
        value.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? value
    }

    private static func base64URLDecode(_ value: String) -> String? {
        var normalized = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        while normalized.count % 4 != 0 {
            normalized.append("=")
        }

        guard let data = Data(base64Encoded: normalized) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
}

