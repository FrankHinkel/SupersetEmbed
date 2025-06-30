# Superset Guest Token Generator

Ein Bash-Skript zum automatischen Generieren von Superset Guest-Token für Dashboard-Einbettungen.

## Das komplette Skript

```bash
#!/bin/bash
# Datei: get_guest_token.sh

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
```

## Übersicht

Dieses Skript führt den kompletten Workflow zur Generierung eines Superset Guest-Token durch:
1. Anmeldung bei Superset und Abrufen eines Access-Token
2. Abrufen eines CSRF-Token für sichere API-Aufrufe
3. Generierung eines Guest-Token mit spezifischen Berechtigungen
4. Dekodierung und Anzeige der Token-Informationen

## Voraussetzungen

- `curl` - für HTTP-Requests
- `jq` - für JSON-Verarbeitung
- `base64` - für Token-Dekodierung (normalerweise vorinstalliert)
- Zugang zu einer laufenden Superset-Instanz

## Installation der Abhängigkeiten

```bash
# macOS mit Homebrew
brew install jq

# Ubuntu/Debian
sudo apt-get install jq curl

# CentOS/RHEL
sudo yum install jq curl
```

## Konfiguration

Das Skript verwendet folgende Konfigurationsvariablen:

```bash
# Superset-Server URL
SUPERSET_URL="http://192.168.178.10:8088"

# Admin-Anmeldedaten für Token-Generierung
USERNAME="admin"
PASSWORD="admin"

# Dashboard-ID für die das Guest-Token erstellt werden soll
DASHBOARD_ID="59ea5070-2cec-4180-86fb-a9264276be90"
```

## Verwendung

```bash
# Skript ausführbar machen
chmod +x get_guest_token.sh

# Skript ausführen
./get_guest_token.sh
```

## Funktionsweise

### Schritt 1: Anmeldung und Access Token

Das Skript meldet sich bei Superset an und erhält ein langlebiges Access-Token:

```bash
LOGIN_RESPONSE=$(curl -s -X POST "${SUPERSET_URL}/api/v1/security/login" \
  -H "Content-Type: application/json" \
  -c "$COOKIE_JAR" \
  -d "{
        \"username\": \"${USERNAME}\",
        \"password\": \"${PASSWORD}\",
        \"provider\": \"db\",
        \"refresh\": true
      }")
```

**Wichtige Parameter:**
- `refresh: true` - Erzeugt ein langlebiges Token
- `-c "$COOKIE_JAR"` - Speichert Session-Cookies

### Schritt 2: CSRF Token abrufen

Für sichere API-Aufrufe wird ein CSRF-Token benötigt:

```bash
CSRF_RESPONSE=$(curl -s -X GET "${SUPERSET_URL}/api/v1/security/csrf_token/" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -b "$COOKIE_JAR" \
  -c "$COOKIE_JAR")
```

**Wichtige Parameter:**
- `-b "$COOKIE_JAR"` - Verwendet gespeicherte Cookies
- `-c "$COOKIE_JAR"` - Aktualisiert Cookie-Speicher

### Schritt 3: Guest Token generieren

Das eigentliche Guest-Token wird mit spezifischen Berechtigungen erstellt:

```bash
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
```

**Payload-Erklärung:**
- `user` - Benutzerdaten für das Guest-Token
- `resources` - Berechtigung für spezifisches Dashboard
- `rls` - Row Level Security Regeln (hier leer)
- `exp` - Optionales Ablaufdatum (Unix-Timestamp)

## Token-Dekodierung

Das Skript dekodiert automatisch das generierte JWT-Token und zeigt folgende Informationen an:

### Header
```json
{
  "alg": "HS256",
  "typ": "JWT"
}
```

### Payload
```json
{
  "user": {
    "username": "embed",
    "first_name": "embedded",
    "last_name": "user"
  },
  "resources": [
    {
      "type": "dashboard",
      "id": "59ea5070-2cec-4180-86fb-a9264276be90"
    }
  ],
  "rls": [],
  "iat": 1751193317,
  "exp": 1751193617,
  "aud": "http://superset:8088/",
  "type": "guest"
}
```

### Ablauf-Informationen

Das Skript berechnet und zeigt:
- Unix-Timestamp des Ablaufdatums
- Lesbares Datum und Zeit
- Verbleibende Gültigkeitsdauer in Minuten/Sekunden

## Ausgabe

Das Skript generiert eine strukturierte Ausgabe:

```
=== Superset Guest Token Generator ===
Verwende Cookie-Jar: /tmp/tmp.XXXXXXXXXX

1. Anmeldung um Access Token zu erhalten...
✅ Access Token erhalten: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

2. CSRF Token wird abgerufen...
✅ CSRF Token erhalten: ImYyMTkzODZmYTVlOGNiZmYyOGQ5NTgyZjc3...

3. Guest Token wird für Dashboard ID generiert: 59ea5070-2cec-4180-86fb-a9264276be90...
✅ Guest Token erfolgreich generiert!

=== ERGEBNISSE ===
Access Token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
CSRF Token: ImYyMTkzODZmYTVlOGNiZmYyOGQ5NTgyZjc3...
Guest Token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

=== ZUM KOPIEREN FÜR IHRE ANWENDUNG ===
Guest Token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

=== DEKODIERTES GUEST TOKEN ===
Header: { ... }
Payload: { ... }

=== TOKEN ABLAUF-INFORMATIONEN ===
Läuft ab am (Unix-Zeitstempel): 1751193617.2526093
Läuft ab am (lesbar): 2025-06-29 15:26:57 CET
Token ist gültig für: 4 Minuten (267 Sekunden)

Aufräumen abgeschlossen.
```

## Sicherheitshinweise

⚠️ **Wichtige Sicherheitsüberlegungen:**

1. **Admin-Zugangsdaten:** Das Skript verwendet Admin-Zugangsdaten - nur für Entwicklung/Test verwenden
2. **Token-Speicherung:** Guest-Token nie in öffentlich zugänglichen Dateien speichern
3. **Cookie-Management:** Temporäre Cookie-Dateien werden automatisch gelöscht
4. **Produktionsumgebung:** Für Produktion separaten Service-Account mit minimalen Berechtigungen verwenden

## Fehlerbehebung

### Häufige Probleme

**Problem:** `jq: command not found`
```bash
# Lösung: jq installieren
brew install jq  # macOS
sudo apt-get install jq  # Ubuntu
```

**Problem:** `base64: invalid input`
```bash
# Das passiert bei ungültigen Token - prüfen Sie die Superset-Verbindung
```

**Problem:** `CSRF session token is missing`
```bash
# Cookie-Session ist abgelaufen - Skript erneut ausführen
```

### Debug-Modus

Für erweiterte Fehlersuche können Sie Debug-Informationen aktivieren:

```bash
# Cookie-Inhalt wird automatisch angezeigt
echo "Debug: Cookie-Inhalt:"
cat "$COOKIE_JAR"
```

## Integration in Anwendungen

### JavaScript/Node.js

```javascript
// Guest-Token vom Backend abrufen
const response = await fetch('/guest-token');
const { guestToken } = await response.json();

// Dashboard einbetten
supersetEmbeddedSdk.embedDashboard({
  id: "59ea5070-2cec-4180-86fb-a9264276be90",
  supersetDomain: "http://192.168.178.10:8088",
  mountPoint: document.getElementById("dashboard-container"),
  fetchGuestToken: () => Promise.resolve(guestToken)
});
```

### Backend-Integration

```javascript
// Express.js Endpoint
app.get('/guest-token', async (req, res) => {
  // Skript ausführen und Token zurückgeben
  const { exec } = require('child_process');
  exec('./get_guest_token.sh', (error, stdout) => {
    if (error) {
      res.status(500).json({ error: 'Token generation failed' });
      return;
    }
    
    // Token aus Ausgabe extrahieren
    const tokenMatch = stdout.match(/Guest Token: (.*)/);
    if (tokenMatch) {
      res.json({ guestToken: tokenMatch[1] });
    }
  });
});
```

## Lizenz

Dieses Skript ist für Entwicklungs- und Testzwecke gedacht. Bitte beachten Sie die Superset-Lizenzbestimmungen für Produktionsumgebungen.
