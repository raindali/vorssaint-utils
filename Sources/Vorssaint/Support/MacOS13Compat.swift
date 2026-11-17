// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
//
// macOS 13 / Intel compatibility layer for the local port.
// Everything here is a no-op or a conservative fallback below macOS 14;
// on macOS 14+ the original API is used unchanged.

import AppKit
import CoreMedia
import CoreVideo
import EventKit
import Foundation
import QuartzCore
import ScreenCaptureKit
import SwiftUI
import VideoToolbox

// MARK: - Calendar

enum CalendarAccessCompat {
    static func isGranted(_ status: EKAuthorizationStatus) -> Bool {
        if #available(macOS 14.0, *) {
            return status == .fullAccess
        }
        return status == .authorized
    }

    static var currentIsGranted: Bool {
        isGranted(EKEventStore.authorizationStatus(for: .event))
    }

    static func needsRequest(_ status: EKAuthorizationStatus) -> Bool {
        if status == .notDetermined { return true }
        if #available(macOS 14.0, *) { return status == .writeOnly }
        return false
    }

    static func requestFullAccess(store: EKEventStore,
                                  completion: @escaping (Bool, Error?) -> Void) {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { granted, error in
                completion(granted, error)
            }
        } else {
            store.requestAccess(to: .event) { granted, error in
                completion(granted, error)
            }
        }
    }
}

// MARK: - App activation

enum AppActivationCompat {
    @discardableResult
    static func activate(_ app: NSRunningApplication,
                         from source: NSRunningApplication,
                         options: NSApplication.ActivationOptions = []) -> Bool {
        if #available(macOS 14.0, *) {
            return app.activate(from: source, options: options)
        }
        return app.activate(options: options)
    }
}

// MARK: - onChange

private struct OnChangeCompatModifier<V: Equatable>: ViewModifier {
    let value: V
    let initial: Bool
    let action: (V, V) -> Void
    @State private var previous: V

    init(value: V, initial: Bool, action: @escaping (V, V) -> Void) {
        self.value = value
        self.initial = initial
        self.action = action
        _previous = State(initialValue: value)
    }

    func body(content: Content) -> some View {
        content
            .onAppear {
                if initial { action(value, value) }
            }
            .onChange(of: value) { newValue in
                let oldValue = previous
                previous = newValue
                if oldValue != newValue {
                    action(oldValue, newValue)
                }
            }
    }
}

extension View {
    /// Two-parameter onChange. Uses the pre-14 API underneath on every OS so
    /// the same closure shape works on macOS 13.
    func onChangeCompat<V: Equatable>(of value: V, initial: Bool = false,
                                      _ action: @escaping (V, V) -> Void) -> some View {
        modifier(OnChangeCompatModifier(value: value, initial: initial, action: action))
    }

    func onChangeCompat<V: Equatable>(of value: V, initial: Bool = false,
                                      _ action: @escaping (V) -> Void) -> some View {
        modifier(OnChangeCompatModifier(value: value, initial: initial) { _, newValue in
            action(newValue)
        })
    }

    func onChangeCompat<V: Equatable>(of value: V, initial: Bool = false,
                                      _ action: @escaping () -> Void) -> some View {
        modifier(OnChangeCompatModifier(value: value, initial: initial) { _, _ in
            action()
        })
    }
}

// MARK: - SwiftUI effects

extension View {
    @ViewBuilder
    func buttonBorderShapeCapsuleCompat() -> some View {
        if #available(macOS 14.0, *) {
            self.buttonBorderShape(.capsule)
        } else {
            self
        }
    }

    @ViewBuilder
    func blurReplaceTransitionCompat() -> some View {
        if #available(macOS 14.0, *) {
            self.transition(.blurReplace)
        } else {
            self.transition(.opacity)
        }
    }

    @ViewBuilder
    func toolbarRemovingSidebarToggleCompat() -> some View {
        if #available(macOS 14.0, *) {
            self.toolbar(removing: .sidebarToggle)
        } else {
            self
        }
    }

    @ViewBuilder
    func coordinateSpaceNamedCompat(_ name: String) -> some View {
        if #available(macOS 14.0, *) {
            self.coordinateSpaceNamedCompat(name)
        } else {
            self.coordinateSpace(name: name)
        }
    }

    func transactionValueCompat<V: Equatable>(value: V,
                                              _ action: @escaping (inout Transaction) -> Void) -> some View {
        modifier(TransactionValueCompatModifier(value: value, action: action))
    }
}

private struct TransactionValueCompatModifier<V: Equatable>: ViewModifier {
    let value: V
    let action: (inout Transaction) -> Void

    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.transaction(value: value, action)
        } else {
            content
        }
    }
}

struct CollapsibleSectionCompat<Content: View, Header: View>: View {
    @Binding var isExpanded: Bool
    @ViewBuilder var content: () -> Content
    @ViewBuilder var header: () -> Header

    var body: some View {
        if #available(macOS 14.0, *) {
            Section(isExpanded: $isExpanded) {
                content()
            } header: {
                header()
            }
        } else {
            Section {
                content()
            } header: {
                header()
            }
        }
    }
}

extension View {
    @ViewBuilder
    func contentTransitionSymbolReplaceCompat() -> some View {
        if #available(macOS 14.0, *) {
            self.contentTransition(.symbolEffect(.replace))
        } else {
            self
        }
    }

    @ViewBuilder
    func symbolBounceCompat(value: Bool) -> some View {
        if #available(macOS 14.0, *) {
            self.symbolEffect(.bounce, value: value)
        } else {
            self
        }
    }

    @ViewBuilder
    func symbolBounceSpeedCompat(value: Bool) -> some View {
        if #available(macOS 14.0, *) {
            self.symbolEffect(.bounce, options: .speed(1.4), value: value)
        } else {
            self
        }
    }

    @ViewBuilder
    func symbolVariableColorCompat(isActive: Bool) -> some View {
        if #available(macOS 14.0, *) {
            self.symbolEffect(.variableColor.iterative, options: .repeating,
                              isActive: isActive)
        } else {
            self
        }
    }

    @ViewBuilder
    func symbolVariableColorReversingCompat(isActive: Bool) -> some View {
        if #available(macOS 14.0, *) {
            self.symbolEffect(.variableColor.iterative.reversing, options: .repeating,
                              isActive: isActive)
        } else {
            self
        }
    }

    @ViewBuilder
    func focusableEditCompat() -> some View {
        if #available(macOS 14.0, *) {
            self.focusable(interactions: .edit)
        } else {
            self.focusable()
        }
    }

    @ViewBuilder
    func focusEffectDisabledCompat(_ disabled: Bool = true) -> some View {
        if #available(macOS 14.0, *) {
            self.focusEffectDisabled(disabled)
        } else {
            self
        }
    }
}

func withAnimationCompletionCompat(_ animation: Animation?,
                                   _ body: () -> Void,
                                   completion: @escaping () -> Void) {
    if #available(macOS 14.0, *) {
        withAnimation(animation, completionCriteria: .logicallyComplete, body, completion: completion)
    } else {
        withAnimation(animation, body)
        completion()
    }
}

extension GeometryProxy {
    func boundsCompat(of name: String) -> CGRect? {
        if #available(macOS 14.0, *) {
            return bounds(of: .named(name))
        }
        return frame(in: .named(name))
    }
}

struct EmptyStateCompat: View {
    let title: String
    let systemImage: String

    var body: some View {
        if #available(macOS 14.0, *) {
            ContentUnavailableView(title, systemImage: systemImage)
        } else {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(.secondary)
                Text(title)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Key handling (macOS 13 keeps the pointer/tap paths)

struct KeyPressUpDownModifier: ViewModifier {
    let up: () -> Void
    let down: () -> Void

    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content
                .onKeyPress(.upArrow) { up(); return .handled }
                .onKeyPress(.downArrow) { down(); return .handled }
        } else {
            content
        }
    }
}

struct KeyPressSpaceModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.onKeyPress(.space) { action(); return .handled }
        } else {
            content
        }
    }
}

// MARK: - Popover

enum PanelSurfaceCompat {
    static func setPopoverFullSizeContent(_ popover: NSPopover, _ enabled: Bool) {
        if #available(macOS 14.0, *) {
            popover.hasFullSizeContent = enabled
        }
    }
}

// MARK: - Display link

/// CADisplayLink is macOS 14+. On 13 a main-run-loop Timer at the requested
/// rate stands in; the call sites only need timestamp / targetTimestamp /
/// duration, which the timer synthesizes.
final class CompatDisplayLink: NSObject {
    private var displayLink: AnyObject?
    private var timer: Timer?
    private var target: AnyObject?
    private let selector: Selector
    private var interval: TimeInterval = 1.0 / 60.0
    private(set) var timestamp: CFTimeInterval = 0
    private(set) var targetTimestamp: CFTimeInterval = 0
    private(set) var duration: CFTimeInterval = 0

    var preferredFrameRateRange: CAFrameRateRange = CAFrameRateRange() {
        didSet {
            if #available(macOS 14.0, *), let link = displayLink as? CADisplayLink {
                link.preferredFrameRateRange = preferredFrameRateRange
            } else if let preferred = preferredFrameRateRange.preferred, preferred > 0 {
                interval = 1.0 / Double(preferred)
            }
        }
    }

    init(view: NSView, target: AnyObject, selector: Selector) {
        self.target = target
        self.selector = selector
        super.init()
        if #available(macOS 14.0, *) {
            displayLink = view.displayLink(target: self, selector: #selector(tick(_:)))
        } else {
            installTimer()
        }
    }

    init(screen: NSScreen, target: AnyObject, selector: Selector) {
        self.target = target
        self.selector = selector
        super.init()
        if #available(macOS 14.0, *) {
            displayLink = screen.displayLink(target: self, selector: #selector(tick(_:)))
        } else {
            installTimer()
        }
    }

    private func installTimer() {
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.timerFired()
        }
        self.timer = timer
    }

    func add(to runLoop: RunLoop, forMode mode: RunLoop.Mode) {
        if #available(macOS 14.0, *), let link = displayLink as? CADisplayLink {
            link.add(to: runLoop, forMode: mode)
            return
        }
        if let timer, timer.timeInterval != interval {
            timer.invalidate()
            installTimer()
        }
        guard let timer else { return }
        runLoop.add(timer, forMode: mode)
    }

    func invalidate() {
        if #available(macOS 14.0, *), let link = displayLink as? CADisplayLink {
            link.invalidate()
        }
        displayLink = nil
        timer?.invalidate()
        timer = nil
        target = nil
    }

    @available(macOS 14.0, *)
    @objc private func tick(_ link: CADisplayLink) {
        timestamp = link.timestamp
        targetTimestamp = link.targetTimestamp
        duration = link.duration
        _ = target?.perform(selector, with: self)
    }

    @objc private func timerFired() {
        let now = CACurrentMediaTime()
        timestamp = now
        targetTimestamp = now + interval
        duration = interval
        _ = target?.perform(selector, with: self)
    }
}

// MARK: - ScreenCaptureKit single-frame capture

private final class SCStreamFrameCapture: NSObject, SCStreamOutput {
    private let continuation: CheckedContinuation<CGImage?, Never>
    private let queue = DispatchQueue(label: "com.vorssaint.compat.scstream")
    private var stream: SCStream?
    private var finished = false
    private var timeout: DispatchWorkItem?

    private init(_ continuation: CheckedContinuation<CGImage?, Never>) {
        self.continuation = continuation
    }

    static func capture(filter: SCContentFilter,
                        configuration: SCStreamConfiguration) async -> CGImage? {
        await withCheckedContinuation { continuation in
            let capture = SCStreamFrameCapture(continuation)
            capture.start(filter: filter, configuration: configuration)
        }
    }

    private func start(filter: SCContentFilter, configuration: SCStreamConfiguration) {
        do {
            let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
            self.stream = stream
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
            let timeout = DispatchWorkItem { [weak self] in self?.finish(nil) }
            self.timeout = timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: timeout)
            stream.startCapture { [weak self] error in
                if error != nil { self?.finish(nil) }
            }
        } catch {
            finish(nil)
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard type == .screen, let buffer = sampleBuffer.imageBuffer else { return }
        var image: CGImage?
        VTCreateCGImageFromCVPixelBuffer(buffer, options: nil, imageOut: &image)
        finish(image)
    }

    private func finish(_ image: CGImage?) {
        guard !finished else { return }
        finished = true
        timeout?.cancel()
        timeout = nil
        stream?.stopCapture { _ in }
        stream = nil
        continuation.resume(returning: image)
    }
}

enum ScreenshotCompat {
    static func captureImage(contentFilter: SCContentFilter,
                             configuration: SCStreamConfiguration) async -> CGImage? {
        if #available(macOS 14.0, *) {
            return await ScreenshotCompat.captureImage(contentFilter: contentFilter,
                                                               configuration: configuration)
        }
        return await SCStreamFrameCapture.capture(filter: contentFilter,
                                                  configuration: configuration)
    }
}


// MARK: - Port diagnostics

enum MacOS13Diagnostics {
    private static func shareableContent() async -> SCShareableContent? {
        await withCheckedContinuation { continuation in
            let lock = NSLock()
            var finished = false
            func finish(_ value: SCShareableContent?) {
                lock.lock()
                if finished { lock.unlock(); return }
                finished = true
                lock.unlock()
                continuation.resume(returning: value)
            }
            SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { content, _ in
                finish(content)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { finish(nil) }
        }
    }

    static func captureMainDisplay() async -> String {
        let requested = CGRequestScreenCaptureAccess()
        let preflight = CGPreflightScreenCaptureAccess()
        try? "preflight=\(preflight) requested=\(requested)"
            .write(toFile: "/tmp/vorssaint-preflight.txt", atomically: true, encoding: .utf8)
        guard let content = await shareableContent() else {
            return "preflight=\(preflight) content timeout"
        }
        guard let display = content.displays.first else {
            return "preflight=\(preflight) no display"
        }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = display.width
        configuration.height = display.height
        configuration.showsCursor = false
        guard let image = await ScreenshotCompat.captureImage(contentFilter: filter,
                                                              configuration: configuration)
        else { return "preflight=\(preflight) capture nil" }
        return "preflight=\(preflight) capture \(image.width)x\(image.height)"
    }

    static func captureFirstWindow() async -> String {
        let requested = CGRequestScreenCaptureAccess()
        let preflight = CGPreflightScreenCaptureAccess()
        guard let content = await shareableContent() else {
            return "preflight=\(preflight) requested=\(requested) content timeout"
        }
        let ownID = Bundle.main.bundleIdentifier
        guard let window = content.windows.first(where: {
            $0.frame.width > 100 && $0.frame.height > 100
                && $0.owningApplication?.bundleIdentifier != ownID
        }) else { return "preflight=\(preflight) no window" }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        configuration.width = Int(window.frame.width)
        configuration.height = Int(window.frame.height)
        configuration.showsCursor = false
        guard let image = await ScreenshotCompat.captureImage(contentFilter: filter,
                                                              configuration: configuration)
        else { return "preflight=\(preflight) capture nil" }
        return "preflight=\(preflight) window \(image.width)x\(image.height)"
    }
}
