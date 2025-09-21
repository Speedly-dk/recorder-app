import SwiftUI
import Combine

class RecorderSettings: ObservableObject {
    @AppStorage("recordingsFolderPath") private var storedFolderPath = ""
    @AppStorage("selectedInputDeviceUID") private var storedInputDeviceUID = ""
    @AppStorage("selectedOutputDeviceUID") private var storedOutputDeviceUID = ""

    @Published var recordingsFolderPath: String = ""
    @Published var selectedInputDeviceUID: String = ""
    @Published var selectedOutputDeviceUID: String = ""

    init() {
        let defaultPath = storedFolderPath.isEmpty ? defaultRecordingsPath() : storedFolderPath
        self.recordingsFolderPath = defaultPath
        self.selectedInputDeviceUID = storedInputDeviceUID
        self.selectedOutputDeviceUID = storedOutputDeviceUID

        setupObservers()
    }

    private func setupObservers() {
        $recordingsFolderPath
            .dropFirst()
            .sink { [weak self] newPath in
                self?.storedFolderPath = newPath
            }
            .store(in: &cancellables)

        $selectedInputDeviceUID
            .dropFirst()
            .sink { [weak self] newUID in
                self?.storedInputDeviceUID = newUID
            }
            .store(in: &cancellables)

        $selectedOutputDeviceUID
            .dropFirst()
            .sink { [weak self] newUID in
                self?.storedOutputDeviceUID = newUID
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

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