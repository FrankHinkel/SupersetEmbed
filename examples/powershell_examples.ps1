# PowerShell Verwendungsbeispiele für get_guest_token.ps1
# filepath: /Users/frank/Documents/Node-Projekte/SupersetEmbed/examples/powershell_examples.ps1

Write-Host "=== PowerShell Guest Token Skript - Verwendungsbeispiele ===" -ForegroundColor Cyan
Write-Host ""

# Basis-Verwendung
Write-Host "1. Basis-Verwendung (Standard-Parameter):" -ForegroundColor Yellow
Write-Host ".\get_guest_token.ps1" -ForegroundColor Gray
Write-Host ""

# Mit eigenen Parametern
Write-Host "2. Mit eigenen Parametern:" -ForegroundColor Yellow
Write-Host ".\get_guest_token.ps1 -SupersetUrl 'http://mein-superset.local:8088' -Username 'admin' -Password 'geheim' -DashboardId 'abc-123'" -ForegroundColor Gray
Write-Host ""

# Debug-Modus aktivieren
Write-Host "3. Debug-Modus für Fehlerbehebung:" -ForegroundColor Yellow
Write-Host ".\get_guest_token.ps1 -Debug" -ForegroundColor Gray
Write-Host ""

# Token in Datei speichern
Write-Host "4. Token in Datei speichern:" -ForegroundColor Yellow
Write-Host ".\get_guest_token.ps1 -OutputFile 'token.txt'" -ForegroundColor Gray
Write-Host ""

# Token in Zwischenablage kopieren
Write-Host "5. Token in Zwischenablage kopieren:" -ForegroundColor Yellow
Write-Host ".\get_guest_token.ps1 -CopyToClipboard" -ForegroundColor Gray
Write-Host ""

# Kombinierte Verwendung
Write-Host "6. Alle Optionen kombiniert:" -ForegroundColor Yellow
Write-Host @"
.\get_guest_token.ps1 \
  -SupersetUrl 'http://192.168.1.100:8088' \
  -Username 'serviceuser' \
  -Password 'servicepassword' \
  -DashboardId 'my-dashboard-uuid' \
  -Debug \
  -OutputFile 'production_token.txt' \
  -CopyToClipboard
"@ -ForegroundColor Gray
Write-Host ""

# Verwendung aus anderen Skripten
Write-Host "7. Programmatische Verwendung in eigenem Skript:" -ForegroundColor Yellow
Write-Host @"
# Token generieren und in Variable speichern
$tokenScript = '.\get_guest_token.ps1'
$result = & $tokenScript -SupersetUrl 'http://localhost:8088' -Username 'admin' -Password 'admin' -DashboardId 'my-id'

# Token aus Datei lesen (wenn -OutputFile verwendet wurde)
if (Test-Path 'token.txt') {
    $token = Get-Content 'token.txt' -Raw
    Write-Host "Token geladen: $($token.Substring(0,50))..."
}
"@ -ForegroundColor Gray
Write-Host ""

# Umgebungsvariablen
Write-Host "8. Mit Umgebungsvariablen (sicherer für Credentials):" -ForegroundColor Yellow
Write-Host @"
# Erst Umgebungsvariablen setzen
$env:SUPERSET_URL = 'http://192.168.178.10:8088'
$env:SUPERSET_USERNAME = 'admin'
$env:SUPERSET_PASSWORD = 'admin'
$env:SUPERSET_DASHBOARD_ID = '59ea5070-2cec-4180-86fb-a9264276be90'

# Dann Skript aufrufen
.\get_guest_token.ps1 \
  -SupersetUrl $env:SUPERSET_URL \
  -Username $env:SUPERSET_USERNAME \
  -Password $env:SUPERSET_PASSWORD \
  -DashboardId $env:SUPERSET_DASHBOARD_ID
"@ -ForegroundColor Gray
Write-Host ""

# Automatisierung
Write-Host "9. Automatisierte Token-Erneuerung:" -ForegroundColor Yellow
Write-Host @"
# Token alle 30 Minuten erneuern
while ($true) {
    Write-Host "$(Get-Date): Erzeuge neuen Guest Token..."
    .\get_guest_token.ps1 -OutputFile 'current_token.txt' -CopyToClipboard
    
    Write-Host "Warte 30 Minuten bis zur nächsten Erneuerung..."
    Start-Sleep -Seconds 1800  # 30 Minuten
}
"@ -ForegroundColor Gray
Write-Host ""

# Fehlerbehandlung
Write-Host "10. Mit robuster Fehlerbehandlung:" -ForegroundColor Yellow
Write-Host @"
try {
    $result = .\get_guest_token.ps1 -SupersetUrl 'http://localhost:8088' -Debug
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Token erfolgreich generiert!"
    } else {
        Write-Host "Token-Generierung fehlgeschlagen (Exit Code: $LASTEXITCODE)"
    }
} catch {
    Write-Host "Fehler beim Ausführen des Skripts: $($_.Exception.Message)"
}
"@ -ForegroundColor Gray
Write-Host ""

Write-Host "=== TIPPS ===" -ForegroundColor Green
Write-Host "• Verwenden Sie -Debug bei Problemen für detaillierte Ausgaben" -ForegroundColor White
Write-Host "• Speichern Sie Credentials sicher in Umgebungsvariablen" -ForegroundColor White
Write-Host "• Prüfen Sie die Token-Ablaufzeit in der Ausgabe" -ForegroundColor White
Write-Host "• Verwenden Sie -CopyToClipboard für schnelles Testen" -ForegroundColor White
Write-Host "• Kombinieren Sie mit -OutputFile für automatisierte Workflows" -ForegroundColor White
Write-Host ""

Write-Host "Für weitere Informationen siehe: ../Dokumentation/Superset Token Generator.md" -ForegroundColor Blue
