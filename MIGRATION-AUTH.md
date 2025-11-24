# Migration vers le système d'authentification par mot de passe

## Vue d'ensemble

Le système PERC a été migré d'un système d'authentification par OTP SMS vers un système par **matricule + mot de passe** pour réduire les coûts et améliorer la sécurité.

## Architecture

### Avant (OTP SMS)
```
Agent → Demande OTP → SMS envoyé → Code OTP → Connexion
```

### Après (Mot de passe)
```
Agent → Matricule + Mot de passe → Connexion
(Premier login: OTP unique pour définir le mot de passe)
```

## Étapes de migration

### 1. Mise à jour de la base de données

Le schéma a été modifié pour inclure :
- `password_hash` : Mot de passe hashé avec bcrypt
- `password_set` : Indique si le mot de passe a été défini
- `first_login_done` : Indique si la première connexion a été effectuée

**Fichier** : `database/schema.sql`

### 2. Génération des mots de passe initiaux

⚠️ **IMPORTANT** : Le système PERC a des particularités à prendre en compte :
- Certains agents ont **plusieurs numéros** de téléphone (ex: "775744436 / 776366412")
- Certains agents **n'ont PAS de numéro** de téléphone dans la base
- Un utilisateur test (M. ABABACAR DIOP, 508924B) a **déjà un mot de passe**

**Stratégies de génération :**

1. **Participants AVEC téléphone** → Mot de passe **UNIQUE aléatoire** (8 caractères)
2. **Participants SANS téléphone** → Mot de passe **COMMUN** : `MDS2024!`
3. **Participants avec mot de passe existant** → **AUCUNE modification**

#### Méthode Recommandée : Script PowerShell Automatisé

Le moyen le plus simple est d'utiliser le script PowerShell d'automatisation :

```powershell
.\scripts\migrate-passwords.ps1
```

Ce script effectue automatiquement :
1. ✅ Suppression de la vue `v_perc_comptes_actifs` (qui bloque les modifications)
2. ✅ Génération des mots de passe selon la stratégie (unique ou commun)
3. ✅ Export CSV avec colonne `type_generation`
4. ✅ Hashage avec bcrypt (10 rounds)
5. ✅ Statistiques détaillées par type
6. ✅ Warnings pour les participants sans téléphone

**Voir la documentation complète** : [scripts/README-MIGRATION.md](scripts/README-MIGRATION.md)

#### Méthode Manuelle (Alternative)

##### Étape 2.1 : Supprimer la vue bloquante
```sql
DROP VIEW IF EXISTS v_perc_comptes_actifs CASCADE;
```

##### Étape 2.2 : Exécuter le script SQL
```bash
docker-compose exec postgres psql -U perc_user -d perc_db -f /tmp/generate-passwords.sql
```

Ce script :
- Génère un mot de passe **unique** de 8 caractères pour chaque participant AVEC téléphone
- Assigne le mot de passe **commun** `MDS2024!` aux participants SANS téléphone
- Stocke les mots de passe en clair dans une table temporaire
- Marque les participants comme "en attente de premier login"

##### Étape 2.3 : Exporter les mots de passe vers CSV
```bash
docker-compose exec postgres psql -U perc_user -d perc_db -c \
  "COPY (SELECT matricule, nom, telephone, email, password_clear, type_generation, 'À changer à la première connexion' AS remarque FROM temp_passwords_to_send ORDER BY type_generation DESC, matricule) TO '/tmp/passwords.csv' WITH CSV HEADER;"

docker cp perc-docker-postgres-1:/tmp/passwords.csv ./output/passwords.csv
```

**⚠️ IMPORTANT** : Le CSV contient une colonne `type_generation` :
- `avec_telephone` : Mot de passe unique, à envoyer par SMS
- `sans_telephone` : Mot de passe commun "MDS2024!", à envoyer par email/courrier

##### Étape 2.4 : Hasher les mots de passe
```bash
docker-compose exec backend node /app/hash-passwords.js
```

Ce script :
- Lit les mots de passe en clair depuis `temp_passwords_to_send`
- Les hash avec bcrypt (10 rounds)
- Met à jour la colonne `password_hash` dans `perc_participants`
- Affiche des statistiques détaillées

##### Étape 2.5 : Envoyer les mots de passe aux agents

**Pour les agents AVEC téléphone** (type: `avec_telephone`) :
- Envoyer par **SMS** le mot de passe unique généré

**Format du SMS** :
```
PERC - Mutuelle des Douanes
Votre mot de passe initial : [PASSWORD]
Connectez-vous sur perc.mutuelle.sn
Changez-le à la première connexion.
```

**Pour les agents SANS téléphone** (type: `sans_telephone`) :
- Envoyer par **email** ou **courrier postal**
- Le mot de passe est : `MDS2024!`

**Format du message** :
```
PERC - Mutuelle des Douanes du Sénégal

Cher(e) participant(e),

Votre matricule : [MATRICULE]
Votre mot de passe temporaire : MDS2024!

Connectez-vous sur perc.mutuelle.sn avec votre matricule et ce mot de passe.
Vous devrez le changer lors de votre première connexion.

Cordialement,
L'équipe PERC
```

##### Étape 2.6 : Supprimer la table temporaire
```sql
DROP TABLE temp_passwords_to_send;
```

**⚠️ CRITIQUE** : Ne pas oublier cette étape pour éviter les fuites de données !

##### Étape 2.7 : Supprimer le fichier CSV
```powershell
Remove-Item output/passwords*.csv
```

**⚠️ SÉCURITÉ** : Le fichier CSV contient des mots de passe en clair !

## API Endpoints

### Authentification Agent

#### 1. Vérifier le statut de l'agent
```http
POST /api/auth/agent/check-status
Content-Type: application/json

{
  "matricule": "123456B"
}

Réponse:
{
  "success": true,
  "data": {
    "matricule": "123456B",
    "nom": "Jean Dupont",
    "has_password": true,
    "first_login_done": false
  }
}
```

#### 2. Connexion avec mot de passe
```http
POST /api/auth/agent/login
Content-Type: application/json

{
  "matricule": "123456B",
  "password": "Motdepasse123"
}

Réponse:
{
  "success": true,
  "message": "Connexion réussie",
  "token": "abc123...",
  "user": {
    "matricule": "123456B",
    "nom": "Jean Dupont",
    "email": "jean@example.com",
    "compte_cgf": "CGF123",
    "solde": 1500000.00
  }
}
```

#### 3. Changer le mot de passe
```http
POST /api/auth/agent/change-password
Authorization: Bearer {token}
Content-Type: application/json

{
  "currentPassword": "AncienMotDePasse",
  "newPassword": "NouveauMotDePasse123"
}

Réponse:
{
  "success": true,
  "message": "Mot de passe modifié avec succès"
}
```

#### 4. Première connexion (OTP + définir mot de passe)
```http
POST /api/auth/agent/request-otp
Content-Type: application/json

{
  "matricule": "123456B",
  "type": "first_login"
}

Puis:
POST /api/auth/agent/verify-otp-and-set-password
Content-Type: application/json

{
  "matricule": "123456B",
  "otp": "123456",
  "password": "MonNouveauMotDePasse123"
}
```

### Authentification Admin

#### Réinitialiser le mot de passe d'un agent
```http
POST /api/auth/admin/reset-password
Authorization: Bearer {admin_token}
Content-Type: application/json

{
  "matricule": "123456B",
  "newPassword": "MotDePasseTemporaire123"
}

Réponse:
{
  "success": true,
  "message": "Mot de passe réinitialisé avec succès. L'agent devra le changer à la prochaine connexion."
}
```

## Middleware

### 1. authMiddleware
Vérifie que l'utilisateur est authentifié.

```javascript
const { authMiddleware } = require('./middleware/auth');

router.get('/protected-route', authMiddleware, async (req, res) => {
  // req.user contient les infos de l'agent
  console.log(req.user.matricule);
});
```

### 2. requirePasswordChange
Force le changement de mot de passe si nécessaire.

```javascript
const { authMiddleware, requirePasswordChange } = require('./middleware/auth');

router.get('/dashboard',
  authMiddleware,
  requirePasswordChange,
  async (req, res) => {
  // L'agent a changé son mot de passe
});
```

### 3. authAdminMiddleware
Vérifie que c'est un administrateur.

```javascript
const { authAdminMiddleware } = require('./middleware/auth');

router.post('/admin-action', authAdminMiddleware, async (req, res) => {
  // req.admin contient les infos de l'admin
});
```

## Pages Frontend

### Pages créées
1. **change-password.html** : Page de changement de mot de passe
   - Vérification de la force du mot de passe
   - Confirmation du mot de passe
   - Validation en temps réel

### Modifications nécessaires
1. Créer **agent-login.html** : Page de login avec matricule + mot de passe
2. Créer **first-login.html** : Page pour la première connexion (OTP + définir mot de passe)
3. Modifier **agent-dashboard.html** : Ajouter lien vers changement de mot de passe

## Sécurité

### Mots de passe
- **Minimum** : 6 caractères
- **Recommandé** : 8+ caractères avec lettres, chiffres et symboles
- **Hash** : bcrypt avec 10 rounds
- **Stockage** : Uniquement le hash, jamais le mot de passe en clair

### Sessions
- **Durée agent** : 30 jours
- **Durée admin** : 7 jours
- **Token** : 32 bytes aléatoires (hex)
- **Stockage** : Table `perc_sessions` avec expiration

### Sécurité supplémentaire
- Tentatives de connexion loguées dans `perc_login_attempts`
- OTP conservé uniquement pour première connexion et reset
- Suppression automatique des sessions expirées

## Tests

### Test de génération de mots de passe
```bash
# 1. Exécuter le script SQL
psql -U perc_user -d perc_db -f database/generate-passwords.sql

# 2. Vérifier la génération
psql -U perc_user -d perc_db -c "SELECT COUNT(*) FROM temp_passwords_to_send;"

# 3. Hasher les mots de passe
node scripts/hash-passwords.js

# 4. Vérifier le hashage
psql -U perc_user -d perc_db -c "SELECT matricule, password_set FROM perc_participants LIMIT 5;"
```

### Test de connexion
```bash
# Tester login agent
curl -X POST http://localhost:3000/api/auth/agent/login \
  -H "Content-Type: application/json" \
  -d '{"matricule":"123456B","password":"MotDePasse123"}'

# Tester changement de mot de passe
curl -X POST http://localhost:3000/api/auth/agent/change-password \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {token}" \
  -d '{"currentPassword":"Ancien","newPassword":"Nouveau123"}'
```

## Dépannage

### Problème : "Matricule ou mot de passe incorrect"
- Vérifier que le mot de passe a été hashé (script hash-passwords.js)
- Vérifier que `password_set = TRUE` dans la base
- Vérifier la casse du matricule

### Problème : "Vous devez d'abord définir un mot de passe"
- L'agent n'a pas encore de mot de passe
- Utiliser le flux OTP + set password
- Ou l'admin peut réinitialiser le mot de passe

### Problème : "Session invalide ou expirée"
- Le token a expiré (> 30 jours)
- Reconnexion nécessaire
- Vérifier la table `perc_sessions`

## Rollback

En cas de problème, pour revenir à l'ancien système OTP :

```sql
-- 1. Supprimer les mots de passe
UPDATE perc_participants
SET password_hash = NULL,
    password_set = FALSE,
    first_login_done = FALSE;

-- 2. Restaurer le code backend précédent
git checkout [commit-avant-migration]

-- 3. Redémarrer le serveur
docker-compose restart backend
```

## Support

Pour toute question ou problème :
- **Email** : support@perc.mutuelle.sn
- **Téléphone** : +221 XX XXX XX XX
- **Documentation** : /docs/auth-system.md
