# Quick Start Guide

Get the Communication Gateway up and running in 5 minutes.

## Prerequisites

- Go 1.21 or higher installed
- WhatsApp account

## Steps

### 1. Setup Environment

```bash
cd communication-gateway
cp .env.example .env
```

Edit `.env` if needed (defaults work fine for local testing):
```env
PORT=8080
ENV=development
WHATSAPP_SESSION_DIR=./sessions
WHATSAPP_LOG_LEVEL=INFO
API_KEY=test-api-key
```

### 2. Build & Run

```bash
# Build the service
go build -o bin/communication-gateway ./cmd/server

# Run it
./bin/communication-gateway
```

Or just run directly:
```bash
go run cmd/server/main.go
```

### 3. Authenticate with WhatsApp

In another terminal, get the QR code:

```bash
curl http://localhost:8080/api/v1/qr
```

The response will contain a QR code string. To display it in your terminal:

```bash
# Install qrencode if needed: brew install qrencode (macOS) or apt install qrencode (Linux)
curl http://localhost:8080/api/v1/qr | jq -r '.qr_code' | qrencode -t ANSIUTF8
```

**Scan the QR code** with WhatsApp on your phone:
1. Open WhatsApp
2. Go to Settings > Linked Devices
3. Tap "Link a Device"
4. Scan the QR code from your terminal

### 4. Test Sending a Message

Once connected, send a test message:

```bash
curl -X POST http://localhost:8080/api/v1/send \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer test-api-key" \
  -d '{
    "phone": "1234567890",
    "message": "Hello from Gobi Communication Gateway!"
  }'
```

**Note:** Replace `1234567890` with your actual phone number (including country code, no special characters).

### 5. Check Status

```bash
curl -H "Authorization: Bearer test-api-key" \
  http://localhost:8080/api/v1/status
```

Should return:
```json
{
  "connected": true,
  "authenticated": true,
  "message": "Ready"
}
```

## Next Steps

- See [README.md](./README.md) for full API documentation
- Integrate with other Gobi modules using the REST API
- Deploy using Docker: `docker-compose up -d`

## Troubleshooting

**QR code won't display:**
- Make sure `qrencode` is installed
- Or copy the QR code string and use an online QR code generator

**"Not connected" error:**
- Check if you've scanned the QR code
- Look at the service logs for connection status
- Try restarting the service

**Session expired:**
```bash
rm -rf sessions/
# Restart service and scan QR code again
```
