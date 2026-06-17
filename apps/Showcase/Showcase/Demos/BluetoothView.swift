import CoreBluetooth
import SwiftUI

/// Scans for nearby Bluetooth Low Energy peripherals and lists them live with
/// signal strength (RSSI).
struct BluetoothView: View {
    @StateObject private var model = BluetoothModel()

    var body: some View {
        VStack(spacing: 0) {
            if model.state == .poweredOn {
                List(model.devices) { device in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(device.name).font(.body)
                            Text(device.id.uuidString).font(.caption2).foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        SignalBars(rssi: device.rssi)
                        Text("\(device.rssi)").font(.caption.monospacedDigit())
                            .frame(width: 36, alignment: .trailing)
                    }
                }
                .listStyle(.plain)
                .overlay {
                    if model.devices.isEmpty {
                        Text("Scanning for devices…").foregroundStyle(.secondary)
                    }
                }
            } else {
                UnavailableView(icon: "dot.radiowaves.left.and.right",
                                title: "Bluetooth \(model.stateDescription)",
                                message: "Turn Bluetooth on to scan for nearby BLE peripherals.")
            }
        }
        .navigationTitle("Bluetooth LE")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.startIfReady() }
        .onDisappear { model.stop() }
    }
}

private struct SignalBars: View {
    let rssi: Int
    var body: some View {
        let strength = max(0, min(4, (rssi + 100) / 12))   // ~ -100…-52 → 0…4
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < strength ? Color.blue : Color.secondary.opacity(0.3))
                    .frame(width: 4, height: 6 + CGFloat(i) * 4)
            }
        }
    }
}

struct BLEDevice: Identifiable {
    let id: UUID
    let name: String
    var rssi: Int
}

final class BluetoothModel: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published var devices: [BLEDevice] = []
    @Published var state: CBManagerState = .unknown

    private var central: CBCentralManager?

    func startIfReady() {
        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main)
        } else if state == .poweredOn {
            central?.scanForPeripherals(withServices: nil,
                                        options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        }
    }

    func stop() { central?.stopScan() }

    var stateDescription: String {
        switch state {
        case .poweredOff: return "off"
        case .unauthorized: return "unauthorized"
        case .unsupported: return "unsupported"
        default: return "unavailable"
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        state = central.state
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: nil,
                                       options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name
            ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? "Unknown device"
        let device = BLEDevice(id: peripheral.identifier, name: name, rssi: RSSI.intValue)
        if let idx = devices.firstIndex(where: { $0.id == device.id }) {
            devices[idx].rssi = device.rssi
        } else {
            devices.append(device)
        }
    }
}
