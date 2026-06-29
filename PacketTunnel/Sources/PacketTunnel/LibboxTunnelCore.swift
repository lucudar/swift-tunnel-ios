#if canImport(Libbox)
import Foundation
import Libbox
import NetworkExtension

final class LibboxTunnelCore: NSObject, TunnelCore, LibboxCommandServerHandlerProtocol {
    private weak var provider: PacketTunnelProvider?
    private let configContent: String
    private let platformAdapter: LibboxPlatformAdapter
    private var commandServer: LibboxCommandServer?

    init(provider: PacketTunnelProvider, configContent: String) {
        self.provider = provider
        self.configContent = configContent
        self.platformAdapter = LibboxPlatformAdapter(provider: provider)
        super.init()
    }

    func start() throws {
        guard configContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw TunnelProviderError.missingSingBoxConfig
        }

        let paths = try LibboxRuntimePaths.resolve()
        LibboxSetLocale(Locale.current.identifier)
        LibboxSetMemoryLimit(true)

        let setupOptions = LibboxSetupOptions()
        setupOptions.basePath = paths.basePath
        setupOptions.workingPath = paths.workingPath
        setupOptions.tempPath = paths.tempPath
        setupOptions.logMaxLines = 1_500
        setupOptions.debug = false

        var setupError: NSError?
        if !LibboxSetup(setupOptions, &setupError) {
            throw setupError ?? coreError("Libbox setup failed.")
        }

        var checkError: NSError?
        if !LibboxCheckConfig(configContent, &checkError) {
            throw checkError ?? coreError("sing-box config validation failed.")
        }

        var serverError: NSError?
        let server = LibboxNewCommandServer(self, platformAdapter, &serverError)
        if let serverError {
            throw serverError
        }
        guard let server else {
            throw coreError("Libbox command server was not created.")
        }

        commandServer = server
        try server.start()
        try startService()

        DebugLogger.shared.log(
            .info,
            source: "Libbox",
            "Started sing-box \(LibboxVersion()) with config size \(configContent.count) bytes"
        )
    }

    func stop() {
        DebugLogger.shared.log(.info, source: "Libbox", "Stopping sing-box service")

        if let commandServer {
            do {
                try commandServer.closeService()
            } catch {
                DebugLogger.shared.log(.warning, source: "Libbox", "closeService failed: \(error.localizedDescription)")
            }
            commandServer.close()
        }

        platformAdapter.reset()
        commandServer = nil
    }

    func sleep() {
        commandServer?.pause()
    }

    func wake() {
        commandServer?.wake()
    }

    func serviceStop() throws {
        DebugLogger.shared.log(.info, source: "Libbox", "Service stop requested by command server")
        try commandServer?.closeService()
        platformAdapter.reset()
    }

    func serviceReload() throws {
        DebugLogger.shared.log(.info, source: "Libbox", "Service reload requested by command server")
        try startService()
    }

    func getSystemProxyStatus() throws -> LibboxSystemProxyStatus {
        platformAdapter.systemProxyStatus()
    }

    func setSystemProxyEnabled(_ enabled: Bool) throws {
        try platformAdapter.setSystemProxyEnabled(enabled)
    }

    func writeDebugMessage(_ message: String?) {
        guard let message, message.isEmpty == false else {
            return
        }
        DebugLogger.shared.log(.debug, source: "Libbox", message)
    }

    func writeMessage(_ message: String) {
        commandServer?.writeMessage(2, message: message)
        DebugLogger.shared.log(.info, source: "Libbox", message)
    }

    private func startService() throws {
        guard let commandServer else {
            throw coreError("Libbox command server is not running.")
        }

        let overrideOptions = LibboxOverrideOptions()
        try commandServer.startOrReloadService(configContent, options: overrideOptions)
    }

    private func coreError(_ message: String) -> NSError {
        NSError(
            domain: "LibboxTunnelCore",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}

private struct LibboxRuntimePaths {
    let basePath: String
    let workingPath: String
    let tempPath: String

    static func resolve() throws -> LibboxRuntimePaths {
        let fileManager = FileManager.default
        let baseURL = fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupIdentifier)?
            .appendingPathComponent("Libbox", isDirectory: true)
            ?? fileManager.temporaryDirectory.appendingPathComponent("SwiftTunnel-Libbox", isDirectory: true)

        let workingURL = baseURL.appendingPathComponent("Working", isDirectory: true)
        let tempURL = baseURL.appendingPathComponent("Temp", isDirectory: true)

        try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: workingURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: tempURL, withIntermediateDirectories: true)

        return LibboxRuntimePaths(
            basePath: baseURL.path,
            workingPath: workingURL.path,
            tempPath: tempURL.path
        )
    }
}
#endif
