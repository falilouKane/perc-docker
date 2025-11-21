-- Script de nettoyage de la base PERC
-- Supprime tous les imports sauf le dernier

-- 1. Supprimer tous les anciens imports
DELETE FROM perc_contributions WHERE import_file_id IN (
    SELECT id FROM perc_import_files WHERE id != (SELECT MAX(id) FROM perc_import_files)
);

DELETE FROM perc_import_rows WHERE import_file_id IN (
    SELECT id FROM perc_import_files WHERE id != (SELECT MAX(id) FROM perc_import_files)
);

DELETE FROM perc_import_files WHERE id != (SELECT MAX(id) FROM perc_import_files);

-- 2. Recalculer les soldes corrects
UPDATE perc_accounts a
SET solde_actuel = (
    SELECT COALESCE(SUM(montant), 0)
    FROM perc_contributions
    WHERE account_id = a.id
);

-- 3. Afficher résultat
DO $$
DECLARE
    v_participants INTEGER;
    v_solde DECIMAL(15,2);
    v_contributions INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_participants FROM perc_participants;
    SELECT SUM(solde_actuel) INTO v_solde FROM perc_accounts;
    SELECT COUNT(*) INTO v_contributions FROM perc_contributions;
    
    RAISE NOTICE '✅ Base nettoyée !';
    RAISE NOTICE 'Participants: %', v_participants;
    RAISE NOTICE 'Solde total: % F CFA', v_solde;
    RAISE NOTICE 'Contributions: %', v_contributions;
END $$;
