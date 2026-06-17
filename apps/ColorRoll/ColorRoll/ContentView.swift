import SwiftUI

struct ContentView: View {
    private let palette: [(name: String, color: Color)] = [
        ("Teal", Color(red: 0.10, green: 0.74, blue: 0.61)),
        ("Indigo", Color(red: 0.29, green: 0.31, blue: 0.78)),
        ("Coral", Color(red: 0.95, green: 0.42, blue: 0.38)),
        ("Amber", Color(red: 0.98, green: 0.74, blue: 0.18)),
        ("Plum", Color(red: 0.56, green: 0.27, blue: 0.52))
    ]
    @State private var index = 0

    var body: some View {
        ZStack {
            palette[index].color
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Text(palette[index].name)
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("Tap anywhere to roll the color")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.25)) {
                index = (index + 1) % palette.count
            }
        }
    }
}

#Preview {
    ContentView()
}
