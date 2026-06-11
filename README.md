# Jarvis Desktop Agent 🚀

AI-powered personal assistant with social media integration, built with Flutter.

## Features

- 🤖 **Hybrid AI Engine** - opencode + Ollama (local) + 300+ cloud models
- 🧠 **Persistent Memory** - FTS5 search + User modeling
- 🎯 **Skills Marketplace** - Import 13,700+ skills + Self-improving
- 👥 **Multi-Agent System** - 8 agent types + Sub-agents
- 📱 **Social Media Integration** - Telegram, Discord, WhatsApp, Instagram, Facebook, Slack
- 🖥️ **System Control** - Shutdown, Restart, Sleep, Lock, Monitor
- 🎤 **Voice Support** - English + Hindi (STT + TTS)
- 📁 **File Management** - Read, Write, Organize, Search
- 🌤️ **Weather** - OpenWeatherMap API
- 🌐 **Browser Automation** - URL opening, Web scraping
- ⏰ **Scheduler** - Natural language reminders + Cron
- 🎨 **Modern UI** - Flutter Desktop with streaming chat

## Getting Started

### Prerequisites

- Flutter SDK 3.x
- Dart SDK 3.x
- macOS or Windows

### Installation

```bash
# Clone the repository
git clone https://github.com/vickydont007/jarivis-dont007.git
cd jarivis-dont007

# Install dependencies
flutter pub get

# Run the app
flutter run -d macos  # For macOS
flutter run -d windows  # For Windows
```

### Platform-Specific Setup

#### macOS

1. Enable permissions:
   - System Settings → Privacy → Accessibility → Allow Jarvis
   - System Settings → Privacy → Automation → Allow Jarvis

2. Run the app:
   ```bash
   flutter run -d macos
   ```

#### Windows

1. Run the app:
   ```bash
   flutter run -d windows
   ```

## Configuration

### AI Provider

1. Open Settings in the app
2. Select your AI provider (opencode, ollama, openai, anthropic, gemini)
3. Enter your API key
4. Save settings

### Social Media

#### Telegram

1. Create a bot via @BotFather
2. Get your bot token
3. Enter the token in Settings → Social Media → Telegram Bot Token

#### Discord

1. Create a bot at Discord Developer Portal
2. Get your bot token
3. Enter the token in Settings → Social Media → Discord Bot Token

### Weather

1. Get an API key from OpenWeatherMap
2. Enter the key in Settings → Weather Settings → API Key

## Architecture

```
lib/
├── core/           # AI Engine, Memory, Skills, Security
├── models/         # Data models
├── services/       # All services (AI, System, File, Weather, Voice, Social)
├── screens/        # UI screens
├── widgets/        # Reusable widgets
├── platform/       # macOS/Windows native code
├── social/         # Social media integrations
├── utils/          # Constants and utilities
├── app.dart        # App configuration
└── main.dart       # Entry point
```

## Tech Stack

- **Framework:** Flutter 3.x
- **Language:** Dart
- **State Management:** Riverpod
- **AI:** opencode, Ollama, OpenAI, Anthropic, Gemini
- **Voice:** speech_to_text, flutter_tts
- **Storage:** SQLite (FTS5), SharedPreferences
- **Networking:** Dio, WebSocket

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [OpenJarvis](https://github.com/open-jarvis/OpenJarvis) - Local-first AI framework
- [Hermes Desktop](https://github.com/NousResearch/hermes-agent) - AI agent platform
- [Flutter](https://flutter.dev/) - Cross-platform UI framework
