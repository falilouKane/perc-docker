# 🚀 Guide Rapide - Migration des Mots de Passe PERC

## TL;DR (Résumé Ultra-Court)

Pour migrer vers l'authentification par mot de passe :

```powershell
# 1. Démarrer Docker
docker-compose up -d

# 2. Lancer le script de migration
.\scripts\migrate-passwords.ps1

# 3. Distribuer les mots de passe
# - SMS pour ceux avec téléphone (mot de passe unique)
# - Email/courrier pour ceux sans téléphone (MDS2024!)

# 4. Supprimer le CSV
Remove-Item output/passwords*.csv
```

---

## ⚡ Exécution Rapide

### Étape 1 : Lancer la migration

```powershell
cd c:\Users\HP\Desktop\dev\perc-docker
.\scripts\migrate-passwords.ps1
```

### Étape 2 : Confirmer

```
Continuer? [o/N]: o
```

### Étape 3 : Attendre la fin

Le script affichera :
```
✓ Mots de passe générés pour 1892 participants
  → Avec téléphone (mot de passe unique) : 1850
  ⚠ → Sans téléphone (mot de passe commun 'MDS2024!') : 42

✓ Mots de passe exportés vers : output/passwords_20251123_143022.csv
```

### Étape 4 : Distribuer les mots de passe

Ouvrir le fichier CSV généré dans `output/`

**Colonne importante : `type_generation`**

#### Pour `type_generation = "avec_telephone"` (1850 agents)
- 📱 Envoyer par **SMS** le mot de passe dans la colonne `password_clear`

**Format du SMS :**
```
PERC - Votre mot de passe : [password_clear]
Connectez-vous sur perc.mutuelle.sn
Changez-le à la première connexion.
```

#### Pour `type_generation = "sans_telephone"` (42 agents)
- 📧 Envoyer par **email** ou **courrier**
- Mot de passe : `MDS2024!` (le même pour tous)

**Format email :**
```
Bonjour,

Matricule : [matricule]
Mot de passe temporaire : MDS2024!

Connectez-vous sur perc.mutuelle.sn
Changez-le à la première connexion.

PERC - Mutuelle des Douanes
```

### Étape 5 : Nettoyer

```powershell
# Supprimer la table temporaire (si pas déjà fait)
docker-compose exec postgres psql -U perc_user -d perc_db -c "DROP TABLE temp_passwords_to_send;"

# Supprimer le fichier CSV
Remove-Item output/passwords*.csv
```

---

## 📊 Vérification Rapide

```sql
-- Nombre total de participants avec mot de passe
SELECT COUNT(*) FROM perc_participants WHERE password_hash IS NOT NULL;
-- Attendu : 1893 (1892 nouveaux + 1 existant)

-- Avec téléphone
SELECT COUNT(*) FROM perc_participants WHERE password_hash IS NOT NULL AND (telephone IS NOT NULL AND telephone != '');

-- Sans téléphone
SELECT COUNT(*) FROM perc_participants WHERE password_hash IS NOT NULL AND (telephone IS NULL OR telephone = '');
```

---

## ⚠️ Points Importants

1. **Deux types de mots de passe** :
   - UNIQUE (avec téléphone) : 8 caractères aléatoires
   - COMMUN (sans téléphone) : `MDS2024!`

2. **Sécurité** :
   - Le CSV contient des mots de passe en clair
   - Le supprimer après distribution
   - Ne JAMAIS le commiter dans Git

3. **Participant test** :
   - M. ABABACAR DIOP (508924B) garde son mot de passe actuel
   - Ne recevra PAS de nouveau mot de passe

---

## 🆘 En cas de problème

### Docker n'est pas démarré
```bash
docker-compose up -d
```

### La table temporaire existe déjà
```sql
DROP TABLE IF EXISTS temp_passwords_to_send;
```
Puis relancer le script.

### Besoin de rollback
```sql
UPDATE perc_participants
SET password_hash = NULL, password_set = FALSE, first_login_done = FALSE
WHERE matricule != '508924B';
```

---

## 📚 Documentation Complète

- **Guide détaillé** : [scripts/README-MIGRATION.md](scripts/README-MIGRATION.md)
- **Documentation API** : [MIGRATION-AUTH.md](MIGRATION-AUTH.md)
- **Scripts** : [scripts/](scripts/)

---

## ✅ Checklist

- [ ] Docker démarré
- [ ] Script `migrate-passwords.ps1` exécuté
- [ ] Fichier CSV généré
- [ ] SMS envoyés (avec téléphone)
- [ ] Emails envoyés (sans téléphone)
- [ ] Connexion testée
- [ ] Table temporaire supprimée
- [ ] Fichier CSV supprimé
- [ ] Utilisateurs informés

---

**Durée estimée** : 30 minutes + temps d'envoi des SMS/emails
