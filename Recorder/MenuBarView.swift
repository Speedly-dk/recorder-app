import SwiftUI

struct MenuBarView: View {
    let isRecording: Bool
    let recordingDuration: String

    var body: some View {
        ZStack {
            if isRecording {
                Rectangle()
                    .cornerRadius(3)
                    .opacity(0.1)
            }
            HStack(spacing: 2.5) {
                if isRecording {
                    Image(systemName: "record.circle")
                        .foregroundStyle(.red)
                    Text(recordingDuration)
                        .offset(y: -0.5)
                        .monospacedDigit()
                } else {
                    Image(systemName: "record.circle.fill")
                        .foregroundColor(.primary)
                }
            }
        }
    }
}

#Preview {
    VStack {
        MenuBarView(isRecording: false, recordingDuration: "00:00")
        MenuBarView(isRecording: true, recordingDuration: "01:23")
    }
}