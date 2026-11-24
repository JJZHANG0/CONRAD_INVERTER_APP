import SwiftUI

extension Color {
    static let ink = Color(UIColor.label)
    static let muted = Color(UIColor.secondaryLabel)
    static let paper = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.035, alpha: 1) : .white })
    static let hero = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.13, alpha: 1) : UIColor(white: 0.025, alpha: 1) })
    static let surface = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.095, alpha: 1) : UIColor(white: 0.965, alpha: 1) })
    static let inverse = Color(UIColor { $0.userInterfaceStyle == .dark ? .black : .white })
    static let crystal = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.82, alpha: 1) : UIColor(white: 0.24, alpha: 1) })
    static let line = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.22, alpha: 1) : UIColor(white: 0.88, alpha: 1) })
    static let sage = crystal
}

extension Emotion {
    var color: Color {
        switch self {
        case .calm: .crystal
        case .happy: .ink
        case .hopeful: .crystal
        case .tired: .muted
        case .anxious: .ink
        case .sad: .muted
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var light = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 15, weight: .semibold))
            .frame(maxWidth: .infinity).padding(.vertical, 17)
            .foregroundStyle(light ? Color.ink : .inverse)
            .background(light ? Color.surface : Color.ink, in: RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View { Text(text).font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(2).foregroundStyle(Color.muted) }
}
struct SectionHeading: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 21, weight: .semibold))
            Spacer()
            if let subtitle { Text(subtitle).font(.system(size: 11, design: .monospaced)).foregroundStyle(Color.muted) }
        }
    }
}
struct PageHeading: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: eyebrow)
            Text(title).font(.system(size: 33, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
            Text(subtitle).font(.system(size: 14)).foregroundStyle(Color.muted).lineSpacing(5)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct EmptySpace: View {
    let icon: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 30, weight: .ultraLight)).foregroundStyle(Color.crystal)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(Color.muted).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 35).padding(.horizontal, 20)
    }
}
struct Tag: View {
    let text: String
    var color: Color = .crystal
    var body: some View { Text(text).font(.system(size: 11, weight: .medium)).padding(.horizontal, 10).padding(.vertical, 6).background(color.opacity(0.08), in: Capsule()).foregroundStyle(color) }
}
struct RowLink: View {
    let icon: String
    let title: String
    var detail: String = ""
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 19, weight: .light)).frame(width: 27).foregroundStyle(Color.crystal)
            Text(title).font(.system(size: 15))
            Spacer()
            Text(detail).font(.system(size: 12)).foregroundStyle(Color.muted)
            Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.muted)
        }.padding(.vertical, 18).contentShape(Rectangle()).foregroundStyle(Color.ink)
    }
}
struct EventRow: View {
    let event: LifeEvent
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: event.feeling.symbol).font(.system(size: 19, weight: .light)).foregroundStyle(event.feeling.color)
                .frame(width: 40, height: 40).background(event.feeling.color.opacity(0.08), in: Circle())
            VStack(alignment: .leading, spacing: 7) {
                Text(event.title).font(.system(size: 15, weight: .medium)).foregroundStyle(Color.ink)
                Text(event.facts).font(.system(size: 12)).foregroundStyle(Color.muted).lineLimit(2).lineSpacing(3)
                HStack(spacing: 8) {
                    Text(event.date.formatted(.dateTime.locale(AppPreferences.shared.locale).month().day()))
                    Text("·  \(event.feeling.label)")
                    if event.isDemo { Text(L("·  示例")) }
                }.font(.system(size: 10)).foregroundStyle(Color.muted)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(Color.muted).padding(.top, 14)
        }.padding(.vertical, 12).contentShape(Rectangle())
    }
}
struct Notice: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "info.circle").padding(.top, 1)
            Text(text).lineSpacing(4)
        }.font(.system(size: 12)).foregroundStyle(Color.muted).frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Procedural wire sculpture: native vector drawing, no downloaded artwork.
struct OrbitArtwork: View {
    var dark = false
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.40
            let color = dark ? Color.white : Color.crystal
            for index in 0..<13 {
                let angle = Double(index) / 13 * .pi
                var path = Path()
                for step in 0...160 {
                    let t = Double(step) / 160 * .pi * 2
                    let x = radius * cos(t)
                    let y = radius * sin(t) * cos(angle)
                    let p = CGPoint(x: center.x + x * 0.91 - y * 0.41, y: center.y + x * 0.41 + y * 0.91)
                    if step == 0 { path.move(to: p) } else { path.addLine(to: p) }
                }
                context.stroke(path, with: .color(color.opacity(0.12 + Double(index % 3) * 0.07)), lineWidth: 0.65)
            }
            for index in 0..<6 {
                let y = radius * (Double(index) / 5 * 1.6 - 0.8)
                let width = sqrt(radius * radius - y * y)
                let rect = CGRect(x: center.x - width, y: center.y + y - width * 0.14, width: width * 2, height: width * 0.28)
                context.stroke(Path(ellipseIn: rect), with: .color(color.opacity(0.16)), lineWidth: 0.55)
            }
            let points: [(Double, Double)] = [(-0.66, -0.57), (0.85, 0.32), (-0.23, 0.83), (0.39, -0.85)]
            for (x, y) in points {
                let point = CGPoint(x: center.x + radius * x, y: center.y + radius * y)
                context.fill(Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)), with: .color(color.opacity(0.8)))
                context.fill(Path(ellipseIn: CGRect(x: point.x - 7, y: point.y - 7, width: 14, height: 14)), with: .color(color.opacity(0.08)))
            }
        }.accessibilityHidden(true)
    }
}

extension View {
    func pageStyle() -> some View { self.background(Color.paper).foregroundStyle(Color.ink) }
    func surface() -> some View { self.padding(20).background(Color.surface, in: RoundedRectangle(cornerRadius: 20)) }
}
