import SwiftUI

enum STColor {
    static let accent = Color(red: 0.0, green: 0.78, blue: 0.65)
    static let warning = Color(red: 1.0, green: 0.73, blue: 0.25)
    static let danger = Color(red: 1.0, green: 0.29, blue: 0.33)
    static let panelDark = Color(red: 0.07, green: 0.07, blue: 0.08)
    static let panelLight = Color(red: 0.96, green: 0.96, blue: 0.97)
}

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Rectangle()
            .fill(colorScheme == .dark ? Color.black : Color.white)
            .ignoresSafeArea()
    }
}

struct PanelStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(colorScheme == .dark ? STColor.panelDark : STColor.panelLight)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

extension View {
    func panel() -> some View {
        modifier(PanelStyle())
    }
}

struct MetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

