import CoreMotion
import SwiftUI

private let motionManager = CMMotionManager()   // one shared manager for the app

// MARK: - Device motion (IMU)

/// Fused accelerometer + gyroscope attitude, shown as numbers and a bubble level.
struct DeviceMotionView: View {
    @StateObject private var model = DeviceMotionModel()

    var body: some View {
        VStack(spacing: 24) {
            BubbleLevel(roll: model.roll, pitch: model.pitch)
                .frame(height: 220)

            VStack(spacing: 10) {
                MetricRow(label: "Roll",  value: String(format: "% .1f°", model.roll * 180 / .pi))
                MetricRow(label: "Pitch", value: String(format: "% .1f°", model.pitch * 180 / .pi))
                MetricRow(label: "Yaw",   value: String(format: "% .1f°", model.yaw * 180 / .pi))
                Divider()
                MetricRow(label: "Accel (g)", value: model.accel)
                MetricRow(label: "Rotation (rad/s)", value: model.rotation)
            }
            .padding()
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
            Spacer()
        }
        .padding()
        .navigationTitle("Device Motion")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}

private struct BubbleLevel: View {
    let roll: Double
    let pitch: Double
    var body: some View {
        GeometryReader { geo in
            let r = min(geo.size.width, geo.size.height) / 2
            let dx = CGFloat(max(min(roll / (.pi / 4), 1), -1)) * (r - 24)
            let dy = CGFloat(max(min(pitch / (.pi / 4), 1), -1)) * (r - 24)
            ZStack {
                Circle().stroke(.secondary, lineWidth: 2)
                Circle().stroke(.quaternary, lineWidth: 1).frame(width: r, height: r)
                Circle().fill(.mint)
                    .frame(width: 36, height: 36)
                    .offset(x: dx, y: dy)
                    .animation(.interactiveSpring, value: dx)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

final class DeviceMotionModel: ObservableObject {
    @Published var roll = 0.0
    @Published var pitch = 0.0
    @Published var yaw = 0.0
    @Published var accel = "—"
    @Published var rotation = "—"

    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let m = motion else { return }
            self.roll = m.attitude.roll
            self.pitch = m.attitude.pitch
            self.yaw = m.attitude.yaw
            self.accel = String(format: "%.2f, %.2f, %.2f",
                                m.userAcceleration.x, m.userAcceleration.y, m.userAcceleration.z)
            self.rotation = String(format: "%.2f, %.2f, %.2f",
                                   m.rotationRate.x, m.rotationRate.y, m.rotationRate.z)
        }
    }

    func stop() { motionManager.stopDeviceMotionUpdates() }
}

// MARK: - Barometer

/// Relative altitude and air pressure from the barometer.
struct BarometerView: View {
    @StateObject private var model = BarometerModel()

    var body: some View {
        VStack(spacing: 24) {
            if model.available {
                VStack(spacing: 4) {
                    Text(String(format: "%+.2f m", model.relativeAltitude))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("relative altitude since opening").font(.footnote).foregroundStyle(.secondary)
                }
                MetricRow(label: "Pressure", value: String(format: "%.2f kPa", model.pressure))
                    .padding()
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
                Text("Walk up some stairs and watch the altitude climb.")
                    .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            } else {
                UnavailableView(icon: "barometer", title: "No barometer",
                                message: "This device doesn't expose a barometric pressure sensor.")
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Barometer")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}

final class BarometerModel: ObservableObject {
    @Published var relativeAltitude = 0.0
    @Published var pressure = 0.0
    @Published var available = CMAltimeter.isRelativeAltitudeAvailable()

    private let altimeter = CMAltimeter()

    func start() {
        guard available else { return }
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            self.relativeAltitude = data.relativeAltitude.doubleValue
            self.pressure = data.pressure.doubleValue   // kPa
        }
    }

    func stop() { altimeter.stopRelativeAltitudeUpdates() }
}

// MARK: - Activity & pedometer

/// Motion-activity classification (walking / running / cycling / driving) and a
/// live step count.
struct ActivityView: View {
    @StateObject private var model = ActivityModel()

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: model.activityIcon).font(.system(size: 64)).foregroundStyle(.red)
                Text(model.activityLabel).font(.title.bold())
                Text("confidence: \(model.confidence)").font(.footnote).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity).padding()
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))

            VStack(spacing: 10) {
                MetricRow(label: "Steps (since opening)", value: "\(model.steps)")
                MetricRow(label: "Distance", value: String(format: "%.0f m", model.distance))
            }
            .padding()
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))

            if let status = model.status {
                Text(status).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Activity & Steps")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}

final class ActivityModel: ObservableObject {
    @Published var activityLabel = "Detecting…"
    @Published var activityIcon = "questionmark"
    @Published var confidence = "—"
    @Published var steps = 0
    @Published var distance = 0.0
    @Published var status: String?

    private let activityManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()

    func start() {
        if CMMotionActivityManager.isActivityAvailable() {
            activityManager.startActivityUpdates(to: .main) { [weak self] activity in
                guard let self, let a = activity else { return }
                let (label, icon) = Self.describe(a)
                self.activityLabel = label
                self.activityIcon = icon
                switch a.confidence {
                case .low: self.confidence = "low"
                case .medium: self.confidence = "medium"
                case .high: self.confidence = "high"
                @unknown default: self.confidence = "—"
                }
            }
        } else {
            status = "Motion activity isn't available on this device."
        }

        if CMPedometer.isStepCountingAvailable() {
            pedometer.startUpdates(from: Date()) { [weak self] data, _ in
                guard let self, let data else { return }
                Task { @MainActor in
                    self.steps = data.numberOfSteps.intValue
                    self.distance = data.distance?.doubleValue ?? 0
                }
            }
        }
    }

    func stop() {
        activityManager.stopActivityUpdates()
        pedometer.stopUpdates()
    }

    private static func describe(_ a: CMMotionActivity) -> (String, String) {
        if a.stationary { return ("Stationary", "figure.stand") }
        if a.walking { return ("Walking", "figure.walk") }
        if a.running { return ("Running", "figure.run") }
        if a.cycling { return ("Cycling", "bicycle") }
        if a.automotive { return ("Driving", "car.fill") }
        return ("Unknown", "questionmark")
    }
}
