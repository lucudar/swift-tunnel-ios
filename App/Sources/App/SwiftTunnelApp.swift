import SwiftUI

@main
struct SwiftTunnelApp: App {
    @StateObject private var vpnManager = VPNManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(vpnManager)
        }
    }
}

