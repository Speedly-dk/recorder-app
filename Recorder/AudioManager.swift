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
        let nameResult = withUnsafeMutablePointer(to: &name) { namePtr in
            AudioObjectGetPropertyData(
                deviceID,
                &nameAddress,
                0,
                nil,
                &nameSize,
                UnsafeMutableRawPointer(namePtr)
            )
        }

        guard nameResult == noErr else { return nil }

        var uidAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var uid: CFString?
        var uidSize = UInt32(MemoryLayout<CFString?>.size)
        withUnsafeMutablePointer(to: &uid) { uidPtr in
            AudioObjectGetPropertyData(
                deviceID,
                &uidAddress,
                0,
                nil,
                &uidSize,
                UnsafeMutableRawPointer(uidPtr)
            )
        }

        return AudioDevice(
            id: deviceID,
            name: (name as String?) ?? "Unknown",
            uid: (uid as String?) ?? ""
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

        // Allocate buffer for stream configuration
        let bufferCount = Int(streamConfigSize) / MemoryLayout<AudioBuffer>.size
        let audioBufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        defer { audioBufferList.deallocate() }

        // Initialize the buffer list
        audioBufferList.pointee.mNumberBuffers = UInt32(bufferCount)

        // Get the actual stream configuration
        status = AudioObjectGetPropertyData(
            deviceID,
            &streamConfigAddress,
            0,
            nil,
            &streamConfigSize,
            audioBufferList
        )

        guard status == noErr else { return false }

        // Count total channels across all buffers
        var totalChannels: UInt32 = 0
        let bufferList = audioBufferList.pointee

        // Access the mBuffers array properly
        withUnsafePointer(to: bufferList.mBuffers) { buffersPtr in
            let buffersBaseAddress = UnsafeRawPointer(buffersPtr).assumingMemoryBound(to: AudioBuffer.self)
            let buffers = UnsafeBufferPointer(
                start: buffersBaseAddress,
                count: Int(bufferList.mNumberBuffers)
            )

            for buffer in buffers {
                totalChannels += buffer.mNumberChannels
            }
        }

        return totalChannels > 0
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