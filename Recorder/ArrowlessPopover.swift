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
}