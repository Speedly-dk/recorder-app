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
        // Delay initial refresh to avoid initialization issues
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.refreshDevices()
        }
    }


    func refreshDevices() {
        inputDevices = getAudioDevices(isInput: true)
        outputDevices = getAudioDevices(isInput: false)

        if let device = selectedInputDevice {
            if !inputDevices.contains(device) {
                selectedInputDevice = inputDevices.first
            }
        } else {
            selectedInputDevice = inputDevices.first
        }

        if let device = selectedOutputDevice {
            if !outputDevices.contains(device) {
                selectedOutputDevice = getDefaultOutputDevice() ?? outputDevices.first
            }
        } else {
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

        // Check if device has channels for the specified scope
        guard hasChannelsForScope(deviceID: deviceID, scope: scope) else { return nil }

        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var name: CFString?
        var nameSize = UInt32(MemoryLayout<CFString?>.size)
        let nameResult = AudioObjectGetPropertyData(
            deviceID,
            &nameAddress,
            0,
            nil,
            &nameSize,
            &name
        )

        guard nameResult == noErr, let deviceName = name as String? else {
            return nil
        }

        var uidAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var uid: CFString?
        var uidSize = UInt32(MemoryLayout<CFString?>.size)
        let uidResult = AudioObjectGetPropertyData(
            deviceID,
            &uidAddress,
            0,
            nil,
            &uidSize,
            &uid
        )

        let deviceUID = (uid as String?) ?? ""

        return AudioDevice(
            id: deviceID,
            name: deviceName,
            uid: deviceUID
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

    private func hasChannelsForScope(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Bool {
        var streamConfigAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )

        // Get the size of stream configuration
        var streamConfigSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(deviceID, &streamConfigAddress, 0, nil, &streamConfigSize)

        guard status == noErr, streamConfigSize > 0 else { return false }

        // Allocate buffer for the entire AudioBufferList structure
        let audioBufferListPtr = malloc(Int(streamConfigSize))
        guard let audioBufferListPtr = audioBufferListPtr else { return false }
        defer { free(audioBufferListPtr) }

        // Get the actual stream configuration
        status = AudioObjectGetPropertyData(
            deviceID,
            &streamConfigAddress,
            0,
            nil,
            &streamConfigSize,
            audioBufferListPtr
        )

        guard status == noErr else { return false }

        // Cast to AudioBufferList and check for channels
        let bufferList = audioBufferListPtr.assumingMemoryBound(to: AudioBufferList.self).pointee

        // Simply check if the first buffer has channels
        // This is sufficient for most audio devices
        if bufferList.mNumberBuffers > 0 {
            return bufferList.mBuffers.mNumberChannels > 0
        }

        return false
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