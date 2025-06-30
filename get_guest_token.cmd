@echo off
rem filepath: /Users/frank/Documents/Node-Projekte/SupersetEmbed/get_guest_token.cmd

rem Konfiguration
set SUPERSET_URL=http://192.168.178.10:8088
set USERNAME=admin
set PASSWORD=admin
set DASHBOARD_ID=59ea5070-2cec-4180-86fb-a9264276be90

rem Temporäre Cookie-Datei erstellen
set COOKIE_JAR=%TEMP%\superset_cookies_%RANDOM%.txt

echo === Superset Guest Token Generator ===
echo Verwende Cookie-Datei: %COOKIE_JAR%
echo.

rem Schritt 1: Anmeldung und Access Token abrufen (mit Cookie-Speicherung)
echo 1. Anmeldung um Access Token zu erhalten...

rem JSON-Payload für Login erstellen
set LOGIN_PAYLOAD={"username":"%USERNAME%","password":"%PASSWORD%","provider":"db","refresh":true}

rem Login-Request ausführen
curl -s -X POST "%SUPERSET_URL%/api/v1/security/login" ^
  -H "Content-Type: application/json" ^
  -c "%COOKIE_JAR%" ^
  -d "%LOGIN_PAYLOAD%" ^
  -o "%TEMP%\login_response.json"

if errorlevel 1 (
    echo ❌ Fehler: Curl-Befehl für Login fehlgeschlagen
    del "%COOKIE_JAR%" 2>nul
    exit /b 1
)

rem Access Token aus der Antwort extrahieren (vereinfacht für CMD)
rem Hinweis: Für vollständige JSON-Verarbeitung sollte jq oder PowerShell verwendet werden
echo ✅ Login-Request abgeschickt, prüfe Antwort...

rem Prüfen ob Login-Response existiert
if not exist "%TEMP%\login_response.json" (
    echo ❌ Fehler: Keine Antwort vom Login-Endpoint erhalten
    del "%COOKIE_JAR%" 2>nul
    exit /b 1
)

echo Login-Antwort:
type "%TEMP%\login_response.json"
echo.

rem Schritt 2: CSRF Token abrufen (mit Cookie-Update)
echo 2. CSRF Token wird abgerufen...
curl -s -X GET "%SUPERSET_URL%/api/v1/security/csrf_token/" ^
  -H "Authorization: Bearer PLACEHOLDER_ACCESS_TOKEN" ^
  -b "%COOKIE_JAR%" ^
  -c "%COOKIE_JAR%" ^
  -o "%TEMP%\csrf_response.json"

if errorlevel 1 (
    echo ❌ Fehler: Curl-Befehl für CSRF Token fehlgeschlagen
    del "%COOKIE_JAR%" 2>nul
    del "%TEMP%\login_response.json" 2>nul
    exit /b 1
)

echo ✅ CSRF-Request abgeschickt, prüfe Antwort...

if not exist "%TEMP%\csrf_response.json" (
    echo ❌ Fehler: Keine Antwort vom CSRF-Endpoint erhalten
    del "%COOKIE_JAR%" 2>nul
    del "%TEMP%\login_response.json" 2>nul
    exit /b 1
)

echo CSRF-Antwort:
type "%TEMP%\csrf_response.json"
echo.

rem Debug: Cookie-Inhalt anzeigen
echo Debug: Cookie-Inhalt:
type "%COOKIE_JAR%"
echo.
echo.

rem Schritt 3: Guest Token generieren (mit angepasstem Payload)
echo 3. Guest Token wird für Dashboard ID generiert: %DASHBOARD_ID%...

rem JSON-Payload für Guest Token erstellen
set GUEST_PAYLOAD={"user":{"first_name":"embedded","last_name":"user","username":"embed"},"resources":[{"type":"dashboard","id":"%DASHBOARD_ID%"}],"rls":[]}

curl -s -X POST "%SUPERSET_URL%/api/v1/security/guest_token/" ^
  -H "Content-Type: application/json" ^
  -H "Authorization: Bearer PLACEHOLDER_ACCESS_TOKEN" ^
  -H "X-CSRFToken: PLACEHOLDER_CSRF_TOKEN" ^
  -H "Referer: %SUPERSET_URL%/" ^
  -b "%COOKIE_JAR%" ^
  -d "%GUEST_PAYLOAD%" ^
  -o "%TEMP%\guest_token_response.json"

if errorlevel 1 (
    echo ❌ Fehler: Curl-Befehl für Guest Token fehlgeschlagen
    goto cleanup
)

echo ✅ Guest Token Request abgeschickt, prüfe Antwort...

if not exist "%TEMP%\guest_token_response.json" (
    echo ❌ Fehler: Keine Antwort vom Guest Token-Endpoint erhalten
    goto cleanup
)

echo === ERGEBNISSE ===
echo.
echo Login-Antwort:
type "%TEMP%\login_response.json"
echo.
echo.
echo CSRF-Antwort:
type "%TEMP%\csrf_response.json"
echo.
echo.
echo Guest Token-Antwort:
type "%TEMP%\guest_token_response.json"
echo.

echo === HINWEISE ===
echo ⚠️  WICHTIG: Dieses CMD-Skript ist eine vereinfachte Version!
echo.
echo Für die vollständige Funktionalität (JSON-Parsing, Token-Dekodierung, etc.)
echo sollten Sie eine der folgenden Alternativen verwenden:
echo.
echo 1. Das Original Bash-Skript auf macOS/Linux
echo 2. PowerShell-Version (siehe get_guest_token.ps1)
echo 3. Node.js-Implementierung
echo.
echo Die Antworten enthalten die Token als JSON - Sie müssen diese manuell extrahieren.

:cleanup
rem Temporäre Dateien aufräumen
del "%COOKIE_JAR%" 2>nul
del "%TEMP%\login_response.json" 2>nul
del "%TEMP%\csrf_response.json" 2>nul
del "%TEMP%\guest_token_response.json" 2>nul
echo.
echo Aufräumen abgeschlossen.

rem Pause für manuelle Inspektion der Ergebnisse
pause
