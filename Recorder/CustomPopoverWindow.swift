import AppKit
import SwiftUI

/// Custom window that mimics a popover appearance without the arrow
class CustomPopoverWindow: NSPanel {

    init(contentView: NSView, relativeTo positioningRect: NSRect, of positioningView: NSView) {
        // Calculate window size based on content
        let contentSize = contentView.fittingSize.width > 0 ? contentView.fittingSize : NSSize(width: 350, height: 480)

        // Calculate window position
        let screenRect = positioningView.window?.convertToScreen(positioningView.convert(positioningRect, to: nil)) ?? .zero
        let windowOrigin = NSPoint(
            x: screenRect.midX - contentSize.width / 2,
            y: screenRect.minY - contentSize.height - 5  // 5pt gap below status bar
        )

        let windowRect = NSRect(origin: windowOrigin, size: contentSize)

        super.init(
            contentRect: windowRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Configure panel appearance
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .popUpMenu
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = false
        self.hasShadow = true

        // Create background view with rounded corners
        let backgroundView = NSVisualEffectView()
        backgroundView.material = .popover
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 8
        backgroundView.layer?.masksToBounds = true

        // Add content view to background
        contentView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: backgroundView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor)
        ])

        self.contentView = backgroundView
    }

    override var canBecomeKey: Bool {
        return true
    }

    override func resignKey() {
        super.resignKey()
        // Close window when it loses key status
        self.close()
    }
}