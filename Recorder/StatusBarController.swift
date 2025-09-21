import AppKit
import SwiftUI
import Combine

class StatusBarController: NSObject, ObservableObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var contentViewController: NSViewController?
    private var monitor: Any?
    private var updateTimer: Timer?
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0

    override init() {
        super.init()

        // Create status bar item first
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Configure the button with simple image instead of NSHostingView
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "Audio Recorder")
            button.action = #selector(handleClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Create popover but don't set content yet
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true

        // Keep status item always visible
        statusItem.isVisible = true

        // Set initial icon state
        updateStatusIcon()
    }

    @objc func handleClick(_ sender: NSStatusBarButton) {
        print("Status bar button clicked")

        // Add guard to prevent potential crashes
        guard let popover = popover else {
            print("ERROR: Popover is nil")
            return
        }

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

        guard let popover = popover else {
            print("ERROR: Popover is nil when trying to show")
            return
        }

        // Create content view controller only once and reuse it
        if contentViewController == nil {
            contentViewController = NSHostingController(rootView: ContentView())
        }

        popover.contentViewController = contentViewController

        print("Showing popover...")
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // Monitor for clicks outside popover
        if monitor == nil {
            monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                if let self = self, self.popover.isShown {
                    self.closePopover()
                }
            }
        }
    }

    func closePopover() {
        print("Closing popover...")
        popover.performClose(nil)

        // Remove event monitor immediately to prevent further events
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }

        // Delay clearing the content view controller to avoid heap corruption
        // This allows the popover animation to complete before releasing resources
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            // Only clear if popover is truly closed
            if !self.popover.isShown {
                self.popover.contentViewController = nil
                // Optionally clear the retained content view controller
                // Keep it retained for better performance on repeated opens
            }
        }
    }

    func updateStatusIcon() {
        guard let button = statusItem.button else { return }

        if isRecording {
            // Show icon with duration text
            let durationString = formatDuration(recordingDuration)

            // Create attributed string with icon and duration
            let attachment = NSTextAttachment()
            attachment.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "Recording")
            attachment.image?.isTemplate = true

            let attributedString = NSMutableAttributedString()
            attributedString.append(NSAttributedString(attachment: attachment))
            attributedString.append(NSAttributedString(string: " \(durationString)", attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor.labelColor
            ]))

            button.attributedTitle = attributedString
            button.image = nil

            // Set red tint for recording state
            button.contentTintColor = NSColor.systemRed
        } else {
            // Show just the icon
            button.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "Audio Recorder")
            button.attributedTitle = NSAttributedString()
            button.contentTintColor = nil
        }
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
        // Clean up in reverse order of creation to avoid use-after-free issues

        // First stop any active timers
        updateTimer?.invalidate()
        updateTimer = nil

        // Remove event monitor
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }

        // Clear popover content before destroying popover
        contentViewController = nil
        popover?.contentViewController = nil
        popover?.close()
        popover = nil

        // Finally remove status item
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }
}