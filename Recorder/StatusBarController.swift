import AppKit
import SwiftUI
import Combine

/// State machine for popover lifecycle management
enum PopoverState {
    case closed
    case opening
    case open
    case closing
}

class StatusBarController: NSObject, ObservableObject {
    private var statusItem: NSStatusItem!
    private lazy var popover: NSPopover = {
        let pop = NSPopover()
        pop.behavior = .transient
        pop.animates = false  // Disable animation to avoid positioning issues
        pop.delegate = self

        return pop
    }()

    // Phase 1.1: Singleton pattern for ContentView
    private lazy var contentView = ContentView()
    private lazy var hostingController = NSHostingController(rootView: contentView)

    // Phase 1.2: State management
    private var popoverState: PopoverState = .closed

    // Phase 1.3: Debouncer for rapid clicks
    private var toggleDebouncer: DispatchWorkItem?

    // Phase 2.3: Improved event monitor
    private var eventMonitor: EventMonitor?

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

        // Setup ContentView once
        setupContentView()

        // Setup observation after initialization completes
        DispatchQueue.main.async { [weak self] in
            self?.setupRecorderObservation()
        }

        // Initialize event monitor with proper handler
        eventMonitor = EventMonitor { [weak self] in
            guard let self = self else { return }
            if self.popoverState == .open {
                self.closePopover()
            }
        }
    }

    private func setupContentView() {
        // Configure hosting controller once
        hostingController.preferredContentSize = NSSize(width: 350, height: 480)

        // Phase 2.2: Add bounds clipping for macOS Sonoma
        if #available(macOS 14.0, *) {
            if let view = hostingController.view as? NSView {
                view.wantsLayer = true
                view.layer?.masksToBounds = true
            }
        }

        // Set the content view controller once
        popover.contentViewController = hostingController
    }

    private func setupRecorderObservation() {
        // Access AudioRecorder safely from AppState
        audioRecorder = AppState.shared.audioRecorder

        guard let audioRecorder = audioRecorder else { return }

        // Phase 2.1: Use weak references in all closures
        audioRecorder.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                guard let self = self else { return }
                self.handleRecordingStateChange(isRecording)
            }
            .store(in: &cancellables)

        // Observe recording duration with weak reference
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

    // Phase 1.3: Implement debounced toggle
    @objc func handleClick(_ sender: NSStatusBarButton) {
        print("Status bar button clicked")

        // Cancel any pending toggle
        toggleDebouncer?.cancel()

        // Create new debounced work item
        toggleDebouncer = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.performToggle()
        }

        // Execute after debounce delay
        if let debouncer = toggleDebouncer {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: debouncer)
        }
    }

    private func performToggle() {
        switch popoverState {
        case .closed:
            showPopoverWithRetry()
        case .open:
            closePopover()
        case .opening, .closing:
            // Ignore clicks during transitions
            print("Ignoring click during transition state: \(popoverState)")
        }
    }

    // Phase 3.2: Implement retry mechanism
    func showPopoverWithRetry(attempts: Int = 3) {
        guard popoverState == .closed else {
            print("Cannot show popover - current state: \(popoverState)")
            return
        }

        guard let button = statusItem.button else {
            print("ERROR: Status item button is nil when trying to show popover")

            if attempts > 0 {
                print("Retrying to show popover, attempts remaining: \(attempts - 1)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.showPopoverWithRetry(attempts: attempts - 1)
                }
            } else {
                print("Failed to show popover after all retry attempts")
            }
            return
        }

        // Update state machine
        popoverState = .opening

        // Debug logging for positioning
        print("\n=== POPOVER POSITIONING DEBUG ===")
        print("Button bounds: \(button.bounds)")
        print("Button frame: \(button.frame)")

        if let window = button.window {
            let windowFrame = window.frame
            print("Button window frame: \(windowFrame)")
            let screenFrame = window.screen?.frame ?? .zero
            print("Screen frame: \(screenFrame)")

            // Convert button frame to screen coordinates
            let buttonScreenFrame = window.convertToScreen(button.frame)
            print("Button screen frame: \(buttonScreenFrame)")
        }

        print("Button title: '\(button.title)'")
        print("Button image: \(button.image?.description ?? "nil")")

        // Handle attributedTitle which is NSAttributedString! (implicitly unwrapped optional)
        var attributedTitleString = ""
        var hasAttributedTitle = false
        if button.attributedTitle != nil {
            attributedTitleString = button.attributedTitle.string
            hasAttributedTitle = !attributedTitleString.isEmpty
        }
        print("Button attributed title: '\(attributedTitleString)'")

        // Track if button has content
        let hasImage = button.image != nil
        let hasTitle = !button.title.isEmpty

        print("Button content - Image: \(hasImage), Title: \(hasTitle), AttributedTitle: \(hasAttributedTitle)")

        print("Showing popover...")
        // Always use the full button bounds for consistent positioning
        // NSPopover will center itself relative to these bounds
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // Log popover position after showing and fix positioning if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self,
                  let popoverWindow = self.popover.contentViewController?.view.window,
                  let button = self.statusItem.button,
                  let buttonWindow = button.window else { return }

            let currentFrame = popoverWindow.frame
            print("Popover window frame after showing: \(currentFrame)")

            // Calculate correct Y position based on button position
            // The popover should be just below the menu bar
            let buttonScreenFrame = buttonWindow.convertToScreen(button.frame)
            let correctY = buttonScreenFrame.minY - currentFrame.height - 20  // 20px gap for arrow

            // If position is significantly off, fix it
            if abs(currentFrame.origin.y - correctY) > 50 {  // More than 50px difference
                var fixedFrame = currentFrame
                fixedFrame.origin.y = correctY
                popoverWindow.setFrame(fixedFrame, display: false, animate: false)
                print("Fixed popover position from Y=\(currentFrame.origin.y) to Y=\(correctY)")
            }
        }
        print("=================================\n")

        // Start event monitoring
        eventMonitor?.start()
    }

    func closePopover() {
        guard popoverState == .open else {
            print("Cannot close popover - current state: \(popoverState)")
            return
        }

        // Update state machine
        popoverState = .closing

        print("Closing popover...")
        popover.performClose(nil)

        // Stop event monitoring immediately
        eventMonitor?.stop()
    }

    func updateStatusIcon() {
        guard let button = statusItem.button else { return }

        // Safe access to audioRecorder
        let isRecording = audioRecorder?.isRecording ?? false
        let recordingDuration = audioRecorder?.recordingDuration ?? 0

        print("\n=== STATUS ICON UPDATE ===")
        print("Is recording: \(isRecording)")
        print("Button bounds before update: \(button.bounds)")
        print("Button frame before update: \(button.frame)")

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

        print("Button bounds after update: \(button.bounds)")
        print("Button frame after update: \(button.frame)")
        print("==========================\n")
    }


    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        formatter.unitsStyle = .positional
        return formatter.string(from: duration) ?? "00:00"
    }

    // Phase 3.3: Crash-safe deinit
    deinit {
        print("StatusBarController deinit starting")

        // Cancel all Combine subscriptions synchronously
        cancellables.removeAll()

        // Stop timer immediately
        updateTimer?.invalidate()
        updateTimer = nil

        // Stop event monitor
        eventMonitor?.stop()
        eventMonitor = nil

        // Close popover if shown
        if popover.isShown {
            popover.close()
        }

        // Clear popover delegate
        popover.delegate = nil

        // Clear popover content
        popover.contentViewController = nil

        // Remove status item
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }

        print("StatusBarController deinit completed")
    }
}

// Phase 3.1: Add NSPopoverDelegate
extension StatusBarController: NSPopoverDelegate {
    func popoverDidShow(_ notification: Notification) {
        print("Popover did show")
        popoverState = .open
    }

    func popoverDidClose(_ notification: Notification) {
        print("Popover did close")
        popoverState = .closed

        // Ensure event monitor is stopped
        eventMonitor?.stop()
    }

    func popoverWillShow(_ notification: Notification) {
        print("Popover will show")
        popoverState = .opening
    }

    func popoverWillClose(_ notification: Notification) {
        print("Popover will close")
        popoverState = .closing
    }
}
