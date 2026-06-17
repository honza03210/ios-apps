import AVFoundation
import SwiftUI
import Vision

// MARK: - Hand pose

/// Vision detects up to two hands, each with 21 finger-joint landmarks.
struct HandPoseView: View {
    @StateObject private var model = HandPoseModel()
    var body: some View {
        CameraView(position: .back) { buffer, preview, overlay in
            model.process(buffer, preview, overlay)
        }
        .ignoresSafeArea()
        .overlay(alignment: .top) { InfoBanner(text: "Hold a hand up to the camera") }
        .navigationTitle("Hand Pose")
        .navigationBarTitleDisplayMode(.inline)
    }
}

final class HandPoseModel: ObservableObject {
    private let request: VNDetectHumanHandPoseRequest = {
        let r = VNDetectHumanHandPoseRequest()
        r.maximumHandCount = 2
        return r
    }()

    func process(_ buffer: CMSampleBuffer, _ preview: AVCaptureVideoPreviewLayer, _ overlay: CAShapeLayer) {
        let handler = VNImageRequestHandler(cmSampleBuffer: buffer, orientation: .up, options: [:])
        try? handler.perform([request])
        var points: [CGPoint] = []
        for hand in request.results ?? [] {
            guard let recognized = try? hand.recognizedPoints(.all) else { continue }
            points += recognized.values.filter { $0.confidence > 0.3 }.map { $0.location }
        }
        DispatchQueue.main.async {
            let path = CGMutablePath()
            for p in points {
                let pt = layerPoint(for: p, in: preview)
                path.addEllipse(in: CGRect(x: pt.x - 6, y: pt.y - 6, width: 12, height: 12))
            }
            overlay.fillColor = UIColor.systemGreen.cgColor
            overlay.path = path
        }
    }
}

// MARK: - Body pose

/// Vision detects a 2D skeleton; we draw joints plus the bones between them.
struct BodyPoseView: View {
    @StateObject private var model = BodyPoseModel()
    var body: some View {
        CameraView(position: .back) { buffer, preview, overlay in
            model.process(buffer, preview, overlay)
        }
        .ignoresSafeArea()
        .overlay(alignment: .top) { InfoBanner(text: "Step back so your whole body is visible") }
        .navigationTitle("Body Pose")
        .navigationBarTitleDisplayMode(.inline)
    }
}

final class BodyPoseModel: ObservableObject {
    private let request = VNDetectHumanBodyPoseRequest()

    // Bones to connect, as joint-name pairs.
    private let bones: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.neck, .nose), (.neck, .leftShoulder), (.neck, .rightShoulder),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.neck, .root), (.root, .leftHip), (.root, .rightHip),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle)
    ]

    func process(_ buffer: CMSampleBuffer, _ preview: AVCaptureVideoPreviewLayer, _ overlay: CAShapeLayer) {
        let handler = VNImageRequestHandler(cmSampleBuffer: buffer, orientation: .up, options: [:])
        try? handler.perform([request])
        guard let obs = request.results?.first,
              let joints = try? obs.recognizedPoints(.all) else {
            DispatchQueue.main.async { overlay.path = nil }
            return
        }
        func location(_ name: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
            guard let p = joints[name], p.confidence > 0.2 else { return nil }
            return p.location
        }
        let dots = joints.values.filter { $0.confidence > 0.2 }.map { $0.location }
        let segments: [(CGPoint, CGPoint)] = bones.compactMap { a, b in
            guard let pa = location(a), let pb = location(b) else { return nil }
            return (pa, pb)
        }
        DispatchQueue.main.async {
            let path = CGMutablePath()
            for (a, b) in segments {
                path.move(to: layerPoint(for: a, in: preview))
                path.addLine(to: layerPoint(for: b, in: preview))
            }
            for p in dots {
                let pt = layerPoint(for: p, in: preview)
                path.addEllipse(in: CGRect(x: pt.x - 5, y: pt.y - 5, width: 10, height: 10))
            }
            overlay.fillColor = UIColor.systemTeal.cgColor
            overlay.strokeColor = UIColor.systemTeal.cgColor
            overlay.path = path
        }
    }
}

// MARK: - Image classification

/// Vision ships a built-in image classifier (no model file needed).
struct ImageClassificationView: View {
    @StateObject private var model = ImageClassificationModel()
    var body: some View {
        CameraView(position: .back) { buffer, _, overlay in
            model.process(buffer, overlay)
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(model.results, id: \.label) { item in
                    HStack {
                        Text(item.label.capitalized)
                        Spacer()
                        Text("\(Int(item.confidence * 100))%").monospacedDigit()
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
            .padding()
        }
        .navigationTitle("Image Classification")
        .navigationBarTitleDisplayMode(.inline)
    }
}

final class ImageClassificationModel: ObservableObject {
    @Published var results: [(label: String, confidence: Float)] = []
    private let request = VNClassifyImageRequest()
    private var frame = 0

    func process(_ buffer: CMSampleBuffer, _ overlay: CAShapeLayer) {
        frame += 1
        guard frame % 12 == 0 else { return }   // throttle: classify ~2–3×/sec
        let handler = VNImageRequestHandler(cmSampleBuffer: buffer, orientation: .up, options: [:])
        try? handler.perform([request])
        let top = (request.results ?? [])
            .filter { $0.confidence > 0.1 }
            .prefix(4)
            .map { (label: $0.identifier, confidence: $0.confidence) }
        DispatchQueue.main.async { self.results = Array(top) }
    }
}

// MARK: - Text recognition (OCR)

/// Live OCR. Vision boxes each recognized string; we outline them and list the
/// text.
struct TextRecognitionView: View {
    @StateObject private var model = TextRecognitionModel()
    var body: some View {
        CameraView(position: .back) { buffer, preview, overlay in
            model.process(buffer, preview, overlay)
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            if !model.lines.isEmpty {
                Text(model.lines.joined(separator: "  ·  "))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
                    .padding()
            }
        }
        .overlay(alignment: .top) { InfoBanner(text: "Point at some printed text") }
        .navigationTitle("Text Recognition")
        .navigationBarTitleDisplayMode(.inline)
    }
}

final class TextRecognitionModel: ObservableObject {
    @Published var lines: [String] = []
    private let request: VNRecognizeTextRequest
    private var frame = 0

    init() {
        request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = true
    }

    func process(_ buffer: CMSampleBuffer, _ preview: AVCaptureVideoPreviewLayer, _ overlay: CAShapeLayer) {
        frame += 1
        guard frame % 8 == 0 else { return }
        let handler = VNImageRequestHandler(cmSampleBuffer: buffer, orientation: .up, options: [:])
        try? handler.perform([request])
        let observations = request.results ?? []
        let boxes = observations.map { $0.boundingBox }
        let strings = observations.compactMap { $0.topCandidates(1).first?.string }
        DispatchQueue.main.async {
            let path = CGMutablePath()
            for box in boxes {
                let bl = layerPoint(for: CGPoint(x: box.minX, y: box.minY), in: preview)
                let tr = layerPoint(for: CGPoint(x: box.maxX, y: box.maxY), in: preview)
                path.addRect(CGRect(x: min(bl.x, tr.x), y: min(bl.y, tr.y),
                                    width: abs(tr.x - bl.x), height: abs(tr.y - bl.y)))
            }
            overlay.fillColor = UIColor.clear.cgColor
            overlay.strokeColor = UIColor.systemYellow.cgColor
            overlay.path = path
            self.lines = Array(strings.prefix(6))
        }
    }
}
