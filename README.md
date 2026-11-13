# AI Assistant

> An open-source, customizable AI companion chat app for Android.
> Plug in your own LLM backend — any OpenAI-compatible API works out of the box.

---

## Features

- **Multi-provider support** — Built-in presets for DeepSeek, Qwen, GLM, Kimi, Doubao (Volcengine), SiliconFlow, OpenAI, and Anthropic Claude. Add any custom OpenAI-compatible endpoint with one tap.
- **Conversation management** — Full conversation history, rename, delete, and switch between chats. All data stored locally via Hive — nothing leaves your device unless you send it to an AI provider.
- **Persona system** — Pre-built personas for daily chat, dating advice, and workplace scenarios. Create your own custom personas with system prompts.
- **Topic library** — Hand-curated conversation starters categorized by scene (ice-breaker, flirting, workplace, etc.). Tap to send instantly.
- **Favorites** — Bookmark any message for quick reference later.
- **Markdown rendering** — AI replies rendered with full Markdown support (code blocks, tables, lists).
- **Dark-first UI** — Clean, modern dark theme built with Material 3.
- **Secure credential storage** — API keys encrypted at rest via `flutter_secure_storage`.

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (≥ 3.19) / Dart (≥ 3.3) |
| State management | Provider |
| HTTP client | Dio |
| Local database | Hive |
| Persistent storage | flutter_secure_storage |
| UI | Material Design 3, flutter_markdown |
| Platform | Android (minSdk defined by Flutter defaults) |

## Getting Started

### Prerequisites

- Flutter SDK ≥ 3.19
- JDK 17
- Android SDK (platform-tools + platform 36 + build-tools 36.0.0)

### Build

```bash
cd ai_assistant

# Install dependencies
flutter pub get

# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release
```

### First Run

1. Launch the app.
2. Pick a preset provider (or choose "Custom") and fill in: **Base URL**, **API Key**, and **Model name**.
3. Start chatting. That's it.

## Project Structure

```
ai_assistant/
├── lib/
│   ├── config/              # Preset AI providers & config models
│   ├── data/                # Static topic card library
│   ├── models/              # Hive data models
│   ├── providers/           # Provider state management
│   ├── screens/             # UI screens
│   │   ├── chat/
│   │   ├── favorites/
│   │   ├── home/
│   │   ├── settings/
│   │   └── topics/
│   ├── services/
│   │   ├── ai/              # AI provider service (Dio + retry)
│   │   ├── floating/        # Floating window service
│   │   └── storage/         # Hive adapters & box helpers
│   ├── theme/               # App theme
│   └── main.dart
├── android/                 # Native Android project
├── pubspec.yaml
└── BUILD.md                 # Detailed build guide (中文)
```

## License

MIT
