import LocalAuthentication
import SwiftUI

/// Biometric authentication via `LAContext` — Face ID or Touch ID, with a
/// device-passcode fallback.
struct LocalAuthView: View {
    @State private var result: String?
    @State private var success = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: biometryIcon)
                .font(.system(size: 72))
                .foregroundStyle(success ? .green : .gray)

            Text(biometryName).font(.title2.bold())

            if let result {
                Text(result)
                    .font(.callout)
                    .foregroundStyle(success ? .green : .red)
                    .multilineTextAlignment(.center)
            }

            Button {
                authenticate()
            } label: {
                Label("Authenticate", systemImage: "lock.open").font(.title3).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .navigationTitle("Local Authentication")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var context: LAContext { LAContext() }

    private var biometryName: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch ctx.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "Passcode"
        }
    }

    private var biometryIcon: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch ctx.biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock.shield"
        }
    }

    private func authenticate() {
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "Use Passcode"
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            result = error?.localizedDescription ?? "Authentication not available."
            success = false
            return
        }
        ctx.evaluatePolicy(.deviceOwnerAuthentication,
                           localizedReason: "Prove it's you to unlock the demo.") { ok, err in
            DispatchQueue.main.async {
                success = ok
                result = ok ? "Authenticated ✓" : (err?.localizedDescription ?? "Authentication failed.")
            }
        }
    }
}
