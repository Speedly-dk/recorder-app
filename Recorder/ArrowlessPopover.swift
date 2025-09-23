import AppKit

/// Custom NSPopover subclass that provides better positioning
class ArrowlessPopover: NSPopover {

    override init() {
        super.init()
        // Configure popover appearance
        self.animates = false
        self.behavior = .transient
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {
        super.show(relativeTo: positioningRect, of: positioningView, preferredEdge: preferredEdge)

        // After showing, adjust the window frame to position it better
        DispatchQueue.main.async { [weak self] in
            guard let window = self?.contentViewController?.view.window else { return }

            var frame = window.frame
            // Adjust position to be closer to menu bar (compensate for arrow space)
            frame.origin.y += 8
            window.setFrame(frame, display: false, animate: false)
        }
    }
}