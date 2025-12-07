import Foundation

final class PersistenceService {
    static let shared = PersistenceService()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let serverIP = "broadcaster_server_ip"
        static let serverPort = "broadcaster_server_port"
        static let lastChannel = "broadcaster_last_channel"
    }

    private init() {}

    var serverConfig: ServerConfig? {
        get {
            guard let ip = defaults.string(forKey: Keys.serverIP) else {
                return nil
            }
            let port = defaults.integer(forKey: Keys.serverPort)
            return ServerConfig(ipAddress: ip, port: port > 0 ? port : 12121)
        }
        set {
            if let config = newValue {
                defaults.set(config.ipAddress, forKey: Keys.serverIP)
                defaults.set(config.port, forKey: Keys.serverPort)
            } else {
                defaults.removeObject(forKey: Keys.serverIP)
                defaults.removeObject(forKey: Keys.serverPort)
            }
        }
    }

    var lastChannelSlug: String? {
        get {
            defaults.string(forKey: Keys.lastChannel)
        }
        set {
            if let slug = newValue {
                defaults.set(slug, forKey: Keys.lastChannel)
            } else {
                defaults.removeObject(forKey: Keys.lastChannel)
            }
        }
    }

    func clearAll() {
        defaults.removeObject(forKey: Keys.serverIP)
        defaults.removeObject(forKey: Keys.serverPort)
        defaults.removeObject(forKey: Keys.lastChannel)
    }
}
