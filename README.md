# Jarvis Desktop Agent 🚀

Cross-platform personal desktop agent for **Windows + macOS**.  
Connects to **Hermes AI** for intelligent task execution, automation, and system control.

## Features

- 🤖 **Hermes AI Integration** — Real-time WebSocket connection
- 🖥️ **System Control** — Shutdown, restart, sleep, lock, monitor
- 📂 **File Management** — Read, write, organize, clean up
- 🌐 **Browser Automation** — Open URLs, scrape data, manage tabs
- ⏰ **Scheduler** — Cron-like task scheduling
- 📊 **System Monitor** — CPU, RAM, Disk usage with alerts
- 🔔 **Desktop Notifications** — Native Win/Mac notifications
- 🎯 **Multi-Agent Ready** — Expand with plugins and custom scripts

## Quick Start

### Prerequisites
- Flutter SDK 3.x ([Install guide](https://flutter.dev/docs/get-started/install))
- Git

### Setup

```bash
# Clone the repo
git clone https://github.com/vickydont007/jarivis-dont007.git
cd jarivis-dont007

# Get dependencies
flutter pub get

# Run the app
flutter run
```

### Platform-Specific

**macOS:**
```bash
# Enable permissions
# System Settings → Privacy → Accessibility → Allow Jarvis
# System Settings → Privacy → Automation → Allow Jarvis

flutter run -d macos
```

**Windows:**
```bash
flutter run -d windows
```

## Connecting to Hermes

1. Launch the app
2. Go to **Settings** tab
3. Enter WebSocket URL (default: `ws://localhost:8765/ws`)
4. Click **Connect**

## Commands

The app accepts these commands from Hermes:

| Command | Description |
|---------|-------------|
| `terminal.run` | Execute shell commands |
| `file.read/write/list` | File operations |
| `file.organize` | Auto-clean Downloads |
| `system.info` | CPU/RAM/Disk stats |
| `system.shutdown/restart/sleep/lock` | System control |
| `app.open` | Launch applications |
| `browser.open` | Open URLs |
| `notification.show` | Desktop notification |
| `ping` | Health check |

## Architecture

```
lib/
├── core/           # Platform detection, constants, logger
├── models/         # Data models (task, command, system_info)
├── services/       # Core services (hermes, terminal, file, etc.)
├── platform/       # Platform-specific commands (win/mac)
├── screens/        # UI screens (dashboard, tasks, settings, logs)
└── widgets/        # Reusable widgets (status_card, etc.)
```

## Tech Stack

- **Flutter 3.x** — Cross-platform desktop UI
- **WebSocket** — Real-time Hermes communication
- **Provider** — Simple state management
- **PowerShell/AppleScript** — Native system control

## License

MIT
