-- Fichier seed.sql - Données de test pour Docker
-- Ce fichier est exécuté automatiquement au démarrage de PostgreSQL

-- Insérer des participants de test
INSERT INTO perc_participants (matricule, compte_cgf, nom, direction, email, telephone)
VALUES 
    ('508924B', '0182000401', 'M. ABABACAR DIOP', 'DOD/DRDP/BUREAU GUICHET UNIQUE VEHICULES', 'baba_diop36@yahoo.fr', '+221776459554'),
    ('679594H', '0224970401', 'M. ABABACAR SADIKH BA', 'DOD/DRC/BUREAU KARANG', NULL, NULL),
    ('679686D', '0225810401', 'M. ABASSE NDIAYE', 'DOD/DRDP/BUREAU DAKAR PORT NORD', NULL, NULL),
    ('679746A', '0226360401', 'M. ABASSE NDIAYE', 'DSID/BIP/SECTION RESEAU PKI', NULL, NULL),
    ('679783F', '0226700401', 'M. ABDALLAH KAMBE', 'DSID/BIP/SECTION RESEAU PKI', NULL, NULL)
ON CONFLICT (matricule) DO NOTHING;

-- Créer les comptes PERC pour chaque participant
INSERT INTO perc_accounts (participant_id, compte_cgf, solde_actuel, date_ouverture, statut)
SELECT 
    id, 
    compte_cgf, 
    0, 
    CURRENT_DATE - INTERVAL '2 years',
    'actif'
FROM perc_participants
ON CONFLICT (compte_cgf) DO NOTHING;

-- Insérer des contributions de test (derniers 12 mois)
DO $$
DECLARE
    v_account_id INTEGER;
    v_participant_id INTEGER;
    v_mois INTEGER;
    v_montant DECIMAL(15,2);
BEGIN
    -- Pour chaque participant
    FOR v_account_id, v_participant_id IN 
        SELECT a.id, p.id 
        FROM perc_accounts a
        JOIN perc_participants p ON a.participant_id = p.id
    LOOP
        -- Générer 12 contributions mensuelles
        FOR v_mois IN 0..11 LOOP
            -- Montant aléatoire entre 500000 et 2000000
            v_montant := 500000 + (RANDOM() * 1500000)::INTEGER;
            
            INSERT INTO perc_contributions (
                account_id, 
                participant_id, 
                montant, 
                type_contribution, 
                periode,
                date_contribution
            )
            VALUES (
                v_account_id,
                v_participant_id,
                v_montant,
                'versement_cgf',
                TO_CHAR(CURRENT_DATE - (v_mois || ' months')::INTERVAL, 'YYYY-MM'),
                CURRENT_DATE - (v_mois || ' months')::INTERVAL
            );
            
            -- Créer un mouvement correspondant
            INSERT INTO perc_movements (
                account_id,
                type_mouvement,
                montant,
                solde_avant,
                solde_apres,
                description,
                date_mouvement
            )
            SELECT 
                v_account_id,
                'contribution',
                v_montant,
                COALESCE(
                    (SELECT SUM(montant) 
                     FROM perc_contributions 
                     WHERE account_id = v_account_id 
                     AND date_contribution < CURRENT_DATE - (v_mois || ' months')::INTERVAL),
                    0
                ),
                COALESCE(
                    (SELECT SUM(montant) 
                     FROM perc_contributions 
                     WHERE account_id = v_account_id 
                     AND date_contribution <= CURRENT_DATE - (v_mois || ' months')::INTERVAL),
                    0
                ),
                'Contribution mensuelle - Données de test',
                CURRENT_DATE - (v_mois || ' months')::INTERVAL;
        END LOOP;
    END LOOP;
END $$;

-- Mettre à jour tous les soldes des comptes
UPDATE perc_accounts a
SET solde_actuel = (
    SELECT COALESCE(SUM(montant), 0)
    FROM perc_contributions
    WHERE account_id = a.id
);

-- Créer un fichier d'import fictif dans l'historique
INSERT INTO perc_import_files (
    nom_fichier,
    nombre_lignes,
    nombre_succes,
    nombre_erreurs,
    statut,
    importe_par
)
VALUES (
    'donnees_test_initiales.xlsx',
    5,
    5,
    0,
    'complet',
    'system'
);

-- Logger la synchronisation
INSERT INTO perc_sync_logs (
    type_sync,
    statut,
    details,
    nombre_enregistrements
)
VALUES (
    'initialisation_docker',
    'success',
    'Données de test créées automatiquement au démarrage Docker',
    5
);

-- Afficher un résumé
DO $$
DECLARE
    v_count_participants INTEGER;
    v_count_accounts INTEGER;
    v_count_contributions INTEGER;
    v_total_solde DECIMAL(15,2);
BEGIN
    SELECT COUNT(*) INTO v_count_participants FROM perc_participants;
    SELECT COUNT(*) INTO v_count_accounts FROM perc_accounts;
    SELECT COUNT(*) INTO v_count_contributions FROM perc_contributions;
    SELECT SUM(solde_actuel) INTO v_total_solde FROM perc_accounts;
    
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '✅ Initialisation PERC Docker terminée';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE 'Participants créés : %', v_count_participants;
    RAISE NOTICE 'Comptes PERC créés : %', v_count_accounts;
    RAISE NOTICE 'Contributions créées : %', v_count_contributions;
    RAISE NOTICE 'Solde total système : % F CFA', v_total_solde;
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE 'Compte de test:';
    RAISE NOTICE '  Matricule : 508924B';
    RAISE NOTICE '  Mot de passe : OTP envoyé par SMS (simulé)';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
END $$;