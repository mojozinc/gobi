# Gobi Mobile App

Flutter mobile application for Project Gobi - Your Personal Medical Assistant.

## Overview

Gobi Mobile is a cross-platform (iOS + Android) Flutter app that helps users manage their health records, medications, and family medical information securely. Built with data sovereignty in mind, the app provides a private environment for managing sensitive medical data.

## Features (Phase 1 - Platform Foundation)

### ✅ Implemented
- **Authentication System**
  - User registration and login
  - JWT-based authentication
  - Secure session management
  - Auto-login on app restart

- **Home Dashboard**
  - Welcome screen with user greeting
  - Quick overview of health stats
  - Coming soon feature previews

- **Bottom Navigation**
  - 5 main sections: Home, Medications, Documents, Family, Settings
  - Clean, intuitive navigation
  - Material Design 3

- **Settings**
  - User profile display
  - Theme toggle (Light/Dark mode)
  - App information
  - Logout functionality

- **UI/UX**
  - Beautiful health-themed color scheme
  - Responsive layouts
  - Loading states and error handling
  - Smooth animations

### 🚧 Coming Soon (Phase 2+)
- **Medications**: Track medications, set reminders, manage inventory
- **Documents**: Scan and store prescriptions, OCR text extraction
- **Family**: Manage multiple family member profiles
- **Health Insights**: Track and analyze health trends

## Tech Stack

- **Framework**: Flutter 3.x
- **Language**: Dart 3.x
- **State Management**: Riverpod 2.x
- **Networking**: Dio 5.x
- **Local Storage**: SharedPreferences, Hive
- **UI**: Material Design 3
- **Fonts**: Google Fonts (Inter)

## Prerequisites

- Flutter SDK 3.0.0 or higher
- Dart SDK 3.0.0 or higher
- iOS Simulator / Android Emulator OR Physical device
- Backend API running (see `../backend-api`)

## Installation

### 1. Install Flutter

Follow the official Flutter installation guide:
https://docs.flutter.dev/get-started/install

Verify installation:
```bash
flutter doctor
```

### 2. Clone and Setup

```bash
cd gobi-mobile

# Get dependencies
flutter pub get
```

### 3. Backend URL Configuration & Environment Variables

The backend API URL can be passed at build/run time via `--dart-define`, without editing source code:

- **Default (Local via ADB reverse / Emulator)**: `http://127.0.0.1:8000`
- **Custom URL / Wi-Fi LAN IP**:
  ```bash
  flutter run --dart-define=API_BASE_URL=http://192.168.0.109:8000
  ```

#### Automatic ADB Reverse Tunneling (`API_BASE_URL_PORT`)
For Android devices (USB or wireless ADB), Gradle automatically runs `adb reverse` before building.
To customize the port forwarded by Gradle, set the environment variable:
- **Linux/macOS:**
  ```bash
  export API_BASE_URL_PORT=8000
  ```
- **Windows (PowerShell):**
  ```powershell
  $env:API_BASE_URL_PORT="8000"
  ```
- **Windows (CMD):**
  ```cmd
  set API_BASE_URL_PORT=8000
  ```

### 4. Run the App

#### Linux / macOS
```bash
# Run on connected device/emulator (defaults to http://127.0.0.1:8000)
flutter run

# Run with custom backend URL
flutter run --dart-define=API_BASE_URL=http://192.168.0.109:8000
```

#### Windows
```powershell
# 1. (Optional) If connecting wirelessly, pair and connect ADB:
adb connect <PHONE_IP>:<PORT>

# 2. Run the mobile app with local backend tunnel (PowerShell):
flutter run

# Or with a custom backend IP:
flutter run --dart-define=API_BASE_URL=http://192.168.0.109:8000
```

## Project Structure

```
lib/
├── main.dart                      # App entry point
├── core/
│   ├── config/
│   │   └── app_config.dart       # API URLs, constants
│   ├── constants/
│   │   └── app_colors.dart       # Color palette
│   ├── theme/
│   │   └── app_theme.dart        # Light/Dark themes
│   └── providers/
│       └── app_providers.dart    # Riverpod providers
├── data/
│   ├── api/
│   │   └── api_client.dart       # Dio HTTP client
│   ├── models/
│   │   └── user.dart             # Data models
│   └── repositories/
│       └── auth_repository.dart  # Business logic
└── features/
    ├── auth/
    │   └── screens/              # Login, Register, Splash
    ├── home/
    │   └── screens/              # Dashboard, Navigation
    ├── medications/
    │   └── screens/              # Medications (placeholder)
    ├── documents/
    │   └── screens/              # Documents (placeholder)
    ├── family/
    │   └── screens/              # Family (placeholder)
    └── settings/
        └── screens/              # Settings, Profile
```

## API Integration

The app communicates with the Go backend API:

### Authentication Endpoints
- `POST /api/v1/auth/register` - User registration
- `POST /api/v1/auth/login` - User login

### User Profile Endpoints
- `GET /api/v1/profile` - Get user profile
- `PUT /api/v1/profile` - Update profile

See `../backend-api/README.md` for full API documentation.

## State Management

Using Riverpod for state management:

- **authStateProvider**: Manages authentication state
- **themeModeProvider**: Manages theme (light/dark)
- **apiClientProvider**: Provides Dio HTTP client
- **authRepositoryProvider**: Provides auth business logic

## Building for Production

### Android APK
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

### iOS IPA
```bash
flutter build ios --release
```

### Android App Bundle (for Play Store)
```bash
flutter build appbundle --release
```

## Development Tips

### Hot Reload
While running `flutter run`, press:
- `r` - Hot reload
- `R` - Hot restart
- `q` - Quit

### Debugging
```bash
# Run in debug mode with verbose logging
flutter run --debug

# Check logs
flutter logs
```

### Code Generation
If you add/modify Hive models:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
```

## Common Issues

### 1. "Unable to connect to backend"
- Ensure backend is running on `localhost:8000`
- Check `app_config.dart` has correct IP
- For Android emulator, use `10.0.2.2:8000`

### 2. "Certificate verification failed"
- For development, backend should use HTTP (not HTTPS)
- For production, ensure valid SSL certificate

### 3. "Plugin not found"
```bash
flutter clean
flutter pub get
```

## Roadmap

### Phase 2: Medication Management
- Add medication CRUD operations
- Implement reminder system
- Inventory tracking

### Phase 3: Document Management
- Camera integration
- OCR for prescriptions
- Document storage & search

### Phase 4: Family Profiles
- Multi-user support
- Dependent management
- Shared medication schedules

## Contributing

This is part of Project Gobi. See main project README for contribution guidelines.

## License

See main Project Gobi repository for license information.

## Support

For issues or questions:
1. Check this README
2. Check backend API documentation
3. Review Flutter documentation: https://docs.flutter.dev
4. Check Riverpod docs: https://riverpod.dev
