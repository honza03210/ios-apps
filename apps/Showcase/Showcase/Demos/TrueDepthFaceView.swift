import ARKit
import Metal
import SceneKit
import SwiftUI

/// TrueDepth front-camera face tracking. ARKit's `ARFaceAnchor` exposes 52
/// blend-shape coefficients (jaw, blinks, brows, smile…) driven by the IR depth
/// sensor. We show the live camera with a green wireframe face mesh, plus bars
/// for a handful of the most expressive coefficients.
struct TrueDepthFaceView: View {
    @StateObject private var model = FaceTrackingModel()

    private let tracked: [(ARFaceAnchor.BlendShapeLocation, String)] = [
        (.jawOpen, "Jaw open"),
        (.mouthSmileLeft, "Smile L"),
        (.mouthSmileRight, "Smile R"),
        (.eyeBlinkLeft, "Blink L"),
        (.eyeBlinkRight, "Blink R"),
        (.browInnerUp, "Brow up"),
        (.cheekPuff, "Cheek puff"),
        (.tongueOut, "Tongue out")
    ]

    var body: some View {
        Group {
            if ARFaceTrackingConfiguration.isSupported {
                ZStack(alignment: .bottom) {
                    FaceTrackingContainer(model: model).ignoresSafeArea()
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(tracked, id: \.1) { shape, label in
                            BlendShapeBar(label: label, value: model.blendShapes[shape] ?? 0)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding()
                }
                .overlay(alignment: .top) {
                    if !model.faceVisible { InfoBanner(text: "Point the front camera at your face") }
                }
            } else {
                UnavailableView(icon: "faceid", title: "No TrueDepth camera",
                                message: "Face tracking needs a device with the front TrueDepth camera (Face ID).")
            }
        }
        .navigationTitle("TrueDepth Face")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct BlendShapeBar: View {
    let label: String
    let value: Float
    var body: some View {
        HStack(spacing: 8) {
            Text(label).font(.caption.monospaced()).frame(width: 80, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule().fill(.pink)
                        .frame(width: geo.size.width * CGFloat(min(max(value, 0), 1)))
                }
            }
            .frame(height: 10)
            Text(String(format: "%.2f", value)).font(.caption2.monospacedDigit())
                .frame(width: 34, alignment: .trailing)
        }
    }
}

/// Receives `ARFaceAnchor` updates and republishes the blend-shape dictionary.
final class FaceTrackingModel: NSObject, ObservableObject, ARSessionDelegate {
    @Published var blendShapes: [ARFaceAnchor.BlendShapeLocation: Float] = [:]
    @Published var faceVisible = false

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let face = anchors.compactMap({ $0 as? ARFaceAnchor }).first else { return }
        var values: [ARFaceAnchor.BlendShapeLocation: Float] = [:]
        for (key, number) in face.blendShapes { values[key] = number.floatValue }
        DispatchQueue.main.async {
            self.blendShapes = values
            self.faceVisible = face.isTracked
        }
    }
}

private struct FaceTrackingContainer: UIViewRepresentable {
    let model: FaceTrackingModel

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView()
        view.automaticallyUpdatesLighting = true
        view.session.delegate = model
        view.delegate = context.coordinator
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        view.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        uiView.session.pause()
    }

    /// Builds and updates a wireframe mesh that tracks the detected face.
    final class Coordinator: NSObject, ARSCNViewDelegate {
        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard anchor is ARFaceAnchor,
                  let device = MTLCreateSystemDefaultDevice(),
                  let geometry = ARSCNFaceGeometry(device: device) else { return nil }
            geometry.firstMaterial?.fillMode = .lines
            geometry.firstMaterial?.diffuse.contents = UIColor.systemGreen
            return SCNNode(geometry: geometry)
        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let faceAnchor = anchor as? ARFaceAnchor,
                  let faceGeometry = node.geometry as? ARSCNFaceGeometry else { return }
            faceGeometry.update(from: faceAnchor.geometry)
        }
    }
}
