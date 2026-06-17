import NearbyInteraction
import SwiftUI

/// Nearby Interaction reports what the U1/U2 Ultra Wideband chip can do. Live
/// ranging needs a second UWB device (another iPhone, a U1 accessory, or a
/// custom anchor) to exchange discovery tokens with, so this demo focuses on
/// capability reporting plus an explanation of how a session works.
struct NearbyInteractionView: View {
    private let caps = NICapabilities()

    var body: some View {
        Form {
            Section("This device") {
                CapabilityRow(label: "Nearby Interaction", on: caps.supported)
                CapabilityRow(label: "Precise distance (UWB)", on: caps.preciseDistance)
                CapabilityRow(label: "Direction / angle-of-arrival", on: caps.direction)
                CapabilityRow(label: "Camera assistance", on: caps.cameraAssistance)
                CapabilityRow(label: "Extended distance", on: caps.extendedDistance)
            }

            Section("How a session works") {
                Text("""
                1. Each device creates an `NISession` and shares its \
                `discoveryToken` over a side channel (e.g. Bluetooth or the \
                local network).
                2. You configure a peer session with the other device's token \
                and call `session.run(...)`.
                3. The delegate then streams `distance` (metres) and, on \
                supported hardware, `direction` (a 3-D vector) several times a \
                second.
                """)
                .font(.callout)
            }

            Section {
                Text("""
                This is the same UWB ranging used by AirTag “Precision Finding” \
                — and the iPhone side of the in-zone room-positioning project, \
                which ranges against custom DWM3001 anchors.
                """)
                .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Nearby Interaction")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CapabilityRow: View {
    let label: String
    let on: Bool
    var body: some View {
        HStack {
            Image(systemName: on ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(on ? .green : .secondary)
            Text(label)
        }
    }
}

/// Reads the UWB capabilities of the current device.
private struct NICapabilities {
    let supported: Bool
    let preciseDistance: Bool
    let direction: Bool
    let cameraAssistance: Bool
    let extendedDistance: Bool

    init() {
        guard NISession.isSupported else {
            supported = false; preciseDistance = false; direction = false
            cameraAssistance = false; extendedDistance = false
            return
        }
        supported = true
        let caps = NISession.deviceCapabilities
        preciseDistance = caps.supportsPreciseDistanceMeasurement
        direction = caps.supportsDirectionMeasurement
        cameraAssistance = caps.supportsCameraAssistance
        extendedDistance = caps.supportsExtendedDistanceMeasurement
    }
}
