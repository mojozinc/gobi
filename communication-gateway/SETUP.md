# WhatsApp Bot Setup Guide

This guide will help you set up your WhatsApp bot in 3 steps.

## Prerequisites

- A dedicated phone number for your bot (can be a new SIM or old number)
- WhatsApp installed on your phone with that number
- Go installed on your server

## Step 1: Start the Service

```bash
cd communication-gateway

# Create environment file
cp .env.example .env

# Build and run
go run cmd/server/main.go
```

You should see:
```
No existing session found. Call GET /api/v1/qr to authenticate
Starting server on :8080
```

## Step 2: Generate and Scan QR Code

### Option A: Using the Helper Script (Easiest)

```bash
# In another terminal
./scripts/show-qr.sh
```

This will display the QR code in your terminal (if you have `qrencode` installed) or give you a link to generate it online.

### Option B: Manual Method

1. **Get the QR code:**
   ```bash
   curl http://localhost:8080/api/v1/qr
   ```

2. **Display it in terminal (if qrencode is installed):**
   ```bash
   # Install qrencode first:
   # macOS: brew install qrencode
   # Linux: sudo apt install qrencode

   curl -s http://localhost:8080/api/v1/qr | jq -r '.qr_code' | qrencode -t ANSIUTF8
   ```

3. **Or generate QR online:**
   ```bash
   # Get the URL
   QR_DATA=$(curl -s http://localhost:8080/api/v1/qr | jq -r '.qr_code')

   # Visit this link in your browser:
   echo "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=$QR_DATA"
   ```

### Option C: Use Online QR Generator

1. Get the QR code data:
   ```bash
   curl http://localhost:8080/api/v1/qr | jq -r '.qr_code'
   ```

2. Copy the output (it looks like: `https://wa.me/settings/linked_devices#2@...`)

3. Go to https://www.qr-code-generator.com/

4. Paste the URL and generate QR code

5. Scan it with WhatsApp

## Step 3: Link Your WhatsApp

1. **Open WhatsApp** on your phone

2. **Go to Settings** (or tap the three dots menu)

3. **Tap "Linked Devices"**

4. **Tap "Link a Device"**

5. **Scan the QR code** from Step 2

6. **Wait for confirmation**

You should see in your server logs:
```
WhatsApp connected successfully
WhatsApp pairing successful
```

## Step 4: Verify It Works

Check the status:
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

Send a test message to yourself:
```bash
curl -X POST http://localhost:8080/api/v1/send \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer test-api-key" \
  -d '{
    "phone": "YOUR_PHONE_NUMBER",
    "message": "Hello! Bot is working!"
  }'
```

Replace `YOUR_PHONE_NUMBER` with your number (include country code, e.g., `1234567890`)

## Troubleshooting

### QR Code Won't Scan

**Problem:** WhatsApp says "Invalid QR code"

**Solutions:**
1. Make sure you're using the FULL URL including `https://wa.me/settings/linked_devices#`
2. Try generating a new QR code (they expire after ~30 seconds)
3. Make sure the QR code is clear and not distorted

### "Already authenticated" Error

Your bot is already linked! Check status:
```bash
curl http://localhost:8080/api/v1/status
```

If you want to re-link:
```bash
# Stop the service
# Delete session
rm -rf sessions/
# Start service again
go run cmd/server/main.go
# Get new QR code
./scripts/show-qr.sh
```

### Service Won't Start

Check if port 8080 is already in use:
```bash
lsof -i :8080
```

Kill the existing process or change the port in `.env`:
```env
PORT=8081
```

### Connection Drops

WhatsApp sessions can expire. The service will try to reconnect automatically. If it fails:

1. Check your internet connection
2. Restart the service
3. If still failing, delete sessions and re-link:
   ```bash
   rm -rf sessions/
   ```

## Understanding the Bot Number

**Important:** The phone number you use for scanning the QR code becomes your **bot's number**.

- Users will send messages TO this number
- Bot will send messages FROM this number
- Use a dedicated number (not your personal WhatsApp)

### Recommended Setup

1. Get a new SIM card OR use an old number
2. Activate WhatsApp on that number
3. Link it to your server using QR code
4. Share this number with your users

## Next Steps

Once linked:

1. **Users can message your bot:**
   - They save your bot's number
   - Send messages like: "Metformin 500mg twice daily"
   - Bot receives and processes them

2. **Bot can send messages:**
   - Medication reminders
   - Stock alerts
   - Confirmations

3. **Integrate with other services:**
   - See [INTEGRATION.md](./INTEGRATION.md) for examples
   - Other modules can use the REST API to send messages

## Production Deployment

For production:

1. **Use Docker:**
   ```bash
   docker-compose up -d
   ```

2. **Set a strong API key** in `.env`:
   ```env
   API_KEY=your-very-secret-key-here
   ```

3. **Keep sessions backed up:**
   ```bash
   # Backup
   tar -czf sessions-backup.tar.gz sessions/

   # Restore if needed
   tar -xzf sessions-backup.tar.gz
   ```

4. **Monitor the logs:**
   ```bash
   # If running with Docker
   docker-compose logs -f

   # If running directly
   tail -f service.log
   ```

## Security Notes

⚠️ **Important:**

- Keep your `sessions/` directory secure (contains auth tokens)
- Use a strong API_KEY in production
- Don't share your QR code or session files
- WhatsApp may ban accounts using unofficial APIs (whatsmeow is unofficial)
- For production, consider official WhatsApp Business API

## Support

If you're still having issues:

1. Check the service logs
2. Verify your phone has internet
3. Try with a different phone number
4. See [README.md](./README.md) for full documentation
