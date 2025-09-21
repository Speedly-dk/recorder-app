import Foundation
import SwiftUI
import Combine

/// Global application state that persists across popover open/close cycles
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    let audioManager = AudioManager()
    let settings = RecorderSettings()
    let audioRecorder = AudioRecorder()
    let updateChecker = UpdateChecker()

    private init() {
        // Initialize once at app startup
        print("AppState initialized")
    }
}