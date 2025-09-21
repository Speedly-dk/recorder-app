# Release Notes - v0.2.0

## 🎉 Major Stability Update

This release brings significant improvements to the application's stability and memory management, addressing critical issues with the NSPopover implementation.

## ✨ What's New

### 🛡️ Stability Improvements
- **Fixed popover crashes** when opening/closing rapidly
- **Eliminated memory leaks** from ContentView recreations
- **Resolved race conditions** with new state machine implementation
- **Added retry mechanism** for resilient popover opening
- **Improved event monitoring** with dedicated lifecycle management

### 🚀 Performance Enhancements
- ContentView now uses singleton pattern (no more recreations)
- Weak references prevent retain cycles in Combine subscriptions
- Synchronous cleanup in deinit prevents use-after-free errors
- Debounced clicking prevents rapid toggle issues

### 🖥️ Compatibility
- Added macOS Sonoma (14.0+) specific fixes for rendering issues
- Maintains backward compatibility with macOS 13.0+

## 🐛 Bug Fixes
- Fixed crash vulnerability in deinitialization sequence (#9)
- Fixed event monitor conflicts causing inconsistent close behavior
- Fixed state synchronization problems between popover and app state
- Fixed potential memory leaks from retained SwiftUI views

## 📋 Technical Details

### Changed Files
- `StatusBarController.swift` - Complete refactor for stability
- `EventMonitor.swift` - New helper class for event management
- `Info.plist` - Version bump to 0.2.0

### Implementation Highlights
- PopoverState enum for proper state tracking
- NSPopoverDelegate for lifecycle synchronization
- 100ms debounce delay for click handling
- Up to 3 retry attempts for popover opening

## 📦 Installation

### First Time Users
1. Download `Recorder.app.zip` from the releases page
2. Unzip the file
3. Move `Recorder.app` to your Applications folder
4. **Important**: Right-click and select "Open" for first launch to bypass Gatekeeper

### Updating from Previous Version
1. Quit the existing Recorder app from the menu bar
2. Download the new version
3. Replace the old app in Applications folder
4. Launch the updated app

## 🔒 Permissions Required
- Microphone access for audio recording
- Screen recording permission for system audio capture (macOS 15.0+ for microphone via ScreenCaptureKit)

## 🙏 Acknowledgments
Thanks to all users who reported stability issues. Your feedback helps make Recorder better!

## 📝 Full Changelog
- fix: Improve NSPopover stability and prevent memory leaks (#9)
- chore: Bump version to 0.2.0

---
For issues or feedback, please visit: https://github.com/Speedly-dk/recorder-app/issues