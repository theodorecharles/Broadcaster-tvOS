import SwiftUI

struct TVGuideView: View {
    @Bindable var viewModel: GuideViewModel
    let channels: [Channel]
    let currentChannelIndex: Int
    let onChannelSelect: (Int) -> Void
    let onClose: () -> Void

    @State private var scrollOffset: CGFloat = 0
    @FocusState private var focusedChannelIndex: Int?

    private let scrollStep: CGFloat = 300 // pixels to scroll per swipe

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.guideBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                guideHeader

                // Time ruler
                timeRuler

                // Channel list and schedule grid
                ScrollViewReader { scrollProxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(channels.enumerated()), id: \.element.id) { index, channel in
                                channelRow(index: index, channel: channel)
                                    .id(index)
                            }
                        }
                    }
                    .onChange(of: focusedChannelIndex) { _, newValue in
                        if let index = newValue {
                            withAnimation {
                                scrollProxy.scrollTo(index, anchor: .center)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 20)

            // Now line
            if viewModel.guideData != nil {
                nowLine
            }
        }
        .focusable(true)
        .onMoveCommand { direction in
            handleMoveCommand(direction)
        }
        .onExitCommand {
            onClose()
        }
        .task {
            await viewModel.loadGuide()
            focusedChannelIndex = currentChannelIndex
            // Scroll to center current time
            scrollOffset = max(0, viewModel.initialScrollOffset)
        }
        .onDisappear {
            viewModel.stopTimeUpdates()
        }
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    handleSwipe(value)
                }
        )
    }

    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        switch direction {
        case .up:
            if let current = focusedChannelIndex, current > 0 {
                focusedChannelIndex = current - 1
            }
        case .down:
            if let current = focusedChannelIndex, current < channels.count - 1 {
                focusedChannelIndex = current + 1
            }
        case .left:
            withAnimation(.easeOut(duration: 0.2)) {
                scrollOffset = max(0, scrollOffset - scrollStep)
            }
        case .right:
            withAnimation(.easeOut(duration: 0.2)) {
                scrollOffset = min(viewModel.totalGuideWidth - 800, scrollOffset + scrollStep)
            }
        @unknown default:
            break
        }
    }

    private func handleSwipe(_ value: DragGesture.Value) {
        let horizontal = value.translation.width
        let vertical = value.translation.height

        if abs(horizontal) > abs(vertical) {
            // Horizontal swipe - scroll timeline
            if horizontal > 50 {
                // Swipe right - scroll left (earlier)
                withAnimation(.easeOut(duration: 0.2)) {
                    scrollOffset = max(0, scrollOffset - scrollStep)
                }
            } else if horizontal < -50 {
                // Swipe left - scroll right (later)
                withAnimation(.easeOut(duration: 0.2)) {
                    scrollOffset = min(viewModel.totalGuideWidth - 800, scrollOffset + scrollStep)
                }
            }
        } else {
            // Vertical swipe - change focused channel
            if vertical > 50 {
                // Swipe down
                if let current = focusedChannelIndex, current < channels.count - 1 {
                    focusedChannelIndex = current + 1
                }
            } else if vertical < -50 {
                // Swipe up
                if let current = focusedChannelIndex, current > 0 {
                    focusedChannelIndex = current - 1
                }
            }
        }
    }

    private var guideHeader: some View {
        HStack {
            Text("TV GUIDE")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(Color.broadcasterGreen)
                .shadow(color: .broadcasterGreen.opacity(0.6), radius: 10)

            Spacer()

            Text(viewModel.formattedTime(viewModel.currentTime))
                .font(.system(size: 28, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)

            Spacer()
                .frame(width: 40)

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 20)
    }

    private var timeRuler: some View {
        HStack(spacing: 0) {
            // Channel column spacer
            Color.clear
                .frame(width: viewModel.channelColumnWidth)

            // Time markers
            ZStack(alignment: .leading) {
                Color.clear
                    .frame(width: viewModel.totalGuideWidth, height: 30)

                ForEach(viewModel.timeMarkers(), id: \.position) { marker in
                    Text(marker.label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .position(x: marker.position + 20, y: 15)
                }
            }
            .offset(x: -scrollOffset)
            .clipped()
        }
        .frame(height: 30)
    }

    private func channelRow(index: Int, channel: Channel) -> some View {
        let guideChannel = viewModel.guideData?.channels[channel.slug]
        let isCurrent = index == currentChannelIndex
        let isFocused = focusedChannelIndex == index

        return HStack(spacing: 0) {
            // Channel info column
            Button {
                onChannelSelect(index)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CH \(index + 1)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.broadcasterGreen)

                    Text(channel.name)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
                .frame(width: viewModel.channelColumnWidth - 20, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 15)
                .background(
                    isCurrent
                        ? Color.currentProgramHighlight
                        : Color.white.opacity(0.05)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isFocused ? Color.broadcasterGreen : Color.clear, lineWidth: 3)
                )
                .scaleEffect(isFocused ? 1.02 : 1.0)
            }
            .buttonStyle(.plain)
            .focused($focusedChannelIndex, equals: index)

            // Schedule grid
            ZStack(alignment: .leading) {
                Color.clear
                    .frame(width: viewModel.totalGuideWidth, height: viewModel.rowHeight - 10)

                if let schedule = guideChannel?.schedule {
                    ForEach(schedule) { program in
                        programBlock(program: program, isCurrent: program.isCurrent)
                    }
                }
            }
            .offset(x: -scrollOffset)
            .clipped()
        }
        .frame(height: viewModel.rowHeight)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }

    private func programBlock(program: Program, isCurrent: Bool) -> some View {
        let position = viewModel.blockPosition(for: program)
        let width = viewModel.blockWidth(for: program)

        return VStack(alignment: .leading, spacing: 4) {
            MarqueeText(text: program.title, width: width - 24)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)

            Text(program.formattedDuration)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: width - 4, height: viewModel.rowHeight - 20, alignment: .leading)
        .background(
            isCurrent
                ? Color.currentProgramHighlight
                : Color.white.opacity(0.1)
        )
        .overlay(
            isCurrent
                ? Rectangle()
                    .fill(Color.broadcasterGreen)
                    .frame(width: 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                : nil
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .position(x: position + width / 2, y: (viewModel.rowHeight - 10) / 2)
    }

    private var nowLine: some View {
        GeometryReader { geo in
            let xPosition = viewModel.channelColumnWidth + viewModel.nowLinePosition - scrollOffset + 40

            if xPosition > viewModel.channelColumnWidth && xPosition < geo.size.width - 40 {
                Rectangle()
                    .fill(Color.broadcasterRed)
                    .frame(width: 2)
                    .shadow(color: .broadcasterRed.opacity(0.8), radius: 5)
                    .shadow(color: .broadcasterRed.opacity(0.6), radius: 10)
                    .position(x: xPosition, y: geo.size.height / 2)
            }
        }
        .allowsHitTesting(false)
    }
}

// Marquee text for long titles
struct MarqueeText: View {
    let text: String
    let width: CGFloat

    @State private var textWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var animate: Bool = false

    var body: some View {
        GeometryReader { geo in
            Text(text)
                .lineLimit(1)
                .fixedSize()
                .background(
                    GeometryReader { textGeo in
                        Color.clear.onAppear {
                            textWidth = textGeo.size.width
                            if textWidth > width {
                                startAnimation()
                            }
                        }
                    }
                )
                .offset(x: offset)
        }
        .frame(width: width, height: 20)
        .clipped()
    }

    private func startAnimation() {
        let overflow = textWidth - width + 20
        guard overflow > 0 else { return }

        withAnimation(
            .linear(duration: Double(overflow) / 30)
            .repeatForever(autoreverses: true)
            .delay(2)
        ) {
            offset = -overflow
        }
    }
}
