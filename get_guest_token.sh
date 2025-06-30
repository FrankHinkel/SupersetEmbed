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
echo "Verwende Cookie-Jar: $COOKIE_JAR"
echo

# Schritt 1: Anmeldung und Access Token abrufen (mit Cookie-Speicherung)
echo "1. Anmeldung um Access Token zu erhalten..."
LOGIN_RESPONSE=$(curl -s -X POST "${SUPERSET_URL}/api/v1/security/login" \
  -H "Content-Type: application/json" \
  -c "$COOKIE_JAR" \
  -d "{
        \"username\": \"${USERNAME}\",
        \"password\": \"${PASSWORD}\",
        \"provider\": \"db\",
        \"refresh\": true
      }")

# Access Token aus der Antwort extrahieren
ACCESS_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.access_token')

if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
    echo "❌ Fehler: Konnte Access Token nicht erhalten"
    echo "Antwort: $LOGIN_RESPONSE"
    rm -f "$COOKIE_JAR"
    exit 1
fi

echo "✅ Access Token erhalten: ${ACCESS_TOKEN:0:50}..."
echo

# Schritt 2: CSRF Token abrufen (mit Cookie-Update)
echo "2. CSRF Token wird abgerufen..."
CSRF_RESPONSE=$(curl -s -X GET "${SUPERSET_URL}/api/v1/security/csrf_token/" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -b "$COOKIE_JAR" \
  -c "$COOKIE_JAR")

CSRF_TOKEN=$(echo "$CSRF_RESPONSE" | jq -r '.result')

if [ "$CSRF_TOKEN" = "null" ] || [ -z "$CSRF_TOKEN" ]; then
    echo "❌ Fehler: Konnte CSRF Token nicht erhalten"
    echo "Antwort: $CSRF_RESPONSE"
    rm -f "$COOKIE_JAR"
    exit 1
fi

echo "✅ CSRF Token erhalten: ${CSRF_TOKEN:0:50}..."
echo

# Debug: Cookie-Inhalt anzeigen
echo "Debug: Cookie-Inhalt:"
cat "$COOKIE_JAR"
echo
echo

# Schritt 3: Guest Token generieren (mit angepasstem Payload)
echo "3. Guest Token wird für Dashboard ID generiert: $DASHBOARD_ID..."
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
    echo "❌ Fehler: Konnte Guest Token nicht generieren"
    echo "Antwort: $GUEST_TOKEN_RESPONSE"
    rm -f "$COOKIE_JAR"
    exit 1
fi

echo "✅ Guest Token erfolgreich generiert!"
echo
echo "=== ERGEBNISSE ==="
echo "Access Token: $ACCESS_TOKEN"
echo
echo "CSRF Token: $CSRF_TOKEN"
echo
echo "Guest Token: $GUEST_TOKEN"
echo
echo "=== ZUM KOPIEREN FÜR IHRE ANWENDUNG ==="
echo "Guest Token: $GUEST_TOKEN"
echo

# Guest Token dekodieren und anzeigen
echo "=== DEKODIERTES GUEST TOKEN ==="
echo "Header:"
echo "$GUEST_TOKEN" | cut -d'.' -f1 | base64 -d 2>/dev/null | jq . 2>/dev/null || echo "Konnte Header nicht dekodieren"
echo
echo "Payload:"
echo "$GUEST_TOKEN" | cut -d'.' -f2 | base64 -d 2>/dev/null | jq . 2>/dev/null || echo "Konnte Payload nicht dekodieren"
echo

# Ablaufdatum extrahieren und konvertieren
echo "=== TOKEN ABLAUF-INFORMATIONEN ==="
EXP_TIMESTAMP=$(echo "$GUEST_TOKEN" | cut -d'.' -f2 | base64 -d 2>/dev/null | jq -r '.exp' 2>/dev/null)
if [ "$EXP_TIMESTAMP" != "null" ] && [ -n "$EXP_TIMESTAMP" ]; then
    # Dezimalstellen für macOS-Kompatibilität entfernen
    EXP_TIMESTAMP_INT=$(echo "$EXP_TIMESTAMP" | cut -d'.' -f1)
    
    echo "Läuft ab am (Unix-Zeitstempel): $EXP_TIMESTAMP"
    echo "Läuft ab am (lesbar): $(date -r $EXP_TIMESTAMP_INT '+%Y-%m-%d %H:%M:%S %Z')"
    
    # Verbleibende Zeit berechnen
    CURRENT_TIME=$(date +%s)
    REMAINING_SECONDS=$((EXP_TIMESTAMP_INT - CURRENT_TIME))
    
    if [ $REMAINING_SECONDS -gt 0 ]; then
        REMAINING_MINUTES=$((REMAINING_SECONDS / 60))
        echo "Token ist gültig für: $REMAINING_MINUTES Minuten ($REMAINING_SECONDS Sekunden)"
    else
        echo "⚠️  Token ist bereits abgelaufen!"
    fi
else
    echo "Konnte Ablauf-Zeitstempel nicht extrahieren"
fi
echo

# Cookie-Datei aufräumen
rm -f "$COOKIE_JAR"
echo
echo "Aufräumen abgeschlossen."
