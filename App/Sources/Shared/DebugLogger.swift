import Foundation
import OSLog

enum DebugLevel: String, Codable, CaseIterable, Identifiable {
    case debug
    case info
    case warning
    case error

    var id: String { rawValue }
}

struct DebugEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let level: DebugLevel
    let source: String
    let message: String

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        level: DebugLevel,
        source: String,
        message: String
    ) {
        self.id = id
        self.date = date
        self.level = level
        self.source = source
        self.message = message
    }
}

final class DebugLogger {
    static let shared = DebugLogger()

    private let logger = Logger(subsystem: "com.swiftunnel.app", category: "debug")
    private let queue = DispatchQueue(label: "com.swiftunnel.debug-log", qos: .utility)
    private let encoder = JSONEncoder()

    private init() {
        encoder.dateEncodingStrategy = .iso8601
    }

    func log(_ level: DebugLevel, source: String, _ message: String) {
        let entry = DebugEntry(level: level, source: source, message: message)

        switch level {
        case .debug:
            logger.debug("[\(source, privacy: .public)] \(message, privacy: .public)")
        case .info:
            logger.info("[\(source, privacy: .public)] \(message, privacy: .public)")
        case .warning:
            logger.warning("[\(source, privacy: .public)] \(message, privacy: .public)")
        case .error:
            logger.error("[\(source, privacy: .public)] \(message, privacy: .public)")
        }

        queue.async { [encoder] in
            guard
                let url = Self.logURL(),
                let data = try? encoder.encode(entry),
                let line = String(data: data, encoding: .utf8)
            else {
                return
            }

            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }

            guard let handle = try? FileHandle(forWritingTo: url) else {
                return
            }

            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: Data((line + "\n").utf8))
        }
    }

    func recentEntries(limit: Int = 200) -> [DebugEntry] {
        guard let url = Self.logURL(), let data = try? Data(contentsOf: url) else {
            return []
        }

        let lines = String(decoding: data, as: UTF8.self)
            .split(separator: "\n")
            .suffix(limit)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return lines.compactMap { line in
            guard let data = line.data(using: .utf8) else {
                return nil
            }

            return try? decoder.decode(DebugEntry.self, from: data)
        }
    }

    func clear() {
        guard let url = Self.logURL() else {
            return
        }

        try? Data().write(to: url, options: .atomic)
    }

    private static func logURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupIdentifier)?
            .appendingPathComponent(AppConstants.debugLogFileName)
    }
}

