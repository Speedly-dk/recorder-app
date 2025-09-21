import SwiftUI
import Combine

class RecorderSettings: ObservableObject {
    @AppStorage("selectedInputDeviceUID") private var storedInputDeviceUID = ""
    @AppStorage("selectedOutputDeviceUID") private var storedOutputDeviceUID = ""
    @AppStorage("checkForUpdates") var checkForUpdates = true

    @Published var selectedInputDeviceUID: String = ""
    @Published var selectedOutputDeviceUID: String = ""

    init() {
        self.selectedInputDeviceUID = storedInputDeviceUID
        self.selectedOutputDeviceUID = storedOutputDeviceUID

        setupObservers()
    }

    private func setupObservers() {
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

    func updateInputDevice(_ uid: String) {
        selectedInputDeviceUID = uid
    }

    func updateOutputDevice(_ uid: String) {
        selectedOutputDeviceUID = uid
    }
}