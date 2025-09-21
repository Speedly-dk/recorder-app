import AppKit
import SwiftUI
import Combine

class StatusBarController: NSObject, ObservableObject {
    private var statusItem: NSStatusItem!
    private lazy var popover: NSPopover = {
        let pop = NSPopover()
        pop.behavior = .transient
        pop.animates = true
        return pop
    }()
    private var contentViewController: NSViewController?
    private var monitor: Any?
    private var updateTimer: Timer?
    private var audioRecorder: AudioRecorder?
    private var cancellables = Set<AnyCancellable>()

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

        // Keep status item always visible
        statusItem.isVisible = true

        // Set initial icon state
        updateStatusIcon()

        // Setup observation after initialization completes
        DispatchQueue.main.async { [weak self] in
            self?.setupRecorderObservation()
        }
    }

    private func setupRecorderObservation() {
        // Access AudioRecorder safely from AppState
        audioRecorder = AppState.shared.audioRecorder

        guard let audioRecorder = audioRecorder else { return }

        // Observe isRecording state
        audioRecorder.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                self?.handleRecordingStateChange(isRecording)
            }
            .store(in: &cancellables)

        // Observe recording duration
        audioRecorder.$recordingDuration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self,
                      let recorder = self.audioRecorder,
                      recorder.isRecording else { return }
                self.updateStatusIcon()
            }
            .store(in: &cancellables)
    }

    private func handleRecordingStateChange(_ isRecording: Bool) {
        if isRecording {
            // Start timer to update the icon regularly
            updateTimer?.invalidate()
            updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.updateStatusIcon()
            }
            RunLoop.current.add(updateTimer!, forMode: .common)
        } else {
            // Stop timer when recording stops
            updateTimer?.invalidate()
            updateTimer = nil
        }

        // Update icon immediately
        updateStatusIcon()
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

        // Always create a fresh ContentView to avoid state issues
        let contentView = ContentView()
        let hostingController = NSHostingController(rootView: contentView)
        hostingController.preferredContentSize = NSSize(width: 350, height: 480)

        popover.contentViewController = hostingController
        contentViewController = hostingController

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

        // Clear the content view controller after a delay to allow animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.contentViewController = nil
        }
    }

    func updateStatusIcon() {
        guard let button = statusItem.button else { return }

        // Safe access to audioRecorder
        let isRecording = audioRecorder?.isRecording ?? false
        let recordingDuration = audioRecorder?.recordingDuration ?? 0

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


    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        formatter.unitsStyle = .positional
        return formatter.string(from: duration) ?? "00:00"
    }

    deinit {
        // Clean up in reverse order of creation to avoid use-after-free issues

        // Cancel all Combine subscriptions
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        // First stop any active timers
        updateTimer?.invalidate()
        updateTimer = nil

        // Remove event monitor
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }

        // Clear popover content before destroying popover
        popover.close()
        popover.contentViewController = nil
        contentViewController = nil

        // Finally remove status item
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }
}