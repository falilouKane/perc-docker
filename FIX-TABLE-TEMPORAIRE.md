# 🔧 Correction - Problème de Table Temporaire

**Date** : 23 novembre 2025
**Problème** : La table `temp_passwords_to_send` disparaît entre les sessions PostgreSQL

---

## 🚨 Problème Identifié

### Erreurs observées lors de l'exécution

```
==> Export des mots de passe vers CSV...
Error response from daemon: Could not find the file /tmp/passwords_export.csv in container perc-postgres

==> Hashage des mots de passe avec bcrypt...
error: relation "temp_passwords_to_send" does not exist
```

### Analyse

1. **Table TEMP disparaît** : `CREATE TEMP TABLE` crée une table qui existe uniquement pendant la session PostgreSQL
2. **Sessions multiples** : Le script PowerShell exécute plusieurs commandes `psql` indépendantes
3. **Flux du problème** :
   ```
   Session 1: psql -f generate-passwords.sql
              → Crée TEMP TABLE
              → Insère les données
              → Session se termine
              → TABLE DISPARAÎT ❌

   Session 2: psql -c "COPY ... TO '/tmp/...'"
              → Cherche la table
              → Table n'existe plus ❌

   Session 3: node hash-passwords.js
              → Cherche la table
              → Table n'existe plus ❌
   ```

---

## ✅ Solution Appliquée

### Changement dans `database/generate-passwords.sql`

**AVANT** (ligne 8) :
```sql
CREATE TEMP TABLE IF NOT EXISTS temp_passwords_to_send (
```

**APRÈS** (lignes 9-11) :
```sql
-- Table (NON temporaire) pour stocker les mots de passe en clair (à supprimer après envoi)
-- IMPORTANT : Cette table doit être supprimée après distribution des mots de passe
DROP TABLE IF EXISTS temp_passwords_to_send;

CREATE TABLE temp_passwords_to_send (
```

### Avantages

✅ La table persiste entre les sessions PostgreSQL
✅ Le script peut exporter le CSV dans une session différente
✅ Le script Node.js peut accéder à la table depuis le conteneur backend
✅ Ajout de `DROP TABLE IF EXISTS` pour permettre de relancer le script

### Inconvénients et Mitigation

⚠️ **Risque** : La table permanente contient des mots de passe en clair
✅ **Mitigation** : Le script demande confirmation avant de la supprimer
✅ **Documentation** : Instructions claires pour supprimer après distribution

---

## 🎯 Améliorations du Script PowerShell

### Ajout du debug SQL (ligne 120-123)

```powershell
# Afficher toute la sortie pour debug
Write-Host "Sortie SQL complète :" -ForegroundColor Gray
$sqlOutput | ForEach-Object {
    Write-Host "  $_" -ForegroundColor DarkGray
}
```

**Pourquoi** : Permet de voir les erreurs SQL si la génération échoue

### Vérification des statistiques (ligne 140-143)

```powershell
if (-not $foundStats) {
    Write-Warning "Aucune statistique trouvée dans la sortie SQL"
    Write-Warning "Le script SQL a peut-être échoué silencieusement"
}
```

**Pourquoi** : Détecte si le script SQL n'a pas fonctionné correctement

---

## 📝 Nouveau Flux de Migration

```
1. DROP TABLE IF EXISTS temp_passwords_to_send
   → Nettoie une éventuelle table précédente

2. CREATE TABLE temp_passwords_to_send
   → Crée une table PERMANENTE

3. INSERT INTO temp_passwords_to_send
   → Génère et insère les mots de passe
   → Table reste accessible

4. COPY TO CSV (nouvelle session psql)
   → Table toujours accessible ✅

5. Node.js hash-passwords.js (depuis conteneur backend)
   → Table toujours accessible ✅

6. DROP TABLE temp_passwords_to_send (après confirmation)
   → Suppression manuelle pour sécurité
```

---

## 🧪 Test de la Correction

### 1. Relancer le script

```powershell
.\scripts\migrate-passwords.ps1
```

### 2. Vérifications attendues

✅ **Sortie SQL complète** s'affiche avec les commandes CREATE TABLE, INSERT, etc.
✅ **Statistiques** s'affichent :
```
✓ Mots de passe générés pour 1892 participants
  → Avec téléphone (mot de passe unique) : 1850
  ⚠ → Sans téléphone (mot de passe commun 'MDS2024!') : 42
```
✅ **CSV créé** dans `output/passwords_YYYYMMDD_HHMMSS.csv`
✅ **Aperçu du CSV** s'affiche
✅ **Hashage réussi** avec logs détaillés

### 3. Vérifier la table manuellement

```bash
# Se connecter à PostgreSQL
docker-compose exec postgres psql -U perc_user -d perc_db

# Vérifier que la table existe
\dt temp_passwords_to_send

# Compter les enregistrements
SELECT COUNT(*) FROM temp_passwords_to_send;

# Afficher quelques exemples
SELECT matricule, type_generation FROM temp_passwords_to_send LIMIT 5;

# Quitter
\q
```

---

## 🔒 Sécurité - Suppression de la Table

### Automatique (recommandé)

Le script demande confirmation à la fin :
```
Supprimer maintenant? [o/N]: o
```

### Manuelle (si non supprimée)

```sql
-- Se connecter
docker-compose exec postgres psql -U perc_user -d perc_db

-- Supprimer la table
DROP TABLE temp_passwords_to_send;
```

Ou en une seule commande :
```bash
docker-compose exec postgres psql -U perc_user -d perc_db -c "DROP TABLE temp_passwords_to_send;"
```

---

## 📋 Checklist Post-Correction

- [x] `database/generate-passwords.sql` modifié (TEMP → permanente)
- [x] Script PowerShell amélioré (debug SQL)
- [x] Documentation créée (ce fichier)
- [ ] Script testé et validé
- [ ] Table supprimée après distribution

---

## ⚠️ Points d'Attention

1. **Ne JAMAIS commiter** la table `temp_passwords_to_send` dans un backup de base de données
2. **Toujours supprimer** la table après distribution des mots de passe
3. **Vérifier** que le CSV a bien été supprimé aussi : `output/passwords_*.csv`

---

## 🔄 En cas d'erreur persistante

Si le script échoue toujours :

### 1. Vérifier que la table existe
```sql
SELECT * FROM temp_passwords_to_send LIMIT 1;
```

### 2. Vérifier les permissions
```sql
-- Vérifier le propriétaire
SELECT tableowner FROM pg_tables WHERE tablename = 'temp_passwords_to_send';

-- Doit être : perc_user
```

### 3. Réinitialiser complètement
```sql
-- Supprimer la table
DROP TABLE IF EXISTS temp_passwords_to_send CASCADE;

-- Relancer le script
```

---

## 📞 Support

Si le problème persiste après ces corrections :
1. Vérifier les logs PostgreSQL : `docker-compose logs postgres`
2. Vérifier la connexion backend → postgres : `docker-compose logs backend`
3. Tester la connexion manuellement depuis le backend

---

**Version** : 1.2.0
**Status** : En attente de test
**Prochaine étape** : Relancer `.\scripts\migrate-passwords.ps1`
