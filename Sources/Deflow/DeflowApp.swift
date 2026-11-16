import AppKit
import DeflowCore
import SwiftUI

@MainActor
final class AppState {
    static let shared = AppState()
    let monitor = CalendarMonitor()
    let takeover = TakeoverController()

    func start() {
        monitor.canPresent = { [unowned self] in !takeover.isPresenting }
        monitor.onTrigger = { [unowned self] event in
            takeover.present(event) { [unowned self] result in
                if result == .snoozed { monitor.snooze(event) }
            }
        }
        monitor.start()
    }

    func presentDemo(late: Bool = false) {
        takeover.present(.demo(startingIn: late ? -134 : 42)) { [unowned self] result in
            if result == .snoozed {
                DispatchQueue.main.asyncAfter(deadline: .now() + 60) { self.presentDemo(late: true) }
            }
        }
    }
}

extension MeetingEvent {
    static func demo(startingIn seconds: TimeInterval) -> MeetingEvent {
        let start = Date().addingTimeInterval(seconds)
        return MeetingEvent(
            id: "demo-\(UUID().uuidString)",
            title: "Acme Robotics — pilot kickoff",
            start: start,
            end: start.addingTimeInterval(30 * 60),
            calendarName: "Work",
            attendees: ["Dana Whitfield", "Luis Ortega", "Priya Nair", "Sam Cho", "Jo Lind"],
            link: MeetingLink.find(in: ["https://acme.zoom.us/j/84512345678?pwd=demo", "Passcode: 481516"])
        )
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Prefs.register()
        let args = CommandLine.arguments
        let late = args.contains("--late")

        // `--snapshot out.png [--late]` renders the takeover to a PNG and exits (design review, no takeover).
        if let i = args.firstIndex(of: "--snapshot"), args.indices.contains(i + 1) {
            Self.snapshot(to: args[i + 1], late: late)
        }
        // Brand assets for the build scripts: `--render-icon out.png`, `--render-dmg-bg out.png [--2x]`.
        if let i = args.firstIndex(of: "--render-icon"), args.indices.contains(i + 1) {
            Self.write(AppIconView(), to: args[i + 1], scale: 1)
        }
        if let i = args.firstIndex(of: "--render-dmg-bg"), args.indices.contains(i + 1) {
            Self.write(DMGBackgroundView(), to: args[i + 1], scale: args.contains("--2x") ? 2 : 1)
        }
        // `--snapshot-menu out.png` renders the menu panel with sample data and exits.
        if let i = args.firstIndex(of: "--snapshot-menu"), args.indices.contains(i + 1) {
            let monitor = CalendarMonitor()
            monitor.loadDemo()
            Self.write(MenuPanel(monitor: monitor), to: args[i + 1])
        }
        AppState.shared.start()
        if args.contains("--demo") { AppState.shared.presentDemo(late: late) }
    }

    @MainActor
    private static func snapshot(to path: String, late: Bool) -> Never {
        let model = TakeoverModel(event: .demo(startingIn: late ? -134 : 42))
        model.animatesIn = false
        model.fixedNow = Date()
        write(TakeoverView(model: model).frame(width: 1512, height: 982), to: path)
    }

    @MainActor
    private static func write(_ view: some View, to path: String, scale: CGFloat = 2) -> Never {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let tiff = renderer.nsImage?.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]),
              (try? png.write(to: URL(fileURLWithPath: path))) != nil
        else { exit(1) }
        exit(0)
    }
}

@main
struct DeflowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @ObservedObject private var monitor = AppState.shared.monitor

    var body: some Scene {
        MenuBarExtra {
            MenuPanel(monitor: monitor)
        } label: {
            MenuLabel(monitor: monitor)
        }
        .menuBarExtraStyle(.window)
    }
}
