import SwiftUI

struct RootView: View {
    @EnvironmentObject private var vpn: VPNManager
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "bolt.horizontal.circle")
                }
                .tag(AppTab.home)

            ProfilesView()
                .tabItem {
                    Label("Nodes", systemImage: "point.3.connected.trianglepath.dotted")
                }
                .tag(AppTab.profiles)

            DebugView()
                .tabItem {
                    Label("Debug", systemImage: "terminal")
                }
                .tag(AppTab.debug)
        }
        .tint(STColor.accent)
    }
}

private enum AppTab {
    case home
    case profiles
    case debug
}

