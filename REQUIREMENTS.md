# Broadcaster tvOS App - Requirements Specification

## Overview

This document specifies the requirements for building a tvOS app frontend for the Broadcaster live TV streaming system. The tvOS app will connect to an existing Broadcaster backend server and provide a native Apple TV experience with Siri Remote navigation.

The app replicates the functionality of the existing web frontend, allowing users to watch continuous live TV channels, switch between channels, and browse a TV guide.

---

## Table of Contents

1. [Architecture](#architecture)
2. [Server Connection](#server-connection)
3. [API Endpoints](#api-endpoints)
4. [Video Playback](#video-playback)
5. [Channel Switching](#channel-switching)
6. [Channel Overlay](#channel-overlay)
7. [TV Guide](#tv-guide)
8. [Remote Control Mapping](#remote-control-mapping)
9. [Data Structures](#data-structures)
10. [UI/UX Specifications](#uiux-specifications)
11. [Error Handling](#error-handling)
12. [Persistence](#persistence)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      tvOS App                                │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   Server    │  │   Video     │  │      TV Guide       │  │
│  │   Setup     │  │   Player    │  │      Overlay        │  │
│  │   View      │  │   View      │  │      View           │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                    Network Layer                             │
│         (REST API calls + HLS streaming)                     │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  Broadcaster Backend                         │
│                  (Node.js + Express)                         │
│                  Port: 12121 (default)                       │
└─────────────────────────────────────────────────────────────┘
```

---

## Server Connection

### Initial Setup Screen

When the app launches for the first time (or when no valid server is configured), display a server configuration screen.

**UI Elements:**
- Text field for server IP address (e.g., `192.168.1.100`)
- Text field for port number (default: `12121`)
- "Connect" button
- Status message area for connection feedback

**Connection Flow:**

1. User enters IP and port
2. App attempts to fetch `/manifest.json` from `http://{ip}:{port}/manifest.json`
3. If successful:
   - Store server configuration in persistent storage
   - Navigate to Video Player View
   - Begin playing static channel
4. If failed:
   - Display error message: "Unable to connect to server. Please check the IP address and port."
   - Allow user to retry

### Automatic Connection

On subsequent launches:

1. Load saved server IP and port from storage
2. Attempt to fetch `/manifest.json`
3. If successful: Skip setup, go directly to Video Player View showing static
4. If failed: Show Server Setup Screen with pre-filled saved values

### Connection Validation

A valid connection is confirmed when `/manifest.json` returns:
- HTTP 200 status
- Valid JSON with a `channels` array

---

## API Endpoints

The tvOS app must interact with these backend endpoints.

**Development/Testing Server:**

A live production backend is available for testing with real payloads:

```
Base URL: https://tv.tedcharles.net/
```

Example requests:
- Channels: `https://tv.tedcharles.net/manifest.json`
- Guide: `https://tv.tedcharles.net/api/guide`
- Stream: `https://tv.tedcharles.net/{slug}.m3u8`
- Static: `https://tv.tedcharles.net/channels/static/_.m3u8`

---

### GET `/manifest.json`

Returns the list of available channels.

**Response:**
```json
{
  "channels": [
    {
      "name": "Star Trek TV",
      "slug": "startrektv"
    },
    {
      "name": "Star Trek Movies",
      "slug": "startrekmovies"
    }
  ],
  "upcoming": []
}
```

**Important Backend Behavior:**

- **Dynamic List:** Only channels with at least one transcoded video segment appear in the manifest
- **Hot Reload:** Backend reloads `channels.json` every 5 minutes - channels can be added/removed without restart
- **Upcoming:** The `upcoming` array contains channels that are defined but not yet ready (still transcoding)

**Usage:** Fetch on app launch and when refreshing channel list.

---

### GET `/{slug}.m3u8`

Returns the HLS master playlist for a specific channel.

**Example:** `/startrektv.m3u8`

**Response:** M3U8 playlist (text/vnd.apple.mpegurl)

```
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:2
#EXT-X-MEDIA-SEQUENCE:12345
#EXTINF:1.920000,
channels/startrektv/videos/abc123/segment_000.ts
#EXTINF:0.960000,
channels/startrektv/videos/abc123/segment_001.ts
#EXT-X-DISCONTINUITY
#EXTINF:1.920000,
channels/startrektv/videos/def456/segment_000.ts
...
```

**Important Backend Behavior:**

- **Live Rolling Playlist:** No `#EXT-X-ENDLIST` tag - treated as a live stream
- **Sliding Window:** Playlist only includes current position + 18 segments ahead (buffer)
- **Discontinuity Tags:** `#EXT-X-DISCONTINUITY` inserted between different video files (important for decoder reset)
- **Looping:** When content loops back to the beginning, media sequence number increments to force player refresh
- **Segment Duration:** Each `.ts` segment is 1-2 seconds
- **Cache Header:** `Cache-Control: max-age=5` - playlist refreshes every 5 seconds
- **Synchronized Playback:** All viewers see the same content at the same time (like real TV)

**Usage:** Load into AVPlayer for channel playback. AVPlayer handles discontinuities and live edge seeking automatically.

---

### GET `/channels/static/_.m3u8`

Returns the HLS playlist for the 16:9 static/loading screen.

**Usage:** Play this stream when:
- App first launches (before selecting a channel)
- During channel transitions
- When connection to a channel fails

---

### GET `/api/guide`

Returns the complete TV guide data for all channels.

**Response:**
```json
{
  "dayStart": 1733107200000,
  "channels": {
    "startrektv": {
      "name": "Star Trek TV",
      "slug": "startrektv",
      "schedule": [
        {
          "title": "Episode Title",
          "startTime": 1733107200000,
          "endTime": 1733113200000,
          "duration": 1800,
          "isCurrent": true
        }
      ]
    }
  }
}
```

**Fields:**
- `dayStart`: UTC timestamp (milliseconds) of 3:00 AM on the current day - used as the left edge of the guide
- `channels`: Object keyed by channel slug
- `schedule[].startTime` / `endTime`: UTC timestamps in milliseconds
- `schedule[].duration`: Duration in seconds
- `schedule[].isCurrent`: Boolean indicating if this show is currently airing

**Important Backend Behavior:**

- **24-Hour Window:** Guide spans from 3:00 AM today to 3:00 AM tomorrow (resets at 3am daily, not midnight)
- **Title Parsing:** Titles are extracted from filenames using these patterns:
  - `Show Name - S01E01 - Episode Title` → extracts "Episode Title"
  - `Show Name - 01 - Episode Title` → extracts "Episode Title"
  - `Movie Name (2024)` → extracts "Movie Name"
  - Fallback: Uses full filename if no pattern matches
- **Episode Merging:** Consecutive episodes under 20 minutes are merged into a single guide entry (prevents clutter)
- **Buffer Offset:** Schedule accounts for 18-segment HLS buffer ahead of "now"
- **Cache:** Guide data is regenerated server-side every 60 seconds
- **Cache Header:** `Cache-Control: no-store, no-cache, must-revalidate` - always fetch fresh

**Usage:** Fetch when user opens TV Guide overlay. Consider caching locally for 30-60 seconds to reduce requests.

---

## Video Playback

### Technology

Use Apple's native `AVPlayer` and `AVPlayerViewController` for HLS playback. tvOS has built-in HLS support - no third-party libraries required.

### Player Configuration

```swift
let playerItem = AVPlayerItem(url: URL(string: "http://\(serverIP):\(serverPort)/\(channelSlug).m3u8")!)
let player = AVPlayer(playerItem: playerItem)

// Configure for live streaming
player.automaticallyWaitsToMinimizeStalling = true

// Seek to live edge (important for live streams)
player.seek(to: CMTime.positiveInfinity)
```

**Live Stream Considerations:**

- **No Seeking:** Users should not be able to rewind or fast-forward (it's live TV)
- **Live Edge:** Always play at the live edge - use `seek(to: .positiveInfinity)` after loading
- **Discontinuity Handling:** AVPlayer handles `#EXT-X-DISCONTINUITY` tags automatically (codec/resolution changes between videos)
- **Buffer Size:** Default AVPlayer buffering is sufficient; the backend provides 18 segments ahead
- **Stall Recovery:** If playback stalls, seek back to live edge rather than waiting for buffer

### Playback States

| State | Description | UI |
|-------|-------------|-----|
| Loading | Fetching playlist/buffering | Show static video stream |
| Playing | Normal playback | Full-screen video |
| Error | Network/playback failure | Show static + error message |

### Static Video Stream

The static video serves as:
1. Initial loading screen when app opens
2. Transition animation between channels
3. Fallback when channel fails to load

**URL:** `http://{serverIP}:{serverPort}/channels/static/_.m3u8`

### Aspect Ratio

- Display video at 16:9 aspect ratio (native Apple TV resolution)
- Video should fill the screen without letterboxing/pillarboxing
- Use `.resizeAspectFill` or `.resizeAspect` as appropriate

### Video Encoding Details

The backend transcodes all videos to these specifications (for reference):

| Property | Value |
|----------|-------|
| Video Codec | H.264 (hardware accelerated when available) |
| Resolution | 640x480 (SD) - configurable on backend |
| Audio Codec | AAC |
| Audio Bitrate | 192 kbps |
| Segment Duration | ~1-2 seconds |
| Container | MPEG-TS (.ts segments) |

Note: All content is transcoded to a consistent format, so the player doesn't need to handle multiple quality levels or adaptive bitrate switching.

---

## Channel Switching

### Navigation

- **Up Arrow / Swipe Up:** Previous channel (wraps from first to last)
- **Down Arrow / Swipe Down:** Next channel (wraps from last to first)

### Channel Index

- Channels are numbered starting at 1 (for display)
- Internal index is 0-based
- Channel -1 represents the static/loading state (no channel selected)

### Switching Flow

1. User presses up/down
2. Calculate new channel index (with wraparound)
3. Display static video stream
4. Show channel overlay (number + name)
5. After 500ms delay, load new channel's HLS stream
6. Begin playback
7. Hide channel overlay after 2 seconds

### Wraparound Logic

```swift
func channelUp() {
    if currentChannelIndex <= 0 {
        currentChannelIndex = channels.count - 1
    } else {
        currentChannelIndex -= 1
    }
    changeChannel(to: currentChannelIndex)
}

func channelDown() {
    if currentChannelIndex >= channels.count - 1 {
        currentChannelIndex = 0
    } else {
        currentChannelIndex += 1
    }
    changeChannel(to: currentChannelIndex)
}
```

---

## Channel Overlay

When a channel is selected or changed, display an overlay with the channel number and name.

### Visual Specifications

**Channel Number (Top-Right Corner):**
- Text: `CH {number}` (e.g., "CH 1", "CH 2")
- Color: Bright green `#00FF00`
- Font: System bold, 48pt equivalent for TV
- Text shadow/glow: Green glow effect (simulate CRT phosphor)
- Position: Top-right corner with 40px padding

**Channel Name (Bottom-Center):**
- Text: Channel name in UPPERCASE (e.g., "STAR TREK TV")
- Color: Bright green `#00FF00`
- Font: System bold, 28pt equivalent for TV
- Text shadow/glow: Green glow effect
- Position: Bottom-center with 60px padding from bottom

### Animation

- Fade in: 0.3 seconds
- Display duration: 2 seconds
- Fade out: 0.3 seconds

### Green Glow Effect

Replicate CRT-style green text:

```swift
// Using shadow layers
label.layer.shadowColor = UIColor.green.cgColor
label.layer.shadowRadius = 10
label.layer.shadowOpacity = 0.8
label.layer.shadowOffset = .zero
```

Or use attributed strings with shadow:

```swift
let shadow = NSShadow()
shadow.shadowBlurRadius = 10
shadow.shadowColor = UIColor(red: 0, green: 1, blue: 0, alpha: 0.8)
shadow.shadowOffset = .zero
```

---

## TV Guide

### Opening the Guide

- **Menu Button (Back Button):** Opens TV Guide overlay
- Guide overlays on top of the playing video (video continues in background, muted or dimmed)

### Closing the Guide

- **Menu Button (Back Button):** Closes guide, returns to video
- **Select on a channel:** Tunes to that channel and closes guide

### Guide Layout

```
┌─────────────────────────────────────────────────────────────────────┐
│  TV GUIDE                                              12:45 PM  X  │
├───────────────┬─────────────────────────────────────────────────────┤
│               │  12:00 PM    12:30 PM    1:00 PM     1:30 PM        │
│               │     │           │           │           │           │
├───────────────┼─────┴───────────┴───────────┴───────────┴───────────┤
│ CH 1          │ ┌─────────────────┬───────────────────────────┐     │
│ Star Trek TV  │ │ Episode Title   │  Movie Title              │     │
│               │ │ 30m             │  2h 15m                   │     │
│               │ └─────────────────┴───────────────────────────┘     │
├───────────────┼─────────────────────────────────────────────────────┤
│ CH 2          │ ┌───────────────────────┬─────────────────────┐     │
│ Star Trek Mov │ │ Film Name             │  Another Film       │     │
│               │ │ 1h 45m                │  2h                 │     │
│               │ └───────────────────────┴─────────────────────┘     │
├───────────────┼─────────────────────────────────────────────────────┤
│               │                    │ ← Red "Now" line                │
└───────────────┴────────────────────┴────────────────────────────────┘
```

### Guide Components

**Header:**
- Title: "TV GUIDE" in green
- Current time display (updates every second)
- Close button (X) - focusable

**Channel List (Left Column):**
- Fixed width: ~200pt
- Each row shows:
  - Channel number (e.g., "CH 1")
  - Channel name
- Current channel highlighted with green background/border
- Vertically scrollable (synced with schedule grid)
- Clicking a channel tunes to it

**Schedule Grid (Right Area):**
- Horizontal timeline spanning 24 hours (3:00 AM to 3:00 AM)
- Scale: 10pt per minute (14,400pt total width)
- Each program block shows:
  - Title (with marquee animation if truncated)
  - Duration
- Current program highlighted with green left border
- Scrollable horizontally and vertically
- Vertical scroll synced with channel list

**Now Line:**
- Vertical red line indicating current time
- Color: Bright red `#FF0000` with glow effect
- Updates position in real-time (refresh every second when guide is open)
- Position calculation:

```swift
// Calculate now line position from left edge of guide
let nowMs = Date().timeIntervalSince1970 * 1000
let pixelsPerMinute: CGFloat = 10.0
let nowLineX = CGFloat(nowMs - Double(guideData.dayStart)) / 60000.0 * pixelsPerMinute
```

### Guide Navigation (Siri Remote)

| Input | Action |
|-------|--------|
| Swipe Up | Scroll channel list up |
| Swipe Down | Scroll channel list down |
| Swipe Left | Scroll timeline backward (earlier) |
| Swipe Right | Scroll timeline forward (later) |
| Click/Select | Tune to focused channel |
| Menu (Back) | Close guide |

### Auto-Scroll Behavior

When guide opens:
1. Scroll horizontally to center the current time (now line)
2. Scroll vertically to show the current channel

### Program Block Sizing

Each program block in the schedule grid is positioned absolutely based on its start time and duration:

```swift
let pixelsPerMinute: CGFloat = 10.0

// Calculate block position and size
let blockLeft = CGFloat(program.startTime - guideData.dayStart) / 60000.0 * pixelsPerMinute
let blockWidth = CGFloat(program.duration) / 60.0 * pixelsPerMinute

// Example: A 30-minute show starting at dayStart + 1 hour
// blockLeft = 60 * 10 = 600 points from left
// blockWidth = 30 * 10 = 300 points wide
```

**Grid Dimensions:**
- Total width: 24 hours × 60 minutes × 10 pixels = 14,400 points
- Row height: ~90 points per channel
- Minimum block width: Ensure at least 60 points for readability

### Marquee Animation for Long Titles

If a program title overflows its container:
- Animate text scrolling left-to-right and back
- Animation duration: 8 seconds
- Only animate when block is in view

---

## Remote Control Mapping

### Video Player View

| Remote Input | Action |
|--------------|--------|
| Swipe Up | Channel up (previous) |
| Swipe Down | Channel down (next) |
| Click Up | Channel up |
| Click Down | Channel down |
| Menu (Back) | Open TV Guide |
| Play/Pause | Toggle play/pause |
| Select (Click) | Show channel overlay momentarily |

### TV Guide View

| Remote Input | Action |
|--------------|--------|
| Swipe Up/Down | Scroll channels vertically |
| Swipe Left/Right | Scroll timeline horizontally |
| Select (Click) | Tune to selected channel |
| Menu (Back) | Close guide, return to video |

### Server Setup View

| Remote Input | Action |
|--------------|--------|
| Swipe/D-pad | Navigate between fields |
| Select (Click) | Activate text field / Submit |
| Menu (Back) | N/A (cannot go back from setup) |

---

## Data Structures

### Swift Models

```swift
struct Channel: Codable, Identifiable {
    let name: String
    let slug: String

    var id: String { slug }
}

struct ChannelManifest: Codable {
    let channels: [Channel]
    let upcoming: [Channel]?
}

struct GuideData: Codable {
    let dayStart: Int64  // Unix timestamp in milliseconds
    let channels: [String: GuideChannel]
}

struct GuideChannel: Codable {
    let name: String
    let slug: String
    let schedule: [Program]
}

struct Program: Codable, Identifiable {
    let title: String
    let startTime: Int64   // Unix timestamp in milliseconds
    let endTime: Int64     // Unix timestamp in milliseconds
    let duration: Int      // Duration in seconds
    let isCurrent: Bool

    var id: String { "\(startTime)-\(title)" }
}

struct ServerConfig: Codable {
    var ipAddress: String
    var port: Int

    var baseURL: String {
        "http://\(ipAddress):\(port)"
    }
}
```

---

## UI/UX Specifications

### Color Palette

| Element | Color | Hex |
|---------|-------|-----|
| Primary Text (Overlays) | Bright Green | `#00FF00` |
| Guide Header | Green | `#00FF00` |
| Now Line | Red | `#FF0000` |
| Current Program Highlight | Dark Green | `#004400` |
| Guide Background | Dark Gray/Black | `#1A1A1A` with 90% opacity |
| Error Text | Red | `#FF4444` |

### Typography

- Channel overlay: Bold, large (48pt number, 28pt name)
- Guide headers: Bold, medium (24pt)
- Program titles: Regular, medium (18pt)
- Time labels: Regular, small (14pt)

### Animations

| Animation | Duration | Easing |
|-----------|----------|--------|
| Channel overlay fade | 0.3s | ease-in-out |
| Guide open/close | 0.3s | ease-out |
| Channel transition (static) | 0.5s | - |
| Now line update | Real-time | - |

### Focus States

For tvOS focus engine:
- Focused channel in guide: Green border, slight scale up (1.05x)
- Focused button: Green highlight
- Default focus on guide open: Current channel

---

## Error Handling

### Network Errors

| Error | User Message | Action |
|-------|--------------|--------|
| Server unreachable | "Unable to connect to server" | Show retry button |
| Channel unavailable | "Channel unavailable" | Show static, allow channel change |
| Stream interrupted | "Stream interrupted. Reconnecting..." | Auto-retry 3 times |
| Guide fetch failed | "Unable to load TV Guide" | Show error in guide, allow retry |

### Recovery Behavior

1. On stream error: Display static, attempt reconnect after 2 seconds
2. After 3 failed reconnects: Show error overlay with option to retry or change channel
3. On guide error: Display partial guide if possible, show refresh button

---

## Persistence

### Stored Data

Using `UserDefaults` or tvOS equivalent:

```swift
// Server configuration
UserDefaults.standard.set(serverIP, forKey: "broadcaster_server_ip")
UserDefaults.standard.set(serverPort, forKey: "broadcaster_server_port")

// Last watched channel (optional enhancement)
UserDefaults.standard.set(lastChannelSlug, forKey: "broadcaster_last_channel")
```

### Data to Persist

| Key | Type | Description |
|-----|------|-------------|
| `broadcaster_server_ip` | String | Server IP address |
| `broadcaster_server_port` | Int | Server port number |
| `broadcaster_last_channel` | String? | Slug of last watched channel (optional) |

---

## Network Considerations

### HTTP vs HTTPS

- **Production server** (`https://tv.tedcharles.net/`): Uses HTTPS - works out of the box
- **Local servers** (`http://192.168.x.x:12121/`): Uses HTTP - requires App Transport Security exception

**Info.plist configuration for local HTTP servers:**

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

Or for more restrictive access (recommended for production):

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>local</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
</dict>
```

### Request Timeouts

Recommended timeout values:
- Manifest/Guide API requests: 10 seconds
- HLS playlist requests: 5 seconds (handled by AVPlayer)
- Segment downloads: Handled by AVPlayer automatically

### Polling Considerations

- **Channel list:** Refresh every 5 minutes (channels can be added/removed dynamically)
- **Guide data:** Fetch fresh when opening guide; optionally cache for 30-60 seconds
- **HLS playlists:** AVPlayer handles polling automatically (backend sets 5-second cache)

---

## Implementation Notes

### tvOS-Specific Considerations

1. **No Web Views:** tvOS does not support WKWebView - all UI must be native SwiftUI or UIKit
2. **Focus Engine:** Use tvOS focus engine for navigation - ensure all interactive elements are focusable
3. **Background Audio:** Consider if audio should continue when guide is open
4. **App Lifecycle:** Handle app going to background and returning - reconnect stream if needed
5. **Memory Management:** HLS streams can be memory-intensive - monitor and handle memory warnings

### Recommended Frameworks

- **UI:** SwiftUI (preferred) or UIKit
- **Video:** AVKit / AVFoundation
- **Networking:** URLSession (built-in) or Alamofire
- **JSON Parsing:** Codable (built-in)

### Project Structure Suggestion

```
BroadcasterTV/
├── App/
│   └── BroadcasterTVApp.swift
├── Views/
│   ├── ServerSetupView.swift
│   ├── VideoPlayerView.swift
│   ├── ChannelOverlayView.swift
│   └── TVGuideView.swift
├── ViewModels/
│   ├── ServerViewModel.swift
│   ├── PlayerViewModel.swift
│   └── GuideViewModel.swift
├── Models/
│   ├── Channel.swift
│   ├── Program.swift
│   └── ServerConfig.swift
├── Services/
│   ├── NetworkService.swift
│   └── PersistenceService.swift
└── Resources/
    └── Assets.xcassets
```

---

## Testing Checklist

### Server Connection
- [ ] First launch shows setup screen
- [ ] Valid IP/port connects successfully
- [ ] Invalid IP/port shows error message
- [ ] Saved config auto-connects on relaunch
- [ ] Failed saved config shows setup with pre-filled values

### Video Playback
- [ ] Static video plays on launch
- [ ] Channels load and play correctly
- [ ] Channel switching shows static briefly
- [ ] Video continues playing when guide is open

### Channel Switching
- [ ] Up/down navigation works
- [ ] Wraparound works (first ↔ last)
- [ ] Channel overlay displays correctly
- [ ] Overlay auto-hides after 2 seconds

### TV Guide
- [ ] Opens with Menu button
- [ ] Closes with Menu button
- [ ] Channels list displays correctly
- [ ] Schedule displays with correct timing
- [ ] Now line shows current time
- [ ] Auto-scrolls to current time on open
- [ ] Selecting channel tunes to it
- [ ] Swipe navigation works in all directions

### Error Handling
- [ ] Network loss handled gracefully
- [ ] Stream errors show static + retry
- [ ] Guide fetch errors show message

---

## Source Reference

For deeper understanding of backend behavior and edge cases, refer to the original Broadcaster source code:

| Component | Path |
|-----------|------|
| Backend HTTP server & API routes | `~/Development/Broadcaster/Webapp/TelevisionUI.js` |
| Playlist generation & HLS logic | `~/Development/Broadcaster/Classes/PlaylistManager.js` |
| Channel management & initialization | `~/Development/Broadcaster/Broadcaster.js` |
| Web frontend (reference implementation) | `~/Development/Broadcaster/Webapp/src/App.jsx` |
| Frontend styling (CSS reference) | `~/Development/Broadcaster/Webapp/src/App.css` |
| Transcoding & segment generation | `~/Development/Broadcaster/Utilities/PreGenerator.js` |

**Key backend details in source:**
- Rolling HLS playlist uses 18-segment lookahead buffer
- `#EXT-X-DISCONTINUITY` tags inserted between different videos
- Media sequence number increments on each playlist loop
- Guide window runs 3:00 AM to 3:00 AM (resets daily)
- M3U8 playlists cached for 5 seconds (`Cache-Control: max-age=5`)
- Segments are 1-2 seconds each
- Title parsing extracts episode names from patterns like `Show - S01E01 - Title`

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2024-12-06 | Initial specification |
