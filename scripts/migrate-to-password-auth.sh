#!/bin/bash
#
# Script de migration vers l'authentification par mot de passe
# PERC - Mutuelle des Douanes du Sénégal
#
# Usage: ./scripts/migrate-to-password-auth.sh
#

set -e  # Arrêter en cas d'erreur

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration de la base de données
DB_USER="${DB_USER:-perc_user}"
DB_NAME="${DB_NAME:-perc_db}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"

# Fichiers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SCHEMA_FILE="$PROJECT_DIR/database/schema.sql"
PASSWORD_GEN_FILE="$PROJECT_DIR/database/generate-passwords.sql"
HASH_SCRIPT="$SCRIPT_DIR/hash-passwords.js"
OUTPUT_DIR="$PROJECT_DIR/output"
PASSWORD_EXPORT_FILE="$OUTPUT_DIR/passwords_$(date +%Y%m%d_%H%M%S).csv"

# Fonction d'affichage
print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Fonction pour exécuter une commande SQL
execute_sql() {
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" "$@"
}

# Fonction pour exécuter un fichier SQL
execute_sql_file() {
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$1"
}

# Fonction pour vérifier les prérequis
check_prerequisites() {
    print_step "Vérification des prérequis..."

    # Vérifier psql
    if ! command -v psql &> /dev/null; then
        print_error "psql n'est pas installé. Installez PostgreSQL client."
        exit 1
    fi

    # Vérifier node
    if ! command -v node &> /dev/null; then
        print_error "Node.js n'est pas installé."
        exit 1
    fi

    # Vérifier les fichiers nécessaires
    if [ ! -f "$PASSWORD_GEN_FILE" ]; then
        print_error "Fichier non trouvé: $PASSWORD_GEN_FILE"
        exit 1
    fi

    if [ ! -f "$HASH_SCRIPT" ]; then
        print_error "Fichier non trouvé: $HASH_SCRIPT"
        exit 1
    fi

    print_success "Tous les prérequis sont satisfaits"
}

# Fonction pour créer le répertoire de sortie
create_output_dir() {
    if [ ! -d "$OUTPUT_DIR" ]; then
        mkdir -p "$OUTPUT_DIR"
        print_success "Répertoire de sortie créé: $OUTPUT_DIR"
    fi
}

# Fonction pour vérifier la connexion à la base de données
check_db_connection() {
    print_step "Vérification de la connexion à la base de données..."

    if execute_sql -c "SELECT 1;" > /dev/null 2>&1; then
        print_success "Connexion à la base de données réussie"
    else
        print_error "Impossible de se connecter à la base de données"
        print_error "Vérifiez les variables d'environnement: DB_HOST, DB_PORT, DB_USER, DB_PASSWORD"
        exit 1
    fi
}

# Fonction principale
main() {
    echo ""
    echo "=========================================="
    echo "  MIGRATION AUTHENTIFICATION PAR MOT DE PASSE"
    echo "  PERC - Mutuelle des Douanes"
    echo "=========================================="
    echo ""

    # Demander confirmation
    read -p "$(echo -e ${YELLOW}⚠${NC} Cette opération va générer des mots de passe pour tous les participants. Continuer? [y/N]: )" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Migration annulée"
        exit 0
    fi

    # Étape 0: Vérifications
    check_prerequisites
    create_output_dir
    check_db_connection

    # Étape 1: Appliquer le schéma (si nécessaire)
    if [ -f "$SCHEMA_FILE" ]; then
        print_step "Application du schéma de base de données..."
        read -p "$(echo -e ${YELLOW}?${NC} Voulez-vous appliquer le schéma? Cela peut écraser des données existantes. [y/N]: )" -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            execute_sql_file "$SCHEMA_FILE"
            print_success "Schéma appliqué avec succès"
        else
            print_warning "Schéma non appliqué (skippé)"
        fi
    fi

    # Étape 2: Générer les mots de passe
    print_step "Génération des mots de passe aléatoires..."
    execute_sql_file "$PASSWORD_GEN_FILE"
    print_success "Mots de passe générés avec succès"

    # Compter les mots de passe générés
    PASSWORD_COUNT=$(execute_sql -t -c "SELECT COUNT(*) FROM temp_passwords_to_send;" | xargs)
    print_success "$PASSWORD_COUNT mots de passe générés"

    # Étape 3: Exporter les mots de passe
    print_step "Export des mots de passe vers CSV..."
    execute_sql -c "COPY (SELECT matricule, nom, telephone, email, password_clear, 'À changer à la première connexion' AS remarque FROM temp_passwords_to_send ORDER BY matricule) TO STDOUT WITH CSV HEADER;" > "$PASSWORD_EXPORT_FILE"
    print_success "Mots de passe exportés vers: $PASSWORD_EXPORT_FILE"

    # Afficher un aperçu
    print_step "Aperçu des 5 premiers mots de passe:"
    head -n 6 "$PASSWORD_EXPORT_FILE"
    echo ""

    # Étape 4: Hasher les mots de passe
    print_step "Hashage des mots de passe avec bcrypt..."
    cd "$PROJECT_DIR"
    node "$HASH_SCRIPT"
    print_success "Mots de passe hashés avec succès"

    # Étape 5: Vérification
    print_step "Vérification du hashage..."
    HASHED_COUNT=$(execute_sql -t -c "SELECT COUNT(*) FROM perc_participants WHERE password_hash IS NOT NULL AND password_hash != '';" | xargs)
    print_success "$HASHED_COUNT participants ont un mot de passe hashé"

    # Étape 6: Instructions pour l'envoi
    echo ""
    print_step "PROCHAINES ÉTAPES:"
    echo "  1. Ouvrir le fichier: $PASSWORD_EXPORT_FILE"
    echo "  2. Envoyer les mots de passe aux agents par SMS ou email sécurisé"
    echo "  3. Une fois envoyés, exécuter la commande suivante pour nettoyer:"
    echo ""
    echo "     psql -U $DB_USER -d $DB_NAME -c \"DROP TABLE temp_passwords_to_send;\""
    echo ""

    # Demander si on supprime maintenant
    read -p "$(echo -e ${YELLOW}?${NC} Voulez-vous supprimer la table temporaire MAINTENANT? [y/N]: )" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_step "Suppression de la table temporaire..."
        execute_sql -c "DROP TABLE IF EXISTS temp_passwords_to_send;"
        print_success "Table temporaire supprimée"
    else
        print_warning "Table temporaire conservée. N'OUBLIEZ PAS de la supprimer après l'envoi des mots de passe !"
    fi

    # Résumé final
    echo ""
    echo "=========================================="
    print_success "MIGRATION TERMINÉE AVEC SUCCÈS !"
    echo "=========================================="
    echo ""
    echo "Résumé:"
    echo "  • Participants avec mot de passe: $HASHED_COUNT"
    echo "  • Fichier d'export: $PASSWORD_EXPORT_FILE"
    echo "  • Prochaine étape: Envoyer les mots de passe aux agents"
    echo ""
    print_warning "IMPORTANT: Sécurisez le fichier CSV et supprimez-le après l'envoi !"
    echo ""
}

# Exécuter le script
main
