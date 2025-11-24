# =========================================================================
# Script de migration vers l'authentification par mot de passe
# PERC - Mutuelle des Douanes du Sénégal
# =========================================================================
#
# Ce script automatise la migration de OTP SMS vers authentification par mot de passe
#
# Prérequis :
#   - Docker et Docker Compose installés
#   - Les conteneurs PERC doivent être en cours d'exécution
#   - Node.js et bcrypt installés dans le conteneur backend
#
# Usage :
#   .\scripts\migrate-passwords.ps1
#

# Fonction pour afficher des messages colorés
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Step {
    param([string]$Message)
    Write-ColorOutput "`n==> $Message" "Cyan"
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput "✓ $Message" "Green"
}

function Write-Warning {
    param([string]$Message)
    Write-ColorOutput "⚠ $Message" "Yellow"
}

function Write-Error {
    param([string]$Message)
    Write-ColorOutput "✗ $Message" "Red"
}

# Bannière
Clear-Host
Write-Host ""
Write-Host "=========================================="
Write-Host "  MIGRATION AUTHENTIFICATION"
Write-Host "  PERC - Mutuelle des Douanes"
Write-Host "=========================================="
Write-Host ""

# Confirmation de l'utilisateur
Write-Warning "Cette opération va générer des mots de passe pour tous les participants."
Write-Warning "Les participants sans numéro de téléphone recevront un mot de passe commun."
$confirmation = Read-Host "Continuer? [o/N]"

if ($confirmation -ne "o" -and $confirmation -ne "O") {
    Write-Warning "Migration annulée"
    exit 0
}

# Variables
$TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"
$OUTPUT_DIR = "output"
$CSV_FILE = "$OUTPUT_DIR/passwords_$TIMESTAMP.csv"
$DOCKER_CSV_PATH = "/tmp/passwords_export.csv"

# Étape 0 : Vérifier que Docker est en cours d'exécution
Write-Step "Vérification de Docker..."
try {
    $dockerStatus = docker-compose ps 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Docker Compose n'est pas en cours d'exécution"
        Write-Host "Démarrez les conteneurs avec : docker-compose up -d"
        exit 1
    }
    Write-Success "Docker Compose est actif"
} catch {
    Write-Error "Erreur lors de la vérification de Docker : $_"
    exit 1
}

# Étape 1 : Créer le répertoire de sortie
Write-Step "Création du répertoire de sortie..."
if (-not (Test-Path $OUTPUT_DIR)) {
    New-Item -ItemType Directory -Path $OUTPUT_DIR | Out-Null
    Write-Success "Répertoire '$OUTPUT_DIR' créé"
} else {
    Write-Success "Répertoire '$OUTPUT_DIR' existe déjà"
}

# Étape 2 : Supprimer la vue qui bloque les modifications
Write-Step "Suppression de la vue v_perc_comptes_actifs si elle existe..."
try {
    docker-compose exec -T postgres psql -U perc_user -d perc_db -c "DROP VIEW IF EXISTS v_perc_comptes_actifs CASCADE;" 2>&1 | Out-Null
    Write-Success "Vue supprimée (ou n'existait pas)"
} catch {
    Write-Warning "Impossible de supprimer la vue (elle n'existe peut-être pas)"
}

# Étape 3 : Copier le script SQL dans le conteneur
Write-Step "Copie du script SQL dans le conteneur..."
try {
    docker cp database/generate-passwords.sql perc-postgres:/tmp/generate-passwords.sql
    Write-Success "Script SQL copié dans le conteneur PostgreSQL"
} catch {
    Write-Error "Erreur lors de la copie du script SQL : $_"
    exit 1
}

# Étape 4 : Exécuter le script de génération de mots de passe
Write-Step "Génération des mots de passe..."
try {
    $sqlOutput = docker-compose exec -T postgres psql -U perc_user -d perc_db -f /tmp/generate-passwords.sql 2>&1

    # Afficher toute la sortie pour debug
    Write-Host "Sortie SQL complète :" -ForegroundColor Gray
    $sqlOutput | ForEach-Object {
        Write-Host "  $_" -ForegroundColor DarkGray
    }

    # Extraire les statistiques des NOTICE
    $foundStats = $false
    $sqlOutput | ForEach-Object {
        if ($_ -match "Génération terminée pour (\d+) participants") {
            Write-Success "Mots de passe générés pour $($matches[1]) participants"
            $foundStats = $true
        }
        if ($_ -match "Avec téléphone.*: (\d+)") {
            Write-Success "  → Avec téléphone (mot de passe unique) : $($matches[1])"
        }
        if ($_ -match "Sans téléphone.*: (\d+)") {
            Write-Warning "  → Sans téléphone (mot de passe commun 'MDS2024!') : $($matches[1])"
        }
    }

    if (-not $foundStats) {
        Write-Warning "Aucune statistique trouvée dans la sortie SQL"
        Write-Warning "Le script SQL a peut-être échoué silencieusement"
    }
} catch {
    Write-Error "Erreur lors de la génération des mots de passe : $_"
    exit 1
}

# Étape 5 : Exporter les mots de passe vers CSV
Write-Step "Export des mots de passe vers CSV..."
try {
    # Exporter dans le conteneur
    docker-compose exec -T postgres psql -U perc_user -d perc_db -c "COPY (SELECT matricule, nom, telephone, email, password_clear, type_generation, 'À changer à la première connexion' AS remarque FROM temp_passwords_to_send ORDER BY type_generation DESC, matricule) TO '$DOCKER_CSV_PATH' WITH CSV HEADER;" 2>&1 | Out-Null

    # Copier depuis le conteneur vers l'hôte
    docker cp perc-postgres:$DOCKER_CSV_PATH $CSV_FILE

    Write-Success "Mots de passe exportés vers : $CSV_FILE"

    # Afficher un aperçu
    Write-Step "Aperçu des premiers mots de passe :"
    Get-Content $CSV_FILE -TotalCount 6 | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Gray
    }
} catch {
    Write-Error "Erreur lors de l'export CSV : $_"
    exit 1
}

# Étape 6 : Hasher les mots de passe avec bcrypt
Write-Step "Hashage des mots de passe avec bcrypt..."
try {
    # Copier le script de hashage dans le conteneur
    docker cp scripts/hash-passwords.js perc-backend:/app/hash-passwords.js

    # Exécuter le script Node.js dans le conteneur
    $hashOutput = docker-compose exec -T backend node /app/hash-passwords.js 2>&1

    # Afficher la sortie du script
    $hashOutput | ForEach-Object {
        if ($_ -match "✅") {
            Write-Host "  $_" -ForegroundColor Green
        } elseif ($_ -match "❌") {
            Write-Host "  $_" -ForegroundColor Red
        } elseif ($_ -match "🔐|📊|🎉|📝|✨") {
            Write-Host "  $_" -ForegroundColor Cyan
        } else {
            Write-Host "  $_"
        }
    }

    Write-Success "Hashage terminé"
} catch {
    Write-Error "Erreur lors du hashage : $_"
    exit 1
}

# Étape 7 : Vérification
Write-Step "Vérification du hashage..."
try {
    $verifyQuery = "SELECT COUNT(*) FROM perc_participants WHERE password_hash IS NOT NULL AND password_hash != '';"
    $hashedCount = docker-compose exec -T postgres psql -U perc_user -d perc_db -t -c $verifyQuery 2>&1
    $hashedCount = $hashedCount.Trim()
    Write-Success "$hashedCount participants ont un mot de passe hashé"
} catch {
    Write-Warning "Impossible de vérifier le hashage"
}

# Étape 8 : Instructions finales
Write-Host ""
Write-Step "PROCHAINES ÉTAPES :"
Write-Host "  1. Ouvrir le fichier : $CSV_FILE"
Write-Host "  2. Envoyer les mots de passe aux agents :"
Write-Host "     - Pour les agents AVEC téléphone : envoyer par SMS leur mot de passe unique"
Write-Host "     - Pour les agents SANS téléphone : les informer que leur mot de passe est 'MDS2024!'"
Write-ColorOutput "  3. IMPORTANT : Sécurisez le fichier CSV et supprimez-le après l'envoi !" "Yellow"
Write-Host ""

# Demander si on supprime la table temporaire
Write-Warning "Voulez-vous supprimer la table temporaire temp_passwords_to_send MAINTENANT?"
Write-Host "  (Recommandé seulement APRÈS avoir envoyé tous les mots de passe)"
$deleteTemp = Read-Host "Supprimer maintenant? [o/N]"

if ($deleteTemp -eq "o" -or $deleteTemp -eq "O") {
    Write-Step "Suppression de la table temporaire..."
    try {
        docker-compose exec -T postgres psql -U perc_user -d perc_db -c "DROP TABLE IF EXISTS temp_passwords_to_send;" 2>&1 | Out-Null
        Write-Success "Table temporaire supprimée"
    } catch {
        Write-Error "Erreur lors de la suppression : $_"
    }
} else {
    Write-Warning "Table temporaire conservée"
    Write-Host "Pour la supprimer plus tard, exécutez :"
    Write-Host "  docker-compose exec postgres psql -U perc_user -d perc_db -c `"DROP TABLE temp_passwords_to_send;`""
    Write-Host ""
}

# Résumé final
Write-Host ""
Write-Host "=========================================="
Write-Success "MIGRATION TERMINÉE AVEC SUCCÈS !"
Write-Host "=========================================="
Write-Host ""
Write-Host "Résumé :"
Write-Host "  • Fichier d'export : $CSV_FILE"
Write-Host "  • Prochaine étape : Envoyer les mots de passe aux agents"
Write-Host ""
Write-ColorOutput "ATTENTION :" "Yellow"
Write-ColorOutput "  - Les participants SANS téléphone ont tous le mot de passe : MDS2024!" "Yellow"
Write-ColorOutput "  - Sécurisez le fichier CSV et supprimez-le après distribution" "Yellow"
Write-Host ""
