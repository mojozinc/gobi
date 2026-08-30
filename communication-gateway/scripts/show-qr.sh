#!/bin/bash

# Simple script to display WhatsApp QR code for pairing

echo "Fetching QR code from Communication Gateway..."
echo ""

# Get QR code from API
RESPONSE=$(curl -s http://localhost:8080/api/v1/qr)

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed"
    echo "Install it with: brew install jq (macOS) or apt install jq (Linux)"
    exit 1
fi

# Extract QR code data (full URL)
QR_URL=$(echo "$RESPONSE" | jq -r '.qr_code')

if [ "$QR_URL" = "null" ] || [ -z "$QR_URL" ]; then
    MESSAGE=$(echo "$RESPONSE" | jq -r '.message')
    echo "Error: $MESSAGE"
    exit 1
fi

# Extract ONLY the data after the # (this is what WhatsApp expects!)
QR_DATA="${QR_URL#*#}"

echo "WhatsApp pairing data extracted"
echo ""

# Check if qrencode is installed
if command -v qrencode &> /dev/null; then
    echo "Scan this QR code with WhatsApp:"
    echo ""
    echo "$QR_DATA" | qrencode -t ANSIUTF8
    echo ""
else
    echo "Install qrencode to display QR in terminal:"
    echo "  macOS: brew install qrencode"
    echo "  Linux: sudo apt install qrencode"
    echo ""
    echo "Or visit this URL to generate QR code online:"
    echo "  https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=$(echo -n "$QR_DATA" | jq -sRr @uri)"
    echo ""
    echo "Or run manually:"
    echo "  QR_DATA='$QR_DATA'"
    echo "  echo \"\$QR_DATA\" | qrencode -t ANSIUTF8"
fi

echo ""
echo "Steps to link:"
echo "1. Open WhatsApp on your phone"
echo "2. Go to Settings → Linked Devices"
echo "3. Tap 'Link a Device'"
echo "4. Scan the QR code above"
