import DeflowCore
import SwiftUI

private enum Ink {
    static let amber = Color(red: 1.0, green: 0.74, blue: 0.42)
    static let coral = Color(red: 1.0, green: 0.50, blue: 0.40)
    static let dim = Color.white.opacity(0.62)
    static let faint = Color.white.opacity(0.38)
}

struct TakeoverView: View {
    @ObservedObject var model: TakeoverModel
    @State private var appeared = false

    private var event: MeetingEvent { model.event }
    private var shown: Bool { appeared || !model.animatesIn }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let now = model.fixedNow ?? ctx.date
            let late = now >= event.start
            GeometryReader { geo in
                let s = max(0.6, min(geo.size.width / 1512, 1.7))
                ZStack {
                    AuroraBackground(late: late)
                    LinearGradient(colors: [.black.opacity(0.62), .black.opacity(0.15), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                    VStack(alignment: .leading, spacing: 0) {
                        topBar(now: now, s: s)
                        Spacer(minLength: 0)
                        hero(now: now, late: late, s: s)
                        Spacer(minLength: 0)
                        actions(s: s)
                    }
                    .padding(.horizontal, 104 * s)
                    .padding(.vertical, 68 * s)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .opacity(shown ? 1 : 0)
                    .offset(y: shown ? 0 : 28)
                }
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .onAppear { withAnimation(.spring(duration: 0.9, bounce: 0.12).delay(0.1)) { appeared = true } }
    }

    // MARK: - Sections

    private func topBar(now: Date, s: CGFloat) -> some View {
        HStack {
            HStack(spacing: 10 * s) {
                Circle().fill(Ink.amber).frame(width: 8 * s, height: 8 * s)
                Text("DEFLOW").tracking(4 * s)
            }
            Spacer()
            Text(now.formatted(date: .omitted, time: .shortened))
        }
        .font(.system(size: 14 * s, weight: .semibold, design: .monospaced))
        .foregroundStyle(Ink.dim)
    }

    private func hero(now: Date, late: Bool, s: CGFloat) -> some View {
        let accent = late ? Ink.coral : Ink.amber
        return VStack(alignment: .leading, spacing: 0) {
            Text(late ? "STARTED" : "STARTS IN")
                .font(.system(size: 17 * s, weight: .semibold, design: .monospaced))
                .tracking(5 * s)
                .foregroundStyle(accent)

            HStack(alignment: .firstTextBaseline, spacing: 18 * s) {
                Text(Countdown.clock(event.start.timeIntervalSince(now)))
                    .font(.system(size: 232 * s, weight: .medium, design: .serif))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: !late))
                    .animation(.snappy(duration: 0.3), value: Int(now.timeIntervalSince1970))
                if late {
                    Text("ago")
                        .font(.system(size: 56 * s, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(Ink.dim)
                }
            }
            .foregroundStyle(.white)
            .padding(.top, -6 * s)
            .padding(.bottom, 4 * s)

            Text(event.title)
                .font(.system(size: 62 * s, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: 1100 * s, alignment: .leading)

            VStack(alignment: .leading, spacing: 12 * s) {
                metaRow("clock", timeRange, s: s)
                if let who = event.attendeeSummary { metaRow("person.2", "with \(who)", s: s) }
                if let where_ = event.location { metaRow("mappin.and.ellipse", where_, s: s) }
            }
            .padding(.top, 30 * s)

            if let link = event.link {
                linkChip(link, accent: accent, s: s).padding(.top, 30 * s)
            }
        }
    }

    private var timeRange: String {
        let t = Date.FormatStyle(date: .omitted, time: .shortened)
        let range = "\(event.start.formatted(t)) – \(event.end.formatted(t))"
        return event.calendarName.isEmpty ? range : "\(range)  ·  \(event.calendarName)"
    }

    private func metaRow(_ symbol: String, _ text: String, s: CGFloat) -> some View {
        HStack(spacing: 14 * s) {
            Image(systemName: symbol)
                .font(.system(size: 19 * s, weight: .medium))
                .frame(width: 28 * s)
                .foregroundStyle(Ink.faint)
            Text(text)
                .font(.system(size: 24 * s, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.86))
                .lineLimit(1)
        }
    }

    private func linkChip(_ link: MeetingLink, accent: Color, s: CGFloat) -> some View {
        HStack(spacing: 18 * s) {
            Image(systemName: "video.fill").foregroundStyle(accent)
            Text(link.provider.rawValue).fontWeight(.semibold)
            if let id = link.meetingID {
                chipDivider(s)
                Text("ID ").foregroundStyle(Ink.faint) + Text(id)
            }
            if let code = link.passcode {
                chipDivider(s)
                Text("PASSCODE ").foregroundStyle(Ink.faint) + Text(code)
            }
        }
        .font(.system(size: 17 * s, weight: .medium, design: .monospaced))
        .foregroundStyle(.white)
        .padding(.horizontal, 22 * s)
        .padding(.vertical, 14 * s)
        .background(.white.opacity(0.08), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 1))
        .textSelection(.enabled)
    }

    private func chipDivider(_ s: CGFloat) -> some View {
        Rectangle().fill(.white.opacity(0.2)).frame(width: 1, height: 18 * s)
    }

    private func actions(s: CGFloat) -> some View {
        HStack(spacing: 18 * s) {
            Button(action: model.onPrimary) {
                HStack(spacing: 14 * s) {
                    Text(event.link.map { "Join \($0.provider.rawValue)" } ?? "I'm on my way")
                    Keycap("↩", s: s, onLight: true)
                }
                .font(.system(size: 23 * s, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.leading, 34 * s).padding(.trailing, 22 * s)
                .frame(height: 68 * s)
                .background(.white, in: Capsule())
                .shadow(color: .white.opacity(0.35), radius: 30 * s)
            }

            Button(action: model.onSnooze) {
                HStack(spacing: 12 * s) {
                    Text("Snooze 1 min")
                    Keycap("S", s: s)
                }
                .font(.system(size: 20 * s, weight: .medium))
                .foregroundStyle(.white)
                .padding(.leading, 28 * s).padding(.trailing, 20 * s)
                .frame(height: 68 * s)
                .background(.white.opacity(0.1), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1))
            }

            Spacer()

            HStack(spacing: 12 * s) {
                ZStack {
                    Circle().stroke(.white.opacity(0.2), lineWidth: 3 * s)
                    Circle().trim(from: 0, to: model.holding ? 1 : 0)
                        .stroke(.white, style: StrokeStyle(lineWidth: 3 * s, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(model.holding
                                   ? .linear(duration: TakeoverController.holdDuration)
                                   : .easeOut(duration: 0.2), value: model.holding)
                }
                .frame(width: 26 * s, height: 26 * s)
                Text("Hold")
                Keycap("esc", s: s)
                Text("to dismiss")
            }
            .font(.system(size: 18 * s, weight: .medium))
            .foregroundStyle(model.holding ? .white : Ink.dim)
            .padding(.horizontal, 20 * s)
            .frame(height: 68 * s)
            .contentShape(Rectangle())
            // Long minimum so the gesture never completes before the controller's own hold timer.
            .onLongPressGesture(minimumDuration: 10, perform: {}, onPressingChanged: { pressing in
                pressing ? model.onHoldBegin() : model.onHoldEnd()
            })
        }
        .buttonStyle(PressScale())
    }
}

private struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

private struct Keycap: View {
    let label: String
    let s: CGFloat
    var onLight = false

    init(_ label: String, s: CGFloat, onLight: Bool = false) {
        self.label = label
        self.s = s
        self.onLight = onLight
    }

    var body: some View {
        Text(label)
            .font(.system(size: 14 * s, weight: .semibold, design: .monospaced))
            .foregroundStyle(onLight ? Color.black.opacity(0.7) : Color.white.opacity(0.8))
            .padding(.horizontal, 9 * s)
            .frame(minWidth: 30 * s, minHeight: 28 * s)
            .background((onLight ? Color.black : Color.white).opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 7 * s, style: .continuous))
    }
}

/// Slow-drifting ember mesh: dark where the text sits, heat pooling on the right. Runs hotter once late.
struct AuroraBackground: View {
    var late: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
            let t = Float(ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600))
            MeshGradient(width: 3, height: 3, points: [
                [0, 0], [0.5 + 0.10 * sin(t * 0.31), 0], [1, 0],
                [0, 0.5 + 0.08 * cos(t * 0.23)],
                [0.58 + 0.16 * sin(t * 0.41), 0.5 + 0.14 * cos(t * 0.33)],
                [1, 0.5 + 0.12 * sin(t * 0.19)],
                [0, 1], [0.5 + 0.12 * cos(t * 0.27), 1], [1, 1],
            ], colors: palette)
        }
        .animation(.easeInOut(duration: 2.5), value: late)
        .overlay(RadialGradient(colors: [.clear, .black.opacity(0.45)],
                                center: .center, startRadius: 200, endRadius: 1400))
        .background(.black)
    }

    private var palette: [Color] {
        let ink = Color(red: 0.03, green: 0.02, blue: 0.05)
        let plum = Color(red: 0.13, green: 0.04, blue: 0.16)
        let violet = Color(red: 0.24, green: 0.06, blue: 0.36)
        let magenta = late ? Color(red: 0.82, green: 0.08, blue: 0.22) : Color(red: 0.70, green: 0.10, blue: 0.38)
        let ember = late ? Color(red: 1.0, green: 0.24, blue: 0.10) : Color(red: 1.0, green: 0.45, blue: 0.12)
        let glow = late ? Color(red: 1.0, green: 0.48, blue: 0.20) : Color(red: 1.0, green: 0.68, blue: 0.28)
        return [
            ink, plum, violet,
            ink, plum, ember,
            ink, magenta, glow,
        ]
    }
}
