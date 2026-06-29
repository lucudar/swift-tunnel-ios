#if canImport(Libbox)
import Foundation
import Libbox
import Network
import NetworkExtension

final class LibboxPlatformAdapter: NSObject, LibboxPlatformInterfaceProtocol {
    private weak var provider: PacketTunnelProvider?
    private var networkSettings: NEPacketTunnelNetworkSettings?
    private var pathMonitor: NWPathMonitor?

    init(provider: PacketTunnelProvider) {
        self.provider = provider
        super.init()
    }

    func openTun(_ options: LibboxTunOptionsProtocol?, ret0_: UnsafeMutablePointer<Int32>?) throws {
        guard let options else {
            throw platformError("Missing TUN options.")
        }
        guard let ret0_ else {
            throw platformError("Missing TUN return pointer.")
        }
        guard let provider else {
            throw platformError("Packet tunnel provider is gone.")
        }

        let settings = makeNetworkSettings(options: options)
        networkSettings = settings
        try provider.applyTunnelNetworkSettings(settings)

        if let fd = provider.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32 {
            ret0_.pointee = fd
            return
        }

        let fd = LibboxGetTunnelFileDescriptor()
        guard fd != -1 else {
            throw platformError("Could not resolve tunnel file descriptor.")
        }
        ret0_.pointee = fd
    }

    func usePlatformAutoDetectControl() -> Bool {
        false
    }

    func usePlatformAutoDetectInterfaceControl() -> Bool {
        usePlatformAutoDetectControl()
    }

    func autoDetectControl(_ fd: Int32) throws {}

    func autoDetectInterfaceControl(_ fd: Int32) throws {
        try autoDetectControl(fd)
    }

    func localDNSTransport() -> (any LibboxLocalDNSTransportProtocol)? {
        nil
    }

    func useProcFS() -> Bool {
        false
    }

    func findConnectionOwner(
        _ ipProtocol: Int32,
        sourceAddress: String?,
        sourcePort: Int32,
        destinationAddress: String?,
        destinationPort: Int32
    ) throws -> LibboxConnectionOwner {
        throw platformError("Connection owner lookup is not available on iOS.")
    }

    func startDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListenerProtocol?) throws {
        guard let listener else {
            return
        }

        let monitor = NWPathMonitor()
        pathMonitor = monitor

        let semaphore = DispatchSemaphore(value: 0)
        var didSendFirstUpdate = false

        monitor.pathUpdateHandler = { [weak self] path in
            self?.updateDefaultInterface(listener: listener, path: path)
            if !didSendFirstUpdate {
                didSendFirstUpdate = true
                semaphore.signal()
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.swiftunnel.libbox.path-monitor", qos: .utility))
        semaphore.wait()
    }

    func closeDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListenerProtocol?) throws {
        pathMonitor?.cancel()
        pathMonitor = nil
    }

    func getInterfaces() throws -> LibboxNetworkInterfaceIteratorProtocol {
        guard let pathMonitor else {
            return NetworkInterfaceIterator([])
        }

        let path = pathMonitor.currentPath
        guard path.status != Network.NWPath.Status.unsatisfied else {
            return NetworkInterfaceIterator([])
        }

        let interfaces = path.availableInterfaces.map { nwInterface in
            let networkInterface = LibboxNetworkInterface()
            networkInterface.name = nwInterface.name
            networkInterface.index = Int32(nwInterface.index)
            networkInterface.mtu = 0
            networkInterface.flags = 0
            networkInterface.addresses = StringIterator([])
            networkInterface.dnsServer = StringIterator([])
            networkInterface.metered = path.isExpensive

            switch nwInterface.type {
            case .wifi:
                networkInterface.type = LibboxInterfaceTypeWIFI
            case .cellular:
                networkInterface.type = LibboxInterfaceTypeCellular
            case .wiredEthernet:
                networkInterface.type = LibboxInterfaceTypeEthernet
            default:
                networkInterface.type = LibboxInterfaceTypeOther
            }

            return networkInterface
        }

        return NetworkInterfaceIterator(interfaces)
    }

    func underNetworkExtension() -> Bool {
        true
    }

    func includeAllNetworks() -> Bool {
        false
    }

    func readWIFIState() -> LibboxWIFIState? {
        nil
    }

    func systemCertificates() -> (any LibboxStringIteratorProtocol)? {
        nil
    }

    func clearDNSCache() {
        guard let provider, let networkSettings else {
            return
        }

        do {
            try provider.applyTunnelNetworkSettings(nil)
            try provider.applyTunnelNetworkSettings(networkSettings)
        } catch {
            DebugLogger.shared.log(.warning, source: "Libbox", "DNS cache refresh failed: \(error.localizedDescription)")
        }
    }

    func send(_ notification: LibboxNotification?) throws {}

    func sendNotification(_ notification: LibboxNotification?) throws {
        try send(notification)
    }

    func reset() {
        networkSettings = nil
        pathMonitor?.cancel()
        pathMonitor = nil
    }

    func systemProxyStatus() -> LibboxSystemProxyStatus {
        let status = LibboxSystemProxyStatus()
        guard let proxySettings = networkSettings?.proxySettings else {
            return status
        }

        status.available = proxySettings.httpServer != nil
        status.enabled = proxySettings.httpEnabled
        return status
    }

    func setSystemProxyEnabled(_ enabled: Bool) throws {
        guard let provider, let settings = networkSettings, let proxySettings = settings.proxySettings else {
            return
        }
        guard proxySettings.httpServer != nil else {
            return
        }

        proxySettings.httpEnabled = enabled
        proxySettings.httpsEnabled = enabled
        settings.proxySettings = proxySettings
        networkSettings = settings
        try provider.applyTunnelNetworkSettings(settings)
    }

    private func makeNetworkSettings(options: LibboxTunOptionsProtocol) -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        guard options.getAutoRoute() else {
            return settings
        }

        settings.mtu = NSNumber(value: options.getMTU())
        settings.ipv4Settings = makeIPv4Settings(options: options)
        settings.ipv6Settings = makeIPv6Settings(options: options)
        settings.dnsSettings = makeDNSSettings(options: options)

        if options.isHTTPProxyEnabled() {
            settings.proxySettings = makeProxySettings(options: options)
        }

        return settings
    }

    private func makeIPv4Settings(options: LibboxTunOptionsProtocol) -> NEIPv4Settings? {
        let addressPrefixes = routePrefixes(from: options.getInet4Address())
        guard addressPrefixes.isEmpty == false else {
            return nil
        }

        let settings = NEIPv4Settings(
            addresses: addressPrefixes.map(\.address),
            subnetMasks: addressPrefixes.map(\.mask)
        )

        let includedRoutes = routePrefixes(from: options.getInet4RouteAddress()).map {
            NEIPv4Route(destinationAddress: $0.address, subnetMask: $0.mask)
        }
        settings.includedRoutes = includedRoutes.isEmpty ? [NEIPv4Route.default()] : includedRoutes

        let excludedRoutes = routePrefixes(from: options.getInet4RouteExcludeAddress()).map {
            NEIPv4Route(destinationAddress: $0.address, subnetMask: $0.mask)
        }
        if excludedRoutes.isEmpty == false {
            settings.excludedRoutes = excludedRoutes
        }

        return settings
    }

    private func makeIPv6Settings(options: LibboxTunOptionsProtocol) -> NEIPv6Settings? {
        let addressPrefixes = routePrefixes(from: options.getInet6Address())
        guard addressPrefixes.isEmpty == false else {
            return nil
        }

        let settings = NEIPv6Settings(
            addresses: addressPrefixes.map(\.address),
            networkPrefixLengths: addressPrefixes.map { NSNumber(value: $0.prefix) }
        )

        let includedRoutes = routePrefixes(from: options.getInet6RouteAddress()).map {
            NEIPv6Route(destinationAddress: $0.address, networkPrefixLength: NSNumber(value: $0.prefix))
        }
        settings.includedRoutes = includedRoutes.isEmpty ? [NEIPv6Route.default()] : includedRoutes

        let excludedRoutes = routePrefixes(from: options.getInet6RouteExcludeAddress()).map {
            NEIPv6Route(destinationAddress: $0.address, networkPrefixLength: NSNumber(value: $0.prefix))
        }
        if excludedRoutes.isEmpty == false {
            settings.excludedRoutes = excludedRoutes
        }

        return settings
    }

    private func makeDNSSettings(options: LibboxTunOptionsProtocol) -> NEDNSSettings? {
        let dnsServer = options.getDNSServerAddress().value
        guard dnsServer.isEmpty == false else {
            return nil
        }

        let settings = NEDNSSettings(servers: [dnsServer])
        settings.matchDomains = [""]
        settings.matchDomainsNoSearch = true
        return settings
    }

    private func makeProxySettings(options: LibboxTunOptionsProtocol) -> NEProxySettings {
        let proxySettings = NEProxySettings()
        let server = NEProxyServer(
            address: options.getHTTPProxyServer(),
            port: Int(options.getHTTPProxyServerPort())
        )
        proxySettings.httpServer = server
        proxySettings.httpsServer = server
        proxySettings.httpEnabled = true
        proxySettings.httpsEnabled = true

        let bypassDomains = strings(from: options.getHTTPProxyBypassDomain())
        if bypassDomains.isEmpty == false {
            proxySettings.exceptionList = bypassDomains
        }

        let matchDomains = strings(from: options.getHTTPProxyMatchDomain())
        if matchDomains.isEmpty == false {
            proxySettings.matchDomains = matchDomains
        }

        return proxySettings
    }

    private func routePrefixes(from iterator: LibboxRoutePrefixIteratorProtocol?) -> [RoutePrefix] {
        guard let iterator else {
            return []
        }

        var prefixes: [RoutePrefix] = []
        while iterator.hasNext() {
            guard let prefix = iterator.next() else {
                continue
            }
            prefixes.append(
                RoutePrefix(
                    address: prefix.address(),
                    mask: prefix.mask(),
                    prefix: prefix.prefix()
                )
            )
        }
        return prefixes
    }

    private func strings(from iterator: LibboxStringIteratorProtocol?) -> [String] {
        guard let iterator else {
            return []
        }

        var values: [String] = []
        while iterator.hasNext() {
            values.append(iterator.next())
        }
        return values
    }

    private func updateDefaultInterface(listener: LibboxInterfaceUpdateListenerProtocol, path: Network.NWPath) {
        guard path.status != Network.NWPath.Status.unsatisfied, let defaultInterface = path.availableInterfaces.first else {
            listener.updateDefaultInterface(
                "",
                interfaceIndex: -1,
                isExpensive: false,
                isConstrained: false
            )
            return
        }

        listener.updateDefaultInterface(
            defaultInterface.name,
            interfaceIndex: Int32(defaultInterface.index),
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained
        )
    }

    private func platformError(_ message: String) -> NSError {
        NSError(
            domain: "LibboxPlatformAdapter",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}

private struct RoutePrefix {
    let address: String
    let mask: String
    let prefix: Int32
}

private final class NetworkInterfaceIterator: NSObject, LibboxNetworkInterfaceIteratorProtocol {
    private let interfaces: [LibboxNetworkInterface]
    private var index = 0

    init(_ interfaces: [LibboxNetworkInterface]) {
        self.interfaces = interfaces
    }

    func hasNext() -> Bool {
        index < interfaces.count
    }

    func next() -> LibboxNetworkInterface? {
        guard index < interfaces.count else {
            return nil
        }

        let value = interfaces[index]
        index += 1
        return value
    }
}

private final class StringIterator: NSObject, LibboxStringIteratorProtocol {
    private let values: [String]
    private var index = 0

    init(_ values: [String]) {
        self.values = values
    }

    func len() -> Int32 {
        Int32(values.count)
    }

    func hasNext() -> Bool {
        index < values.count
    }

    func next() -> String {
        guard index < values.count else {
            return ""
        }

        let value = values[index]
        index += 1
        return value
    }
}
#endif
