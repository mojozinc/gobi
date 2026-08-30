# Gobi Backend API

REST API backend for Project Gobi mobile app, built with Go, Gin, and PostgreSQL.

## Features

- User registration and authentication with JWT
- User profile management
- PostgreSQL database with migrations
- Docker support for easy deployment
- CORS enabled for mobile app integration

## Prerequisites

- Go 1.21 or higher
- PostgreSQL 15+ (or use Docker)
- Docker and Docker Compose (optional)

## Quick Start

### Using Docker (Recommended)

1. Start all services:
```bash
make docker-up
```

2. Check health:
```bash
curl http://localhost:8000/health
```

3. Stop services:
```bash
make docker-down
```

### Local Development

1. Install dependencies:
```bash
go mod download
```

2. Create `.env` file:
```bash
cp .env.example .env
# Edit .env with your database credentials
```

3. Start PostgreSQL (or use Docker):
```bash
docker run -d \
  --name gobi-postgres \
  -e POSTGRES_USER=gobi \
  -e POSTGRES_PASSWORD=gobi_password \
  -e POSTGRES_DB=gobi_db \
  -p 5432:5432 \
  postgres:15-alpine
```

4. Run the server:
```bash
make run
```

## API Endpoints

### Health Check
```bash
GET /health
```

### Authentication

#### Register
```bash
POST /api/v1/auth/register
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123",
  "name": "John Doe",
  "phone": "+1234567890"
}
```

#### Login
```bash
POST /api/v1/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123"
}
```

Response:
```json
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "name": "John Doe",
    "phone": "+1234567890",
    "photo_url": "",
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-01T00:00:00Z"
  }
}
```

### User Profile (Protected)

#### Get Profile
```bash
GET /api/v1/profile
Authorization: Bearer <token>
```

#### Update Profile
```bash
PUT /api/v1/profile
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "Jane Doe",
  "phone": "+9876543210",
  "photo_url": "https://example.com/photo.jpg"
}
```

## Project Structure

```
backend-api/
├── cmd/
│   └── server/
│       └── main.go           # Application entry point
├── internal/
│   ├── api/
│   │   └── handlers.go       # HTTP handlers
│   ├── auth/
│   │   └── auth.go          # JWT & password hashing
│   ├── config/
│   │   └── config.go        # Configuration
│   ├── database/
│   │   └── database.go      # DB connection & migrations
│   ├── middleware/
│   │   ├── auth.go          # Auth middleware
│   │   └── cors.go          # CORS middleware
│   └── models/
│       └── user.go          # Data models
├── .env.example             # Environment template
├── docker-compose.yml       # Docker services
├── Dockerfile              # Container build
├── Makefile               # Build commands
└── README.md
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Server port | `8000` |
| `ENV` | Environment (development/production) | `development` |
| `DB_HOST` | Database host | `localhost` |
| `DB_PORT` | Database port | `5432` |
| `DB_USER` | Database user | `gobi` |
| `DB_PASSWORD` | Database password | `gobi_password` |
| `DB_NAME` | Database name | `gobi_db` |
| `DB_SSLMODE` | SSL mode | `disable` |
| `JWT_SECRET` | JWT signing secret | (required in production) |
| `JWT_EXPIRY_HOURS` | Token expiry in hours | `72` |

## Testing

Test the API with curl:

```bash
# Register a user
curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123",
    "name": "Test User",
    "phone": "+1234567890"
  }'

# Login
TOKEN=$(curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }' | jq -r '.token')

# Get profile
curl http://localhost:8000/api/v1/profile \
  -H "Authorization: Bearer $TOKEN"

# Update profile
curl -X PUT http://localhost:8000/api/v1/profile \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Updated Name",
    "phone": "+9999999999"
  }'
```

## Security Notes

- Always use a strong `JWT_SECRET` in production
- Deploy behind HTTPS in production
- Use strong database passwords
- Keep `.env` file out of version control

## License

Part of Project Gobi
