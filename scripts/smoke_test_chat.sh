#!/usr/bin/env bash
set -e

API_BASE="${API_BASE:-http://127.0.0.1:8000}"
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}        Gobi AI Chat API Smoke & Sanity Test           ${NC}"
echo -e "${BLUE}======================================================${NC}"
echo -e "Target API: ${YELLOW}${API_BASE}${NC}\n"

# 1. Health Check
echo -ne "1. Testing backend health... "
HEALTH_RES=$(curl -s -w "\n%{http_code}" "${API_BASE}/health")
HEALTH_STATUS=$(echo "$HEALTH_RES" | tail -n1)
HEALTH_BODY=$(echo "$HEALTH_RES" | sed '$d')

if [ "$HEALTH_STATUS" -ne 200 ]; then
    echo -e "${RED}FAILED (HTTP $HEALTH_STATUS)${NC}"
    echo "Response: $HEALTH_BODY"
    exit 1
fi
echo -e "${GREEN}OK (200)${NC}"

# 2. Anonymous Auth
echo -ne "2. Authenticating as test user... "
AUTH_RES=$(curl -s -w "\n%{http_code}" -X POST "${API_BASE}/api/v1/auth/anonymous" \
  -H "Content-Type: application/json" \
  -d '{"device_id": "smoke_test_runner", "name": "Smoke Test User"}')
AUTH_STATUS=$(echo "$AUTH_RES" | tail -n1)
AUTH_BODY=$(echo "$AUTH_RES" | sed '$d')

if [ "$AUTH_STATUS" -ne 200 ]; then
    echo -e "${RED}FAILED (HTTP $AUTH_STATUS)${NC}"
    echo "Response: $AUTH_BODY"
    exit 1
fi

TOKEN=$(echo "$AUTH_BODY" | jq -r '.token // empty')
if [ -z "$TOKEN" ]; then
    echo -e "${RED}FAILED (No token in response)${NC}"
    echo "Response: $AUTH_BODY"
    exit 1
fi
echo -e "${GREEN}OK (Token generated)${NC}"

# 3. AI Health Chat Query
QUERY="${1:-What medications do I have scheduled for today?}"
echo -ne "3. Sending chat query: \"${QUERY}\"... "

START_TIME=$(date +%s%N)
CHAT_RES=$(curl -s -w "\n%{http_code}" -X POST "${API_BASE}/api/v1/ai/chat" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"query\": \"${QUERY}\", \"conversation_history\": []}")
END_TIME=$(date +%s%N)
DURATION_MS=$(( (END_TIME - START_TIME) / 1000000 ))

CHAT_STATUS=$(echo "$CHAT_RES" | tail -n1)
CHAT_BODY=$(echo "$CHAT_RES" | sed '$d')

if [ "$CHAT_STATUS" -ne 200 ]; then
    echo -e "${RED}FAILED (HTTP $CHAT_STATUS in ${DURATION_MS}ms)${NC}"
    echo "Response: $CHAT_BODY"
    exit 1
fi

RESPONSE_TEXT=$(echo "$CHAT_BODY" | jq -r '.response // empty')
if [ -z "$RESPONSE_TEXT" ]; then
    echo -e "${RED}FAILED (Empty response)${NC}"
    echo "Response: $CHAT_BODY"
    exit 1
fi

echo -e "${GREEN}OK (200 in ${DURATION_MS}ms)${NC}\n"
echo -e "${BLUE}--- Response Preview ---${NC}"
echo -e "$RESPONSE_TEXT"
echo -e "${BLUE}------------------------${NC}\n"

echo -e "${GREEN}🎉 All AI Chat smoke tests PASSED successfully!${NC}"
