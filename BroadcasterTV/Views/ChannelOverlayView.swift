import SwiftUI

struct ChannelOverlayView: View {
    let channelNumber: Int
    let channelName: String
    let isVisible: Bool

    var body: some View {
        ZStack {
            // Channel number - top right
            VStack {
                HStack {
                    Spacer()
                    Text("CH \(channelNumber)")
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.broadcasterGreen)
                        .shadow(color: .broadcasterGreen.opacity(0.8), radius: 10)
                        .shadow(color: .broadcasterGreen.opacity(0.6), radius: 20)
                        .shadow(color: .broadcasterGreen.opacity(0.4), radius: 30)
                        .padding(.top, 40)
                        .padding(.trailing, 40)
                }
                Spacer()
            }

            // Channel name - bottom center
            VStack {
                Spacer()
                Text(channelName.uppercased())
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.broadcasterGreen)
                    .shadow(color: .broadcasterGreen.opacity(0.8), radius: 8)
                    .shadow(color: .broadcasterGreen.opacity(0.6), radius: 16)
                    .shadow(color: .broadcasterGreen.opacity(0.4), radius: 24)
                    .padding(.bottom, 60)
            }
        }
        .opacity(isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: isVisible)
    }
}

struct ErrorOverlayView: View {
    let message: String
    let onRetry: () -> Void

    @FocusState private var isRetryFocused: Bool

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)

            Text(message)
                .font(.title2)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Button("Retry") {
                onRetry()
            }
            .buttonStyle(BroadcasterButtonStyle())
            .focused($isRetryFocused)
        }
        .padding(40)
        .background(Color.black.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onAppear {
            isRetryFocused = true
        }
    }
}
