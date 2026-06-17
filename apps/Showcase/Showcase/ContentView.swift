import SwiftUI

/// Home menu. One row per capability demo, grouped by theme.
struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Camera & Depth") {
                    DemoRow(icon: "faceid", tint: .pink, title: "TrueDepth Face",
                            subtitle: "52 live blendshapes from the front IR camera") {
                        TrueDepthFaceView()
                    }
                    DemoRow(icon: "hand.raised.fingers.spread", tint: .green, title: "Hand Pose",
                            subtitle: "21 finger landmarks via Vision") {
                        HandPoseView()
                    }
                    DemoRow(icon: "figure.walk", tint: .teal, title: "Body Pose",
                            subtitle: "Live skeleton overlay via Vision") {
                        BodyPoseView()
                    }
                    DemoRow(icon: "tag", tint: .orange, title: "Image Classification",
                            subtitle: "Vision's built-in object taxonomy") {
                        ImageClassificationView()
                    }
                    DemoRow(icon: "text.viewfinder", tint: .blue, title: "Text Recognition",
                            subtitle: "Live OCR via Vision") {
                        TextRecognitionView()
                    }
                }

                Section("Audio") {
                    DemoRow(icon: "waveform.badge.mic", tint: .purple, title: "Speech Recognition",
                            subtitle: "On-device live transcription") {
                        SpeechRecognitionView()
                    }
                    DemoRow(icon: "ear", tint: .indigo, title: "Sound Classification",
                            subtitle: "Identify ~300 everyday sounds") {
                        SoundClassificationView()
                    }
                }

                Section("Motion & Environment") {
                    DemoRow(icon: "gyroscope", tint: .mint, title: "Device Motion",
                            subtitle: "Accelerometer + gyroscope attitude") {
                        DeviceMotionView()
                    }
                    DemoRow(icon: "barometer", tint: .cyan, title: "Barometer",
                            subtitle: "Relative altitude & air pressure") {
                        BarometerView()
                    }
                    DemoRow(icon: "figure.run", tint: .red, title: "Activity & Steps",
                            subtitle: "Motion classification + pedometer") {
                        ActivityView()
                    }
                }

                Section("Connectivity") {
                    DemoRow(icon: "dot.radiowaves.left.and.right", tint: .blue, title: "Bluetooth LE",
                            subtitle: "Scan for nearby BLE peripherals") {
                        BluetoothView()
                    }
                    DemoRow(icon: "location.north.line", tint: .orange, title: "Nearby Interaction",
                            subtitle: "Ultra Wideband (UWB) capabilities") {
                        NearbyInteractionView()
                    }
                    DemoRow(icon: "wave.3.right", tint: .green, title: "NFC",
                            subtitle: "Read nearby NFC tags") {
                        NFCView()
                    }
                }

                Section("System & ML") {
                    DemoRow(icon: "iphone.radiowaves.left.and.right", tint: .pink, title: "Core Haptics",
                            subtitle: "Custom Taptic Engine patterns") {
                        HapticsView()
                    }
                    DemoRow(icon: "text.book.closed", tint: .brown, title: "Natural Language",
                            subtitle: "Language ID & sentiment, on-device") {
                        NaturalLanguageView()
                    }
                    DemoRow(icon: "lock.shield", tint: .gray, title: "Face ID / Touch ID",
                            subtitle: "Local biometric authentication") {
                        LocalAuthView()
                    }
                }
            }
            .navigationTitle("Capabilities")
            .listStyle(.insetGrouped)
        }
    }
}

/// A navigable list row with an icon tile, title and subtitle.
struct DemoRow<Destination: View>: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(tint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

#Preview {
    ContentView()
}
