import Foundation
import ScreenCaptureKit
import AVFoundation
import Combine

@MainActor
class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var errorMessage: String?

    private var stream: SCStream?
    private var streamOutput: StreamOutput?
    private var assetWriter: AVAssetWriter?
    private var audioInput: AVAssetWriterInput?
    private var microphoneInput: AVAssetWriterInput?

    private var durationTimer: Timer?
    private var recordingURL: URL?

    // Track first sample time for proper timestamp alignment
    private var firstAudioSampleTime: CMTime?
    private var firstMicrophoneSampleTime: CMTime?
    private var sessionStartTime: CMTime?

    // Audio settings
    private let audioSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: 48000.0,
        AVNumberOfChannelsKey: 2,
        AVEncoderBitRateKey: 128000
    ]

    override init() {
        super.init()
    }

    static func getRecordingsFolderURL() -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent("Recordings")
    }

    func startRecording(audioManager: AudioManager, settings: RecorderSettings) async throws {
        guard !isRecording else { return }

        // Request screen recording permission first
        guard await requestScreenRecordingPermission() else {
            throw RecordingError.permissionDenied
        }

        // Setup recording file
        let fileName = generateFileName()

        // Always use the app's container Documents/Recordings folder
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folderURL = documentsURL.appendingPathComponent("Recordings")

        // Create the Recordings folder if it doesn't exist
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            print("Created recordings folder: \(folderURL.path)")
        }
        print("Using app container folder: \(folderURL.path)")

        print("Recording folder exists: \(FileManager.default.fileExists(atPath: folderURL.path))")

        recordingURL = folderURL.appendingPathComponent(fileName)

        guard let recordingURL = recordingURL else {
            throw RecordingError.invalidURL
        }

        print("Recording to file: \(recordingURL.path)")

        // Setup AVAssetWriter
        try setupAssetWriter(url: recordingURL)

        // Setup ScreenCaptureKit stream with selected input device
        let inputDeviceUID = audioManager.selectedInputDevice?.uid
        try await setupStream(inputDeviceUID: inputDeviceUID)

        // Start recording
        do {
            print("Starting stream capture...")
            try await stream?.startCapture()
            print("Stream capture started successfully")
        } catch {
            print("Failed to start stream capture: \(error)")
            print("Error details: \(error.localizedDescription)")

            // Clean up on failure
            assetWriter?.cancelWriting()
            assetWriter = nil
            audioInput = nil
            stream = nil
            streamOutput = nil

            throw RecordingError.writerFailed
        }

        isRecording = true
        startDurationTimer()

        // Reset timestamp tracking
        firstAudioSampleTime = nil
        firstMicrophoneSampleTime = nil
        sessionStartTime = nil
    }

    func stopRecording() async {
        guard isRecording else { return }

        // Stop the stream
        do {
            try await stream?.stopCapture()
        } catch {
            print("Error stopping capture: \(error)")
        }

        // Stop duration timer on main thread
        await MainActor.run {
            durationTimer?.invalidate()
            durationTimer = nil
        }

        // Finish writing
        await finishWriting()

        // Clean up
        stream = nil
        streamOutput = nil
        assetWriter = nil
        audioInput = nil
        microphoneInput = nil

        isRecording = false
        recordingDuration = 0

        // Reset timestamps
        firstAudioSampleTime = nil
        firstMicrophoneSampleTime = nil
        sessionStartTime = nil
    }

    private func setupAssetWriter(url: URL) throws {
        // Note: Directory should already exist since we either selected it via NSOpenPanel
        // or are using the container directory
        let folderURL = url.deletingLastPathComponent()
        print("Checking directory: \(folderURL.path)")

        if !FileManager.default.fileExists(atPath: folderURL.path) {
            print("Warning: Directory doesn't exist, will try to create: \(folderURL.path)")
            do {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
                print("Created directory: \(folderURL.path)")
            } catch {
                print("Failed to create directory: \(error)")
                throw RecordingError.invalidURL
            }
        } else {
            print("Directory exists: \(folderURL.path)")
        }

        // Remove existing file if needed
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
            print("Removed existing file")
        }

        // Create asset writer
        do {
            print("Creating AVAssetWriter with URL: \(url)")
            print("File type: .m4a")
            assetWriter = try AVAssetWriter(outputURL: url, fileType: .m4a)
            print("AVAssetWriter created successfully")
        } catch {
            print("Failed to create AVAssetWriter: \(error)")
            print("Error details: \(error.localizedDescription)")
            throw RecordingError.writerFailed
        }

        // Setup audio input for system audio
        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput?.expectsMediaDataInRealTime = true

        // Add audio input to writer
        if let audioInput = audioInput {
            if assetWriter?.canAdd(audioInput) == true {
                assetWriter?.add(audioInput)
            } else {
                print("Cannot add audio input to asset writer")
                throw RecordingError.writerFailed
            }
        }

        // Setup separate input for microphone audio if available
        if #available(macOS 15.0, *) {
            microphoneInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            microphoneInput?.expectsMediaDataInRealTime = true

            if let microphoneInput = microphoneInput {
                if assetWriter?.canAdd(microphoneInput) == true {
                    assetWriter?.add(microphoneInput)
                    print("Added microphone input to asset writer")
                } else {
                    print("Cannot add microphone input to asset writer")
                    self.microphoneInput = nil
                }
            }
        }

        // Start writing
        guard assetWriter?.startWriting() == true else {
            print("Failed to start asset writer. Status: \(String(describing: assetWriter?.status.rawValue)), Error: \(String(describing: assetWriter?.error))")
            throw RecordingError.writerFailed
        }

        print("Successfully initialized asset writer for URL: \(url)")
    }

    private func setupStream(inputDeviceUID: String? = nil) async throws {
        // Create content filter for audio only
        let filter = try await createContentFilter()

        // Configure stream for audio
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.sampleRate = 48000
        configuration.channelCount = 2

        // Enable microphone capture on macOS 15.0+
        if #available(macOS 15.0, *) {
            configuration.captureMicrophone = true
            configuration.microphoneCaptureDeviceID = inputDeviceUID
            print("Microphone capture enabled with device UID: \(inputDeviceUID ?? "default")")
        }

        // Set reasonable video dimensions even though we won't use video
        // ScreenCaptureKit requires valid dimensions
        configuration.width = 1920
        configuration.height = 1080
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        configuration.scalesToFit = false

        // Disable actual video encoding to save resources
        configuration.showsCursor = false
        configuration.backgroundColor = .clear

        // Create stream
        stream = SCStream(filter: filter, configuration: configuration, delegate: nil)

        guard stream != nil else {
            print("Failed to create SCStream")
            throw RecordingError.writerFailed
        }

        print("SCStream created successfully")

        // Setup output handler
        streamOutput = StreamOutput(recorder: self)

        // Add audio output
        do {
            try stream?.addStreamOutput(streamOutput!, type: .audio, sampleHandlerQueue: DispatchQueue(label: "audio.capture.queue"))
            print("Added audio stream output")
        } catch {
            print("Failed to add audio output: \(error)")
            throw RecordingError.writerFailed
        }

        // Add microphone output if available
        if #available(macOS 15.0, *) {
            do {
                try stream?.addStreamOutput(streamOutput!, type: .microphone, sampleHandlerQueue: DispatchQueue(label: "mic.capture.queue"))
                print("Added microphone stream output")
            } catch {
                // Microphone may not be available, continue with system audio only
                print("Microphone capture not available: \(error)")
            }
        }

        // Note: We're NOT adding a video output handler, so video frame errors are expected and can be ignored
    }

    private func createContentFilter() async throws -> SCContentFilter {
        // Get shareable content
        print("Getting shareable content...")
        let content = try await SCShareableContent.current

        print("Available displays: \(content.displays.count)")
        print("Available windows: \(content.windows.count)")
        print("Available applications: \(content.applications.count)")

        // For audio-only recording, we'll capture the entire screen but only process audio
        guard let display = content.displays.first else {
            print("No displays available")
            throw RecordingError.noDisplay
        }

        print("Using display: \(display.displayID), size: \(display.width)x\(display.height)")

        // Create filter for the display with no app exclusions (captures all system audio)
        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])

        print("Content filter created successfully")
        return filter
    }

    private func requestScreenRecordingPermission() async -> Bool {
        // Check if we already have permission
        if CGPreflightScreenCaptureAccess() {
            return true
        }

        // Request permission
        return CGRequestScreenCaptureAccess()
    }

    private func generateFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = formatter.string(from: Date())
        return "Recording_\(dateString).m4a"
    }

    @MainActor
    private func startDurationTimer() {
        let startTime = Date()

        // Run timer on main thread's RunLoop
        DispatchQueue.main.async { [weak self] in
            self?.durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.recordingDuration = Date().timeIntervalSince(startTime)
                }
            }

            // Ensure timer is added to common run loop modes to work while UI is being interacted with
            if let timer = self?.durationTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }

    private func finishWriting() async {
        // Mark inputs as finished
        audioInput?.markAsFinished()
        microphoneInput?.markAsFinished()

        // Finish writing
        await assetWriter?.finishWriting()
    }

    // MARK: - Stream Output Handler

    class StreamOutput: NSObject, SCStreamOutput {
        weak var recorder: AudioRecorder?

        init(recorder: AudioRecorder) {
            self.recorder = recorder
            super.init()
        }

        func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
            guard let recorder = recorder else { return }

            // Ensure we're still recording and buffer is ready
            guard recorder.isRecording,
                  CMSampleBufferDataIsReady(sampleBuffer) else { return }

            switch type {
            case .audio:
                recorder.handleAudioSample(sampleBuffer)
            case .microphone:
                if #available(macOS 15.0, *) {
                    recorder.handleMicrophoneSample(sampleBuffer)
                }
            case .screen:
                // We're not recording video, ignore screen samples
                break
            @unknown default:
                break
            }
        }
    }

    private func handleAudioSample(_ sampleBuffer: CMSampleBuffer) {
        guard let audioInput = audioInput,
              audioInput.isReadyForMoreMediaData else { return }

        // Log first few samples for debugging
        if firstAudioSampleTime == nil {
            print("Received first audio sample")
            firstAudioSampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

            // Start session if this is the first sample
            if sessionStartTime == nil {
                sessionStartTime = firstAudioSampleTime
                assetWriter?.startSession(atSourceTime: sessionStartTime!)
                print("Started AVAssetWriter session at time: \(sessionStartTime!.seconds)")
            }
        }

        // Adjust timestamps if needed
        let adjustedBuffer = adjustTimestamp(for: sampleBuffer, isFirstSample: false)

        // Append the sample
        if !audioInput.append(adjustedBuffer) {
            print("Warning: Failed to append audio sample")
        }
    }

    private func handleMicrophoneSample(_ sampleBuffer: CMSampleBuffer) {
        // Try to use separate microphone input first for better quality
        if let microphoneInput = microphoneInput,
           microphoneInput.isReadyForMoreMediaData {

            // Log first microphone sample
            if firstMicrophoneSampleTime == nil {
                print("Received first microphone sample")
                firstMicrophoneSampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

                // Start session if this is the first sample
                if sessionStartTime == nil {
                    sessionStartTime = firstMicrophoneSampleTime
                    assetWriter?.startSession(atSourceTime: sessionStartTime!)
                    print("Started AVAssetWriter session at time: \(sessionStartTime!.seconds)")
                }
            }

            // Adjust timestamps and append to microphone input
            let adjustedBuffer = adjustTimestamp(for: sampleBuffer, isFirstSample: false)

            if !microphoneInput.append(adjustedBuffer) {
                print("Warning: Failed to append microphone sample to separate input")
            }
        } else if let audioInput = audioInput,
                  audioInput.isReadyForMoreMediaData {
            // Fallback: mix with system audio if no separate input available
            print("Mixing microphone with system audio (fallback)")

            let adjustedBuffer = adjustTimestamp(for: sampleBuffer, isFirstSample: firstMicrophoneSampleTime == nil)

            if firstMicrophoneSampleTime == nil {
                firstMicrophoneSampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

                if sessionStartTime == nil {
                    sessionStartTime = firstMicrophoneSampleTime
                    assetWriter?.startSession(atSourceTime: sessionStartTime!)
                }
            }

            audioInput.append(adjustedBuffer)
        }
    }

    private func adjustTimestamp(for sampleBuffer: CMSampleBuffer, isFirstSample: Bool) -> CMSampleBuffer {
        // For the first sample, we might need to adjust the timestamp to start from zero
        // This ensures proper synchronization between audio streams

        if isFirstSample || sessionStartTime == nil {
            return sampleBuffer
        }

        // Calculate relative timestamp
        let currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let relativeTime = CMTimeSubtract(currentTime, sessionStartTime!)

        // Create new timing info
        var timingInfo = CMSampleTimingInfo()
        timingInfo.presentationTimeStamp = relativeTime
        timingInfo.decodeTimeStamp = .invalid
        timingInfo.duration = CMSampleBufferGetDuration(sampleBuffer)

        // Create adjusted buffer
        var adjustedBuffer: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: sampleBuffer,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleBufferOut: &adjustedBuffer
        )

        return adjustedBuffer ?? sampleBuffer
    }
}

// MARK: - Error Types

enum RecordingError: LocalizedError {
    case permissionDenied
    case invalidURL
    case writerFailed
    case noDisplay

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen recording permission is required. Please grant permission in System Settings > Privacy & Security > Screen Recording."
        case .invalidURL:
            return "Invalid recording folder. Please select a valid folder in settings."
        case .writerFailed:
            return "Failed to initialize audio writer."
        case .noDisplay:
            return "No display available for recording."
        }
    }
}