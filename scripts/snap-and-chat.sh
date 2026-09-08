#!/usr/bin/env bash
set -e

DEVICE_IP=192.168.0.106
DEVICE_PORT=38787

# Ensure adb and agy paths are available
export PATH="$HOME/android-sdk/platform-tools:$HOME/development/flutter/bin:$HOME/.gemini/antigravity-cli/bin:$HOME/.local/bin:$PATH"

SCREENSHOT_PATH="/tmp/gobi_screenshot.png"

# Find connected ADB device
DEVICE=$(adb devices | grep -v "List of devices" | grep "device$" | awk '{print $1}' | head -n 1)

if [ -z "$DEVICE" ]; then
    echo "⚠️  No ADB device currently attached. Attempting reconnect..."
    adb connect $DEVICE_IP:$DEVICE_PORT >/dev/null 2>&1 || true
    DEVICE=$(adb devices | grep -v "List of devices" | grep "device$" | awk '{print $1}' | head -n 1)
fi

if [ -z "$DEVICE" ]; then
    echo "❌ Error: No ADB device connected. Please ensure Wireless Debugging is enabled on your phone."
    exit 1
fi

echo "📸 Capturing screenshot from device: $DEVICE..."
# Wake display if asleep
adb -s "$DEVICE" shell input keyevent KEYCODE_WAKEUP 2>/dev/null || true
sleep 0.3

# Capture screenshot
adb -s "$DEVICE" exec-out screencap -p > "$SCREENSHOT_PATH"

if [ ! -s "$SCREENSHOT_PATH" ]; then
    echo "❌ Failed to capture screenshot."
    exit 1
fi

echo "✅ Screenshot saved to $SCREENSHOT_PATH"

# Build prompt with optional user arguments
USER_QUERY="$*"
if [ -z "$USER_QUERY" ]; then
    INITIAL_PROMPT="I have captured a live screenshot of the connected Android device ($DEVICE) saved at $SCREENSHOT_PATH. Please view this file using view_file and analyze the current UI and state."
else
    INITIAL_PROMPT="I have captured a live screenshot of the connected Android device ($DEVICE) saved at $SCREENSHOT_PATH. Please view this file using view_file and assist with: $USER_QUERY"
fi

echo "🚀 Launching agy chat with screenshot context..."
exec agy -i "$INITIAL_PROMPT"
