import AppKit

/// Custom NSPopover subclass that removes the arrow and provides proper positioning
class ArrowlessPopover: NSPopover {

    override init() {
        super.init()

        // This private API removes the popover arrow
        // Using respondsToSelector for safety
        if self.responds(to: NSSelectorFromString("setHasArrow:")) {
            self.setValue(false, forKey: "hasArrow")
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}