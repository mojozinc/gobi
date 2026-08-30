# Project Gobi - Complete Setup Guide

This guide will help you set up and run the complete Project Gobi platform: Backend API + Flutter Mobile App.

## 🎯 Overview

Project Gobi consists of two main components:
1. **Backend API** - Go REST API with PostgreSQL
2. **Mobile App** - Flutter app for iOS and Android

## 📋 Prerequisites

### Backend Requirements
- Docker & Docker Compose (recommended) OR
- Go 1.21+
- PostgreSQL 15+

### Mobile Requirements
- Flutter SDK 3.0+
- iOS Simulator OR Android Emulator
- Xcode (for iOS development on Mac)
- Android Studio (for Android development)

## 🚀 Quick Start (Recommended)

### Step 1: Start Backend with Docker

```bash
cd backend-api
docker-compose up -d
```

This will start:
- PostgreSQL database on port 5432
- Backend API on port 8000

Verify backend is running:
```bash
curl http://localhost:8000/health
```

### Step 2: Configure Mobile App

Edit `gobi-mobile/lib/core/config/app_config.dart`:

```dart
// For iOS Simulator
static const String baseUrl = 'http://localhost:8000';

// For Android Emulator
static const String baseUrl = 'http://10.0.2.2:8000';

// For Physical Device (replace with your computer's IP)
static const String baseUrl = 'http://192.168.1.100:8000';
```

### Step 3: Run Mobile App

```bash
cd gobi-mobile
flutter pub get
flutter run
```

## 📱 Complete Workflow

### 1. First Time Setup

#### Backend Setup
```bash
cd backend-api

# Copy environment template
cp .env.example .env

# Start services
docker-compose up -d

# Check logs
docker-compose logs -f backend

# Verify health
curl http://localhost:8000/health
```

#### Mobile Setup
```bash
cd gobi-mobile

# Install dependencies
flutter pub get

# Check Flutter setup
flutter doctor

# List available devices
flutter devices

# Run on specific device
flutter run -d <device-id>
```

### 2. Testing the Complete Flow

#### A. Register a User (Mobile App)
1. Launch the app
2. Click "Sign Up" on login screen
3. Fill in:
   - Name: John Doe
   - Email: john@example.com
   - Phone: +1234567890 (optional)
   - Password: password123
4. Click "Create Account"

#### B. Verify in Backend
```bash
# Access database
docker exec -it gobi-postgres psql -U gobi -d gobi_db

# Check user
SELECT * FROM users;
```

#### C. Explore the App
- **Home**: View dashboard and coming soon features
- **Medications**: See placeholder for future features
- **Documents**: See placeholder for future features
- **Family**: See placeholder for future features
- **Settings**:
  - View profile
  - Toggle dark/light theme
  - Logout

### 3. Development Workflow

#### Backend Changes
```bash
cd backend-api

# Make code changes...

# Rebuild and restart
docker-compose down
docker-compose up -d --build

# View logs
docker-compose logs -f backend
```

#### Mobile Changes
```bash
cd gobi-mobile

# Make code changes...

# Flutter hot reload is automatic while running
# Just save your files and see changes instantly

# Or restart
# Press 'R' in terminal running flutter
```

## 🔧 Detailed Setup

### Backend API - Manual Setup (without Docker)

```bash
cd backend-api

# Install Go dependencies
go mod download

# Setup PostgreSQL
psql -U postgres
CREATE DATABASE gobi_db;
CREATE USER gobi WITH PASSWORD 'gobi_password';
GRANT ALL PRIVILEGES ON DATABASE gobi_db TO gobi;
\q

# Configure .env
cp .env.example .env
# Edit .env with your database credentials

# Run migrations and start server
go run cmd/server/main.go
```

### Mobile App - Platform Specific Setup

#### iOS Setup (Mac Only)
```bash
cd gobi-mobile/ios
pod install
cd ..

# Run on iOS
flutter run -d iPhone
```

#### Android Setup
```bash
# Run on Android
flutter run -d Android

# Or build APK
flutter build apk
```

## 🌐 Network Configuration

### Finding Your Computer's IP

#### macOS/Linux
```bash
ifconfig | grep "inet "
# or
ipconfig getifaddr en0
```

#### Windows
```bash
ipconfig
```

### Firewall Rules

If mobile device can't connect:

#### macOS
```bash
# Allow port 8000
sudo pfctl -d  # Disable firewall temporarily for testing
```

#### Windows
Add inbound rule for port 8000 in Windows Firewall

#### Linux
```bash
sudo ufw allow 8000
```

## 🧪 Testing API Endpoints

### Register User
```bash
curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123",
    "name": "Test User",
    "phone": "+1234567890"
  }'
```

### Login
```bash
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
```

### Get Profile (with token)
```bash
TOKEN="<token-from-login>"

curl http://localhost:8000/api/v1/profile \
  -H "Authorization: Bearer $TOKEN"
```

## 🐛 Troubleshooting

### Backend Issues

#### "Failed to connect to database"
```bash
# Check if PostgreSQL is running
docker ps | grep postgres

# Check logs
docker logs gobi-postgres

# Restart services
docker-compose restart
```

#### "Port 8000 already in use"
```bash
# Find process using port 8000
lsof -i :8000

# Kill process
kill -9 <PID>
```

### Mobile Issues

#### "Unable to connect to backend"
1. Verify backend is running: `curl http://localhost:8000/health`
2. Check `app_config.dart` has correct IP
3. For Android emulator, use `10.0.2.2:8000`
4. For physical device, use computer's IP on same network

#### "Plugin not found" or build errors
```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..  # iOS only
flutter run
```

#### "No connected devices"
```bash
# Check available devices
flutter devices

# Start emulator
flutter emulators --launch <emulator-id>

# For iOS
open -a Simulator
```

## 📊 Monitoring & Logs

### Backend Logs
```bash
# Docker logs
docker-compose logs -f backend

# Specific number of lines
docker-compose logs --tail=100 backend

# PostgreSQL logs
docker-compose logs -f postgres
```

### Mobile Logs
```bash
# Flutter logs
flutter logs

# Or while running
# Logs appear in terminal automatically
```

## 🔐 Security Notes

### Development
- Default JWT secret is insecure - only for development
- CORS is wide open - only for development
- HTTP (not HTTPS) - only for development

### Production Checklist
- [ ] Change JWT_SECRET to strong random value
- [ ] Configure proper CORS origins
- [ ] Use HTTPS with valid SSL certificate
- [ ] Use strong database passwords
- [ ] Enable PostgreSQL SSL mode
- [ ] Configure proper firewall rules
- [ ] Set ENV=production
- [ ] Remove debug logging

## 📱 Building for Production

### Backend
```bash
cd backend-api

# Build binary
go build -o server cmd/server/main.go

# Or use Docker
docker build -t gobi-backend:latest .
```

### Mobile

#### Android
```bash
cd gobi-mobile

# Build APK
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle --release
```

#### iOS
```bash
cd gobi-mobile

# Build for App Store
flutter build ios --release

# Archive in Xcode
open ios/Runner.xcworkspace
# Product > Archive
```

## 🎓 Next Steps

Now that you have the platform running:

1. **Explore the App**: Try all screens and features
2. **Test API**: Use curl or Postman to test endpoints
3. **Read Code**: Understand the architecture
4. **Plan Features**: Review Phase 2 roadmap (Medications module)
5. **Contribute**: Add new features or fix bugs

## 📚 Additional Resources

- [Backend API Documentation](backend-api/README.md)
- [Mobile App Documentation](gobi-mobile/README.md)
- [Flutter Documentation](https://docs.flutter.dev)
- [Go Documentation](https://go.dev/doc)
- [PostgreSQL Documentation](https://www.postgresql.org/docs)

## 💬 Support

For questions or issues:
1. Check this guide
2. Review component-specific READMEs
3. Check troubleshooting section
4. Search existing issues
5. Open a new issue with detailed description

Happy coding! 🚀
