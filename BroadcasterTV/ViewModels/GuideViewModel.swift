import Foundation
import Observation

@Observable
@MainActor
final class GuideViewModel {
    var guideData: GuideData?
    var isLoading: Bool = false
    var errorMessage: String?
    var currentTime: Date = Date()

    private var serverConfig: ServerConfig?
    private var timeUpdateTask: Task<Void, Never>?

    let pixelsPerMinute: CGFloat = 10.0
    let rowHeight: CGFloat = 90.0
    let channelColumnWidth: CGFloat = 200.0

    var totalGuideWidth: CGFloat {
        24 * 60 * pixelsPerMinute // 14,400 points for 24 hours
    }

    var dayStart: Int64 {
        guideData?.dayStart ?? 0
    }

    var nowLinePosition: CGFloat {
        let nowMs = currentTime.timeIntervalSince1970 * 1000
        return CGFloat(nowMs - Double(dayStart)) / 60000.0 * pixelsPerMinute
    }

    var initialScrollOffset: CGFloat {
        nowLinePosition - 400 // Scroll to show "now" with some context
    }

    func configure(with config: ServerConfig) {
        self.serverConfig = config
    }

    func loadGuide() async {
        guard let config = serverConfig else { return }

        isLoading = true
        errorMessage = nil

        do {
            guideData = try await NetworkService.shared.fetchGuide(from: config)
            startTimeUpdates()
        } catch {
            errorMessage = "Unable to load TV Guide"
        }

        isLoading = false
    }

    func startTimeUpdates() {
        timeUpdateTask?.cancel()
        timeUpdateTask = Task {
            while !Task.isCancelled {
                currentTime = Date()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    func stopTimeUpdates() {
        timeUpdateTask?.cancel()
        timeUpdateTask = nil
    }

    func blockPosition(for program: Program) -> CGFloat {
        CGFloat(program.startTime - dayStart) / 60000.0 * pixelsPerMinute
    }

    func blockWidth(for program: Program) -> CGFloat {
        max(60, CGFloat(program.duration) / 60.0 * pixelsPerMinute)
    }

    func orderedChannels(from channels: [Channel]) -> [(index: Int, channel: Channel, guideChannel: GuideChannel?)] {
        channels.enumerated().map { index, channel in
            (index: index, channel: channel, guideChannel: guideData?.channels[channel.slug])
        }
    }

    func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    func timeMarkers() -> [(position: CGFloat, label: String)] {
        guard dayStart > 0 else { return [] }

        var markers: [(position: CGFloat, label: String)] = []
        let calendar = Calendar.current
        let startDate = Date(timeIntervalSince1970: Double(dayStart) / 1000.0)

        for hour in 0..<24 {
            if let markerDate = calendar.date(byAdding: .hour, value: hour, to: startDate) {
                let position = CGFloat(hour * 60) * pixelsPerMinute
                let formatter = DateFormatter()
                formatter.dateFormat = "h a"
                markers.append((position: position, label: formatter.string(from: markerDate)))
            }
        }

        return markers
    }
}
