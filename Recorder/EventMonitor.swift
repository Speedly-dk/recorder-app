import AppKit

/// Manages global event monitoring for detecting clicks outside the popover
/// This class ensures proper lifecycle management of NSEvent monitors to prevent
/// memory leaks and race conditions
final class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: () -> Void

    init(mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown],
         handler: @escaping () -> Void) {
        self.mask = mask
        self.handler = handler
    }

    func start() {
        // Ensure we don't create duplicate monitors
        guard monitor == nil else {
            print("EventMonitor: Monitor already active, skipping start")
            return
        }

        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            self?.handler()
        }

        print("EventMonitor: Started monitoring events")
    }

    func stop() {
        guard let monitor = monitor else {
            print("EventMonitor: No monitor to stop")
            return
        }

        NSEvent.removeMonitor(monitor)
        self.monitor = nil
        print("EventMonitor: Stopped monitoring events")
    }

    deinit {
        // Ensure cleanup on deallocation
        stop()
    }
}