// routes/stats.js - Routes pour les statistiques du dashboard
const express = require('express');
const router = express.Router();
const { query } = require('../config/database');
const adminAuthMiddleware = require('../middleware/adminAuth');

// Middleware admin
router.use(adminAuthMiddleware);

// GET /api/stats/dashboard - Statistiques du dashboard admin
router.get('/dashboard', async (req, res) => {
    try {
        // 1. Nombre de participants actifs
        const participantsResult = await query(
            'SELECT COUNT(DISTINCT p.id) as total FROM perc_participants p JOIN perc_accounts a ON p.id = a.participant_id WHERE a.statut = $1',
            ['actif']
        );

        // 2. Solde total système
        const soldeResult = await query(
            'SELECT COALESCE(SUM(solde_actuel), 0) as total FROM perc_accounts WHERE statut = $1',
            ['actif']
        );

        // 3. Contributions ce mois
        const contribResult = await query(
            `SELECT COUNT(*) as total 
             FROM perc_contributions 
             WHERE EXTRACT(MONTH FROM date_contribution) = EXTRACT(MONTH FROM CURRENT_DATE)
             AND EXTRACT(YEAR FROM date_contribution) = EXTRACT(YEAR FROM CURRENT_DATE)`
        );

        // 4. Nombre d'imports effectués
        const importsResult = await query(
            'SELECT COUNT(*) as total FROM perc_import_files'
        );

        res.json({
            success: true,
            data: {
                participants_actifs: parseInt(participantsResult.rows[0].total),
                solde_total: parseFloat(soldeResult.rows[0].total),
                contributions_mois: parseInt(contribResult.rows[0].total),
                imports_effectues: parseInt(importsResult.rows[0].total)
            }
        });

    } catch (error) {
        console.error('Erreur stats dashboard:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur chargement statistiques'
        });
    }
});

// GET /api/stats/recent-activity - Activité récente
router.get('/recent-activity', async (req, res) => {
    try {
        const activities = [];

        // Dernier import
        const lastImport = await query(
            `SELECT nom_fichier, date_import, nombre_succes 
             FROM perc_import_files 
             ORDER BY date_import DESC 
             LIMIT 1`
        );

        if (lastImport.rows.length > 0) {
            const imp = lastImport.rows[0];
            const heures = Math.floor((Date.now() - new Date(imp.date_import)) / 3600000);
            activities.push({
                type: 'import',
                message: `Import réussi - ${imp.nombre_succes} contributions ajoutées`,
                time: `Il y a ${heures} heure${heures > 1 ? 's' : ''}`
            });
        }

        // Dernier participant
        const lastParticipant = await query(
            `SELECT nom, date_creation 
             FROM perc_participants 
             ORDER BY date_creation DESC 
             LIMIT 1`
        );

        if (lastParticipant.rows.length > 0) {
            const part = lastParticipant.rows[0];
            const heures = Math.floor((Date.now() - new Date(part.date_creation)) / 3600000);
            activities.push({
                type: 'participant',
                message: `Nouveau participant ajouté: ${part.nom}`,
                time: `Il y a ${heures} heure${heures > 1 ? 's' : ''}`
            });
        }

        res.json({ success: true, data: activities });

    } catch (error) {
        console.error('Erreur activité récente:', error);
        res.status(500).json({ success: false, message: 'Erreur' });
    }
});

// Ajoute dans backend/routes/stats.js (ou crée participants.js)

// GET /api/stats/participants - Liste des participants avec soldes
router.get('/participants', async (req, res) => {
    try {
        const { search = '', limit = 50 } = req.query;

        let query_text = `
            SELECT 
                p.matricule,
                p.nom,
                p.email,
                p.telephone,
                p.direction,
                a.compte_cgf,
                a.solde_actuel
            FROM perc_participants p
            LEFT JOIN perc_accounts a ON p.id = a.participant_id
            WHERE p.matricule ILIKE $1 OR p.nom ILIKE $1
            ORDER BY p.nom
            LIMIT $2
        `;

        const result = await query(query_text, [`%${search}%`, limit]);

        res.json({
            success: true,
            data: result.rows
        });

    } catch (error) {
        console.error('Erreur participants:', error);
        res.status(500).json({ success: false, message: 'Erreur' });
    }
});

// GET /api/stats/participant/:matricule - Détails d'un participant
router.get('/participant/:matricule', async (req, res) => {
    try {
        const { matricule } = req.params;

        const result = await query(
            `SELECT 
                p.*,
                a.compte_cgf,
                a.solde_actuel,
                a.date_ouverture,
                (SELECT COUNT(*) FROM perc_contributions WHERE participant_id = p.id) as nb_contributions,
                (SELECT MAX(date_contribution) FROM perc_contributions WHERE participant_id = p.id) as derniere_contribution
            FROM perc_participants p
            LEFT JOIN perc_accounts a ON p.id = a.participant_id
            WHERE p.matricule = $1`,
            [matricule]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ success: false, message: 'Participant non trouvé' });
        }

        res.json({ success: true, data: result.rows[0] });

    } catch (error) {
        console.error('Erreur détails participant:', error);
        res.status(500).json({ success: false, message: 'Erreur' });
    }
});

// PUT /api/stats/participant/:matricule/solde - Modifier le solde
router.put('/participant/:matricule/solde', async (req, res) => {
    try {
        const { matricule } = req.params;
        const { nouveau_solde, raison } = req.body;

        // Récupérer l'account_id
        const participant = await query(
            'SELECT a.id as account_id, a.solde_actuel FROM perc_participants p JOIN perc_accounts a ON p.id = a.participant_id WHERE p.matricule = $1',
            [matricule]
        );

        if (participant.rows.length === 0) {
            return res.status(404).json({ success: false, message: 'Participant non trouvé' });
        }

        const accountId = participant.rows[0].account_id;
        const ancienSolde = parseFloat(participant.rows[0].solde_actuel);
        const nouveauSolde = parseFloat(nouveau_solde);

        // Mettre à jour le solde
        await query(
            'UPDATE perc_accounts SET solde_actuel = $1, date_maj = CURRENT_TIMESTAMP WHERE id = $2',
            [nouveauSolde, accountId]
        );

        // Créer un mouvement de correction
        await query(
            `INSERT INTO perc_movements (account_id, type_mouvement, montant, solde_avant, solde_apres, description)
             VALUES ($1, $2, $3, $4, $5, $6)`,
            [accountId, 'correction', nouveauSolde - ancienSolde, ancienSolde, nouveauSolde, `Correction manuelle: ${raison || 'Aucune raison'}`]
        );

        res.json({ success: true, message: 'Solde modifié' });

    } catch (error) {
        console.error('Erreur modification solde:', error);
        res.status(500).json({ success: false, message: 'Erreur' });
    }
});

module.exports = router;