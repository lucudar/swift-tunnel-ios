import SwiftUI

struct RootView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    HomeView()
                case .profiles:
                    ProfilesView()
                case .debug:
                    DebugView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomDock(selectedTab: $selectedTab)
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
        }
        .tint(STColor.accent)
    }
}

private struct BottomDock: View {
    @Binding var selectedTab: AppTab
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 17, weight: .semibold))
                        Text(tab.title)
                            .font(.caption2.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .foregroundStyle(selectedTab == tab ? activeForeground : Color.secondary)
                    .background(selectedTab == tab ? activeBackground : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(dockBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.09 : 0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.08), radius: 22, y: 12)
    }

    private var activeForeground: Color {
        colorScheme == .dark ? .black : .white
    }

    private var activeBackground: Color {
        colorScheme == .dark ? STColor.accent : Color.black
    }

    private var dockBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.08, green: 0.082, blue: 0.09).opacity(0.96)
            : Color.white.opacity(0.96)
    }
}

private enum AppTab: String, CaseIterable, Identifiable {
    case home
    case profiles
    case debug

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .profiles:
            return "Nodes"
        case .debug:
            return "Logs"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            return "power"
        case .profiles:
            return "server.rack"
        case .debug:
            return "terminal"
        }
    }
}
