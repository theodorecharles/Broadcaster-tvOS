import Foundation

struct ServerConfig: Codable, Equatable {
    var ipAddress: String
    var port: Int

    var baseURL: String {
        if ipAddress.hasPrefix("https://") || ipAddress.hasPrefix("http://") {
            return ipAddress.hasSuffix("/") ? String(ipAddress.dropLast()) : ipAddress
        }
        return "http://\(ipAddress):\(port)"
    }

    func streamURL(for slug: String) -> URL? {
        URL(string: "\(baseURL)/\(slug).m3u8")
    }

    func staticStreamURL() -> URL? {
        URL(string: "\(baseURL)/channels/static/_.m3u8")
    }

    func manifestURL() -> URL? {
        URL(string: "\(baseURL)/manifest.json")
    }

    func guideURL() -> URL? {
        URL(string: "\(baseURL)/api/guide")
    }

    static let `default` = ServerConfig(ipAddress: "192.168.1.100", port: 12121)
    static let production = ServerConfig(ipAddress: "https://tv.tedcharles.net", port: 443)
}
