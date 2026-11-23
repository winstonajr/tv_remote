# Orbita (TV Remote)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.3+-0175C2?style=flat-square&logo=dart)](https://dart.dev)

Flutter remote control for Android TV and TV Boxes implementing the Android TV Remote v2 protocol over local TCP/TLS sockets.

## Features

- **No ADB required**: communicates directly over ports `6467` (pairing) and `6466` (control), matching the official Google TV remote protocol without developer options.
- **6-character pairing**: authenticates on first connection using the pairing code displayed on the TV screen.
- **Demo mode**: runs the UI independently without a physical TV via `--dart-define=DEMO=true`.
- **Automated Android build**: `build.sh` configures network permissions, generates launcher icons, and builds the release APK.

## Quick Start

### Prerequisites

- Flutter SDK (Dart `>=3.3.0 <4.0.0`)

### Running in Demo Mode

```bash
git clone https://github.com/winstonajr/tv_remote.git
cd tv_remote
flutter pub get
flutter run --dart-define=DEMO=true
```

### Building the Release APK

```bash
./build.sh
```

The APK is generated at `build/app/outputs/flutter-apk/app-release.apk`.

## Project Structure

```text
tv_remote/
├── assets/icon/        # App and adaptive launcher icons
├── lib/
│   ├── main.dart       # Application entrypoint
│   ├── theme.dart      # Material theme configuration
│   ├── screens/        # App screens
│   ├── state/          # Connection and remote state management
│   ├── transport/      # Android TV Remote v2 socket/pairing transport
│   └── widgets/        # Reusable UI controls
├── test/               # Widget and unit tests
├── build.sh            # Android manifest setup and release APK build script
└── pubspec.yaml
```

## Development and Testing

```bash
flutter analyze
flutter test
```
