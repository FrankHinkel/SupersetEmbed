#!/bin/bash
# filepath: /Users/frank/Documents/Node-Projekte/SupersetEmbed/get_guest_token.sh

# Konfiguration
SUPERSET_URL="http://192.168.178.10:8088"
USERNAME="admin"
PASSWORD="admin"
DASHBOARD_ID="59ea5070-2cec-4180-86fb-a9264276be90"

# Temporäre Cookie-Datei erstellen
COOKIE_JAR=$(mktemp)

echo "=== Superset Guest Token Generator ==="
echo "Using cookie jar: $COOKIE_JAR"
echo

# Schritt 1: Login und Access Token abrufen (mit Cookie-Speicherung)
echo "1. Logging in to get access token..."
LOGIN_RESPONSE=$(curl -s -X POST "${SUPERSET_URL}/api/v1/security/login" \
  -H "Content-Type: application/json" \
  -c "$COOKIE_JAR" \
  -d "{
        \"username\": \"${USERNAME}\",
        \"password\": \"${PASSWORD}\",
        \"provider\": \"db\",
        \"refresh\": true
      }")

# Access Token extrahieren
ACCESS_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.access_token')

if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
    echo "❌ Error: Could not get access token"
    echo "Response: $LOGIN_RESPONSE"
    rm -f "$COOKIE_JAR"
    exit 1
fi

echo "✅ Access Token retrieved: ${ACCESS_TOKEN:0:50}..."
echo

# Schritt 2: CSRF Token abrufen (mit Cookie-Update)
echo "2. Getting CSRF token..."
CSRF_RESPONSE=$(curl -s -X GET "${SUPERSET_URL}/api/v1/security/csrf_token/" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -b "$COOKIE_JAR" \
  -c "$COOKIE_JAR")

CSRF_TOKEN=$(echo "$CSRF_RESPONSE" | jq -r '.result')

if [ "$CSRF_TOKEN" = "null" ] || [ -z "$CSRF_TOKEN" ]; then
    echo "❌ Error: Could not get CSRF token"
    echo "Response: $CSRF_RESPONSE"
    rm -f "$COOKIE_JAR"
    exit 1
fi

echo "✅ CSRF Token retrieved: ${CSRF_TOKEN:0:50}..."
echo

# Debug: Cookie-Inhalt anzeigen
echo "Debug: Cookie content:"
cat "$COOKIE_JAR"
echo
echo

# Schritt 3: Guest Token generieren (mit angepasstem Payload)
echo "3. Generating guest token for dashboard ID: $DASHBOARD_ID..."
GUEST_TOKEN_RESPONSE=$(curl -s -X POST "${SUPERSET_URL}/api/v1/security/guest_token/" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "X-CSRFToken: ${CSRF_TOKEN}" \
  -H "Referer: ${SUPERSET_URL}/" \
  -b "$COOKIE_JAR" \
  -d "{
        \"user\": {
          \"first_name\": \"embedded\",
          \"last_name\": \"user\",
          \"username\": \"embed\"
        },
        \"resources\": [{
          \"type\": \"dashboard\",
          \"id\": \"${DASHBOARD_ID}\"
        }],
        \"rls\": [],
        \"exp\": 1751227521

      }")

GUEST_TOKEN=$(echo "$GUEST_TOKEN_RESPONSE" | jq -r '.token')

if [ "$GUEST_TOKEN" = "null" ] || [ -z "$GUEST_TOKEN" ]; then
    echo "❌ Error: Could not generate guest token"
    echo "Response: $GUEST_TOKEN_RESPONSE"
    rm -f "$COOKIE_JAR"
    exit 1
fi

echo "✅ Guest Token generated successfully!"
echo
echo "=== RESULTS ==="
echo "Access Token: $ACCESS_TOKEN"
echo
echo "CSRF Token: $CSRF_TOKEN"
echo
echo "Guest Token: $GUEST_TOKEN"
echo
echo "=== COPY THIS FOR YOUR APPLICATION ==="
echo "Guest Token: $GUEST_TOKEN"
echo

# Decode und anzeigen des Guest Tokens
echo "=== DECODED GUEST TOKEN ==="
echo "Header:"
echo "$GUEST_TOKEN" | cut -d'.' -f1 | base64 -d 2>/dev/null | jq . 2>/dev/null || echo "Could not decode header"
echo
echo "Payload:"
echo "$GUEST_TOKEN" | cut -d'.' -f2 | base64 -d 2>/dev/null | jq . 2>/dev/null || echo "Could not decode payload"
echo

# Extrahiere und konvertiere das Ablaufdatum
echo "=== TOKEN EXPIRY INFO ==="
EXP_TIMESTAMP=$(echo "$GUEST_TOKEN" | cut -d'.' -f2 | base64 -d 2>/dev/null | jq -r '.exp' 2>/dev/null)
if [ "$EXP_TIMESTAMP" != "null" ] && [ -n "$EXP_TIMESTAMP" ]; then
    # Entferne Dezimalstellen für macOS-Kompatibilität
    EXP_TIMESTAMP_INT=$(echo "$EXP_TIMESTAMP" | cut -d'.' -f1)
    
    echo "Expires at (Unix timestamp): $EXP_TIMESTAMP"
    echo "Expires at (readable): $(date -r $EXP_TIMESTAMP_INT '+%Y-%m-%d %H:%M:%S %Z')"
    
    # Berechne verbleibende Zeit
    CURRENT_TIME=$(date +%s)
    REMAINING_SECONDS=$((EXP_TIMESTAMP_INT - CURRENT_TIME))
    
    if [ $REMAINING_SECONDS -gt 0 ]; then
        REMAINING_MINUTES=$((REMAINING_SECONDS / 60))
        echo "Token is valid for: $REMAINING_MINUTES minutes ($REMAINING_SECONDS seconds)"
    else
        echo "⚠️  Token has already expired!"
    fi
else
    echo "Could not extract expiry timestamp"
fi
echo

# Cookie-Datei aufräumen
rm -f "$COOKIE_JAR"
echo
echo "Cleanup completed."
