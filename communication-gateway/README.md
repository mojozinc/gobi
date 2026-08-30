# Communication Gateway

A standalone WhatsApp gateway microservice that provides REST API endpoints for sending and receiving WhatsApp messages. Built with Go and whatsmeow, this service acts as the communication layer for Project Gobi's modular architecture.

## Features

- **WhatsApp Integration**: Connect to WhatsApp using the unofficial whatsmeow library
- **REST API**: Simple HTTP endpoints for sending messages and checking status
- **Session Management**: Persistent sessions stored in SQLite
- **QR Code Authentication**: Easy pairing via QR code scan
- **Event Handling**: Extensible event system for processing incoming messages
- **Docker Support**: Containerized deployment with Docker and Docker Compose
- **API Authentication**: Bearer token authentication for protected endpoints

## Prerequisites

- Go 1.21 or higher
- Docker and Docker Compose (optional, for containerized deployment)
- WhatsApp account

## Installation

### Local Development

1. **Clone the repository** (if not already in the gobi project):
   ```bash
   cd gobi/communication-gateway
   ```

2. **Install Go dependencies**:
   ```bash
   go mod download
   ```

3. **Create environment file**:
   ```bash
   cp .env.example .env
   ```

4. **Edit `.env` file** with your configuration:
   ```env
   PORT=8080
   ENV=development
   WHATSAPP_SESSION_DIR=./sessions
   WHATSAPP_LOG_LEVEL=INFO
   API_KEY=your-secret-api-key-here
   ```

5. **Run the service**:
   ```bash
   go run cmd/server/main.go
   ```

### Docker Deployment

1. **Build and start the container**:
   ```bash
   docker-compose up -d
   ```

2. **View logs**:
   ```bash
   docker-compose logs -f
   ```

3. **Stop the service**:
   ```bash
   docker-compose down
   ```

## API Documentation

### Base URL
```
http://localhost:8080
```

### Authentication

Protected endpoints require a Bearer token in the Authorization header:
```bash
Authorization: Bearer your-secret-api-key
```

---

### Endpoints

#### 1. Health Check
Check if the service is running.

**Request:**
```http
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "service": "communication-gateway",
  "time": 1693123456
}
```

---

#### 2. Get QR Code
Generate a QR code for WhatsApp authentication. Scan this with your WhatsApp app.

**Request:**
```http
GET /api/v1/qr
```

**Response:**
```json
{
  "qr_code": "2@xxxxxxxxxxx...",
  "message": "Scan this QR code with WhatsApp"
}
```

**Usage:**
```bash
# Get QR code and display in terminal (requires qrencode)
curl http://localhost:8080/api/v1/qr | jq -r '.qr_code' | qrencode -t ANSIUTF8
```

---

#### 3. Get Status
Check WhatsApp connection and authentication status.

**Request:**
```http
GET /api/v1/status
Authorization: Bearer your-api-key
```

**Response:**
```json
{
  "connected": true,
  "authenticated": true,
  "message": "Ready"
}
```

---

#### 4. Send Message
Send a text message to a WhatsApp number.

**Request:**
```http
POST /api/v1/send
Authorization: Bearer your-api-key
Content-Type: application/json

{
  "phone": "1234567890",
  "message": "Hello from Gobi!"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Message sent successfully"
}
```

**Phone Number Format:**
- Include country code (e.g., `1234567890` for US)
- No special characters (no `+`, `-`, spaces)
- Example: US number `+1 (555) 123-4567` becomes `15551234567`

---

#### 5. Webhook (for incoming messages)
This endpoint is called internally when messages are received. Other microservices can register to receive these events.

**Request:**
```http
POST /webhook
Content-Type: application/json

{
  "phone": "1234567890",
  "message": "Hello!",
  "timestamp": 1693123456
}
```

---

## Integration Guide for Other Modules

Other microservices can integrate with the Communication Gateway using simple HTTP calls:

### Example: Medication Service Sending a Reminder

```go
package main

import (
    "bytes"
    "encoding/json"
    "net/http"
)

type SendMessageRequest struct {
    Phone   string `json:"phone"`
    Message string `json:"message"`
}

func sendReminder(phone string, message string) error {
    payload := SendMessageRequest{
        Phone:   phone,
        Message: message,
    }

    body, _ := json.Marshal(payload)

    req, _ := http.NewRequest(
        "POST",
        "http://localhost:8080/api/v1/send",
        bytes.NewBuffer(body),
    )

    req.Header.Set("Content-Type", "application/json")
    req.Header.Set("Authorization", "Bearer your-api-key")

    client := &http.Client{}
    resp, err := client.Do(req)
    if err != nil {
        return err
    }
    defer resp.Body.Close()

    return nil
}
```

### Example: Using cURL

```bash
# Send a medication reminder
curl -X POST http://localhost:8080/api/v1/send \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-api-key" \
  -d '{
    "phone": "1234567890",
    "message": "Reminder: Take your Metformin 500mg now"
  }'
```

## Project Structure

```
communication-gateway/
├── cmd/
│   └── server/
│       └── main.go              # Application entry point
├── internal/
│   ├── api/
│   │   ├── handlers.go          # HTTP request handlers
│   │   ├── middleware.go        # Authentication, CORS
│   │   └── server.go            # HTTP server setup
│   ├── config/
│   │   └── config.go            # Configuration management
│   └── whatsapp/
│       ├── client.go            # WhatsApp client wrapper
│       └── handlers.go          # Message event handlers
├── .env.example                 # Environment variables template
├── .gitignore
├── docker-compose.yml           # Docker Compose configuration
├── Dockerfile                   # Container build instructions
├── go.mod                       # Go module definition
└── README.md                    # This file
```

## Configuration

All configuration is done via environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | HTTP server port | `8080` |
| `ENV` | Environment (development/production) | `development` |
| `WHATSAPP_SESSION_DIR` | Directory for session storage | `./sessions` |
| `WHATSAPP_LOG_LEVEL` | Logging level (DEBUG/INFO/WARN/ERROR) | `INFO` |
| `API_KEY` | API key for authentication | (none) |

## Session Management

WhatsApp sessions are stored in SQLite database in the configured `WHATSAPP_SESSION_DIR`. Once authenticated via QR code, the session persists across restarts.

**Important:** Keep the `sessions/` directory backed up to avoid re-authentication.

## Troubleshooting

### "Not connected to WhatsApp" error
1. Check if authenticated: `GET /api/v1/status`
2. If not authenticated, get QR code: `GET /api/v1/qr`
3. Scan QR code with WhatsApp app
4. Wait for connection (check logs)

### Session expired
If your session expires, simply restart the authentication flow:
1. Delete the `sessions/` directory
2. Restart the service
3. Get a new QR code and scan

### Phone number format issues
Ensure phone numbers:
- Include country code
- Contain only digits
- Have no special characters

## Security Notes

- **API Key**: Always use a strong API key in production
- **HTTPS**: Deploy behind a reverse proxy with SSL in production
- **Session Storage**: Protect the `sessions/` directory - it contains authentication credentials
- **Unofficial API**: whatsmeow is an unofficial library; WhatsApp may block accounts using it

## Future Enhancements

- [ ] Support for media messages (images, PDFs, audio)
- [ ] Webhook routing to registered module endpoints
- [ ] Rate limiting for outbound messages
- [ ] Message queue for high-volume sending
- [ ] Support for group messages
- [ ] Message delivery status tracking
- [ ] Multi-device session support

## Contributing

This service is part of Project Gobi. For contribution guidelines, see the main project README.

## License

See the main Project Gobi repository for license information.
