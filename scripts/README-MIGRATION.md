# Guide de Migration - Authentification par Mot de Passe

## Vue d'ensemble

Ce guide décrit le processus de migration de l'authentification OTP SMS vers l'authentification par **matricule + mot de passe** pour le système PERC.

## Contexte Important

### Particularités de la base de données PERC

1. **Numéros de téléphone multiples** : Certains agents ont plusieurs numéros (format: "775744436 / 776366412")
2. **Numéros internationaux** : Certains utilisent le format international ("+221776566250")
3. **Participants sans téléphone** : Certains agents n'ont PAS de numéro de téléphone dans la base
4. **Utilisateur test existant** : M. ABABACAR DIOP (508924B) a déjà un mot de passe hashé

### Stratégie de génération des mots de passe

Le système génère des mots de passe selon deux stratégies :

#### 1. **Participants AVEC numéro de téléphone**
- ✅ Mot de passe **UNIQUE** et **ALÉATOIRE** de 8 caractères
- Format : Majuscules + minuscules + chiffres
- Exemple : `Kx9mP2Lq`, `Wr5tN8Js`
- Distribution : Par **SMS**
- Type : `avec_telephone`

#### 2. **Participants SANS numéro de téléphone**
- ⚠️ Mot de passe **COMMUN** : `MDS2024!`
- Raison : Impossible d'envoyer par SMS
- Distribution : Par **email** ou **courrier postal**
- Type : `sans_telephone`

#### 3. **Participants avec mot de passe existant**
- 🔒 **AUCUNE modification**
- Le mot de passe actuel est conservé
- Exemple : M. ABABACAR DIOP (508924B)

---

## Fichiers de Migration

### 1. `database/generate-passwords.sql`
Script SQL qui génère les mots de passe selon la stratégie définie.

**Modifications apportées :**
- ✅ Champ `telephone` étendu à VARCHAR(100) au lieu de VARCHAR(20)
- ✅ Ajout du champ `type_generation` ('avec_telephone' ou 'sans_telephone')
- ✅ Logique conditionnelle pour générer mot de passe unique ou commun
- ✅ Exclusion des participants ayant déjà un mot de passe
- ✅ Statistiques détaillées affichées dans les logs

### 2. `scripts/hash-passwords.js`
Script Node.js qui hash les mots de passe générés avec bcrypt.

**Modifications apportées :**
- ✅ Lecture du champ `type_generation`
- ✅ Compteurs séparés pour les deux types
- ✅ Logging détaillé avec distinction unique/commun
- ✅ Message d'alerte si participants sans téléphone détectés

### 3. `scripts/migrate-passwords.ps1`
Script PowerShell d'automatisation complète de la migration.

**Fonctionnalités :**
- ✅ Suppression de la vue `v_perc_comptes_actifs` qui bloque les modifications
- ✅ Copie et exécution du script SQL dans le conteneur Docker
- ✅ Export CSV avec colonne `type_generation`
- ✅ Hashage automatique des mots de passe
- ✅ Statistiques détaillées avec compteurs par type
- ✅ Messages colorés pour meilleure lisibilité
- ✅ Confirmation avant suppression de la table temporaire
- ✅ Warnings spécifiques pour les participants sans téléphone

---

## Processus de Migration

### Prérequis

1. **Docker Desktop** installé et en cours d'exécution
2. **Conteneurs PERC** démarrés : `docker-compose up -d`
3. **Node.js et bcrypt** installés dans le conteneur backend
4. **Variables d'environnement** configurées dans `.env`

### Étapes d'exécution

#### 1. Lancer le script PowerShell

```powershell
cd c:\Users\HP\Desktop\dev\perc-docker
.\scripts\migrate-passwords.ps1
```

#### 2. Confirmer l'opération

Le script demandera confirmation :
```
⚠ Cette opération va générer des mots de passe pour tous les participants.
⚠ Les participants sans numéro de téléphone recevront un mot de passe commun.
Continuer? [o/N]
```

Tapez `o` pour continuer.

#### 3. Le script effectuera automatiquement :

1. ✅ Vérification de Docker
2. ✅ Création du répertoire `output/`
3. ✅ Suppression de la vue `v_perc_comptes_actifs`
4. ✅ Copie du script SQL dans le conteneur PostgreSQL
5. ✅ Génération des mots de passe
6. ✅ Export CSV vers `output/passwords_YYYYMMDD_HHMMSS.csv`
7. ✅ Hashage des mots de passe avec bcrypt
8. ✅ Vérification finale

#### 4. Vérifier les statistiques

Le script affichera des statistiques détaillées :

```
✓ Mots de passe générés pour 1892 participants
  → Avec téléphone (mot de passe unique) : 1850
  ⚠ → Sans téléphone (mot de passe commun 'MDS2024!') : 42
```

#### 5. Distribution des mots de passe

##### Pour les participants AVEC téléphone (1850)
- 📱 Ouvrir le fichier CSV : `output/passwords_YYYYMMDD_HHMMSS.csv`
- 📱 Filtrer les lignes où `type_generation = "avec_telephone"`
- 📱 Envoyer chaque mot de passe par **SMS** au numéro indiqué

**Format du SMS :**
```
PERC - Mutuelle des Douanes
Votre mot de passe initial : [PASSWORD]
Connectez-vous sur perc.mutuelle.sn
Changez-le à la première connexion.
```

##### Pour les participants SANS téléphone (42)
- 📧 Filtrer les lignes où `type_generation = "sans_telephone"`
- 📧 Envoyer par **email** ou **courrier postal**
- 📧 Informer que le mot de passe est : `MDS2024!`

**Format du message :**
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

#### 6. Supprimer la table temporaire

Après distribution de TOUS les mots de passe :

```powershell
# Le script demandera confirmation
Supprimer maintenant? [o/N]
```

Ou manuellement :
```bash
docker-compose exec postgres psql -U perc_user -d perc_db -c "DROP TABLE temp_passwords_to_send;"
```

#### 7. Sécuriser le fichier CSV

⚠️ **CRITIQUE** : Le fichier CSV contient des mots de passe en clair !

Actions recommandées :
- 🔒 **Déplacer** le fichier vers un emplacement sécurisé
- 🔒 **Chiffrer** le fichier si nécessaire
- 🔒 **Supprimer** le fichier après distribution complète
- 🔒 **Ne JAMAIS** le commiter dans Git

```powershell
# Supprimer le fichier CSV
Remove-Item output/passwords_*.csv
```

---

## Structure du CSV généré

Le fichier CSV contient les colonnes suivantes :

| Colonne | Description | Exemple |
|---------|-------------|---------|
| `matricule` | Matricule de l'agent | 508924B |
| `nom` | Nom complet | ABABACAR DIOP |
| `telephone` | Numéro(s) de téléphone | 775744436 / 776366412 |
| `email` | Adresse email | agent@example.com |
| `password_clear` | Mot de passe en clair | Kx9mP2Lq ou MDS2024! |
| `type_generation` | Type de génération | avec_telephone ou sans_telephone |
| `remarque` | Note | À changer à la première connexion |

**Ordre de tri :**
1. Par `type_generation` (DESC) : les "sans_telephone" apparaissent en premier
2. Par `matricule` (ASC)

---

## Vérifications Post-Migration

### 1. Vérifier le nombre de participants avec mot de passe

```sql
SELECT COUNT(*)
FROM perc_participants
WHERE password_hash IS NOT NULL AND password_hash != '';
```

Résultat attendu : **1893** (1892 nouveaux + 1 existant)

### 2. Vérifier la répartition par type

```sql
-- Participants AVEC téléphone
SELECT COUNT(*)
FROM perc_participants
WHERE password_hash IS NOT NULL
  AND (telephone IS NOT NULL AND telephone != '');

-- Participants SANS téléphone
SELECT COUNT(*)
FROM perc_participants
WHERE password_hash IS NOT NULL
  AND (telephone IS NULL OR telephone = '');
```

### 3. Tester la connexion

Tester avec un participant :
- Matricule : `508924B`
- Mot de passe : Voir le CSV ou utiliser le mot de passe généré

```bash
curl -X POST http://localhost:3000/api/auth/agent/login \
  -H "Content-Type: application/json" \
  -d '{"matricule":"508924B","password":"[PASSWORD]"}'
```

---

## Dépannage

### Problème : "value too long for type character varying(20)"

**Cause :** Le champ `telephone` est trop court pour les numéros multiples.

**Solution :** Déjà corrigée dans `generate-passwords.sql` (VARCHAR(100))

### Problème : "relation 'v_perc_comptes_actifs' does not exist"

**Cause :** La vue a déjà été supprimée.

**Solution :** Ignorer cette erreur, c'est normal.

### Problème : "temp_passwords_to_send already exists"

**Cause :** Une exécution précédente a laissé la table temporaire.

**Solution :**
```sql
DROP TABLE IF EXISTS temp_passwords_to_send;
```

Puis relancer le script.

### Problème : Docker n'est pas démarré

**Erreur :** `Docker Compose n'est pas en cours d'exécution`

**Solution :**
```bash
docker-compose up -d
```

---

## Rollback (Retour en arrière)

En cas de problème critique, pour revenir à l'état précédent :

### 1. Supprimer tous les mots de passe générés

```sql
UPDATE perc_participants
SET
    password_hash = NULL,
    password_set = FALSE,
    first_login_done = FALSE
WHERE matricule != '508924B';  -- Garder l'utilisateur test
```

### 2. Supprimer la table temporaire

```sql
DROP TABLE IF EXISTS temp_passwords_to_send;
```

### 3. Restaurer le code backend OTP

```bash
git checkout [commit-avant-migration]
docker-compose restart backend
```

---

## Support

Pour toute question ou problème :
- **Documentation complète** : [MIGRATION-AUTH.md](../MIGRATION-AUTH.md)
- **Email** : support@perc.mutuelle.sn
- **Scripts** : [scripts/](.)

---

## Checklist de Migration

- [ ] Vérifier que Docker est démarré
- [ ] Exécuter `migrate-passwords.ps1`
- [ ] Vérifier les statistiques affichées
- [ ] Ouvrir le fichier CSV généré
- [ ] Filtrer les participants AVEC téléphone
- [ ] Envoyer les SMS pour les mots de passe uniques
- [ ] Filtrer les participants SANS téléphone
- [ ] Envoyer les emails/courriers avec mot de passe commun
- [ ] Tester la connexion avec quelques comptes
- [ ] Supprimer la table temporaire
- [ ] Supprimer le fichier CSV
- [ ] Vérifier le nombre total de comptes migrés
- [ ] Informer les utilisateurs de la nouvelle méthode d'authentification

---

**Date de création** : 23 novembre 2025
**Version** : 1.0
**Auteur** : Équipe PERC
