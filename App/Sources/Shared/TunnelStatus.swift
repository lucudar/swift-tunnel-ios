import Foundation

enum TunnelStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case invalid
    case reasserting
    case unknown

    var title: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .disconnecting:
            return "Disconnecting"
        case .invalid:
            return "Invalid"
        case .reasserting:
            return "Reasserting"
        case .unknown:
            return "Unknown"
        }
    }

    var isActive: Bool {
        switch self {
        case .connected, .connecting, .reasserting:
            return true
        case .disconnected, .disconnecting, .invalid, .unknown:
            return false
        }
    }
}

