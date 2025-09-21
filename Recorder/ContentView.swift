import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @StateObject private var settings = RecorderSettings()
    @State private var isMicrophoneAccessGranted = false
    @State private var isRefreshing = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Recorder Settings")
                .font(.headline)
                .padding(.top)

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
        .frame(width: 300, height: 400)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            checkMicrophoneAccess()
            restoreSelectedDevices()
        }
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder for recordings"

        if panel.runModal() == .OK {
            if let url = panel.url {
                settings.updateRecordingsFolder(url.path)
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
}