import CoreGraphics
import Foundation

/// Active session event tap on the main run loop.
@MainActor
final class EventTap {
    typealias Handler = @MainActor (CGEventTapProxy, CGEventType, CGEvent) -> Unmanaged<CGEvent>?

    let handler: Handler
    private var port: CFMachPort?
    private var source: CFRunLoopSource?

    var isRunning: Bool { port.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    /// Returns false if the system refused (no permissions).
    func start() -> Bool {
        if port != nil { return true }
        let types: [CGEventType] = [.keyDown, .flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        let source = CFMachPortCreateRunLoopSource(nil, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        self.port = port
        self.source = source
        return true
    }

    func reenable() {
        if let port { CGEvent.tapEnable(tap: port, enable: true) }
    }
}

/// Carries callback arguments into `MainActor.assumeIsolated`; safe because the tap's
/// run loop source is on the main run loop, so the callback always runs on the main thread.
private struct TapCall: @unchecked Sendable {
    let proxy: CGEventTapProxy
    let type: CGEventType
    let event: CGEvent
    let refcon: UnsafeMutableRawPointer
}

private struct TapResult: @unchecked Sendable {
    let value: Unmanaged<CGEvent>?
}

private func eventTapCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let call = TapCall(proxy: proxy, type: type, event: event, refcon: refcon)
    return MainActor.assumeIsolated {
        let tap = Unmanaged<EventTap>.fromOpaque(call.refcon).takeUnretainedValue()
        return TapResult(value: tap.handler(call.proxy, call.type, call.event))
    }.value
}
