import SwiftUI

struct ContentView: View {
    @State private var taps = 0

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
            Text("Hello, TestFlight!")
                .font(.largeTitle.bold())
            Text("Shipped from a monorepo subdirectory\nby GitHub Actions — no Mac required.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Tapped \(taps) time\(taps == 1 ? "" : "s")") {
                taps += 1
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
