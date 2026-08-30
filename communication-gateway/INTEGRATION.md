# Integration Guide for Other Modules

This guide explains how other Gobi microservices can integrate with the Communication Gateway to send and receive WhatsApp messages.

## Overview

The Communication Gateway exposes a REST API that handles all WhatsApp communication. Your module simply makes HTTP requests to send messages and can register webhooks to receive incoming messages.

## Base URL

```
http://localhost:8080    # Local development
http://communication-gateway:8080    # Docker/Kubernetes internal
```

## Authentication

All protected endpoints require a Bearer token in the Authorization header:

```http
Authorization: Bearer your-api-key
```

The API key is configured via the `API_KEY` environment variable in the Communication Gateway.

## Sending Messages

### Endpoint

```http
POST /api/v1/send
```

### Request

```json
{
  "phone": "1234567890",
  "message": "Your medication reminder text here"
}
```

### Response

Success (200):
```json
{
  "success": true,
  "message": "Message sent successfully"
}
```

Error (400/500):
```json
{
  "success": false,
  "message": "Error details here"
}
```

## Language-Specific Examples

### Go Example

```go
package main

import (
    "bytes"
    "encoding/json"
    "fmt"
    "io"
    "net/http"
)

type SendMessageRequest struct {
    Phone   string `json:"phone"`
    Message string `json:"message"`
}

type SendMessageResponse struct {
    Success bool   `json:"success"`
    Message string `json:"message"`
}

func sendWhatsAppMessage(phone, message, apiKey string) error {
    gatewayURL := "http://localhost:8080/api/v1/send"

    payload := SendMessageRequest{
        Phone:   phone,
        Message: message,
    }

    jsonData, err := json.Marshal(payload)
    if err != nil {
        return fmt.Errorf("failed to marshal request: %w", err)
    }

    req, err := http.NewRequest("POST", gatewayURL, bytes.NewBuffer(jsonData))
    if err != nil {
        return fmt.Errorf("failed to create request: %w", err)
    }

    req.Header.Set("Content-Type", "application/json")
    req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", apiKey))

    client := &http.Client{}
    resp, err := client.Do(req)
    if err != nil {
        return fmt.Errorf("failed to send request: %w", err)
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK {
        body, _ := io.ReadAll(resp.Body)
        return fmt.Errorf("request failed with status %d: %s", resp.StatusCode, string(body))
    }

    var result SendMessageResponse
    if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
        return fmt.Errorf("failed to decode response: %w", err)
    }

    if !result.Success {
        return fmt.Errorf("message sending failed: %s", result.Message)
    }

    return nil
}

// Usage example
func main() {
    err := sendWhatsAppMessage(
        "1234567890",
        "Time to take your Metformin 500mg",
        "your-api-key",
    )
    if err != nil {
        fmt.Printf("Error: %v\n", err)
    }
}
```

### Python Example

```python
import requests
import json

class CommunicationGatewayClient:
    def __init__(self, base_url, api_key):
        self.base_url = base_url
        self.api_key = api_key
        self.headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}"
        }

    def send_message(self, phone, message):
        """Send a WhatsApp message"""
        url = f"{self.base_url}/api/v1/send"
        payload = {
            "phone": phone,
            "message": message
        }

        try:
            response = requests.post(url, json=payload, headers=self.headers)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"Error sending message: {e}")
            return None

    def get_status(self):
        """Check WhatsApp connection status"""
        url = f"{self.base_url}/api/v1/status"
        try:
            response = requests.get(url, headers=self.headers)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"Error getting status: {e}")
            return None

# Usage example
if __name__ == "__main__":
    client = CommunicationGatewayClient(
        base_url="http://localhost:8080",
        api_key="your-api-key"
    )

    # Send a message
    result = client.send_message(
        phone="1234567890",
        message="Reminder: Take your medication"
    )
    print(result)

    # Check status
    status = client.get_status()
    print(status)
```

### Node.js Example

```javascript
const axios = require('axios');

class CommunicationGatewayClient {
  constructor(baseURL, apiKey) {
    this.client = axios.create({
      baseURL: baseURL,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`
      }
    });
  }

  async sendMessage(phone, message) {
    try {
      const response = await this.client.post('/api/v1/send', {
        phone: phone,
        message: message
      });
      return response.data;
    } catch (error) {
      console.error('Error sending message:', error.response?.data || error.message);
      throw error;
    }
  }

  async getStatus() {
    try {
      const response = await this.client.get('/api/v1/status');
      return response.data;
    } catch (error) {
      console.error('Error getting status:', error.response?.data || error.message);
      throw error;
    }
  }
}

// Usage example
const client = new CommunicationGatewayClient(
  'http://localhost:8080',
  'your-api-key'
);

(async () => {
  // Send a message
  const result = await client.sendMessage(
    '1234567890',
    'Reminder: Take your medication'
  );
  console.log(result);

  // Check status
  const status = await client.getStatus();
  console.log(status);
})();
```

### cURL Example

```bash
#!/bin/bash

API_KEY="your-api-key"
GATEWAY_URL="http://localhost:8080"

# Function to send WhatsApp message
send_message() {
    local phone=$1
    local message=$2

    curl -X POST "${GATEWAY_URL}/api/v1/send" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${API_KEY}" \
        -d "{
            \"phone\": \"${phone}\",
            \"message\": \"${message}\"
        }"
}

# Function to check status
check_status() {
    curl -H "Authorization: Bearer ${API_KEY}" \
        "${GATEWAY_URL}/api/v1/status"
}

# Usage
send_message "1234567890" "Time to take your medication"
check_status
```

## Receiving Messages (Webhooks)

**Coming Soon**: The webhook system for receiving incoming messages will be implemented in Phase 2.

When implemented, your service will be able to register a webhook endpoint to receive incoming messages:

```json
POST /api/v1/webhook/register
{
  "url": "http://your-service:port/whatsapp-webhook",
  "events": ["message"]
}
```

Your webhook will receive payloads like:

```json
{
  "phone": "1234567890",
  "message": "User's reply here",
  "timestamp": 1693123456
}
```

## Phone Number Format

**Important:** Phone numbers must:
- Include country code (e.g., `1` for US, `91` for India)
- Contain only digits
- Have NO special characters (no `+`, `-`, spaces, parentheses)

Examples:
- ✅ `15551234567` (US number)
- ✅ `919876543210` (India number)
- ❌ `+1 (555) 123-4567`
- ❌ `555-123-4567`

## Error Handling

Always check the `success` field in responses:

```go
result, err := sendMessage(phone, msg)
if err != nil {
    log.Printf("HTTP error: %v", err)
    return err
}

if !result.Success {
    log.Printf("Message failed: %s", result.Message)
    return fmt.Errorf("failed to send: %s", result.Message)
}
```

Common error scenarios:
- `503 Service Unavailable`: WhatsApp not connected
- `401 Unauthorized`: Invalid API key
- `400 Bad Request`: Invalid phone number or missing fields
- `500 Internal Server Error`: Server-side error

## Docker Compose Integration

If your module runs in Docker Compose, add the Communication Gateway as a dependency:

```yaml
version: '3.8'

services:
  communication-gateway:
    build: ../communication-gateway
    ports:
      - "8080:8080"
    environment:
      - API_KEY=shared-secret-key
    volumes:
      - ./sessions:/app/sessions
    restart: unless-stopped

  your-service:
    build: .
    depends_on:
      - communication-gateway
    environment:
      - GATEWAY_URL=http://communication-gateway:8080
      - GATEWAY_API_KEY=shared-secret-key
```

## Environment Variables for Your Service

Add these to your service's `.env`:

```env
# Communication Gateway Configuration
COMMUNICATION_GATEWAY_URL=http://localhost:8080
COMMUNICATION_GATEWAY_API_KEY=your-api-key
```

## Health Checks

Before sending messages, verify the gateway is healthy:

```bash
curl http://localhost:8080/health
```

Response:
```json
{
  "status": "healthy",
  "service": "communication-gateway",
  "time": 1693123456
}
```

And check WhatsApp connection status:

```bash
curl -H "Authorization: Bearer your-api-key" \
  http://localhost:8080/api/v1/status
```

## Best Practices

1. **Retry Logic**: Implement exponential backoff for failed sends
2. **Rate Limiting**: Don't send messages too quickly (WhatsApp may block)
3. **Health Checks**: Verify gateway status before critical operations
4. **Error Logging**: Log all failures for debugging
5. **Configuration**: Use environment variables for gateway URL and API key
6. **Testing**: Use mock responses in tests, don't hit the real gateway

## Example: Medication Reminder Service

Here's a complete example of how the Medication Service might integrate:

```go
package medication

import (
    "fmt"
    "log"
    "os"
    "time"

    "your-module/internal/gateway"
)

type ReminderService struct {
    gatewayClient *gateway.Client
}

func NewReminderService() *ReminderService {
    return &ReminderService{
        gatewayClient: gateway.NewClient(
            os.Getenv("COMMUNICATION_GATEWAY_URL"),
            os.Getenv("COMMUNICATION_GATEWAY_API_KEY"),
        ),
    }
}

func (s *ReminderService) SendReminder(phone, medName, dosage string) error {
    message := fmt.Sprintf(
        "⏰ Medication Reminder\n\n"+
        "Time to take: %s\n"+
        "Dosage: %s\n\n"+
        "Reply 'Taken' to confirm or 'Snooze' to delay 15 minutes.",
        medName,
        dosage,
    )

    // Check if gateway is ready
    if !s.isGatewayReady() {
        return fmt.Errorf("communication gateway not ready")
    }

    // Send with retry
    var err error
    for attempt := 1; attempt <= 3; attempt++ {
        err = s.gatewayClient.SendMessage(phone, message)
        if err == nil {
            log.Printf("Reminder sent to %s for %s", phone, medName)
            return nil
        }

        log.Printf("Attempt %d failed: %v", attempt, err)
        time.Sleep(time.Duration(attempt) * time.Second)
    }

    return fmt.Errorf("failed after 3 attempts: %w", err)
}

func (s *ReminderService) isGatewayReady() bool {
    status, err := s.gatewayClient.GetStatus()
    if err != nil {
        log.Printf("Failed to check gateway status: %v", err)
        return false
    }
    return status.Connected && status.Authenticated
}
```

## Support

For issues or questions:
- Check the Communication Gateway logs
- Verify your API key and environment variables
- Ensure the gateway is running and authenticated with WhatsApp
- See the main README.md for troubleshooting steps
