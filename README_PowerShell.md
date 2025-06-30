# PowerShell Guest Token Generator für Superset

Eine vollautomatisierte PowerShell-Lösung zur Generierung von Superset Guest Tokens mit JWT-Dekodierung und erweiterten Features.

## Features

✅ **Vollständige Automatisierung** - Ein Befehl generiert den kompletten Token  
✅ **JWT-Token-Dekodierung** - Zeigt alle Token-Details an  
✅ **Session-Cookie-Handling** - Korrekte Authentifizierung  
✅ **Ablaufzeit-Berechnung** - Verbleibende Zeit anzeigen  
✅ **Debug-Modus** - Detaillierte Ausgaben für Fehlerbehebung  
✅ **Flexible Parameter** - Anpassbare Konfiguration  
✅ **Datei-Export** - Token in Datei speichern  
✅ **Zwischenablage** - Direktes Kopieren möglich  
✅ **Fehlerbehandlung** - Robuste Fehlerbehandlung  

## Schnellstart

```powershell
# Basis-Verwendung mit Standard-Parametern
.\get_guest_token.ps1

# Mit eigenen Parametern
.\get_guest_token.ps1 -SupersetUrl "http://mein-superset:8088" -Username "admin" -Password "geheim" -DashboardId "my-uuid"

# Debug-Modus für Problemanalyse
.\get_guest_token.ps1 -Debug

# Token in Datei speichern
.\get_guest_token.ps1 -OutputFile "token.txt"

# Token in Zwischenablage kopieren
.\get_guest_token.ps1 -CopyToClipboard
```

## Parameter

| Parameter | Typ | Standard | Beschreibung |
|-----------|-----|----------|--------------|
| `SupersetUrl` | String | `http://192.168.178.10:8088` | Superset Server URL |
| `Username` | String | `admin` | Superset Benutzername |
| `Password` | String | `admin` | Superset Passwort |
| `DashboardId` | String | `59ea5070-...` | UUID des Dashboards |
| `Debug` | Switch | `false` | Debug-Ausgaben aktivieren |
| `OutputFile` | String | `""` | Pfad zur Token-Ausgabe-Datei |
| `CopyToClipboard` | Switch | `false` | Token in Zwischenablage kopieren |

## Ausgabe-Beispiel

```
=== SUPERSET GUEST TOKEN GENERATOR (PowerShell) ===
Superset URL: http://192.168.178.10:8088
Benutzer: admin
Dashboard ID: 59ea5070-2cec-4180-86fb-a9264276be90

=== Schritt 1: Anmeldung ===
Anmeldung bei Superset um Access Token zu erhalten...
✅ Login erfolgreich!

=== Schritt 2: CSRF Token ===
CSRF Token wird abgerufen...
✅ CSRF Token erfolgreich abgerufen!

=== Schritt 3: Guest Token ===
Guest Token wird für Dashboard ID '59ea5070-2cec-4180-86fb-a9264276be90' generiert...
✅ Guest Token erfolgreich generiert!

=== TOKEN INFORMATIONEN ===
Guest Token: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...

=== DEKODIERTE TOKEN-DATEN ===
Benutzer: embedded user (embed)
Zugelassene Ressourcen:
  - dashboard: 59ea5070-2cec-4180-86fb-a9264276be90
Row Level Security Regeln: 0
Token läuft ab: 2024-01-15 14:30:45
Gültig für: 0h 59m 30s

=== VERWENDUNGSBEISPIELE ===

JavaScript (embedDashboard):
embedDashboard({
  id: "59ea5070-2cec-4180-86fb-a9264276be90",
  supersetDomain: "http://192.168.178.10:8088",
  mountPoint: document.getElementById("superset-container"),
  fetchGuestToken: () => Promise.resolve("eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."),
  dashboardUiConfig: {
    hideTitle: true,
    hideChartControls: false,
    hideTab: true,
  },
});

=== ERFOLGREICH ABGESCHLOSSEN ===
```

## Sicherheitshinweise

⚠️ **Produktions-Sicherheit:**
- Verwenden Sie Service-Accounts statt Admin-Credentials
- Nutzen Sie Umgebungsvariablen für sensible Daten
- Beschränken Sie Dashboard-Zugriffe entsprechend
- Implementieren Sie Token-Rotation

## Verwendung in Skripten

### Umgebungsvariablen (empfohlen)

```powershell
# Credentials sicher setzen
$env:SUPERSET_URL = "http://192.168.178.10:8088"
$env:SUPERSET_USERNAME = "serviceuser"
$env:SUPERSET_PASSWORD = "servicepassword"
$env:SUPERSET_DASHBOARD_ID = "my-dashboard-uuid"

# Skript aufrufen
.\get_guest_token.ps1 `
  -SupersetUrl $env:SUPERSET_URL `
  -Username $env:SUPERSET_USERNAME `
  -Password $env:SUPERSET_PASSWORD `
  -DashboardId $env:SUPERSET_DASHBOARD_ID `
  -OutputFile "token.txt"
```

### Automatisierte Token-Erneuerung

```powershell
# Token alle 30 Minuten erneuern
while ($true) {
    Write-Host "$(Get-Date): Generiere neuen Guest Token..."
    
    .\get_guest_token.ps1 -OutputFile "current_token.txt"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Token erfolgreich erneuert"
    } else {
        Write-Host "❌ Token-Erneuerung fehlgeschlagen"
    }
    
    Start-Sleep -Seconds 1800  # 30 Minuten warten
}
```

### Integration in Web-Anwendung

```powershell
# Token für Web-App bereitstellen
function Get-SupersetToken {
    $tokenFile = ".\current_token.txt"
    
    # Prüfe ob Token-Datei existiert und aktuell ist
    if (Test-Path $tokenFile) {
        $tokenAge = (Get-Date) - (Get-Item $tokenFile).LastWriteTime
        if ($tokenAge.TotalMinutes -lt 50) {
            # Token ist noch gültig
            return Get-Content $tokenFile -Raw
        }
    }
    
    # Neuen Token generieren
    .\get_guest_token.ps1 -OutputFile $tokenFile -CopyToClipboard
    
    if ($LASTEXITCODE -eq 0) {
        return Get-Content $tokenFile -Raw
    }
    
    return $null
}

# Verwendung
$token = Get-SupersetToken
if ($token) {
    Write-Host "Token verfügbar: $($token.Substring(0,50))..."
} else {
    Write-Host "❌ Konnte keinen Token generieren"
}
```

## Fehlerbehebung

### Häufige Probleme

1. **Login fehlgeschlagen**
   ```
   ❌ Login fehlgeschlagen: Der Remoteserver hat einen Fehler zurückgegeben: (401) Nicht autorisiert.
   ```
   **Lösung:** Prüfen Sie Username/Password und Superset-URL

2. **Dashboard nicht gefunden**
   ```
   ❌ Guest Token Generierung fehlgeschlagen: Der Remoteserver hat einen Fehler zurückgegeben: (404) Nicht gefunden.
   ```
   **Lösung:** Überprüfen Sie die Dashboard-ID (UUID)

3. **CSRF Token Fehler**
   ```
   ❌ CSRF Token Abruf fehlgeschlagen
   ```
   **Lösung:** Stellen Sie sicher, dass Cookies aktiviert sind

### Debug-Modus verwenden

```powershell
# Ausführliche Debug-Ausgaben
.\get_guest_token.ps1 -Debug

# Zeigt zusätzlich:
# 🔍 DEBUG: Login URL: http://192.168.178.10:8088/api/v1/security/login
# 🔍 DEBUG: Login Payload: {"username":"admin",...}
# 🔍 DEBUG: Access Token erhalten (Länge: 432)
# 🔍 DEBUG: CSRF URL: http://192.168.178.10:8088/api/v1/security/csrf_token/
# 🔍 DEBUG: CSRF Token: abc123...
```

## Vergleich mit anderen Varianten

| Feature | PowerShell | Bash | CMD |
|---------|------------|------|-----|
| JSON-Parsing | ✅ Nativ | ✅ jq | ❌ Manuell |
| JWT-Dekodierung | ✅ Vollständig | ✅ Vollständig | ❌ Keine |
| Session-Cookies | ✅ Automatisch | ✅ curl | ❌ Eingeschränkt |
| Fehlerbehandlung | ✅ Umfangreich | ✅ Gut | ❌ Basic |
| Parameter | ✅ Typisiert | ✅ Bash-Variablen | ❌ Umgebungsvariablen |
| Cross-Platform | ✅ Linux/Mac/Win | ✅ Linux/Mac | ❌ Windows |

## Siehe auch

- `get_guest_token.sh` - Bash-Version (Linux/macOS)
- `get_guest_token.cmd` - Windows CMD-Version
- `examples/powershell_examples.ps1` - Weitere Verwendungsbeispiele
- `Dokumentation/Superset Token Generator.md` - Vollständige Dokumentation
