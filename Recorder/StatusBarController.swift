import AppKit
import SwiftUI
import Combine

class StatusBarController: NSObject, ObservableObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var monitor: Any?
    private var updateTimer: Timer?
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0

    override init() {
        super.init()

        // Create status bar item first
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Configure the button
        if let button = statusItem.button {
            button.action = #selector(handleClick(_:))
            button.target = self
            updateStatusIcon()
        }

        // Create and configure popover
        popover = NSPopover()
        popover.contentViewController = NSHostingController(rootView: ContentView())
        popover.behavior = .transient

        // Keep status item always visible
        statusItem.isVisible = true
    }

    @objc func handleClick(_ sender: NSStatusBarButton) {
        print("Status bar button clicked")

        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    func showPopover() {
        guard let button = statusItem.button else {
            print("ERROR: Status item button is nil when trying to show popover")
            return
        }

        print("Showing popover...")
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // Monitor for clicks outside popover
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let self = self, self.popover.isShown {
                self.closePopover()
            }
        }
    }

    func closePopover() {
        print("Closing popover...")
        popover.performClose(nil)

        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    func updateStatusIcon() {
        guard let button = statusItem.button else { return }

        let durationString = formatDuration(recordingDuration)
        let iconView = NSHostingView(rootView: MenuBarView(isRecording: isRecording, recordingDuration: durationString))

        // Remove any existing subviews
        button.subviews.forEach { $0.removeFromSuperview() }

        // Set the frame based on recording state
        let width: CGFloat = isRecording ? 72 : 28
        iconView.frame = NSRect(x: 0, y: 0, width: width, height: 22)

        button.addSubview(iconView)
        button.frame.size = iconView.frame.size
    }

    func setRecordingState(_ recording: Bool, duration: TimeInterval = 0) {
        isRecording = recording
        recordingDuration = duration

        if recording {
            // Start timer to update duration display
            updateTimer?.invalidate()
            updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.updateStatusIcon()
            }
            RunLoop.current.add(updateTimer!, forMode: .common)
        } else {
            // Stop timer
            updateTimer?.invalidate()
            updateTimer = nil
            recordingDuration = 0
        }

        updateStatusIcon()
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        formatter.unitsStyle = .positional
        return formatter.string(from: duration) ?? "00:00"
    }

    deinit {
        updateTimer?.invalidate()

        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }

        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }
}