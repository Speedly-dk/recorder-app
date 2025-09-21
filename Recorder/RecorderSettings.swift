import SwiftUI
import Combine

class RecorderSettings: ObservableObject {
    @AppStorage("recordingsFolderPath") private var storedFolderPath = ""
    @AppStorage("recordingsFolderBookmark") private var storedFolderBookmark: Data?
    @AppStorage("selectedInputDeviceUID") private var storedInputDeviceUID = ""
    @AppStorage("selectedOutputDeviceUID") private var storedOutputDeviceUID = ""

    @Published var recordingsFolderPath: String = ""
    @Published var recordingsFolderBookmark: Data?
    @Published var selectedInputDeviceUID: String = ""
    @Published var selectedOutputDeviceUID: String = ""

    init() {
        // Try to resolve bookmark first if available
        if let bookmarkData = storedFolderBookmark,
           let resolvedURL = resolveBookmark(bookmarkData) {
            self.recordingsFolderPath = resolvedURL.path
            self.recordingsFolderBookmark = bookmarkData
        } else {
            // Fall back to stored path or default
            let defaultPath = storedFolderPath.isEmpty ? defaultRecordingsPath() : storedFolderPath
            self.recordingsFolderPath = defaultPath
            self.recordingsFolderBookmark = storedFolderBookmark
        }

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

        $recordingsFolderBookmark
            .dropFirst()
            .sink { [weak self] newBookmark in
                self?.storedFolderBookmark = newBookmark
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
        // Use the app's container Documents directory for sandbox compatibility
        if let containerURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let recordingsFolder = containerURL.appendingPathComponent("Recordings")

            if !FileManager.default.fileExists(atPath: recordingsFolder.path) {
                do {
                    try FileManager.default.createDirectory(at: recordingsFolder, withIntermediateDirectories: true, attributes: nil)
                    print("Created default recordings folder: \(recordingsFolder.path)")
                } catch {
                    print("Failed to create recordings folder: \(error)")
                }
            }

            print("Using default recordings path: \(recordingsFolder.path)")
            return recordingsFolder.path
        }

        // Fallback
        return NSHomeDirectory() + "/Documents/Recordings"
    }

    func updateRecordingsFolder(_ path: String) {
        recordingsFolderPath = path
    }

    func updateRecordingsFolderWithBookmark(_ path: String, bookmark: Data?) {
        recordingsFolderPath = path
        recordingsFolderBookmark = bookmark
    }

    func saveBookmark(for url: URL) -> Data? {
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            recordingsFolderBookmark = bookmarkData
            recordingsFolderPath = url.path
            print("Successfully created security-scoped bookmark for: \(url.path)")
            return bookmarkData
        } catch {
            print("Failed to create bookmark: \(error)")
            return nil
        }
    }

    func resolveBookmark(_ bookmarkData: Data? = nil) -> URL? {
        let data = bookmarkData ?? recordingsFolderBookmark
        guard let data = data else {
            print("No bookmark data available")
            return nil
        }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                print("Bookmark is stale and needs to be recreated")
                // Clear the stale bookmark
                recordingsFolderBookmark = nil
                return nil
            }

            print("Successfully resolved bookmark for: \(url.path)")
            return url
        } catch {
            print("Failed to resolve bookmark: \(error)")
            return nil
        }
    }

    func startAccessingSecurityScopedFolder() -> (url: URL, needsStop: Bool)? {
        // First try to resolve the bookmark
        if let url = resolveBookmark() {
            let didStart = url.startAccessingSecurityScopedResource()
            if didStart {
                print("Started accessing security-scoped resource: \(url.path)")
                return (url, true)
            } else {
                print("Did not need to start security-scoped access (already have permission): \(url.path)")
                return (url, false)
            }
        }

        // Fall back to the path if we have it and it's in the container
        if !recordingsFolderPath.isEmpty {
            let url = URL(fileURLWithPath: recordingsFolderPath)
            if recordingsFolderPath.contains("/Library/Containers/") {
                // This is within our sandbox, no security scope needed
                return (url, false)
            }
        }

        return nil
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