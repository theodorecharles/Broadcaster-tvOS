import Foundation

struct Program: Codable, Identifiable {
    let title: String
    let startTime: Int64
    let endTime: Int64
    let duration: Int
    let isCurrent: Bool

    var id: String { "\(startTime)-\(title)" }

    var startDate: Date {
        Date(timeIntervalSince1970: Double(startTime) / 1000.0)
    }

    var endDate: Date {
        Date(timeIntervalSince1970: Double(endTime) / 1000.0)
    }

    var durationMinutes: Int {
        duration / 60
    }

    var formattedDuration: String {
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
