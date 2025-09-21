import SwiftUI
import AppKit
import AVFoundation

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @StateObject private var settings = RecorderSettings()
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var isMicrophoneAccessGranted = false
    @State private var isRefreshing = false
    @State private var showingError = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Recorder Settings")
                .font(.headline)
                .padding(.top)

            // Recording Controls
            VStack(spacing: 12) {
                Button(action: toggleRecording) {
                    HStack(spacing: 8) {
                        Image(systemName: audioRecorder.isRecording ? "stop.circle.fill" : "record.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(audioRecorder.isRecording ? .red : .accentColor)

                        Text(audioRecorder.isRecording ? "Stop Recording" : "Start Recording")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(audioRecorder.isRecording ? Color.red.opacity(0.1) : Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(!settings.folderExists() || (audioManager.selectedInputDevice == nil && audioManager.selectedOutputDevice == nil))

                if audioRecorder.isRecording {
                    HStack {
                        Image(systemName: "waveform")
                            .font(.caption)
                            .foregroundColor(.red)
                            .symbolEffect(.variableColor.iterative.dimInactiveLayers.nonReversing)

                        Text("Recording: \(formatDuration(audioRecorder.recordingDuration))")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                    .padding(.horizontal, 8)
                }
            }
            .padding(.horizontal)

            Divider()

            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recording Folder")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack {
                        Text(settings.folderName())
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button("Choose...") {
                            selectFolder()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Input Device (Microphone)")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Picker("", selection: Binding(
                        get: {
                            audioManager.selectedInputDevice ?? AudioManager.AudioDevice(id: 0, name: "None", uid: "")
                        },
                        set: { device in
                            audioManager.selectedInputDevice = device
                            settings.updateInputDevice(device.uid)
                        }
                    )) {
                        if audioManager.inputDevices.isEmpty {
                            Text("No input devices").tag(AudioManager.AudioDevice(id: 0, name: "None", uid: ""))
                        } else {
                            ForEach(audioManager.inputDevices) { device in
                                Text(device.name).tag(device)
                            }
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .disabled(!isMicrophoneAccessGranted || audioManager.inputDevices.isEmpty)
                }
                .padding(.horizontal)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Output Device")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Picker("", selection: Binding(
                        get: {
                            audioManager.selectedOutputDevice ?? AudioManager.AudioDevice(id: 0, name: "None", uid: "")
                        },
                        set: { device in
                            audioManager.selectedOutputDevice = device
                            settings.updateOutputDevice(device.uid)
                        }
                    )) {
                        if audioManager.outputDevices.isEmpty {
                            Text("No output devices").tag(AudioManager.AudioDevice(id: 0, name: "None", uid: ""))
                        } else {
                            ForEach(audioManager.outputDevices) { device in
                                Text(device.name).tag(device)
                            }
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                .padding(.horizontal)

                Divider()

                if !isMicrophoneAccessGranted {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text("Microphone access required")
                            .font(.caption)
                        Button("Grant Access") {
                            requestMicrophoneAccess()
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                    .padding(.horizontal)
                }

                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isRefreshing = true
                        }
                        audioManager.refreshDevices()
                        restoreSelectedDevices()

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isRefreshing = false
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            if isRefreshing {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption)
                            }
                            Text("Refresh Devices")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRefreshing)

                    Spacer()

                    if !audioManager.inputDevices.isEmpty || !audioManager.outputDevices.isEmpty {
                        Text("\(audioManager.inputDevices.count) input, \(audioManager.outputDevices.count) output")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
            }

            Spacer()
        }
        .frame(width: 350, height: 480)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            // Don't request microphone permission immediately
            // Only check current status
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                isMicrophoneAccessGranted = true
                audioManager.refreshDevices()
            case .denied, .restricted:
                isMicrophoneAccessGranted = false
            case .notDetermined:
                isMicrophoneAccessGranted = false
            @unknown default:
                isMicrophoneAccessGranted = false
            }
            restoreSelectedDevices()
        }
        .alert("Recording Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(audioRecorder.errorMessage ?? "An unknown error occurred")
        }
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder for recordings. The app will have permission to save recordings here."
        panel.prompt = "Select Folder"

        if panel.runModal() == .OK {
            if let url = panel.url {
                // Start accessing the security-scoped resource
                let didStart = url.startAccessingSecurityScopedResource()
                defer {
                    if didStart {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                // Create a security-scoped bookmark for persistent access
                if let bookmarkData = settings.saveBookmark(for: url) {
                    print("Successfully saved bookmark for: \(url.path)")
                } else {
                    // Fall back to just saving the path
                    settings.updateRecordingsFolder(url.path)
                    print("Warning: Could not create bookmark, saved path only: \(url.path)")

                    // Show warning to user
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Folder Access Warning"
                        alert.informativeText = "The folder was selected, but persistent access couldn't be established. You may need to reselect the folder after restarting the app."
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                }
            }
        }
    }

    private func checkMicrophoneAccess() {
        audioManager.requestMicrophonePermission { granted in
            isMicrophoneAccessGranted = granted
            if granted {
                audioManager.refreshDevices()
            }
        }
    }

    private func requestMicrophoneAccess() {
        checkMicrophoneAccess()
    }

    private func restoreSelectedDevices() {
        if !settings.selectedInputDeviceUID.isEmpty {
            audioManager.selectedInputDevice = audioManager.inputDevices.first { $0.uid == settings.selectedInputDeviceUID }
        }
        if !settings.selectedOutputDeviceUID.isEmpty {
            audioManager.selectedOutputDevice = audioManager.outputDevices.first { $0.uid == settings.selectedOutputDeviceUID }
        }
    }

    private func toggleRecording() {
        Task {
            if audioRecorder.isRecording {
                await audioRecorder.stopRecording()
            } else {
                do {
                    try await audioRecorder.startRecording(audioManager: audioManager, settings: settings)
                } catch {
                    audioRecorder.errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}