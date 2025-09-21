import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Recorder")
                .font(.headline)
                .padding(.top)

            Spacer()

            Text("Empty Container")
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(width: 300, height: 400)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}