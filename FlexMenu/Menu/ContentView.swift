import SwiftUI

struct ContentView: View {
    let model: MenuModel

    var body: some View {
        let items = model.menuItems
        ZStack {
            if model.state == .feedback, let title = model.feedbackTitle {
                Text(L10n.format("执行：%@", title))
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(.primary.opacity(0.12)))
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
            } else if model.state != .waiting, !items.isEmpty {
                ForEach(items.indices, id: \.self) { index in
                    segment(item: items[index], at: index, count: items.count)
                }
            }
        }
        .frame(width: MenuWheelGeometry.size, height: MenuWheelGeometry.size)
        .contentShape(Rectangle())
    }

    private func segment(item: MenuItem, at index: Int, count: Int) -> some View {
        let segmentAngle = 360.0 / Double(count)
        let gap = count > 1 ? MenuWheelGeometry.gapDegrees / 2 : 0
        let angle = MenuWheelGeometry.angle(for: index, count: count)
        let start = angle - segmentAngle / 2 + gap
        let end = angle + segmentAngle / 2 - gap
        let mid = angle * .pi / 180
        let labelRadius = (MenuWheelGeometry.innerRadius + MenuWheelGeometry.outerRadius) / 2
        let selected = model.selectedIndex == index
        let slice = MenuWheelSlice(start: start, end: end, fullCircle: count == 1)

        return ZStack {
            slice
                .fill(selected
                    ? AnyShapeStyle(Color(nsColor: .controlAccentColor))
                    : AnyShapeStyle(.ultraThinMaterial), style: FillStyle(eoFill: true))
                .overlay(slice.stroke(.primary.opacity(0.18), lineWidth: 0.5))

            VStack(spacing: 2) {
                if index < 9 {
                    Text("\(index + 1)")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .opacity(0.72)
                }
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(selected ? Color.white : Color.primary)
            .frame(width: 84)
            .position(
                x: MenuWheelGeometry.size / 2 + cos(mid) * labelRadius,
                y: MenuWheelGeometry.size / 2 + sin(mid) * labelRadius
            )
        }
        .frame(width: MenuWheelGeometry.size, height: MenuWheelGeometry.size)
    }
}

private struct MenuWheelSlice: Shape {
    let start: Double
    let end: Double
    let fullCircle: Bool

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        if fullCircle {
            path.addEllipse(in: CGRect(
                x: center.x - MenuWheelGeometry.outerRadius,
                y: center.y - MenuWheelGeometry.outerRadius,
                width: MenuWheelGeometry.outerRadius * 2,
                height: MenuWheelGeometry.outerRadius * 2
            ))
            path.addEllipse(in: CGRect(
                x: center.x - MenuWheelGeometry.innerRadius,
                y: center.y - MenuWheelGeometry.innerRadius,
                width: MenuWheelGeometry.innerRadius * 2,
                height: MenuWheelGeometry.innerRadius * 2
            ))
            return path
        }
        path.addArc(
            center: center,
            radius: MenuWheelGeometry.outerRadius,
            startAngle: .degrees(start),
            endAngle: .degrees(end),
            clockwise: false
        )
        path.addArc(
            center: center,
            radius: MenuWheelGeometry.innerRadius,
            startAngle: .degrees(end),
            endAngle: .degrees(start),
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    let model = MenuModel()

    ContentView(model: model)
        .onAppear {
            model.state = .normal
        }
}
