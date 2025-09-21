# 🎙️ Recorder

A lightweight macOS menu bar app for high-quality audio recording, capturing both system audio and microphone input simultaneously.

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2013.0%2B-blue" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-5.0-orange" alt="Swift">
  <img src="https://img.shields.io/github/v/release/Speedly-dk/recorder-app?include_prereleases&label=Version" alt="Version">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License">
</p>

## ✨ Features

- 🎵 **Dual Audio Capture** - Record system audio and microphone simultaneously
- 🎛️ **Device Selection** - Choose specific input/output devices for recording
- 💾 **High-Quality Output** - M4A format with AAC compression (48kHz, stereo, 128kbps)
- 🔄 **Auto-Updates** - Get notified when new versions are available
- 🖥️ **Menu Bar Interface** - Unobtrusive popover UI that stays out of your way
- 📁 **Quick Access** - Easy access to recordings folder directly from the app
- ⚡ **Lightweight** - Minimal CPU and memory footprint

## 📋 Requirements

- macOS 13.0 or later
- macOS 15.0+ for microphone capture via ScreenCaptureKit
- Microphone permission
- Screen recording permission (for system audio capture)

## 🚀 Installation

### Download Release

1. Download the latest release from the [Releases page](https://github.com/Speedly-dk/recorder-app/releases)
2. Unzip `Recorder-vX.X.X.zip`
3. Drag `Recorder.app` to your Applications folder
4. **First Launch** (Important - app is not yet notarized):
   - **Right-click** on Recorder.app and select **"Open"**
   - Click "Open" in the security dialog
   - This only needs to be done once
5. Grant required permissions when prompted

> **Note**: The security warning appears because this is a beta release that isn't yet notarized by Apple. The app is safe and the source code is available for review.

### Build from Source

```bash
# Clone the repository
git clone https://github.com/Speedly-dk/recorder-app.git
cd recorder-app

# Open in Xcode
open Recorder.xcodeproj

# Build and run (⌘R)
```

## 🎯 Usage

1. **Launch** - Click the Recorder icon in your menu bar
2. **Configure** - Select your preferred audio devices:
   - Input Device (Microphone)
   - Output Device (System Audio)
3. **Record** - Click "Start Recording" to begin
4. **Stop** - Click "Stop Recording" when finished
5. **Access** - Click "Open in Finder" to access recordings (stored in the app's container)

## 🛠️ Technical Details

### Architecture

- **SwiftUI** - Modern declarative UI framework
- **ScreenCaptureKit** - Apple's framework for high-quality audio capture
- **AVFoundation** - Audio processing and file writing
- **CoreAudio** - Low-level audio device management

### Audio Specifications

- **Format**: M4A (MPEG-4 Audio)
- **Codec**: AAC-LC
- **Sample Rate**: 48 kHz
- **Channels**: Stereo
- **Bitrate**: 128 kbps

### Storage Location

Recordings are saved in the app's sandboxed container:
- **Path**: `~/Library/Containers/dk.ap3.Recorder/Data/Documents/Recordings/`
- **Access**: Use the "Open in Finder" button in the app for easy access

### Project Structure

```
Recorder/
├── RecorderApp.swift          # App entry point and lifecycle
├── ContentView.swift          # Main UI popover view
├── StatusBarController.swift  # Menu bar integration
├── AudioRecorder.swift        # Recording implementation
├── AudioManager.swift         # Device management
├── UpdateChecker.swift        # Auto-update functionality
├── RecorderSettings.swift     # User preferences
└── AppState.swift            # Global state management
```

## 🔒 Privacy & Permissions

Recorder requires the following permissions:
- **Microphone Access** - To record from your microphone
- **Screen Recording** - To capture system audio (no video is recorded)

All recordings are stored locally on your machine. No data is sent to external servers.

## 🐛 Known Issues

- Microphone capture via ScreenCaptureKit requires macOS 15.0+
- On macOS 13-14, only system audio can be recorded
- First launch requires right-click → Open to bypass Gatekeeper (unsigned beta)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🏢 About

Recorder is a project by [AP3](https://ap3.dk) - Digital Agency specializing in innovative software solutions.

## 🙏 Acknowledgments

- Built with Apple's ScreenCaptureKit framework
- Inspired by the need for simple, high-quality audio recording on macOS
- Auto-update implementation inspired by [Azayaka](https://github.com/Mnpn/Azayaka)

## 📬 Support

For bug reports and feature requests, please use the [GitHub Issues](https://github.com/Speedly-dk/recorder-app/issues) page.

For other inquiries, visit [AP3.dk](https://ap3.dk).

---

<p align="center">
  Made with ❤️ by <a href="https://ap3.dk">AP3</a>
</p>