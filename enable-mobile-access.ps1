# Script pour autoriser l'accès mobile au backend PERC
# À exécuter en tant qu'Administrateur

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Configuration Accès Mobile PERC" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Vérifier si exécuté en tant qu'admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "❌ ERREUR : Ce script doit être exécuté en tant qu'Administrateur" -ForegroundColor Red
    Write-Host ""
    Write-Host "Clic droit sur PowerShell → Exécuter en tant qu'administrateur" -ForegroundColor Yellow
    Write-Host ""
    pause
    exit 1
}

Write-Host "✓ Exécution en tant qu'Administrateur" -ForegroundColor Green
Write-Host ""

# Obtenir l'adresse IP WiFi
Write-Host "==> Récupération de l'adresse IP WiFi..." -ForegroundColor Cyan
$ipAddress = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Wi-Fi*" | Select-Object -First 1).IPAddress

if ($ipAddress) {
    Write-Host "✓ Adresse IP WiFi détectée : $ipAddress" -ForegroundColor Green
} else {
    Write-Host "⚠ Impossible de détecter l'adresse WiFi automatiquement" -ForegroundColor Yellow
    Write-Host "Vérifiez manuellement avec : ipconfig" -ForegroundColor Yellow
}

Write-Host ""

# Ajouter la règle de pare-feu pour le port 3000
Write-Host "==> Ajout de la règle de pare-feu pour le port 3000..." -ForegroundColor Cyan

# Vérifier si la règle existe déjà
$existingRule = Get-NetFirewallRule -DisplayName "Docker Backend PERC" -ErrorAction SilentlyContinue

if ($existingRule) {
    Write-Host "⚠ La règle existe déjà, suppression..." -ForegroundColor Yellow
    Remove-NetFirewallRule -DisplayName "Docker Backend PERC"
}

# Créer la nouvelle règle
New-NetFirewallRule -DisplayName "Docker Backend PERC" `
                    -Direction Inbound `
                    -Protocol TCP `
                    -LocalPort 3000 `
                    -Action Allow `
                    -Profile Private,Domain `
                    -Description "Autoriser l'accès au backend PERC depuis le réseau local"

Write-Host "✓ Règle de pare-feu ajoutée avec succès" -ForegroundColor Green
Write-Host ""

# Instructions pour le smartphone
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  INSTRUCTIONS POUR TON SMARTPHONE" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

if ($ipAddress) {
    Write-Host "1. Connecte ton téléphone au WiFi : 'home'" -ForegroundColor White
    Write-Host ""
    Write-Host "2. Ouvre le navigateur sur ton téléphone" -ForegroundColor White
    Write-Host ""
    Write-Host "3. Accède à l'URL suivante :" -ForegroundColor White
    Write-Host ""
    Write-Host "   http://${ipAddress}:3000/agent-login.html" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "4. Connecte-toi avec :" -ForegroundColor White
    Write-Host "   Matricule : 365978H" -ForegroundColor Yellow
    Write-Host "   Mot de passe : MDS2024!" -ForegroundColor Yellow
} else {
    Write-Host "1. Trouve ton adresse IP avec : ipconfig" -ForegroundColor White
    Write-Host "2. Cherche 'Carte réseau sans fil Wi-Fi'" -ForegroundColor White
    Write-Host "3. Note l'adresse IPv4 (ex: 192.168.1.17)" -ForegroundColor White
    Write-Host "4. Sur ton téléphone, accède à :" -ForegroundColor White
    Write-Host "   http://[TON_IP]:3000/agent-login.html" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  CONFIGURATION TERMINÉE !" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Test de connectivité
Write-Host "==> Test de connectivité..." -ForegroundColor Cyan
$testResult = Test-NetConnection -ComputerName localhost -Port 3000 -WarningAction SilentlyContinue

if ($testResult.TcpTestSucceeded) {
    Write-Host "✓ Le backend est accessible sur le port 3000" -ForegroundColor Green
} else {
    Write-Host "❌ Le backend n'est pas accessible" -ForegroundColor Red
    Write-Host "Vérifiez que Docker est démarré : docker-compose ps" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Appuyez sur une touche pour fermer..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
