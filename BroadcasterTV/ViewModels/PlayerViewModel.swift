import AVFoundation
import AVKit
import Observation
import Combine

enum PlaybackState {
    case idle
    case loading
    case playing
    case error(String)
}

@Observable
@MainActor
final class PlayerViewModel {
    var channels: [Channel] = []
    var currentChannelIndex: Int = -1
    var playbackState: PlaybackState = .idle
    var showChannelOverlay: Bool = false
    var showGuide: Bool = false
    var errorMessage: String?

    let player = AVPlayer()
    private var serverConfig: ServerConfig?
    private var playerObserver: AnyCancellable?
    private var statusObserver: NSKeyValueObservation?
    private var errorObserver: NSKeyValueObservation?
    private var overlayHideTask: Task<Void, Never>?
    private var channelRefreshTask: Task<Void, Never>?
    private var retryCount: Int = 0
    private let maxRetries: Int = 3

    var currentChannel: Channel? {
        guard currentChannelIndex >= 0, currentChannelIndex < channels.count else {
            return nil
        }
        return channels[currentChannelIndex]
    }

    var displayChannelNumber: Int {
        currentChannelIndex + 1
    }

    func configure(with config: ServerConfig) async {
        self.serverConfig = config
        player.automaticallyWaitsToMinimizeStalling = true

        do {
            let manifest = try await NetworkService.shared.fetchManifest(from: config)
            self.channels = manifest.channels

            playStaticStream()

            if let lastSlug = PersistenceService.shared.lastChannelSlug,
               let index = channels.firstIndex(where: { $0.slug == lastSlug }) {
                await changeChannel(to: index)
            }

            startChannelRefresh()
        } catch {
            self.errorMessage = "Failed to load channels: \(error.localizedDescription)"
            playbackState = .error(errorMessage ?? "Unknown error")
        }
    }

    private func startChannelRefresh() {
        channelRefreshTask?.cancel()
        channelRefreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000_000) // 5 minutes
                await refreshChannels()
            }
        }
    }

    func playStaticStream() {
        guard let config = serverConfig, let url = config.staticStreamURL() else { return }

        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        player.play()
        seekToLive()
    }

    func changeChannel(to index: Int) async {
        guard index >= 0, index < channels.count else { return }

        currentChannelIndex = index
        retryCount = 0
        playbackState = .loading

        playStaticStream()

        showOverlay()

        try? await Task.sleep(nanoseconds: 500_000_000)

        guard let config = serverConfig,
              let url = config.streamURL(for: channels[index].slug) else {
            playbackState = .error("Invalid channel URL")
            return
        }

        loadStream(url: url)

        PersistenceService.shared.lastChannelSlug = channels[index].slug
    }

    private func loadStream(url: URL) {
        let playerItem = AVPlayerItem(url: url)

        statusObserver?.invalidate()
        errorObserver?.invalidate()

        statusObserver = playerItem.observe(\.status) { [weak self] item, _ in
            Task { @MainActor in
                self?.handlePlayerStatus(item.status)
            }
        }

        errorObserver = playerItem.observe(\.error) { [weak self] item, _ in
            if let error = item.error {
                Task { @MainActor in
                    self?.handlePlaybackError(error)
                }
            }
        }

        player.replaceCurrentItem(with: playerItem)
        player.play()
        seekToLive()
    }

    private func handlePlayerStatus(_ status: AVPlayerItem.Status) {
        switch status {
        case .readyToPlay:
            playbackState = .playing
            retryCount = 0
            seekToLive()
        case .failed:
            handlePlaybackError(player.currentItem?.error)
        case .unknown:
            break
        @unknown default:
            break
        }
    }

    private func handlePlaybackError(_ error: Error?) {
        if retryCount < maxRetries {
            retryCount += 1
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if let channel = currentChannel,
                   let config = serverConfig,
                   let url = config.streamURL(for: channel.slug) {
                    loadStream(url: url)
                }
            }
        } else {
            playbackState = .error("Stream interrupted. Press select to retry.")
            playStaticStream()
        }
    }

    func seekToLive() {
        player.seek(to: CMTime.positiveInfinity)
    }

    func channelUp() async {
        guard !channels.isEmpty else { return }

        let newIndex: Int
        if currentChannelIndex <= 0 {
            newIndex = channels.count - 1
        } else {
            newIndex = currentChannelIndex - 1
        }
        await changeChannel(to: newIndex)
    }

    func channelDown() async {
        guard !channels.isEmpty else { return }

        let newIndex: Int
        if currentChannelIndex >= channels.count - 1 {
            newIndex = 0
        } else {
            newIndex = currentChannelIndex + 1
        }
        await changeChannel(to: newIndex)
    }

    func showOverlay() {
        overlayHideTask?.cancel()
        showChannelOverlay = true

        overlayHideTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if !Task.isCancelled {
                showChannelOverlay = false
            }
        }
    }

    func togglePlayPause() {
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    func retry() async {
        retryCount = 0
        if let index = currentChannelIndex >= 0 ? currentChannelIndex : nil {
            await changeChannel(to: index)
        } else if !channels.isEmpty {
            await changeChannel(to: 0)
        }
    }

    func openGuide() {
        showGuide = true
    }

    func closeGuide() {
        showGuide = false
    }

    func refreshChannels() async {
        guard let config = serverConfig else { return }

        do {
            let manifest = try await NetworkService.shared.fetchManifest(from: config)
            self.channels = manifest.channels
        } catch {
            // Silently fail on refresh
        }
    }
}
