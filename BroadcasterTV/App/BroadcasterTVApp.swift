import SwiftUI

@main
struct BroadcasterTVApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
    }
}

enum ConnectionState {
    case checking
    case connected
    case disconnected
}

@Observable
@MainActor
final class AppState {
    var connectionState: ConnectionState = .checking
    var serverConfig: ServerConfig?
    var playerViewModel = PlayerViewModel()
    var serverViewModel = ServerViewModel()

    init() {
        checkSavedConnection()
    }

    func checkSavedConnection() {
        if let config = PersistenceService.shared.serverConfig {
            serverConfig = config
            serverViewModel.ipAddress = config.ipAddress
            serverViewModel.port = String(config.port)

            Task {
                do {
                    let isValid = try await NetworkService.shared.validateConnection(config: config)
                    if isValid {
                        connectionState = .connected
                        await playerViewModel.configure(with: config)
                    } else {
                        connectionState = .disconnected
                    }
                } catch {
                    connectionState = .disconnected
                }
            }
        } else {
            connectionState = .disconnected
        }
    }

    func connect(with config: ServerConfig) async {
        serverConfig = config
        connectionState = .connected
        await playerViewModel.configure(with: config)
    }

    func disconnect() {
        connectionState = .disconnected
        serverConfig = nil
        PersistenceService.shared.clearAll()
    }
}

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            switch appState.connectionState {
            case .checking:
                LoadingView()
            case .connected:
                VideoPlayerView(viewModel: appState.playerViewModel)
            case .disconnected:
                ServerSetupView(viewModel: appState.serverViewModel) { config in
                    Task {
                        await appState.connect(with: config)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 30) {
                Text("BROADCASTER")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(Color.broadcasterGreen)
                    .shadow(color: .broadcasterGreen.opacity(0.8), radius: 20)

                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)

                Text("Connecting...")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
