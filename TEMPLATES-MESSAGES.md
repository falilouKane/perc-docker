# 📧 Templates de Messages - Distribution des Mots de Passe

## Vue d'ensemble

Ce document contient les templates de messages pour distribuer les mots de passe aux participants PERC selon leur situation.

---

## 📱 Template SMS - Participants AVEC Téléphone

**Utilisation :** Pour les participants avec `type_generation = "avec_telephone"` dans le CSV

**Longueur :** ~150 caractères (pour 1 SMS)

### Version Française

```
PERC - Mutuelle des Douanes
Votre mot de passe initial : [PASSWORD]
Connectez-vous sur perc.mutuelle.sn
Changez-le à la première connexion.
```

### Version Wolof (optionnel)

```
PERC - Mutuelle des Douanes
Sa mot de passe : [PASSWORD]
Dugal ci perc.mutuelle.sn
Waral ko ci primera connexion.
```

### Variables à remplacer

| Variable | Source | Exemple |
|----------|--------|---------|
| `[PASSWORD]` | Colonne `password_clear` du CSV | `Kx9mP2Lq` |

### Exemple concret

```
PERC - Mutuelle des Douanes
Votre mot de passe initial : Kx9mP2Lq
Connectez-vous sur perc.mutuelle.sn
Changez-le à la première connexion.
```

---

## 📧 Template Email - Participants SANS Téléphone

**Utilisation :** Pour les participants avec `type_generation = "sans_telephone"` dans le CSV

**Sujet :** PERC - Vos identifiants de connexion

### Corps du message

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
        }
        .header {
            background: linear-gradient(135deg, #0047ab, #003380);
            color: white;
            padding: 20px;
            text-align: center;
        }
        .content {
            padding: 30px;
            background: #f9f9f9;
        }
        .credentials {
            background: white;
            border-left: 4px solid #ff4500;
            padding: 20px;
            margin: 20px 0;
        }
        .credentials strong {
            color: #0047ab;
        }
        .warning {
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 15px;
            margin: 20px 0;
        }
        .footer {
            text-align: center;
            color: #666;
            font-size: 0.9em;
            padding: 20px;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>PERC - Mutuelle des Douanes du Sénégal</h1>
        <p>Plan Épargne Retraite Complémentaire</p>
    </div>

    <div class="content">
        <p>Cher(e) <strong>[NOM]</strong>,</p>

        <p>Dans le cadre de la modernisation de notre système d'authentification,
        nous vous transmettons vos nouveaux identifiants de connexion à la plateforme PERC.</p>

        <div class="credentials">
            <h3>Vos identifiants de connexion :</h3>
            <p><strong>Matricule :</strong> [MATRICULE]</p>
            <p><strong>Mot de passe temporaire :</strong> MDS2024!</p>
            <p><strong>URL de connexion :</strong> <a href="https://perc.mutuelle.sn">perc.mutuelle.sn</a></p>
        </div>

        <div class="warning">
            <h4>⚠️ IMPORTANT - Sécurité</h4>
            <ul>
                <li>Ce mot de passe est <strong>temporaire</strong></li>
                <li>Vous <strong>devez le changer</strong> lors de votre première connexion</li>
                <li>Choisissez un mot de passe <strong>unique et sécurisé</strong> (minimum 6 caractères)</li>
                <li>Ne partagez <strong>jamais</strong> votre mot de passe</li>
            </ul>
        </div>

        <h3>📋 Étapes de première connexion :</h3>
        <ol>
            <li>Rendez-vous sur <a href="https://perc.mutuelle.sn">perc.mutuelle.sn</a></li>
            <li>Entrez votre matricule : <strong>[MATRICULE]</strong></li>
            <li>Entrez le mot de passe temporaire : <strong>MDS2024!</strong></li>
            <li>Vous serez invité à définir un nouveau mot de passe personnel</li>
            <li>Choisissez un mot de passe fort (lettres, chiffres, symboles)</li>
            <li>Confirmez votre nouveau mot de passe</li>
        </ol>

        <p>Si vous rencontrez des difficultés, n'hésitez pas à contacter notre support technique.</p>

        <p>Cordialement,<br>
        <strong>L'équipe PERC</strong><br>
        Mutuelle des Douanes du Sénégal</p>
    </div>

    <div class="footer">
        <p>📞 Support : +221 XX XXX XX XX | 📧 Email : support@perc.mutuelle.sn</p>
        <p>Ce message est confidentiel. Si vous l'avez reçu par erreur, merci de nous en informer.</p>
    </div>
</body>
</html>
```

### Version texte simple

```
PERC - Mutuelle des Douanes du Sénégal
Plan Épargne Retraite Complémentaire

Cher(e) [NOM],

Dans le cadre de la modernisation de notre système d'authentification,
nous vous transmettons vos nouveaux identifiants de connexion.

═══════════════════════════════════════════════════
VOS IDENTIFIANTS DE CONNEXION
═══════════════════════════════════════════════════

Matricule : [MATRICULE]
Mot de passe temporaire : MDS2024!
URL : perc.mutuelle.sn

═══════════════════════════════════════════════════
⚠️ IMPORTANT - SÉCURITÉ
═══════════════════════════════════════════════════

✓ Ce mot de passe est TEMPORAIRE
✓ Vous DEVEZ le changer lors de votre première connexion
✓ Choisissez un mot de passe UNIQUE et SÉCURISÉ (min 6 caractères)
✓ Ne partagez JAMAIS votre mot de passe

═══════════════════════════════════════════════════
ÉTAPES DE PREMIÈRE CONNEXION
═══════════════════════════════════════════════════

1. Allez sur perc.mutuelle.sn
2. Entrez votre matricule : [MATRICULE]
3. Entrez le mot de passe temporaire : MDS2024!
4. Définissez un nouveau mot de passe personnel
5. Confirmez votre nouveau mot de passe

═══════════════════════════════════════════════════

Pour toute question, contactez notre support :
📞 Téléphone : +221 XX XXX XX XX
📧 Email : support@perc.mutuelle.sn

Cordialement,
L'équipe PERC - Mutuelle des Douanes du Sénégal

---
Ce message est confidentiel. Si vous l'avez reçu par erreur,
merci de nous en informer immédiatement.
```

### Variables à remplacer

| Variable | Source | Exemple |
|----------|--------|---------|
| `[NOM]` | Colonne `nom` du CSV | `JEAN DUPONT` |
| `[MATRICULE]` | Colonne `matricule` du CSV | `123456C` |

---

## 📄 Template Courrier Postal - Participants SANS Contact

**Utilisation :** Pour les participants sans téléphone ET sans email

### Format A4

```
═══════════════════════════════════════════════════════════════════════════

                    PERC - MUTUELLE DES DOUANES DU SÉNÉGAL
                   Plan Épargne Retraite Complémentaire

                   Siège Social : [ADRESSE]
                   Tél : +221 XX XXX XX XX
                   Email : contact@perc.mutuelle.sn

═══════════════════════════════════════════════════════════════════════════

                              COURRIER CONFIDENTIEL

Destinataire :
[NOM]
[ADRESSE_PARTICIPANT]

Réf : PERC/AUTH/2025/[MATRICULE]
Date : [DATE]

Objet : Nouveaux identifiants de connexion à la plateforme PERC

═══════════════════════════════════════════════════════════════════════════

Cher(e) Monsieur/Madame [NOM],

Dans le cadre de la modernisation de notre système d'information, nous avons
le plaisir de vous informer de la mise en place d'un nouveau système
d'authentification pour accéder à votre espace personnel PERC.

Vos identifiants de connexion sont les suivants :

┌────────────────────────────────────────────────────────────────────────┐
│                                                                        │
│  MATRICULE :         [MATRICULE]                                       │
│                                                                        │
│  MOT DE PASSE :      MDS2024!                                          │
│                                                                        │
│  SITE WEB :          perc.mutuelle.sn                                  │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘


⚠️  IMPORTANT - CONSIGNES DE SÉCURITÉ

Ce mot de passe est TEMPORAIRE. Pour des raisons de sécurité, vous devrez
obligatoirement le modifier lors de votre première connexion.

Recommandations :
• Choisissez un mot de passe d'au moins 6 caractères
• Utilisez une combinaison de lettres, chiffres et symboles
• Ne partagez jamais votre mot de passe
• Changez votre mot de passe régulièrement


PROCÉDURE DE PREMIÈRE CONNEXION

1. Rendez-vous sur le site : perc.mutuelle.sn
2. Saisissez votre matricule : [MATRICULE]
3. Saisissez le mot de passe temporaire : MDS2024!
4. Vous serez automatiquement invité à définir un nouveau mot de passe
5. Choisissez un mot de passe personnel et sécurisé
6. Confirmez votre nouveau mot de passe


ASSISTANCE TECHNIQUE

En cas de difficulté, notre équipe support est à votre disposition :

    📞 Téléphone : +221 XX XXX XX XX
       (Du lundi au vendredi, de 8h à 17h)

    📧 Email : support@perc.mutuelle.sn

    🏢 Accueil physique : [ADRESSE SIEGE]


Nous restons à votre disposition pour tout renseignement complémentaire.

Cordialement,

La Direction Générale
PERC - Mutuelle des Douanes du Sénégal


═══════════════════════════════════════════════════════════════════════════

              Ce document est strictement confidentiel et personnel.
         Il ne doit en aucun cas être communiqué à un tiers ou reproduit.

═══════════════════════════════════════════════════════════════════════════
```

### Variables à remplacer

| Variable | Source | Exemple |
|----------|--------|---------|
| `[NOM]` | Colonne `nom` du CSV | `JEAN DUPONT` |
| `[MATRICULE]` | Colonne `matricule` du CSV | `123456C` |
| `[DATE]` | Date d'envoi | `23 novembre 2025` |
| `[ADRESSE_PARTICIPANT]` | Base de données | - |

---

## 🔄 Script d'Envoi Automatique (Exemple)

### PowerShell - Envoi SMS via API

```powershell
# Exemple d'envoi SMS automatique
# Remplacer par votre service SMS (Twilio, Nexmo, etc.)

$csvPath = "output/passwords_20251123_143022.csv"
$smsApiUrl = "https://api.sms-provider.com/send"
$apiKey = "YOUR_API_KEY"

# Importer le CSV
$participants = Import-Csv -Path $csvPath

# Filtrer ceux AVEC téléphone
$participantsAvecTel = $participants | Where-Object { $_.type_generation -eq "avec_telephone" }

foreach ($p in $participantsAvecTel) {
    $message = @"
PERC - Mutuelle des Douanes
Votre mot de passe initial : $($p.password_clear)
Connectez-vous sur perc.mutuelle.sn
Changez-le à la première connexion.
"@

    # Nettoyer le numéro de téléphone (prendre le premier si plusieurs)
    $phoneNumber = ($p.telephone -split ' / ')[0].Trim()

    # Ajouter indicatif si nécessaire
    if (-not $phoneNumber.StartsWith('+')) {
        $phoneNumber = "+221$phoneNumber"
    }

    # Envoyer le SMS
    try {
        $body = @{
            to = $phoneNumber
            message = $message
            api_key = $apiKey
        } | ConvertTo-Json

        Invoke-RestMethod -Uri $smsApiUrl -Method Post -Body $body -ContentType "application/json"

        Write-Host "✓ SMS envoyé à $($p.matricule) - $($p.nom)" -ForegroundColor Green

        # Pause pour respecter les limites de taux
        Start-Sleep -Milliseconds 500

    } catch {
        Write-Host "✗ Erreur pour $($p.matricule) : $_" -ForegroundColor Red
    }
}

Write-Host "`nTotal envoyé : $($participantsAvecTel.Count) SMS" -ForegroundColor Cyan
```

### PowerShell - Envoi Email

```powershell
# Exemple d'envoi email automatique

$csvPath = "output/passwords_20251123_143022.csv"
$smtpServer = "smtp.perc.sn"
$smtpPort = 587
$fromEmail = "noreply@perc.mutuelle.sn"
$credentials = Get-Credential

# Importer le CSV
$participants = Import-Csv -Path $csvPath

# Filtrer ceux SANS téléphone
$participantsSansTel = $participants | Where-Object { $_.type_generation -eq "sans_telephone" }

foreach ($p in $participantsSansTel) {
    # Vérifier qu'il y a un email
    if ([string]::IsNullOrWhiteSpace($p.email)) {
        Write-Host "⚠ Pas d'email pour $($p.matricule) - $($p.nom)" -ForegroundColor Yellow
        continue
    }

    $subject = "PERC - Vos identifiants de connexion"

    $body = @"
Cher(e) $($p.nom),

Dans le cadre de la modernisation de notre système d'authentification,
nous vous transmettons vos nouveaux identifiants de connexion.

VOS IDENTIFIANTS :
Matricule : $($p.matricule)
Mot de passe temporaire : MDS2024!
URL : perc.mutuelle.sn

IMPORTANT :
- Ce mot de passe est TEMPORAIRE
- Vous DEVEZ le changer lors de votre première connexion
- Choisissez un mot de passe sécurisé (min 6 caractères)

PREMIÈRE CONNEXION :
1. Allez sur perc.mutuelle.sn
2. Entrez votre matricule : $($p.matricule)
3. Entrez le mot de passe : MDS2024!
4. Définissez votre nouveau mot de passe

Support : support@perc.mutuelle.sn

Cordialement,
L'équipe PERC
"@

    try {
        Send-MailMessage `
            -From $fromEmail `
            -To $p.email `
            -Subject $subject `
            -Body $body `
            -SmtpServer $smtpServer `
            -Port $smtpPort `
            -Credential $credentials `
            -UseSsl

        Write-Host "✓ Email envoyé à $($p.matricule) - $($p.nom)" -ForegroundColor Green

    } catch {
        Write-Host "✗ Erreur pour $($p.matricule) : $_" -ForegroundColor Red
    }
}

Write-Host "`nTotal envoyé : $($participantsSansTel.Count) emails" -ForegroundColor Cyan
```

---

## 📊 Statistiques d'Envoi

Après distribution, tenir à jour :

| Catégorie | Nombre total | Envoyés | En attente | Échecs |
|-----------|--------------|---------|------------|---------|
| SMS (avec téléphone) | 1850 | ___ | ___ | ___ |
| Email (sans téléphone) | 42 | ___ | ___ | ___ |
| Courrier postal | ___ | ___ | ___ | ___ |
| **TOTAL** | **1892** | ___ | ___ | ___ |

---

## ✅ Checklist de Distribution

- [ ] CSV exporté et sécurisé
- [ ] Templates de messages préparés
- [ ] Service SMS configuré (si automatique)
- [ ] SMTP configuré (si email automatique)
- [ ] Envoi SMS démarré
- [ ] Envoi emails démarré
- [ ] Courriers imprimés (si nécessaire)
- [ ] Statistiques d'envoi notées
- [ ] Échecs identifiés et traités
- [ ] Support informé du déploiement
- [ ] CSV supprimé après distribution complète

---

**Date de création** : 23 novembre 2025
**Version** : 1.0
