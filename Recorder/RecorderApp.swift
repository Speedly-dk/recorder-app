import SwiftUI

@main
struct RecorderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController!  // Make it implicitly unwrapped to ensure it's not deallocated

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()

        // Ensure the app doesn't terminate when last window closes
        NSApp.setActivationPolicy(.accessory)

        // Check for updates if enabled
        Task { @MainActor in
            let appState = AppState.shared
            if appState.settings.checkForUpdates {
                await appState.updateChecker.checkForUpdates()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false  // Keep app running even when all windows are closed
    }
}