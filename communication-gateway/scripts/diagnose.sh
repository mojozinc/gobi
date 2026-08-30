#!/bin/bash

echo "=== WhatsApp Bot Diagnostics ==="
echo ""

# Check if service is running
if curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo "✓ Service is running"
else
    echo "✗ Service is NOT running"
    echo "  Start it with: go run cmd/server/main.go"
    exit 1
fi

echo ""
echo "Getting QR code data..."

QR_RESPONSE=$(curl -s http://localhost:8080/api/v1/qr)
QR_CODE=$(echo "$QR_RESPONSE" | jq -r '.qr_code' 2>/dev/null)

if [ "$QR_CODE" = "null" ] || [ -z "$QR_CODE" ]; then
    echo "✗ Failed to get QR code"
    echo "Response: $QR_RESPONSE"
    exit 1
fi

echo "✓ QR code generated"
echo ""
echo "QR Code format check:"
echo "  Length: ${#QR_CODE} characters"

if [[ $QR_CODE == https://wa.me/settings/linked_devices#* ]]; then
    echo "  Format: ✓ Correct (wa.me URL format)"
else
    echo "  Format: ✗ Unexpected format"
fi

echo ""
echo "=== Troubleshooting Steps ==="
echo ""
echo "1. WhatsApp Version:"
echo "   - Make sure you have the latest WhatsApp"
echo "   - Update from Play Store / App Store"
echo ""
echo "2. Multi-Device Beta:"
echo "   - Open WhatsApp → Settings → Linked Devices"
echo "   - Look for 'Multi-device beta' and enable it"
echo ""
echo "3. Try WhatsApp Web first:"
echo "   - Go to https://web.whatsapp.com"
echo "   - Scan that QR code to verify linking works"
echo "   - If that works, our bot should work too"
echo ""
echo "4. Account Status:"
echo "   - New accounts (< 14 days) may have restrictions"
echo "   - Business accounts work better for bots"
echo ""
echo "5. Alternative: Use WhatsApp Business API"
echo "   - Official API (costs money)"
echo "   - Or switch to Telegram (100% free, better API)"

