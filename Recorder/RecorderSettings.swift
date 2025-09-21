import SwiftUI

class RecorderSettings: ObservableObject {
    @AppStorage("recordingsFolderPath") private var storedFolderPath = ""
    @AppStorage("selectedInputDeviceUID") private var storedInputDeviceUID = ""
    @AppStorage("selectedOutputDeviceUID") private var storedOutputDeviceUID = ""

    @Published var recordingsFolderPath: String {
        didSet {
            storedFolderPath = recordingsFolderPath
        }
    }

    @Published var selectedInputDeviceUID: String {
        didSet {
            storedInputDeviceUID = selectedInputDeviceUID
        }
    }

    @Published var selectedOutputDeviceUID: String {
        didSet {
            storedOutputDeviceUID = selectedOutputDeviceUID
        }
    }

    init() {
        self.recordingsFolderPath = storedFolderPath.isEmpty ? defaultRecordingsPath() : storedFolderPath
        self.selectedInputDeviceUID = storedInputDeviceUID
        self.selectedOutputDeviceUID = storedOutputDeviceUID
    }

    private func defaultRecordingsPath() -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let recordingsFolder = documentsPath.appendingPathComponent("Recordings")

        if !FileManager.default.fileExists(atPath: recordingsFolder.path) {
            try? FileManager.default.createDirectory(at: recordingsFolder, withIntermediateDirectories: true, attributes: nil)
        }

        return recordingsFolder.path
    }

    func updateRecordingsFolder(_ path: String) {
        recordingsFolderPath = path
    }

    func updateInputDevice(_ uid: String) {
        selectedInputDeviceUID = uid
    }

    func updateOutputDevice(_ uid: String) {
        selectedOutputDeviceUID = uid
    }

    func folderName() -> String {
        if recordingsFolderPath.isEmpty {
            return "Not Selected"
        }
        return URL(fileURLWithPath: recordingsFolderPath).lastPathComponent
    }

    func folderExists() -> Bool {
        return FileManager.default.fileExists(atPath: recordingsFolderPath)
    }
}