import Foundation
import Observation

@Observable
@MainActor
final class ServerViewModel {
    var ipAddress: String = ""
    var port: String = "12121"
    var isConnecting: Bool = false
    var errorMessage: String?
    var isConnected: Bool = false

    private let persistence = PersistenceService.shared

    init() {
        loadSavedConfig()
    }

    func loadSavedConfig() {
        if let config = persistence.serverConfig {
            ipAddress = config.ipAddress
            port = String(config.port)
        }
    }

    func connect() async -> ServerConfig? {
        guard !ipAddress.isEmpty else {
            errorMessage = "Please enter a server IP address"
            return nil
        }

        guard let portNumber = Int(port), portNumber > 0, portNumber <= 65535 else {
            errorMessage = "Please enter a valid port number (1-65535)"
            return nil
        }

        isConnecting = true
        errorMessage = nil

        defer { isConnecting = false }

        let config = ServerConfig(ipAddress: ipAddress, port: portNumber)

        do {
            let isValid = try await NetworkService.shared.validateConnection(config: config)

            if isValid {
                persistence.serverConfig = config
                isConnected = true
                return config
            } else {
                errorMessage = "Server has no channels available"
                return nil
            }
        } catch {
            errorMessage = "Unable to connect to server. Please check the IP address and port."
            return nil
        }
    }

    func useProductionServer() async -> ServerConfig? {
        ipAddress = "https://tv.tedcharles.net"
        port = "443"
        return await connect()
    }

    var currentConfig: ServerConfig? {
        guard !ipAddress.isEmpty, let portNumber = Int(port) else {
            return nil
        }
        return ServerConfig(ipAddress: ipAddress, port: portNumber)
    }
}
