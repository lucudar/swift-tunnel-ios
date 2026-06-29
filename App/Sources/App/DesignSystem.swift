import SwiftUI

enum STColor {
    static let accent = Color(red: 0.0, green: 0.74, blue: 0.62)
    static let accentSoft = Color(red: 0.46, green: 0.86, blue: 0.78)
    static let warning = Color(red: 1.0, green: 0.72, blue: 0.24)
    static let danger = Color(red: 1.0, green: 0.28, blue: 0.32)
    static let darkSurface = Color(red: 0.055, green: 0.058, blue: 0.064)
    static let lightSurface = Color(red: 0.955, green: 0.956, blue: 0.962)
}

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()

            MinimalField()
                .opacity(colorScheme == .dark ? 0.9 : 0.72)
        }
    }
}

private struct MinimalField: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let line = colorScheme == .dark
                    ? Color.white.opacity(0.045)
                    : Color.black.opacity(0.035)
                let accent = STColor.accent.opacity(colorScheme == .dark ? 0.12 : 0.08)

                for index in 0..<8 {
                    var path = Path()
                    let y = size.height * CGFloat(index + 1) / 9
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(line), lineWidth: 0.5)
                }

                let center = CGPoint(x: size.width / 2, y: size.height * 0.36)
                for index in 0..<3 {
                    let radius = CGFloat(92 + index * 42)
                    let start = Angle.degrees(time * 10 + Double(index) * 28)
                    let end = Angle.degrees(start.degrees + 115)
                    var arc = Path()
                    arc.addArc(
                        center: center,
                        radius: radius,
                        startAngle: start,
                        endAngle: end,
                        clockwise: false
                    )
                    context.stroke(arc, with: .color(accent), lineWidth: 1)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct PanelStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(surfaceColor)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.07), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var surfaceColor: Color {
        colorScheme == .dark
            ? STColor.darkSurface.opacity(0.94)
            : STColor.lightSurface.opacity(0.96)
    }
}

extension View {
    func panel() -> some View {
        modifier(PanelStyle())
    }
}

struct MinimalIconButton: View {
    let systemName: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 42, height: 42)
                .background(Color.primary.opacity(0.06))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct StatusDot: View {
    let isActive: Bool

    var body: some View {
        Circle()
            .fill(isActive ? STColor.accent : Color.secondary.opacity(0.35))
            .frame(width: 8, height: 8)
            .overlay {
                if isActive {
                    Circle()
                        .stroke(STColor.accent.opacity(0.42), lineWidth: 6)
                }
            }
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    var systemName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let systemName {
                    Image(systemName: systemName)
                        .font(.caption)
                }
                Text(title)
                    .font(.caption)
            }
            .foregroundStyle(.secondary)

            Text(value)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panel()
    }
}

struct PowerControl: View {
    let isActive: Bool
    let isBusy: Bool
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                PowerRings(isActive: isActive, isBusy: isBusy)
                    .frame(width: 238, height: 238)

                Circle()
                    .fill(fillStyle)
                    .frame(width: 142, height: 142)
                    .overlay {
                        Circle()
                            .strokeBorder(Color.primary.opacity(isActive ? 0.0 : 0.08), lineWidth: 1)
                    }
                    .shadow(color: isActive ? STColor.accent.opacity(0.26) : .clear, radius: 24, y: 10)

                Image(systemName: "power")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(isActive ? Color.black : Color.primary)
                    .scaleEffect(isBusy ? 0.92 : 1.0)
            }
            .scaleEffect(pressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.18), value: pressed)
            .animation(.easeInOut(duration: 0.7), value: isBusy)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
        .accessibilityLabel(isActive ? "Disconnect" : "Connect")
    }

    private var fillStyle: LinearGradient {
        if isActive {
            return LinearGradient(
                colors: [STColor.accentSoft, STColor.accent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [Color.primary.opacity(0.08), Color.primary.opacity(0.035)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct PowerRings: View {
    let isActive: Bool
    let isBusy: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let activeOpacity = isActive ? 0.44 : 0.16
                let speed = isBusy ? 48.0 : 16.0

                for index in 0..<3 {
                    let radius = CGFloat(74 + index * 31)
                    var circle = Path()
                    circle.addEllipse(in: CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    ))

                    context.stroke(
                        circle,
                        with: .color((isActive ? STColor.accent : Color.secondary).opacity(activeOpacity - Double(index) * 0.08)),
                        style: StrokeStyle(
                            lineWidth: index == 0 ? 2 : 1,
                            lineCap: .round,
                            dash: [24, 18],
                            dashPhase: CGFloat(t * speed + Double(index) * 18)
                        )
                    )
                }
            }
        }
    }
}

struct TrafficLine: View {
    let isActive: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                var path = Path()
                let mid = size.height / 2
                let amplitude = size.height * (isActive ? 0.32 : 0.12)

                for step in 0...36 {
                    let x = size.width * CGFloat(step) / 36
                    let wave = sin(t * (isActive ? 2.2 : 0.7) + Double(step) * 0.55)
                    let y = mid + CGFloat(wave) * amplitude
                    if step == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                context.stroke(
                    path,
                    with: .color((isActive ? STColor.accent : Color.secondary).opacity(isActive ? 0.78 : 0.32)),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .frame(height: 34)
        .accessibilityHidden(true)
    }
}

struct CapsuleBadge: View {
    let text: String
    var systemName: String?

    var body: some View {
        HStack(spacing: 5) {
            if let systemName {
                Image(systemName: systemName)
                    .font(.caption2)
            }
            Text(text)
                .font(.caption2.monospaced())
                .lineLimit(1)
        }
        .foregroundStyle(.secondary)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.primary.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
