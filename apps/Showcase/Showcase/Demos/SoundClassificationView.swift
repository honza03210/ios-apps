import AVFoundation
import SoundAnalysis
import SwiftUI

/// Identifies everyday sounds (dog bark, applause, typing, music…) from the mic
/// using Apple's built-in `SNClassifierIdentifier.version1` model (~300 classes).
struct SoundClassificationView: View {
    @StateObject private var model = SoundModel()

    var body: some View {
        VStack(spacing: 16) {
            if model.results.isEmpty {
                Text(model.isRunning ? "Listening…" : "Tap “Start” and make some noise.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(model.results, id: \.label) { item in
                    HStack {
                        Text(item.label.replacingOccurrences(of: "_", with: " ").capitalized)
                        Spacer()
                        ProgressView(value: Double(item.confidence))
                            .frame(width: 120)
                        Text("\(Int(item.confidence * 100))%").monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                .listStyle(.plain)
            }

            if let status = model.statusMessage {
                Text(status).font(.footnote).foregroundStyle(.secondary)
            }

            Button {
                model.isRunning ? model.stop() : model.start()
            } label: {
                Label(model.isRunning ? "Stop" : "Start",
                      systemImage: model.isRunning ? "stop.circle.fill" : "ear.fill")
                    .font(.title2).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(model.isRunning ? .red : .indigo)
            .padding(.horizontal)
        }
        .padding(.vertical)
        .navigationTitle("Sound Classification")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { model.stop() }
    }
}

final class SoundModel: ObservableObject {
    struct Result { let label: String; let confidence: Double }

    @Published var results: [Result] = []
    @Published var isRunning = false
    @Published var statusMessage: String?

    private let audioEngine = AVAudioEngine()
    private var analyzer: SNAudioStreamAnalyzer?
    private let analysisQueue = DispatchQueue(label: "showcase.sound.analysis")
    private var observer: SoundObserver?

    func start() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                guard granted else { self.statusMessage = "Microphone permission denied."; return }
                self.beginSession()
            }
        }
    }

    private func beginSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)

            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            let analyzer = SNAudioStreamAnalyzer(format: format)
            self.analyzer = analyzer

            let request = try SNClassifySoundRequest(classifierIdentifier: .version1)

            let observer = SoundObserver { [weak self] results in
                Task { @MainActor in self?.results = results }
            }
            self.observer = observer
            try analyzer.add(request, withObserver: observer)

            input.installTap(onBus: 0, bufferSize: 8192, format: format) { [weak self] buffer, when in
                self?.analysisQueue.async {
                    self?.analyzer?.analyze(buffer, atAudioFramePosition: when.sampleTime)
                }
            }
            audioEngine.prepare()
            try audioEngine.start()
            isRunning = true
            statusMessage = nil
        } catch {
            statusMessage = "Couldn't start: \(error.localizedDescription)"
            stop()
        }
    }

    func stop() {
        guard isRunning || audioEngine.isRunning else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        analyzer?.removeAllRequests()
        analyzer = nil
        observer = nil
        isRunning = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}

/// `SNResultsObserving` must be an `NSObject`; it forwards the top classifications.
private final class SoundObserver: NSObject, SNResultsObserving {
    private let onResults: ([SoundModel.Result]) -> Void
    init(onResults: @escaping ([SoundModel.Result]) -> Void) { self.onResults = onResults }

    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let classification = result as? SNClassificationResult else { return }
        let top = classification.classifications
            .filter { $0.confidence > 0.1 }
            .prefix(5)
            .map { SoundModel.Result(label: $0.identifier, confidence: $0.confidence) }
        onResults(Array(top))
    }
}
