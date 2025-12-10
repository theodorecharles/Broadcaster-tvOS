# Broadcaster tvOS

A native tvOS app for the Broadcaster live TV streaming system. Watch continuous live TV channels, switch between channels with the Siri Remote, and browse the TV guide.

## Features

- **Live HLS Streaming** - Seamless playback of live TV channels via AVPlayer
- **Channel Switching** - Swipe up/down or use the d-pad to change channels
- **Channel Overlay** - Retro green CRT-style channel display
- **TV Guide** - Full 24-hour program guide with timeline navigation
- **Siri Remote Support** - Intuitive navigation with swipes, clicks, and the menu button
- **Auto-Reconnect** - Automatic stream recovery on network interruptions
- **Persistent Settings** - Remembers server configuration and last watched channel

## Requirements

- tvOS 26.0+
- Xcode 16.2+
- A running [Broadcaster](https://github.com/theodorecharles/Broadcaster) backend server

## Setup

1. Clone this repository
2. Open `BroadcasterTV.xcodeproj` in Xcode
3. Select your development team in Signing & Capabilities
4. Build and run on Apple TV or tvOS Simulator

## Configuration

On first launch, enter your Broadcaster server details:

- **Server IP**: Your server's IP address (e.g., `192.168.1.100`)
- **Port**: Server port (default: `12121`)

## Remote Controls

### Video Player
| Input | Action |
|-------|--------|
| Swipe Up/Down | Change channel |
| Click (Select) | Show channel info |
| Menu | Open TV Guide |
| Play/Pause | Toggle playback |

### TV Guide
| Input | Action |
|-------|--------|
| Swipe Up/Down | Navigate channels |
| Swipe Left/Right | Scroll timeline |
| Click (Select) | Tune to channel |
| Menu | Close guide |

## Project Structure

```
BroadcasterTV/
├── App/
│   └── BroadcasterTVApp.swift      # App entry point
├── Models/
│   ├── Channel.swift                # Channel data model
│   ├── GuideData.swift              # TV Guide data model
│   ├── Program.swift                # Program/show model
│   └── ServerConfig.swift           # Server configuration
├── ViewModels/
│   ├── GuideViewModel.swift         # TV Guide logic
│   ├── PlayerViewModel.swift        # Video player & channels
│   └── ServerViewModel.swift        # Server connection
├── Views/
│   ├── ChannelOverlayView.swift     # Channel info overlay
│   ├── ServerSetupView.swift        # Server config screen
│   ├── TVGuideView.swift            # Program guide
│   └── VideoPlayerView.swift        # Main video player
├── Services/
│   ├── NetworkService.swift         # API communication
│   └── PersistenceService.swift     # UserDefaults storage
└── Resources/
    ├── Info.plist
    └── Assets.xcassets/
```

## License

MIT
