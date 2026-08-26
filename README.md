# ChalkBoard 🖍️

A real-time collaborative chalkboard Flutter application that lets two people draw on the same canvas simultaneously across devices over the Internet or local Wi-Fi.

---

## ✨ Features

- **Real-Time Synchronized Drawing**:
  - Point-by-point live stroke streaming (watch strokes appear as your partner is drawing them, not only after they lift their finger).
  - Smooth Bézier curve interpolation for silky fluid lines.
  - Normalized coordinate system (`0.0` to `1.0`) ensuring drawings scale consistently across phones, tablets, and desktops of varying screen sizes and aspect ratios.

- **Live Peer Cursors & Presence**:
  - See your partner's live touch position, name tag, tool, and active color moving in real time.
  - Pulsing drawing indicator ring when the other user is actively drawing.

- **Full Drawing Toolkit**:
  - **Chalk**: Authentic chalkboard texture and chalk dust effect.
  - **Pen / Marker**: Solid clean vector lines.
  - **Highlighter**: Translucent wide strokes.
  - **Chalk Eraser**: Clean erasing brush.
  - **Palette**: Quick chalkboard presets + full HSV color wheel.
  - **Brush Size**: Adjustable stroke width (fine to ultra) with live preview.

- **Collaborative History & Board Management**:
  - User-specific Undo & Redo (undo your own last stroke without removing your partner's work).
  - Clear board with safety confirmation.
  - Multiple board themes (Classic Dark Forest Chalkboard, Dark Slate, Deep Blackboard, Whiteboard).
  - Canvas state auto-synchronization when a partner joins mid-session.

- **Export & Share**:
  - High-resolution PNG export of the board.
  - Native system share sheet integration.

- **Flexible Multiplayer Networking**:
  - **Cloud / WebSocket Relay**: Connects anywhere over the internet.
  - **Built-in Direct Wi-Fi Host**: One tap inside the app turns your device into a local WebSocket server—no cloud or API keys needed.
  - **QR Code & 6-character Room Codes**: Instant pairing by scanning a QR code or entering a room code.

---

## 🚀 Getting Started

### 1. Run the Flutter App

From the `chalk_board` directory:

```bash
cd chalk_board
flutter run
```

Supports Android, iOS, Web, macOS, Linux, and Windows.

---

## 🌐 Multiplayer Connection Options

### Option A: Built-in Direct Wi-Fi (No Server Setup Needed)
1. Device 1 taps **"Host Wi-Fi"** on the home screen.
2. Device 2 taps **"Join Wi-Fi"** and enters the IP and Room Code displayed on Device 1 (or scans the QR code).

### Option B: Dedicated WebSocket Relay Server (For Internet Play)

You can run the included lightweight relay server locally or deploy it to Render, Fly.io, Railway, or any VPS:

**Using Dart:**
```bash
dart run server/bin/server.dart
```

**Using Node.js:**
```bash
cd server
npm install ws
node server.js
```

In the app, tap the **Settings** gear icon in the top right and enter your server's WebSocket URL (e.g. `wss://your-chalkboard-relay.onrender.com/ws`).
