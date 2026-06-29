import SwiftUI

enum STColor {
    static let accent = Color(red: 0.0, green: 0.78, blue: 0.65)
    static let accent2 = Color(red: 0.18, green: 0.56, blue: 1.0)
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
            .background((colorScheme == .dark ? STColor.panelDark : STColor.panelLight).opacity(0.9))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06), lineWidth: 1)
            }
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

struct AnimatedTunnelBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var phase = false

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let base = colorScheme == .dark ? Color.black : Color.white
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(base))

                let lineColor = colorScheme == .dark ? STColor.accent.opacity(0.18) : STColor.accent2.opacity(0.14)
                let secondary = colorScheme == .dark ? STColor.accent2.opacity(0.12) : STColor.accent.opacity(0.12)

                for index in 0..<10 {
                    var path = Path()
                    let y = size.height * CGFloat(index) / 9
                    let offset = CGFloat(sin(t * 0.45 + Double(index))) * 18
                    path.move(to: CGPoint(x: -40, y: y + offset))

                    for step in 0...6 {
                        let x = size.width * CGFloat(step) / 6
                        let wave = CGFloat(sin(t * 0.9 + Double(step + index))) * 22
                        path.addLine(to: CGPoint(x: x, y: y + offset + wave))
                    }

                    context.stroke(path, with: .color(index.isMultiple(of: 2) ? lineColor : secondary), lineWidth: 1)
                }

                let glowCenter = CGPoint(
                    x: size.width * (0.72 + CGFloat(sin(t * 0.23)) * 0.06),
                    y: size.height * (0.18 + CGFloat(cos(t * 0.31)) * 0.05)
                )
                let glow = Path(ellipseIn: CGRect(x: glowCenter.x - 90, y: glowCenter.y - 90, width: 180, height: 180))
                context.fill(glow, with: .radialGradient(
                    Gradient(colors: [STColor.accent.opacity(colorScheme == .dark ? 0.22 : 0.13), .clear]),
                    center: glowCenter,
                    startRadius: 0,
                    endRadius: 96
                ))
            }
        }
        .ignoresSafeArea()
    }
}

struct ConnectOrb: View {
    let isActive: Bool
    let action: () -> Void
    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            ZStack {
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    STColor.accent.opacity(isActive ? 0.55 : 0.18),
                                    STColor.accent2.opacity(isActive ? 0.35 : 0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 150 + CGFloat(index * 28), height: 150 + CGFloat(index * 28))
                        .scaleEffect(pulse && isActive ? 1.08 : 0.96)
                        .opacity(isActive ? 0.9 - Double(index) * 0.2 : 0.45)
                        .animation(
                            .easeInOut(duration: 1.8 + Double(index) * 0.25).repeatForever(autoreverses: true),
                            value: pulse
                        )
                }

                Circle()
                    .fill(
                        RadialGradient(
                            colors: isActive
                                ? [STColor.accent, STColor.accent2.opacity(0.84), Color.black]
                                : [Color.primary, Color.primary.opacity(0.82), Color.secondary.opacity(0.38)],
                            center: .topLeading,
                            startRadius: 12,
                            endRadius: 86
                        )
                    )
                    .frame(width: 132, height: 132)
                    .shadow(color: isActive ? STColor.accent.opacity(0.42) : .clear, radius: 28)

                Image(systemName: isActive ? "bolt.shield.fill" : "power")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(isActive ? Color.black : Color(uiColor: .systemBackground))
                    .scaleEffect(pulse && isActive ? 1.08 : 0.96)
                    .animation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true), value: pulse)
            }
            .frame(width: 230, height: 230)
        }
        .buttonStyle(.plain)
        .onAppear { pulse = true }
    }
}

struct ThroughputStrip: View {
    let isActive: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let bars = 26
                let gap: CGFloat = 4
                let width = max(2, (size.width - CGFloat(bars - 1) * gap) / CGFloat(bars))

                for index in 0..<bars {
                    let phase = t * (isActive ? 3.2 : 0.7) + Double(index) * 0.42
                    let normalized = (sin(phase) + 1) / 2
                    let height = size.height * CGFloat(0.18 + normalized * (isActive ? 0.75 : 0.26))
                    let rect = CGRect(
                        x: CGFloat(index) * (width + gap),
                        y: size.height - height,
                        width: width,
                        height: height
                    )
                    let color = isActive
                        ? STColor.accent.opacity(0.35 + normalized * 0.55)
                        : Color.secondary.opacity(0.12 + normalized * 0.18)
                    context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(color))
                }
            }
        }
        .frame(height: 42)
    }
}
