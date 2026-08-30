# Changelog

All notable changes to Project Gobi will be documented in this file.

## [1.0.0] - 2024-08-30

### Added - Phase 1: Platform Foundation

#### Backend API
- Go REST API with Gin framework
- PostgreSQL database with automatic migrations
- User authentication system (register, login, JWT)
- User profile management (get, update)
- Middleware for authentication and CORS
- Docker and Docker Compose configuration
- Comprehensive API documentation

#### Mobile App
- Flutter cross-platform app (iOS + Android)
- User authentication screens (splash, login, register)
- Home dashboard with health overview
- Bottom navigation with 5 sections
- Settings screen with profile display
- Theme toggle (light/dark mode)
- Beautiful Material Design 3 UI
- Health-themed color palette
- Riverpod state management
- Dio HTTP client with interceptors
- Placeholder screens for future features:
  - Medications
  - Documents
  - Family management

#### Documentation
- Main README with project overview
- Backend API README with API docs
- Mobile app README with setup guide
- Complete SETUP_GUIDE for both components
- Changelog (this file)

### Technical Highlights
- Clean architecture with separation of concerns
- Type-safe API models
- Secure password hashing with bcrypt
- JWT-based authentication
- Responsive UI design
- Error handling and loading states
- Session persistence

### Infrastructure
- Docker containerization
- PostgreSQL database
- Automated database migrations
- Environment-based configuration
- Health check endpoints

---

## Roadmap

### [2.0.0] - Phase 2: Medication Management (Planned)
- Add medication CRUD operations
- Implement medication schedules
- Push notification system
- Medication reminders
- Inventory tracking
- Refill alerts
- Adherence tracking and history
- Calendar view of medications

### [3.0.0] - Phase 3: Document Management (Planned)
- Camera integration
- Document scanning (prescriptions, reports)
- OCR text extraction
- Document storage and organization
- Search and filtering
- Secure sharing

### [4.0.0] - Phase 4: Family Profiles (Planned)
- Add family members/dependents
- Individual health profiles
- Separate medication schedules per member
- Family health timeline
- Switch between family member views

### [5.0.0] - Phase 5: Advanced Features (Planned)
- Consultation transcription
- Health insights and analytics
- Secure second opinion sharing
- Data export capabilities
- Backup and restore

---

## Version History

- **1.0.0** (2024-08-30): Initial release with mobile app platform and backend API
