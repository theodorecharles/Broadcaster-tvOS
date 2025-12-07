import Foundation

struct GuideData: Codable {
    let dayStart: Int64
    let channels: [String: GuideChannel]

    var dayStartDate: Date {
        Date(timeIntervalSince1970: Double(dayStart) / 1000.0)
    }
}

struct GuideChannel: Codable {
    let name: String
    let slug: String
    let schedule: [Program]
}
