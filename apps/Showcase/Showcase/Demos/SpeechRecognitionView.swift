import AVFoundation
import Speech
import SwiftUI

/// On-device live speech-to-text. Uses `SFSpeechRecognizer` with
/// `requiresOnDeviceRecognition = true` so nothing leaves the phone, fed by the
/// microphone via `AVAudioEngine`.
struct SpeechRecognitionView: View {
    @StateObject private var model = SpeechModel()

    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                Text(model.transcript.isEmpty ? "Tap “Start” and say something…" : model.transcript)
                    .font(.title3)
                    .foregroundStyle(model.transcript.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))

            if let status = model.statusMessage {
                Text(status).font(.footnote).foregroundStyle(.secondary)
            }
            if model.onDevice == false {
                Label("On-device model unavailable — using server recognition.",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }

            Button {
                model.isRunning ? model.stop() : model.start()
            } label: {
                Label(model.isRunning ? "Stop" : "Start",
                      systemImage: model.isRunning ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.title2)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(model.isRunning ? .red : .purple)
        }
        .padding()
        .navigationTitle("Speech Recognition")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { model.stop() }
    }
}

final class SpeechModel: ObservableObject {
    @Published var transcript = ""
    @Published var isRunning = false
    @Published var statusMessage: String?
    @Published var onDevice: Bool?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func start() {
        guard let recognizer, recognizer.isAvailable else {
            statusMessage = "Speech recognizer unavailable for this locale."
            return
        }
        SFSpeechRecognizer.requestAuthorization { [weak self] auth in
            guard let self else { return }
            guard auth == .authorized else {
                DispatchQueue.main.async { self.statusMessage = "Speech recognition permission denied." }
                return
            }
            // Speech recognition over the mic also needs microphone permission.
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    guard granted else { self.statusMessage = "Microphone permission denied."; return }
                    self.beginSession(recognizer)
                }
            }
        }
    }

    private func beginSession(_ recognizer: SFSpeechRecognizer) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
                onDevice = true
            } else {
                onDevice = false
            }
            self.request = request

            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.request?.append(buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()

            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                DispatchQueue.main.async {
                    if let result { self?.transcript = result.bestTranscription.formattedString }
                    if error != nil || (result?.isFinal ?? false) { self?.stop() }
                }
            }
            isRunning = true
            statusMessage = "Listening…"
        } catch {
            statusMessage = "Couldn't start audio: \(error.localizedDescription)"
            stop()
        }
    }

    func stop() {
        guard isRunning || audioEngine.isRunning else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isRunning = false
        statusMessage = transcript.isEmpty ? nil : "Stopped."
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
