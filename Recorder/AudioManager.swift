import AVFoundation
import CoreAudio
import Combine

class AudioManager: ObservableObject {
    @Published var inputDevices: [AudioDevice] = []
    @Published var outputDevices: [AudioDevice] = []
    @Published var selectedInputDevice: AudioDevice?
    @Published var selectedOutputDevice: AudioDevice?

    struct AudioDevice: Identifiable, Hashable {
        let id: AudioDeviceID
        let name: String
        let uid: String

        static func == (lhs: AudioDevice, rhs: AudioDevice) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    init() {
        refreshDevices()
    }


    func refreshDevices() {
        inputDevices = getAudioDevices(isInput: true)
        outputDevices = getAudioDevices(isInput: false)

        if selectedInputDevice == nil || !inputDevices.contains(selectedInputDevice!) {
            selectedInputDevice = inputDevices.first
        }

        if selectedOutputDevice == nil || !outputDevices.contains(selectedOutputDevice!) {
            selectedOutputDevice = getDefaultOutputDevice() ?? outputDevices.first
        }
    }

    private func getAudioDevices(isInput: Bool) -> [AudioDevice] {
        var devices: [AudioDevice] = []

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == noErr else { return devices }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var audioDevices = [AudioDeviceID](repeating: 0, count: deviceCount)

        let result = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &audioDevices
        )

        guard result == noErr else { return devices }

        for deviceID in audioDevices {
            if let device = getDeviceInfo(deviceID: deviceID, isInput: isInput) {
                devices.append(device)
            }
        }

        return devices
    }

    private func getDeviceInfo(deviceID: AudioDeviceID, isInput: Bool) -> AudioDevice? {
        let scope = isInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput

        var streamConfigAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )

        var streamConfigSize: UInt32 = 0
        AudioObjectGetPropertyDataSize(deviceID, &streamConfigAddress, 0, nil, &streamConfigSize)

        let streamCount = Int(streamConfigSize) - MemoryLayout<UInt32>.size
        guard streamCount > 0 else { return nil }

        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var name: CFString = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)
        let nameResult = AudioObjectGetPropertyData(
            deviceID,
            &nameAddress,
            0,
            nil,
            &nameSize,
            &name
        )

        guard nameResult == noErr else { return nil }

        var uidAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var uid: CFString = "" as CFString
        var uidSize = UInt32(MemoryLayout<CFString>.size)
        AudioObjectGetPropertyData(
            deviceID,
            &uidAddress,
            0,
            nil,
            &uidSize,
            &uid
        )

        return AudioDevice(
            id: deviceID,
            name: name as String,
            uid: uid as String
        )
    }

    private func getDefaultOutputDevice() -> AudioDevice? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID: AudioDeviceID = 0
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let result = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceID
        )

        guard result == noErr else { return nil }

        return outputDevices.first { $0.id == deviceID }
    }

    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        // Check current authorization status first
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            // Only request if not determined
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

}