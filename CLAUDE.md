# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a macOS menu bar audio recording application built with SwiftUI. It appears as a status bar item that shows a popover for audio device configuration and recording settings.

## Architecture

### Core Components

1. **RecorderApp.swift** - Main app entry point with AppDelegate that initializes the StatusBarController
2. **StatusBarController.swift** - Manages the menu bar status item and popover presentation
3. **ContentView.swift** - Main UI for the popover, displays audio device settings, recording controls, and folder selection
4. **AudioManager.swift** - Handles CoreAudio device enumeration and microphone permission management
5. **RecorderSettings.swift** - Manages persistent user preferences using @AppStorage
6. **AudioRecorder.swift** - Implements audio recording using ScreenCaptureKit to capture system audio and microphone input

### Key Technical Details

- **Audio Device Management**: Uses CoreAudio APIs (AudioObjectPropertyAddress, AudioObjectGetPropertyData) to enumerate input/output devices
- **Audio Recording**: Leverages ScreenCaptureKit (macOS 13+) to capture system audio and microphone input simultaneously
- **File Writing**: Uses AVAssetWriter with AAC codec for efficient compression and continuous streaming to disk
- **Permissions**: Handles both microphone and screen recording permissions with proper authorization checks
- **State Management**: Uses SwiftUI's @StateObject and @Published for reactive UI updates
- **Persistence**: Settings stored using @AppStorage (UserDefaults wrapper)
- **UI Pattern**: Menu bar app with NSPopover hosting SwiftUI ContentView
- **Recording Format**: M4A files with 48kHz stereo audio, AAC compression at 128kbps

## Build Commands

### Building the Application
```bash
# Build for debug
xcodebuild -project Recorder.xcodeproj -scheme Recorder -configuration Debug build

# Build for release
xcodebuild -project Recorder.xcodeproj -scheme Recorder -configuration Release build

# Clean build folder
xcodebuild -project Recorder.xcodeproj clean
```

### Running the Application
```bash
# Run the built app (after building)
open build/Debug/Recorder.app

# Or build and run in one command
xcodebuild -project Recorder.xcodeproj -scheme Recorder -configuration Debug build && open build/Debug/Recorder.app
```

### Testing
```bash
# Run tests (if test targets are added)
xcodebuild test -project Recorder.xcodeproj -scheme Recorder
```

## Development Notes

### Working with Audio Devices
- The app uses CoreAudio framework for device enumeration
- Device changes are handled manually with a refresh button
- Default output device is detected using kAudioHardwarePropertyDefaultOutputDevice

### Entitlements Required
- `com.apple.security.app-sandbox`: App sandboxing enabled
- `com.apple.security.device.audio-input`: Microphone access
- `com.apple.security.files.user-selected.read-write`: File system access for recording folder

### Recording Implementation
- **ScreenCaptureKit Setup**: Creates SCStream with audio-only configuration (no video capture)
- **Audio Streams**: Handles both system audio (.audio) and microphone (.microphone) output types
- **Timestamp Synchronization**: Adjusts CMSampleBuffer timestamps to ensure proper audio alignment
- **Continuous Writing**: Streams audio directly to disk via AVAssetWriter to handle long recordings
- **Error Handling**: Comprehensive error handling for permissions, file I/O, and stream failures
- **macOS Version Support**: Microphone capture through ScreenCaptureKit requires macOS 15.0+

### SwiftUI Integration
- ContentView is hosted in NSPopover via NSHostingController
- Uses AppDelegate pattern with @NSApplicationDelegateAdaptor for menu bar setup