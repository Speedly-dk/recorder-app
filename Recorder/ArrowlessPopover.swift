import AppKit

/// Custom NSPopover subclass that removes the arrow and provides proper positioning
class ArrowlessPopover: NSPopover {

    private var hasConfiguredArrow = false

    override init() {
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {
        // Remove arrow before showing
        if !hasConfiguredArrow {
            removeArrow()
            hasConfiguredArrow = true
        }

        super.show(relativeTo: positioningRect, of: positioningView, preferredEdge: preferredEdge)

        // Adjust window position after showing to compensate for removed arrow
        DispatchQueue.main.async { [weak self] in
            self?.adjustWindowPosition()
        }
    }

    private func removeArrow() {
        // Try multiple private API approaches to remove the arrow

        // Method 1: _setHasArrow
        if responds(to: Selector(("_setHasArrow:"))) {
            perform(Selector(("_setHasArrow:")), with: false)
        }

        // Method 2: setValue for private properties
        do {
            try setValue(false, forKey: "hasArrow")
        } catch {
            print("Failed to set hasArrow: \(error)")
        }

        // Method 3: shouldHideAnchor
        do {
            try setValue(true, forKey: "shouldHideAnchor")
        } catch {
            print("Failed to set shouldHideAnchor: \(error)")
        }
    }

    private func adjustWindowPosition() {
        guard let window = contentViewController?.view.window else { return }

        var frame = window.frame
        // Move window up by approximately the arrow height (8-12 points)
        frame.origin.y += 10
        window.setFrame(frame, display: false, animate: false)
    }
}