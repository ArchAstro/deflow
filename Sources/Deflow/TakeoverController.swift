import AppKit
import DeflowCore
import SwiftUI

extension MeetingLink {
    /// Opens the desktop client when one handles the deep link, otherwise the browser.
    @MainActor func open() {
        if let native = nativeURL, NSWorkspace.shared.urlForApplication(toOpen: native) != nil {
            NSWorkspace.shared.open(native)
        } else {
            NSWorkspace.shared.open(url)
        }
    }
}

enum TakeoverResult { case joined, snoozed, dismissed, expired }

@MainActor
final class TakeoverModel: ObservableObject {
    let event: MeetingEvent
    @Published var holding = false
    /// Off for static renders (snapshots), where onAppear animations never run.
    var animatesIn = true
    var fixedNow: Date?
    var fixedHeat: Double?

    var onPrimary: () -> Void = {}
    var onSnooze: () -> Void = {}
    var onHoldBegin: () -> Void = {}
    var onHoldEnd: () -> Void = {}

    init(event: MeetingEvent) { self.event = event }
}

private final class TakeoverWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Covers every display with the takeover and owns its keyboard, sound and lifetime.
@MainActor
final class TakeoverController {
    static let holdDuration: TimeInterval = 1.2

    private(set) var isPresenting = false
    private var windows: [NSWindow] = []
    private var model: TakeoverModel?
    private var completion: ((TakeoverResult) -> Void)?
    private var keyMonitor: Any?
    private var holdWork: DispatchWorkItem?
    private var chimeTimer: Timer?
    private var expiryTimer: Timer?
    private var savedOptions: NSApplication.PresentationOptions = []

    func present(_ event: MeetingEvent, completion: @escaping (TakeoverResult) -> Void) {
        guard !isPresenting else { return }
        isPresenting = true
        self.completion = completion

        let model = TakeoverModel(event: event)
        model.onPrimary = { [weak self] in self?.primary() }
        model.onSnooze = { [weak self] in self?.finish(.snoozed) }
        model.onHoldBegin = { [weak self] in self?.beginHold() }
        model.onHoldEnd = { [weak self] in self?.endHold() }
        self.model = model

        for screen in NSScreen.screens {
            let w = TakeoverWindow(contentRect: screen.frame, styleMask: .borderless,
                                   backing: .buffered, defer: false)
            w.isReleasedWhenClosed = false
            w.level = .screenSaver
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            w.isOpaque = true
            w.backgroundColor = .black
            w.hasShadow = false
            w.contentView = NSHostingView(rootView: TakeoverView(model: model))
            w.setFrame(screen.frame, display: true)
            w.alphaValue = 0
            w.orderFrontRegardless()
            windows.append(w)
        }

        savedOptions = NSApp.presentationOptions
        NSApp.presentationOptions = [.hideDock, .hideMenuBar, .disableProcessSwitching]
        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            windows.forEach { $0.animator().alphaValue = 1 }
        }

        installKeyMonitor()
        startChime()

        // Safety valve: never outlive the meeting itself.
        let life = max(event.end.timeIntervalSinceNow, 15 * 60)
        expiryTimer = Timer.scheduledTimer(withTimeInterval: life, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.finish(.expired) }
        }
    }

    // MARK: - Actions

    private func primary() {
        guard let link = model?.event.link else { return finish(.dismissed) }
        link.open()
        finish(.joined)
    }

    private func beginHold() {
        guard holdWork == nil else { return }
        model?.holding = true
        let work = DispatchWorkItem { [weak self] in self?.finish(.dismissed) }
        holdWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.holdDuration, execute: work)
    }

    private func endHold() {
        holdWork?.cancel()
        holdWork = nil
        model?.holding = false
    }

    private func finish(_ result: TakeoverResult) {
        guard isPresenting else { return }
        holdWork?.cancel(); holdWork = nil
        chimeTimer?.invalidate(); chimeTimer = nil
        expiryTimer?.invalidate(); expiryTimer = nil
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        NSApp.presentationOptions = savedOptions

        let closing = windows
        windows = []
        model = nil
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            closing.forEach { $0.animator().alphaValue = 0 }
        }, completionHandler: {
            closing.forEach { $0.orderOut(nil) }
        })

        isPresenting = false
        let done = completion
        completion = nil
        done?(result)
    }

    // MARK: - Input & sound

    /// Swallows the whole keyboard while up: only ↩ (join), S (snooze) and held esc (dismiss) do anything.
    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] e in
            guard let self else { return e }
            switch (e.type, e.keyCode) {
            case (.keyDown, 36), (.keyDown, 76): if !e.isARepeat { self.primary() }
            case (.keyDown, 1): if !e.isARepeat { self.finish(.snoozed) }
            case (.keyDown, 53): if !e.isARepeat { self.beginHold() }
            case (.keyUp, 53): self.endHold()
            default: break
            }
            return nil
        }
    }

    private func startChime() {
        guard UserDefaults.standard.bool(forKey: Prefs.sound) else { return }
        NSSound(named: "Hero")?.play()
        chimeTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { _ in
            NSSound(named: "Glass")?.play()
        }
    }
}
