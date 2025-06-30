# PowerShell Guest Token Generator für Superset
# filepath: /Users/frank/Documents/Node-Projekte/SupersetEmbed/get_guest_token.ps1

param(
    [string]$SupersetUrl = "http://192.168.178.10:8088",
    [string]$Username = "admin",
    [string]$Password = "admin",
    [string]$DashboardId = "59ea5070-2cec-4180-86fb-a9264276be90",
    [switch]$Debug = $false,
    [string]$OutputFile = "",
    [switch]$CopyToClipboard = $false
)

# Konfiguration
$Script:Config = @{
    SupersetUrl = $SupersetUrl
    Username = $Username
    Password = $Password
    DashboardId = $DashboardId
    Debug = $Debug
    OutputFile = $OutputFile
    CopyToClipboard = $CopyToClipboard
}

# Session für Cookie-Handling
$Script:Session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

# Hilfsfunktionen
function Write-DebugInfo {
    param([string]$Message)
    if ($Script:Config.Debug) {
        Write-Host "🔍 DEBUG: $Message" -ForegroundColor Cyan
    }
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Decode-JwtPayload {
    param([string]$Token)
    
    try {
        # JWT Token besteht aus drei Teilen, getrennt durch Punkte
        $parts = $Token.Split('.')
        if ($parts.Length -ne 3) {
            Write-Warning "JWT Token hat nicht das erwartete Format (3 Teile)"
            return $null
        }
        
        # Payload ist der zweite Teil (Index 1)
        $payload = $parts[1]
        
        # Base64-Padding hinzufügen falls nötig
        while ($payload.Length % 4 -ne 0) {
            $payload += "="
        }
        
        # Base64-Dekodierung
        $bytes = [System.Convert]::FromBase64String($payload)
        $json = [System.Text.Encoding]::UTF8.GetString($bytes)
        
        # JSON parsen
        $decoded = $json | ConvertFrom-Json
        
        return $decoded
    }
    catch {
        Write-Warning "Fehler beim Dekodieren des JWT Tokens: $($_.Exception.Message)"
        return $null
    }
}

function Format-ExpiryTime {
    param([int]$UnixTimestamp)
    
    try {
        $epoch = Get-Date "1970-01-01 00:00:00"
        $expiryTime = $epoch.AddSeconds($UnixTimestamp)
        $currentTime = Get-Date
        $timeUntilExpiry = $expiryTime - $currentTime
        
        $result = @{
            ExpiryTime = $expiryTime.ToString("yyyy-MM-dd HH:mm:ss")
            TimeUntilExpiry = $timeUntilExpiry
            IsExpired = $expiryTime -lt $currentTime
        }
        
        return $result
    }
    catch {
        Write-Warning "Fehler beim Formatieren der Ablaufzeit: $($_.Exception.Message)"
        return $null
    }
}

function Invoke-SupersetLogin {
    Write-Host "=== Schritt 1: Anmeldung ==="
    Write-Host "Anmeldung bei Superset um Access Token zu erhalten..."
    
    $loginUrl = "$($Script:Config.SupersetUrl)/api/v1/security/login"
    $loginPayload = @{
        username = $Script:Config.Username
        password = $Script:Config.Password
        provider = "db"
        refresh = $true
    } | ConvertTo-Json -Compress
    
    Write-DebugInfo "Login URL: $loginUrl"
    Write-DebugInfo "Login Payload: $loginPayload"
    
    try {
        $response = Invoke-RestMethod -Uri $loginUrl -Method POST -Body $loginPayload -ContentType "application/json" -WebSession $Script:Session
        
        if ($response.access_token) {
            Write-Success "Login erfolgreich!"
            Write-DebugInfo "Access Token erhalten (Länge: $($response.access_token.Length))"
            return $response.access_token
        } else {
            Write-Error "Kein Access Token in der Antwort gefunden"
            Write-DebugInfo "Antwort: $($response | ConvertTo-Json -Depth 3)"
            return $null
        }
    }
    catch {
        Write-Error "Login fehlgeschlagen: $($_.Exception.Message)"
        if ($_.Exception.Response) {
            Write-DebugInfo "HTTP Status: $($_.Exception.Response.StatusCode)"
            Write-DebugInfo "Response: $($_.Exception.Response | ConvertTo-Json -Depth 2)"
        }
        return $null
    }
}

function Get-CsrfToken {
    param([string]$AccessToken)
    
    Write-Host "`n=== Schritt 2: CSRF Token ==="
    Write-Host "CSRF Token wird abgerufen..."
    
    $csrfUrl = "$($Script:Config.SupersetUrl)/api/v1/security/csrf_token/"
    
    Write-DebugInfo "CSRF URL: $csrfUrl"
    
    try {
        $headers = @{
            "Authorization" = "Bearer $AccessToken"
        }
        
        $response = Invoke-RestMethod -Uri $csrfUrl -Method GET -Headers $headers -WebSession $Script:Session
        
        if ($response.result) {
            Write-Success "CSRF Token erfolgreich abgerufen!"
            Write-DebugInfo "CSRF Token: $($response.result)"
            return $response.result
        } else {
            Write-Error "Kein CSRF Token in der Antwort gefunden"
            Write-DebugInfo "Antwort: $($response | ConvertTo-Json -Depth 3)"
            return $null
        }
    }
    catch {
        Write-Error "CSRF Token Abruf fehlgeschlagen: $($_.Exception.Message)"
        if ($_.Exception.Response) {
            Write-DebugInfo "HTTP Status: $($_.Exception.Response.StatusCode)"
        }
        return $null
    }
}

function New-GuestToken {
    param(
        [string]$AccessToken,
        [string]$CsrfToken
    )
    
    Write-Host "`n=== Schritt 3: Guest Token ==="
    Write-Host "Guest Token wird für Dashboard ID '$($Script:Config.DashboardId)' generiert..."
    
    $guestTokenUrl = "$($Script:Config.SupersetUrl)/api/v1/security/guest_token/"
    $guestPayload = @{
        user = @{
            first_name = "embedded"
            last_name = "user"
            username = "embed"
        }
        resources = @(
            @{
                type = "dashboard"
                id = $Script:Config.DashboardId
            }
        )
        rls = @()
    } | ConvertTo-Json -Compress -Depth 4
    
    Write-DebugInfo "Guest Token URL: $guestTokenUrl"
    Write-DebugInfo "Guest Token Payload: $guestPayload"
    
    try {
        $headers = @{
            "Authorization" = "Bearer $AccessToken"
            "X-CSRFToken" = $CsrfToken
            "Referer" = "$($Script:Config.SupersetUrl)/"
        }
        
        $response = Invoke-RestMethod -Uri $guestTokenUrl -Method POST -Body $guestPayload -ContentType "application/json" -Headers $headers -WebSession $Script:Session
        
        if ($response.token) {
            Write-Success "Guest Token erfolgreich generiert!"
            return $response.token
        } else {
            Write-Error "Kein Guest Token in der Antwort gefunden"
            Write-DebugInfo "Antwort: $($response | ConvertTo-Json -Depth 3)"
            return $null
        }
    }
    catch {
        Write-Error "Guest Token Generierung fehlgeschlagen: $($_.Exception.Message)"
        if ($_.Exception.Response) {
            Write-DebugInfo "HTTP Status: $($_.Exception.Response.StatusCode)"
            try {
                $errorContent = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($errorContent)
                $errorBody = $reader.ReadToEnd()
                Write-DebugInfo "Error Body: $errorBody"
            }
            catch {
                Write-DebugInfo "Konnte Error Body nicht lesen"
            }
        }
        return $null
    }
}

function Show-TokenInfo {
    param([string]$Token)
    
    Write-Host "`n=== TOKEN INFORMATIONEN ==="
    Write-Host "Guest Token: $Token"
    Write-Host ""
    
    # Token dekodieren
    $decoded = Decode-JwtPayload -Token $Token
    if ($decoded) {
        Write-Host "=== DEKODIERTE TOKEN-DATEN ==="
        Write-Host "Benutzer: $($decoded.first_name) $($decoded.last_name) ($($decoded.username))" -ForegroundColor Blue
        
        if ($decoded.resources) {
            Write-Host "Zugelassene Ressourcen:" -ForegroundColor Blue
            foreach ($resource in $decoded.resources) {
                Write-Host "  - $($resource.type): $($resource.id)" -ForegroundColor Blue
            }
        }
        
        if ($decoded.rls) {
            Write-Host "Row Level Security Regeln: $($decoded.rls.Count)" -ForegroundColor Blue
        }
        
        if ($decoded.exp) {
            $expiryInfo = Format-ExpiryTime -UnixTimestamp $decoded.exp
            if ($expiryInfo) {
                Write-Host "Token läuft ab: $($expiryInfo.ExpiryTime)" -ForegroundColor $(if ($expiryInfo.IsExpired) { "Red" } else { "Blue" })
                
                if (-not $expiryInfo.IsExpired) {
                    $hours = [math]::Floor($expiryInfo.TimeUntilExpiry.TotalHours)
                    $minutes = $expiryInfo.TimeUntilExpiry.Minutes
                    $seconds = $expiryInfo.TimeUntilExpiry.Seconds
                    Write-Host "Gültig für: ${hours}h ${minutes}m ${seconds}s" -ForegroundColor Green
                } else {
                    Write-Host "⚠️  TOKEN IST BEREITS ABGELAUFEN!" -ForegroundColor Red
                }
            }
        }
        
        Write-Host ""
    }
}

function Show-UsageExamples {
    param([string]$Token)
    
    Write-Host "=== VERWENDUNGSBEISPIELE ==="
    Write-Host ""
    Write-Host "JavaScript (embedDashboard):" -ForegroundColor Yellow
    Write-Host @"
embedDashboard({
  id: "$($Script:Config.DashboardId)",
  supersetDomain: "$($Script:Config.SupersetUrl)",
  mountPoint: document.getElementById("superset-container"),
  fetchGuestToken: () => Promise.resolve("$Token"),
  dashboardUiConfig: {
    hideTitle: true,
    hideChartControls: false,
    hideTab: true,
  },
});
"@ -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "Node.js fetch Beispiel:" -ForegroundColor Yellow
    Write-Host @"
const response = await fetch('$($Script:Config.SupersetUrl)/api/v1/chart/data', {
  headers: {
    'Authorization': 'Bearer $Token',
    'Content-Type': 'application/json'
  }
});
"@ -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "Curl Beispiel:" -ForegroundColor Yellow
    Write-Host @"
curl -H "Authorization: Bearer $Token" \
     "$($Script:Config.SupersetUrl)/api/v1/dashboard/$($Script:Config.DashboardId)"
"@ -ForegroundColor Gray
}

# Hauptfunktion
function Main {
    Write-Host "=== SUPERSET GUEST TOKEN GENERATOR (PowerShell) ===" -ForegroundColor Magenta
    Write-Host "Superset URL: $($Script:Config.SupersetUrl)"
    Write-Host "Benutzer: $($Script:Config.Username)"
    Write-Host "Dashboard ID: $($Script:Config.DashboardId)"
    if ($Script:Config.Debug) {
        Write-Host "Debug-Modus: Aktiviert" -ForegroundColor Cyan
    }
    Write-Host ""
    
    # Schritt 1: Login
    $accessToken = Invoke-SupersetLogin
    if (-not $accessToken) {
        Write-Error "Abbruch: Login fehlgeschlagen"
        exit 1
    }
    
    # Schritt 2: CSRF Token
    $csrfToken = Get-CsrfToken -AccessToken $accessToken
    if (-not $csrfToken) {
        Write-Error "Abbruch: CSRF Token konnte nicht abgerufen werden"
        exit 1
    }
    
    # Schritt 3: Guest Token
    $guestToken = New-GuestToken -AccessToken $accessToken -CsrfToken $csrfToken
    if (-not $guestToken) {
        Write-Error "Abbruch: Guest Token konnte nicht generiert werden"
        exit 1
    }
    
    # Ergebnisse anzeigen
    Show-TokenInfo -Token $guestToken
    Show-UsageExamples -Token $guestToken
    
    # Token speichern oder in Zwischenablage kopieren
    if ($Script:Config.OutputFile) {
        try {
            $guestToken | Out-File -FilePath $Script:Config.OutputFile -Encoding UTF8
            Write-Success "Token wurde gespeichert in: $($Script:Config.OutputFile)"
        }
        catch {
            Write-Warning "Konnte Token nicht in Datei speichern: $($_.Exception.Message)"
        }
    }
    
    if ($Script:Config.CopyToClipboard) {
        try {
            $guestToken | Set-Clipboard
            Write-Success "Token wurde in die Zwischenablage kopiert!"
        }
        catch {
            Write-Warning "Konnte Token nicht in Zwischenablage kopieren: $($_.Exception.Message)"
        }
    }
    
    Write-Host "=== ERFOLGREICH ABGESCHLOSSEN ===" -ForegroundColor Green
}

# Fehlerbehandlung
try {
    Main
}
catch {
    Write-Error "Unerwarteter Fehler: $($_.Exception.Message)"
    Write-DebugInfo "Stack Trace: $($_.Exception.StackTrace)"
    exit 1
}
