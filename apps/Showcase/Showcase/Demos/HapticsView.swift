import CoreHaptics
import SwiftUI

/// Plays custom Taptic Engine patterns built from transient and continuous
/// haptic events with intensity / sharpness envelopes.
struct HapticsView: View {
    @StateObject private var model = HapticsModel()

    var body: some View {
        Group {
            if model.supported {
                VStack(spacing: 16) {
                    Text("Tap a pattern to feel it.")
                        .foregroundStyle(.secondary)
                    patternButton("Single tap", "hand.tap.fill") { model.playTap() }
                    patternButton("Double tap", "hand.tap") { model.playDoubleTap() }
                    patternButton("Rising buzz", "waveform.path.ecg") { model.playRising() }
                    patternButton("Heartbeat", "heart.fill") { model.playHeartbeat() }
                    Spacer()
                }
                .padding()
            } else {
                UnavailableView(icon: "iphone.slash", title: "No haptics",
                                message: "This device doesn't support Core Haptics.")
            }
        }
        .navigationTitle("Core Haptics")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func patternButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.title3).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.pink)
    }
}

final class HapticsModel: ObservableObject {
    let supported = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var engine: CHHapticEngine?

    init() {
        guard supported else { return }
        engine = try? CHHapticEngine()
        engine?.resetHandler = { [weak self] in try? self?.engine?.start() }
        try? engine?.start()
    }

    private func play(_ events: [CHHapticEvent]) {
        guard let engine else { return }
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try engine.start()
            try player.start(atTime: 0)
        } catch {
            // A failed playback shouldn't crash the demo.
        }
    }

    private func transient(at t: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        ], relativeTime: t)
    }

    func playTap() {
        play([transient(at: 0, intensity: 1, sharpness: 0.5)])
    }

    func playDoubleTap() {
        play([transient(at: 0, intensity: 1, sharpness: 0.7),
              transient(at: 0.12, intensity: 1, sharpness: 0.7)])
    }

    func playRising() {
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
        ], relativeTime: 0, duration: 1.0)
        play([event])
    }

    func playHeartbeat() {
        play([transient(at: 0.0, intensity: 1.0, sharpness: 0.3),
              transient(at: 0.18, intensity: 0.7, sharpness: 0.3),
              transient(at: 0.9, intensity: 1.0, sharpness: 0.3),
              transient(at: 1.08, intensity: 0.7, sharpness: 0.3)])
    }
}
