import Foundation

struct Channel: Codable, Identifiable, Hashable {
    let name: String
    let slug: String

    var id: String { slug }
}

struct ChannelManifest: Codable {
    let channels: [Channel]
    let upcoming: [Channel]?
}
