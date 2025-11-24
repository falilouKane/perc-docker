// routes/perc.js - Routes de consultation PERC
const express = require('express');
const router = express.Router();
const { query } = require('../config/database');
const { authMiddleware } = require('../middleware/auth');

// Middleware d'authentification sur toutes les routes PERC
router.use(authMiddleware);

// GET /api/perc/dashboard - Tableau de bord principal
router.get('/dashboard', async (req, res) => {
    try {
        const { matricule } = req.user;

        // Récupérer les infos du compte
        const accountResult = await query(
            `SELECT p.*, a.compte_cgf, a.solde_actuel, a.date_ouverture, a.statut
             FROM perc_participants p
             LEFT JOIN perc_accounts a ON p.id = a.participant_id
             WHERE p.matricule = $1`,
            [matricule]
        );

        if (accountResult.rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Compte non trouvé'
            });
        }

        const account = accountResult.rows[0];

        // Récupérer les statistiques
        const statsResult = await query(
            `SELECT 
                COUNT(*) as nombre_contributions,
                SUM(montant) as total_verse,
                MAX(date_contribution) as derniere_contribution,
                MIN(date_contribution) as premiere_contribution
             FROM perc_contributions c
             JOIN perc_accounts a ON c.account_id = a.id
             JOIN perc_participants p ON a.participant_id = p.id
             WHERE p.matricule = $1`,
            [matricule]
        );

        const stats = statsResult.rows[0];

        // Récupérer les dernières contributions (5 dernières)
        const recentContributions = await query(
            `SELECT 
                montant,
                periode,
                date_contribution,
                type_contribution
             FROM perc_contributions c
             JOIN perc_accounts a ON c.account_id = a.id
             JOIN perc_participants p ON a.participant_id = p.id
             WHERE p.matricule = $1
             ORDER BY date_contribution DESC
             LIMIT 5`,
            [matricule]
        );

        res.json({
            success: true,
            data: {
                participant: {
                    matricule: account.matricule,
                    nom: account.nom,
                    direction: account.direction,
                    email: account.email,
                    telephone: account.telephone
                },
                compte: {
                    numero: account.compte_cgf,
                    solde_actuel: parseFloat(account.solde_actuel || 0),
                    date_ouverture: account.date_ouverture,
                    statut: account.statut
                },
                statistiques: {
                    nombre_contributions: parseInt(stats.nombre_contributions),
                    total_verse: parseFloat(stats.total_verse || 0),
                    derniere_contribution: stats.derniere_contribution,
                    premiere_contribution: stats.premiere_contribution
                },
                dernieres_contributions: recentContributions.rows
            }
        });

    } catch (error) {
        console.error('Erreur dashboard:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur lors du chargement du tableau de bord'
        });
    }
});

// GET /api/perc/contributions - Historique complet des contributions
router.get('/contributions', async (req, res) => {
    try {
        const { matricule } = req.user;
        const { page = 1, limit = 20, annee } = req.query;

        const offset = (page - 1) * limit;

        let queryText = `
            SELECT 
                c.id,
                c.montant,
                c.periode,
                c.date_contribution,
                c.type_contribution,
                c.commentaire
            FROM perc_contributions c
            JOIN perc_accounts a ON c.account_id = a.id
            JOIN perc_participants p ON a.participant_id = p.id
            WHERE p.matricule = $1
        `;

        const params = [matricule];

        // Filtrer par année si spécifié
        if (annee) {
            queryText += ` AND EXTRACT(YEAR FROM c.date_contribution) = $${params.length + 1}`;
            params.push(annee);
        }

        queryText += ` ORDER BY c.date_contribution DESC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
        params.push(limit, offset);

        const contributions = await query(queryText, params);

        // Compter le total
        let countQuery = `
            SELECT COUNT(*) as total
            FROM perc_contributions c
            JOIN perc_accounts a ON c.account_id = a.id
            JOIN perc_participants p ON a.participant_id = p.id
            WHERE p.matricule = $1
        `;

        const countParams = [matricule];
        if (annee) {
            countQuery += ` AND EXTRACT(YEAR FROM c.date_contribution) = $2`;
            countParams.push(annee);
        }

        const countResult = await query(countQuery, countParams);
        const total = parseInt(countResult.rows[0].total);

        res.json({
            success: true,
            data: contributions.rows,
            pagination: {
                page: parseInt(page),
                limit: parseInt(limit),
                total: total,
                pages: Math.ceil(total / limit)
            }
        });

    } catch (error) {
        console.error('Erreur contributions:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur lors du chargement de l\'historique'
        });
    }
});

// GET /api/perc/mouvements - Historique des mouvements
router.get('/mouvements', async (req, res) => {
    try {
        const { matricule } = req.user;
        const { limit = 50 } = req.query;

        const mouvements = await query(
            `SELECT 
                m.id,
                m.type_mouvement,
                m.montant,
                m.solde_avant,
                m.solde_apres,
                m.description,
                m.date_mouvement,
                m.reference
             FROM perc_movements m
             JOIN perc_accounts a ON m.account_id = a.id
             JOIN perc_participants p ON a.participant_id = p.id
             WHERE p.matricule = $1
             ORDER BY m.date_mouvement DESC
             LIMIT $2`,
            [matricule, limit]
        );

        res.json({
            success: true,
            data: mouvements.rows
        });

    } catch (error) {
        console.error('Erreur mouvements:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur lors du chargement des mouvements'
        });
    }
});

// GET /api/perc/statistiques/:annee - Statistiques par année
router.get('/statistiques/:annee', async (req, res) => {
    try {
        const { matricule } = req.user;
        const { annee } = req.params;

        const stats = await query(
            `SELECT
                EXTRACT(MONTH FROM date_contribution) as mois,
                COUNT(*) as nombre,
                SUM(montant) as total
             FROM perc_contributions c
             JOIN perc_accounts a ON c.account_id = a.id
             JOIN perc_participants p ON a.participant_id = p.id
             WHERE p.matricule = $1
             AND EXTRACT(YEAR FROM c.date_contribution) = $2
             GROUP BY EXTRACT(MONTH FROM date_contribution)
             ORDER BY mois`,
            [matricule, annee]
        );

        res.json({
            success: true,
            annee: parseInt(annee),
            data: stats.rows
        });

    } catch (error) {
        console.error('Erreur statistiques:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur lors du chargement des statistiques'
        });
    }
});

// GET /api/perc/solde - Récupérer uniquement le solde
router.get('/solde', async (req, res) => {
    try {
        const { matricule } = req.user;

        const result = await query(
            `SELECT a.compte_cgf, a.solde_actuel
             FROM perc_accounts a
             JOIN perc_participants p ON a.participant_id = p.id
             WHERE p.matricule = $1`,
            [matricule]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Compte non trouvé'
            });
        }

        res.json({
            success: true,
            solde: result.rows[0].solde_actuel,
            compte_cgf: result.rows[0].compte_cgf
        });

    } catch (error) {
        console.error('Erreur solde:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur lors du chargement du solde'
        });
    }
});

// GET /api/perc/operations - Récupérer les opérations (contributions + mouvements)
router.get('/operations', async (req, res) => {
    try {
        const { matricule } = req.user;
        const { limit = 5 } = req.query;

        // Combiner contributions et mouvements
        const operations = await query(
            `SELECT
                'contribution' as type,
                c.montant,
                c.date_contribution as date_operation,
                CONCAT('Contribution ', c.periode) as libelle,
                c.type_contribution
             FROM perc_contributions c
             JOIN perc_accounts a ON c.account_id = a.id
             JOIN perc_participants p ON a.participant_id = p.id
             WHERE p.matricule = $1

             UNION ALL

             SELECT
                'mouvement' as type,
                m.montant,
                m.date_mouvement as date_operation,
                m.description as libelle,
                m.type_mouvement as type_contribution
             FROM perc_movements m
             JOIN perc_accounts a ON m.account_id = a.id
             JOIN perc_participants p ON a.participant_id = p.id
             WHERE p.matricule = $1

             ORDER BY date_operation DESC
             LIMIT $2`,
            [matricule, limit]
        );

        res.json({
            success: true,
            data: operations.rows
        });

    } catch (error) {
        console.error('Erreur operations:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur lors du chargement des opérations'
        });
    }
});

module.exports = router;