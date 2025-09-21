import AppKit
import SwiftUI

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem
    private var popover: NSPopover

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
        popover.animates = true

        super.init()

        setupStatusButton()
        setupPopoverContent()
    }

    private func setupStatusButton() {
        if let button = statusItem.button {
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)

            if let image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Record") {
                let coloredImage = image.withSymbolConfiguration(config)
                coloredImage?.isTemplate = false

                button.image = coloredImage
                button.imagePosition = .imageOnly
                button.action = #selector(togglePopover)
                button.target = self
            } else {
                button.title = "⏺"
            }
        }
    }

    private func setupPopoverContent() {
        popover.contentViewController = NSHostingController(rootView: ContentView())
    }

    @objc private func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
}