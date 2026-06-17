import CoreNFC
import SwiftUI

/// Reads NDEF messages from nearby NFC tags and shows their records.
struct NFCView: View {
    @StateObject private var model = NFCModel()

    var body: some View {
        VStack(spacing: 16) {
            if NFCNDEFReaderSession.readingAvailable {
                if model.records.isEmpty {
                    ContentUnavailableViewCompat(icon: "wave.3.right",
                                                 title: "No tag scanned yet",
                                                 message: "Tap “Scan” and hold an NFC tag (or NFC sticker, transit card, passport) to the top of the phone.")
                } else {
                    List(model.records) { record in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.type).font(.caption).foregroundStyle(.secondary)
                            Text(record.payload).font(.body)
                        }
                    }
                    .listStyle(.plain)
                }

                if let status = model.status {
                    Text(status).font(.footnote).foregroundStyle(.secondary)
                }

                Button {
                    model.beginScan()
                } label: {
                    Label("Scan a tag", systemImage: "wave.3.right").font(.title2).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.horizontal)
            } else {
                UnavailableView(icon: "wave.3.right.circle",
                                title: "NFC unavailable",
                                message: "NFC tag reading needs a capable iPhone, the NFC entitlement (a signed TestFlight build), and isn't offered on sideloaded/free-provisioned builds.")
            }
        }
        .padding(.vertical)
        .navigationTitle("NFC")
        .navigationBarTitleDisplayMode(.inline)
    }
}

final class NFCModel: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {
    struct Record: Identifiable { let id = UUID(); let type: String; let payload: String }

    @Published var records: [Record] = []
    @Published var status: String?
    private var session: NFCNDEFReaderSession?

    func beginScan() {
        guard NFCNDEFReaderSession.readingAvailable else { return }
        records = []
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = "Hold your iPhone near an NFC tag."
        session?.begin()
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        let parsed = messages.flatMap { $0.records }.map { record -> Record in
            let type = String(data: record.type, encoding: .utf8) ?? "tag"
            let payload = Self.readablePayload(record)
            return Record(type: Self.describeType(record, fallback: type), payload: payload)
        }
        DispatchQueue.main.async {
            self.records = parsed
            self.status = "Read \(parsed.count) record(s)."
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async { self.status = error.localizedDescription }
    }

    private static func describeType(_ record: NFCNDEFPayload, fallback: String) -> String {
        switch record.typeNameFormat {
        case .nfcWellKnown:
            let t = String(data: record.type, encoding: .utf8) ?? ""
            if t == "U" { return "URI" }
            if t == "T" { return "Text" }
            return "Well-known: \(t)"
        case .absoluteURI: return "Absolute URI"
        case .media: return "Media: \(String(data: record.type, encoding: .utf8) ?? "")"
        case .nfcExternal: return "External"
        case .empty: return "Empty"
        default: return fallback.isEmpty ? "Unknown" : fallback
        }
    }

    private static func readablePayload(_ record: NFCNDEFPayload) -> String {
        // URI / text records have a 1-byte prefix; `wellKnownTypeURIPayload`
        // and `wellKnownTypeTextPayload` decode them for us.
        if let url = record.wellKnownTypeURIPayload() { return url.absoluteString }
        let (text, _) = record.wellKnownTypeTextPayload()
        if let text { return text }
        return String(data: record.payload, encoding: .utf8)
            ?? record.payload.map { String(format: "%02x", $0) }.joined()
    }
}
