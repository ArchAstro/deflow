import AppKit
import SwiftUI

/// The Deflow mark: a loop (flow) broken open by a single dot (the interruption).
struct BrandMark: View {
    var ring: Color = .white
    var dot: Color = Color(red: 1.0, green: 0.70, blue: 0.34)

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let stroke = side * 0.17
            let radius = (side - stroke) / 2
            let angle = Angle.degrees(-45).radians
            ZStack {
                Circle()
                    .trim(from: 0.11, to: 0.89)
                    .stroke(ring, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                    .rotationEffect(.degrees(-45))
                    .padding(stroke / 2)
                Circle()
                    .fill(dot)
                    .frame(width: stroke * 1.12, height: stroke * 1.12)
                    .offset(x: radius * cos(angle), y: radius * sin(angle))
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// 1024pt macOS app icon: ember mesh squircle on the standard 824pt grid.
struct AppIconView: View {
    var body: some View {
        let ink = Color(red: 0.05, green: 0.03, blue: 0.08)
        let plum = Color(red: 0.20, green: 0.05, blue: 0.24)
        let magenta = Color(red: 0.74, green: 0.10, blue: 0.36)
        let ember = Color(red: 1.0, green: 0.42, blue: 0.12)
        let shape = RoundedRectangle(cornerRadius: 186, style: .continuous)
        return ZStack {
            MeshGradient(width: 3, height: 3, points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.55], [0.6, 0.5], [1, 0.45],
                [0, 1], [0.45, 1], [1, 1],
            ], colors: [
                ink, plum, magenta,
                ink, plum, ember,
                plum, magenta, Color(red: 1.0, green: 0.62, blue: 0.24),
            ])
            LinearGradient(colors: [.white.opacity(0.14), .clear], startPoint: .top, endPoint: .center)
            BrandMark()
                .padding(196)
                .shadow(color: .black.opacity(0.35), radius: 26, y: 14)
        }
        .frame(width: 824, height: 824)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(0.12), lineWidth: 3))
        .shadow(color: .black.opacity(0.3), radius: 18, y: 10)
        .frame(width: 1024, height: 1024)
    }
}

/// 660×420 disk-image window art. Finder places the app at (170, 205) and Applications at (490, 205);
/// a bundle of flow lines streams from one to the other.
struct DMGBackgroundView: View {
    private let from = CGPoint(x: 170, y: 205)
    private let to = CGPoint(x: 490, y: 205)

    var body: some View {
        let ink = Color(red: 0.04, green: 0.025, blue: 0.065)
        let plum = Color(red: 0.15, green: 0.04, blue: 0.19)
        let magenta = Color(red: 0.62, green: 0.09, blue: 0.33)
        let ember = Color(red: 1.0, green: 0.44, blue: 0.12)
        let amber = Color(red: 1.0, green: 0.70, blue: 0.34)
        return ZStack {
            MeshGradient(width: 3, height: 3, points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.62, 0.52], [1, 0.42],
                [0, 1], [0.42, 1], [1, 1],
            ], colors: [
                ink, ink, plum,
                ink, plum, magenta,
                plum, magenta, ember,
            ])

            // Oversized brand ring bleeding off the corner.
            BrandMark(ring: .white.opacity(0.07), dot: amber.opacity(0.5))
                .frame(width: 520, height: 520)
                .position(x: 610, y: 400)

            // Flow lines: a lens-shaped bundle from the app to Applications.
            ForEach(-5..<6, id: \.self) { i in
                let bulge = CGFloat(i) * 17
                Path { p in
                    p.move(to: CGPoint(x: -20, y: from.y + bulge * 2.2))
                    p.addCurve(to: from,
                               control1: CGPoint(x: 50, y: from.y + bulge * 2.2),
                               control2: CGPoint(x: 110, y: from.y))
                    p.addCurve(to: to,
                               control1: CGPoint(x: from.x + 100, y: from.y + bulge),
                               control2: CGPoint(x: to.x - 100, y: to.y + bulge))
                    p.addCurve(to: CGPoint(x: 680, y: to.y - bulge * 2.2),
                               control1: CGPoint(x: 550, y: to.y),
                               control2: CGPoint(x: 610, y: to.y - bulge * 2.2))
                }
                .stroke(
                    LinearGradient(colors: [.white.opacity(0.05), amber.opacity(i == 0 ? 0.9 : 0.42), .white.opacity(0.08)],
                                   startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: i == 0 ? 2 : 1.1, lineCap: .round)
                )
            }

            // Direction chevrons riding the centre line.
            HStack(spacing: 7) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: "chevron.right")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white.opacity(0.35 + Double(i) * 0.25))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(ink.opacity(0.85), in: Capsule())
            .position(x: 330, y: 205)

            // Pools of light where the two icons land.
            ForEach([from, to], id: \.x) { spot in
                Circle()
                    .fill(RadialGradient(colors: [.white.opacity(0.20), .white.opacity(0.05), .clear],
                                         center: .center, startRadius: 0, endRadius: 92))
                    .frame(width: 184, height: 184)
                    .position(spot)
            }

            // Finder draws icon labels in black over picture backgrounds, so give them light plates.
            ForEach([(from.x, 78.0), (to.x, 112.0)], id: \.0) { x, width in
                Capsule()
                    .fill(.white.opacity(0.9))
                    .frame(width: width, height: 22)
                    .position(x: x, y: 279)
            }

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    BrandMark().frame(width: 24, height: 24)
                    Text("Deflow").font(.system(size: 27, weight: .semibold, design: .serif))
                }
                .padding(.top, 30)
                Spacer()
                Text("Drag it in. Never miss the meeting.")
                    .font(.system(size: 19, weight: .regular, design: .serif)).italic()
                    .foregroundStyle(.white.opacity(0.82))
                Text("DEFLOW LIVES IN YOUR MENU BAR")
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .tracking(2.4)
                    .foregroundStyle(.white.opacity(0.42))
                    .padding(.top, 8)
                    .padding(.bottom, 30)
            }
        }
        .foregroundStyle(.white)
        .frame(width: 660, height: 420)
        .clipped()
    }
}

/// 1280×640 card for link previews (GitHub social preview): wordmark left, live takeover right.
struct SocialCardView: View {
    @MainActor static func make() -> SocialCardView {
        let model = TakeoverModel(event: .demo(startingIn: 41.9))
        model.animatesIn = false
        model.fixedNow = Date()
        return SocialCardView(model: model)
    }

    let model: TakeoverModel

    var body: some View {
        let screen = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return ZStack {
            AuroraBackground(late: false, time: 40, heat: 0.35)
            LinearGradient(colors: [.black.opacity(0.72), .black.opacity(0.2)], startPoint: .leading, endPoint: .trailing)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 18) {
                        BrandMark().frame(width: 62, height: 62)
                        Text("Deflow").font(.system(size: 76, weight: .semibold, design: .serif))
                    }
                    Text("Never miss\nthe meeting.")
                        .font(.system(size: 58, weight: .medium, design: .serif))
                        .lineSpacing(-4)
                        .padding(.top, 44)
                    Text("FULL-SCREEN MEETING TAKEOVERS\nFOR GOOGLE CALENDAR ON macOS")
                        .font(.system(size: 17, weight: .semibold, design: .monospaced))
                        .tracking(2.6)
                        .lineSpacing(7)
                        .foregroundStyle(Color(red: 1.0, green: 0.74, blue: 0.42))
                        .padding(.top, 34)
                }
                .padding(.leading, 76)
                Spacer(minLength: 0)
            }

            TakeoverView(model: model)
                .frame(width: 1512, height: 982)
                .scaleEffect(0.5)
                .frame(width: 756, height: 491)
                .clipShape(screen)
                .overlay(screen.strokeBorder(.white.opacity(0.22), lineWidth: 2))
                .shadow(color: .black.opacity(0.55), radius: 40, y: 24)
                .rotationEffect(.degrees(-3))
                .offset(x: 400, y: 30)
        }
        .foregroundStyle(.white)
        .frame(width: 1280, height: 640)
        .clipped()
    }
}

enum Brand {
    /// Template glyph for the menu bar, drawn from the same geometry as the mark.
    static let menuGlyph: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius: CGFloat = 6.3
            let ring = NSBezierPath()
            ring.appendArc(withCenter: center, radius: radius, startAngle: 85, endAngle: 365)
            ring.lineWidth = 2.3
            ring.lineCapStyle = .round
            NSColor.black.setStroke()
            ring.stroke()
            let a = CGFloat.pi / 4
            let dot = NSPoint(x: center.x + radius * cos(a), y: center.y + radius * sin(a))
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: dot.x - 1.5, y: dot.y - 1.5, width: 3, height: 3)).fill()
            return true
        }
        image.isTemplate = true
        return image
    }()
}
