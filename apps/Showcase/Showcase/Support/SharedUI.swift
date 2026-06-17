import SwiftUI

/// A translucent banner pinned over a full-screen demo (e.g. camera demos).
struct InfoBanner: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.callout.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.black.opacity(0.55), in: Capsule())
            .padding(.top, 8)
    }
}

/// A centered "this isn't available" placeholder for unsupported hardware.
struct UnavailableView: View {
    let icon: String
    let title: String
    let message: String
    var body: some View {
        ContentUnavailableViewCompat(icon: icon, title: title, message: message)
    }
}

/// `ContentUnavailableView` is iOS 17+, so provide a small back-port that also
/// works on the iOS 16 deployment target.
struct ContentUnavailableViewCompat: View {
    let icon: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title).font(.title3.bold())
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A simple labelled metric used across the motion demos.
struct MetricRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.body.monospacedDigit().weight(.medium))
        }
    }
}
