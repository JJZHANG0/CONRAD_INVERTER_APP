import SwiftUI

/// Native rendering of the MIT-licensed GrokBot geometry; no web view or network.
struct BotAvatar: View {
    var state = "idle"
    var tint: Color? = nil
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false
    @State private var started = Date()
    private static let shapes: [String: [Double]] = {
        guard let url = Bundle.main.url(forResource: "BotShapes", withExtension: "json"),
              let data = try? Data(contentsOf: url), let shapes = try? JSONDecoder().decode([String:[Double]].self, from: data) else { return [:] }
        return shapes
    }()
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || !visible || phase != .active)) { timeline in
            let t = reduceMotion ? 0 : max(0, timeline.date.timeIntervalSince(started))
            Canvas { context, size in
                let radius = min(size.width, size.height) * 0.37
                let thinking = state == "working"
                let speaking = state == "speaking"
                let listening = state == "listening"
                let happy = state == "done"
                let cycle = thinking ? ["circle", "cloud", "clover", "squircle", "flower"] : ["circle", "blob", "egg", "cloud", "circle"]
                let step = t / (thinking ? 2.6 : 5.0)
                let i = Int(step) % cycle.count
                let from = happy ? "heart" : listening || speaking ? "circle" : cycle[i]
                let to = happy ? "heart" : listening || speaking ? "blob" : cycle[(i + 1) % cycle.count]
                let f = listening || speaking ? (sin(t * 1.6) + 1) * 0.10 : min(1, (step - floor(step)) * 2)
                let blend = f * f * (3 - 2 * f)
                let a = Self.shapes[from] ?? [], b = Self.shapes[to] ?? a
                guard a.count == 144, b.count == a.count else { return }
                let bounce = reduceMotion ? 0 : sin(t * (speaking ? 7 : happy ? 3.4 : 1.8))
                let nod = listening && !reduceMotion ? pow(max(0, sin(t * 1.5)), 8) : 0
                let tilt = reduceMotion ? 0 : sin(t * (speaking ? 2.8 : 0.8)) * (listening ? 5 : 3)
                // Small satellites follow the selected mode while considering a reply.
                if thinking && !reduceMotion {
                    for n in 0..<3 {
                        let angle = t * 0.65 + Double(n) * 2.094
                        let dot = CGPoint(x: size.width / 2 + cos(angle) * radius * 1.2, y: size.height / 2 + sin(angle) * radius * 1.13)
                        context.fill(Path(ellipseIn: CGRect(x: dot.x - 2, y: dot.y - 2, width: 4, height: 4)), with: .color((tint ?? (scheme == .dark ? .white : .black)).opacity(0.4)))
                    }
                }
                context.translateBy(x: size.width / 2, y: size.height / 2 + (bounce * 0.035 + nod * 0.045) * radius)
                context.rotate(by: .degrees(tilt))
                context.scaleBy(x: radius * (1 + bounce * 0.012), y: radius * (1 - bounce * 0.014))
                var points: [CGPoint] = []
                for n in stride(from: 0, to: a.count, by: 2) {
                    points.append(CGPoint(x: a[n] + (b[n] - a[n]) * blend, y: a[n+1] + (b[n+1] - a[n+1]) * blend))
                }
                var body = Path(); body.move(to: points[0])
                for n in points.indices {
                    let p0 = points[(n + 71) % 72], p1 = points[n], p2 = points[(n+1) % 72], p3 = points[(n+2) % 72]
                    body.addCurve(to: p2, control1: CGPoint(x: p1.x + (p2.x-p0.x)/6, y: p1.y + (p2.y-p0.y)/6), control2: CGPoint(x: p2.x - (p3.x-p1.x)/6, y: p2.y - (p3.y-p1.y)/6))
                }
                body.closeSubpath()
                context.fill(body, with: .color(tint ?? (scheme == .dark ? .white : .black)))
                context.clip(to: body)
                let blinkPhase = t.truncatingRemainder(dividingBy: 6.9)
                let blinkA = max(0, 1 - abs(blinkPhase - 4.3) / 0.13)
                let blinkB = max(0, 1 - abs(blinkPhase - 4.65) / 0.1)
                let blink = reduceMotion ? 1 : 1 - 0.94 * max(blinkA, blinkB)
                let eyeHeight = (happy ? 0.18 : thinking ? 0.28 : listening ? 0.46 : 0.40) * blink
                let lookX = 0.20 + (reduceMotion ? 0 : sin(t * 0.63) * (listening ? 0.035 : 0.12))
                let lookY = -0.26 + (reduceMotion ? 0 : sin(t * 0.49) * 0.065 + nod * 0.07)
                for side in [-1.0, 1.0] {
                    var eyeContext = context
                    eyeContext.translateBy(x: lookX + side * 0.18, y: lookY)
                    eyeContext.rotate(by: .degrees(state == "sad" ? 18 : -20))
                    let wink = !reduceMotion && !thinking && !listening && !speaking && side > 0 && t.truncatingRemainder(dividingBy: 14) > 10.2 && t.truncatingRemainder(dividingBy: 14) < 10.5
                    let height = wink ? 0.06 : eyeHeight
                    let eye = Path(roundedRect: CGRect(x: -0.075, y: -height/2, width: 0.15, height: height), cornerRadius: 0.075)
                    eyeContext.fill(eye, with: .color(tint != nil || scheme == .dark ? .black : .white))
                }
                if speaking {
                    let openness = reduceMotion ? 0.06 : 0.055 + (sin(t * 12) + 1) * 0.045
                    let mouth = Path(roundedRect: CGRect(x: lookX - 0.10, y: lookY + 0.28, width: 0.20, height: openness), cornerRadius: 0.07)
                    context.fill(mouth, with: .color(tint != nil || scheme == .dark ? .black : .white))
                }
            }
        }.accessibilityHidden(true)
            .onAppear { visible = true; started = Date() }
            .onDisappear { visible = false }
    }
}
