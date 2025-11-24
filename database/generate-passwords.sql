-- Script de génération de mots de passe pour les participants PERC
-- Ce script génère un mot de passe unique et sécurisé pour chaque participant

-- IMPORTANT : Ce script doit être exécuté APRÈS l'import des participants
-- Les mots de passe générés doivent être communiqués aux agents

-- Table (NON temporaire) pour stocker les mots de passe en clair (à supprimer après envoi)
-- IMPORTANT : Cette table doit être supprimée après distribution des mots de passe
DROP TABLE IF EXISTS temp_passwords_to_send;

CREATE TABLE temp_passwords_to_send (
    matricule VARCHAR(20),
    nom VARCHAR(255),
    telephone VARCHAR(100),
    email VARCHAR(255),
    password_clear TEXT,
    type_generation VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Fonction pour générer un mot de passe aléatoire sécurisé
-- Format : 8 caractères (majuscules + minuscules + chiffres)
CREATE OR REPLACE FUNCTION generate_random_password()
RETURNS TEXT AS $$
DECLARE
    chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
    password TEXT := '';
    i INTEGER;
BEGIN
    FOR i IN 1..8 LOOP
        password := password || substr(chars, floor(random() * length(chars) + 1)::int, 1);
    END LOOP;
    RETURN password;
END;
$$ LANGUAGE plpgsql;

-- NOTE : Les mots de passe seront hashés côté Node.js avec bcrypt
-- Ce script génère uniquement les mots de passe en clair et les stocke temporairement

-- Générer les mots de passe pour tous les participants qui n'en ont pas
DO $$
DECLARE
    participant RECORD;
    generated_password TEXT;
    type_gen VARCHAR(20);
    count_avec_tel INTEGER := 0;
    count_sans_tel INTEGER := 0;
BEGIN
    FOR participant IN
        SELECT id, matricule, nom, telephone, email
        FROM perc_participants
        WHERE password_hash IS NULL OR password_hash = ''
    LOOP
        -- Générer mot de passe selon le cas
        IF participant.telephone IS NULL OR participant.telephone = '' THEN
            -- Mot de passe commun pour ceux sans téléphone
            generated_password := 'MDS2024!';
            type_gen := 'sans_telephone';
            count_sans_tel := count_sans_tel + 1;
        ELSE
            -- Mot de passe aléatoire unique pour ceux avec téléphone
            generated_password := generate_random_password();
            type_gen := 'avec_telephone';
            count_avec_tel := count_avec_tel + 1;
        END IF;

        -- Stocker dans la table temporaire pour export
        INSERT INTO temp_passwords_to_send (matricule, nom, telephone, email, password_clear, type_generation)
        VALUES (participant.matricule, participant.nom, participant.telephone, participant.email, generated_password, type_gen);

        -- Marquer comme "en attente de premier login"
        UPDATE perc_participants
        SET
            password_set = FALSE,
            first_login_done = FALSE
        WHERE id = participant.id;

    END LOOP;

    RAISE NOTICE 'Génération terminée pour % participants', (SELECT COUNT(*) FROM temp_passwords_to_send);
    RAISE NOTICE '  - Avec téléphone (mot de passe unique) : %', count_avec_tel;
    RAISE NOTICE '  - Sans téléphone (mot de passe commun "MDS2024!") : %', count_sans_tel;
END $$;

-- Afficher les mots de passe générés (à exporter vers CSV/Excel)
SELECT
    matricule AS "Matricule",
    nom AS "Nom complet",
    telephone AS "Téléphone",
    email AS "Email",
    password_clear AS "Mot de passe initial",
    type_generation AS "Type",
    'À changer à la première connexion' AS "Remarque"
FROM temp_passwords_to_send
ORDER BY type_generation DESC, matricule;

-- Instructions pour l'export :
-- 1. Copier les résultats ci-dessus dans un fichier Excel sécurisé
-- 2. Communiquer les mots de passe aux agents (SMS ou email sécurisé)
-- 3. Exécuter le script Node.js pour hasher les mots de passe : npm run hash-passwords
-- 4. Supprimer cette table temporaire : DROP TABLE temp_passwords_to_send;

-- Log de l'opération
INSERT INTO perc_sync_logs (type_sync, statut, details, nombre_enregistrements)
SELECT
    'generation_passwords',
    'success',
    'Génération des mots de passe initiaux pour les participants',
    COUNT(*)
FROM temp_passwords_to_send;

-- IMPORTANT : Ne pas oublier de :
-- 1. Exporter les résultats en CSV/Excel
-- 2. Exécuter le script Node.js pour hasher : node scripts/hash-passwords.js
-- 3. Supprimer la table temporaire après envoi : DROP TABLE temp_passwords_to_send;
