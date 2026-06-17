import AVFoundation
import SwiftUI
import UIKit

/// A reusable full-screen camera preview that hands every frame to a callback,
/// along with the preview & overlay layers so a Vision demo can draw results in
/// screen coordinates. The callback runs on a background queue — dispatch any
/// layer/UI mutation to the main queue.
final class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    enum Position { case front, back }

    var position: Position = .back
    var onFrame: ((CMSampleBuffer, AVCaptureVideoPreviewLayer, CAShapeLayer) -> Void)?

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "showcase.camera.frames")
    private var previewLayer: AVCaptureVideoPreviewLayer!
    let overlayLayer = CAShapeLayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        overlayLayer.fillColor = UIColor.systemGreen.cgColor
        overlayLayer.strokeColor = UIColor.systemGreen.cgColor
        overlayLayer.lineWidth = 3
        view.layer.addSublayer(overlayLayer)
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        overlayLayer.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self, granted else { return }
            self.queue.async { if !self.session.isRunning { self.session.startRunning() } }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        queue.async { if self.session.isRunning { self.session.stopRunning() } }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high
        let avPosition: AVCaptureDevice.Position = position == .front ? .front : .back
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: avPosition),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }
        if let conn = output.connection(with: .video) {
            if conn.isVideoOrientationSupported { conn.videoOrientation = .portrait }
            if position == .front, conn.isVideoMirroringSupported {
                conn.automaticallyAdjustsVideoMirroring = false
                conn.isVideoMirrored = true
            }
        }
        session.commitConfiguration()
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        onFrame?(sampleBuffer, previewLayer, overlayLayer)
    }
}

/// SwiftUI wrapper around `CameraViewController`.
struct CameraView: UIViewControllerRepresentable {
    var position: CameraViewController.Position = .back
    var onFrame: (CMSampleBuffer, AVCaptureVideoPreviewLayer, CAShapeLayer) -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        let vc = CameraViewController()
        vc.position = position
        vc.onFrame = onFrame
        return vc
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        uiViewController.onFrame = onFrame
    }
}

/// Converts a Vision normalized point (origin bottom-left) to a point in the
/// preview layer's coordinate space.
func layerPoint(for visionPoint: CGPoint, in preview: AVCaptureVideoPreviewLayer) -> CGPoint {
    // Vision is bottom-left origin; capture-device space is top-left origin.
    let devicePoint = CGPoint(x: visionPoint.x, y: 1 - visionPoint.y)
    return preview.layerPointConverted(fromCaptureDevicePoint: devicePoint)
}
