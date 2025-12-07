import SwiftUI
import AVKit

struct VideoPlayerView: View {
    @Bindable var viewModel: PlayerViewModel
    @State private var guideViewModel = GuideViewModel()

    var body: some View {
        ZStack {
            // Video player layer
            PlayerContainerView(player: viewModel.player)
                .ignoresSafeArea()

            // Channel overlay
            if let channel = viewModel.currentChannel {
                ChannelOverlayView(
                    channelNumber: viewModel.displayChannelNumber,
                    channelName: channel.name,
                    isVisible: viewModel.showChannelOverlay
                )
            }

            // Error overlay
            if case .error(let message) = viewModel.playbackState {
                ErrorOverlayView(message: message) {
                    Task {
                        await viewModel.retry()
                    }
                }
            }

            // TV Guide overlay
            if viewModel.showGuide {
                TVGuideView(
                    viewModel: guideViewModel,
                    channels: viewModel.channels,
                    currentChannelIndex: viewModel.currentChannelIndex,
                    onChannelSelect: { index in
                        viewModel.closeGuide()
                        Task {
                            await viewModel.changeChannel(to: index)
                        }
                    },
                    onClose: {
                        viewModel.closeGuide()
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .focusable(!viewModel.showGuide)
        .onMoveCommand { direction in
            handleMove(direction)
        }
        .onPlayPauseCommand {
            viewModel.togglePlayPause()
        }
        .onExitCommand {
            if viewModel.showGuide {
                viewModel.closeGuide()
            } else {
                viewModel.openGuide()
            }
        }
        .gesture(
            TapGesture()
                .onEnded { _ in
                    if !viewModel.showGuide {
                        viewModel.showOverlay()
                    }
                }
        )
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    guard !viewModel.showGuide else { return }

                    let verticalMovement = value.translation.height
                    let horizontalMovement = value.translation.width

                    // Only respond to primarily vertical swipes
                    if abs(verticalMovement) > abs(horizontalMovement) {
                        if verticalMovement < -30 {
                            Task { await viewModel.channelUp() }
                        } else if verticalMovement > 30 {
                            Task { await viewModel.channelDown() }
                        }
                    }
                }
        )
        .task {
            if let config = PersistenceService.shared.serverConfig {
                guideViewModel.configure(with: config)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.showGuide)
    }

    private func handleMove(_ direction: MoveCommandDirection) {
        guard !viewModel.showGuide else { return }

        switch direction {
        case .up:
            Task { await viewModel.channelUp() }
        case .down:
            Task { await viewModel.channelDown() }
        default:
            break
        }
    }
}

struct PlayerContainerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspect
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}
