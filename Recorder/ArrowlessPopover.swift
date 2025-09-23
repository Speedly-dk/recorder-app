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
        // Ensure popover is properly closed before showing again
        if self.isShown {
            self.close()
        }

        super.show(relativeTo: positioningRect, of: positioningView, preferredEdge: preferredEdge)
    }
}