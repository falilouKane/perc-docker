// routes/auth.js - Routes d'authentification
const express = require('express');
const router = express.Router();
const { query } = require('../config/database');
const { generateOTP, sendOTP, verifyOTP } = require('../utils/otpService');
const crypto = require('crypto');

// Étape 1: Demander un OTP
router.post('/request-otp', async (req, res) => {
    try {
        const { matricule } = req.body;

        if (!matricule) {
            return res.status(400).json({
                success: false,
                message: 'Le matricule est requis'
            });
        }

        // Vérifier si le matricule existe
        const result = await query(
            'SELECT * FROM perc_participants WHERE matricule = $1',
            [matricule]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Matricule non trouvé dans le système PERC'
            });
        }

        const participant = result.rows[0];

        // Générer un code OTP
        const otpCode = generateOTP();
        const expirationDate = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes

        // Stocker l'OTP en base
        await query(
            `INSERT INTO perc_otp (matricule, code, telephone, date_expiration) 
             VALUES ($1, $2, $3, $4)`,
            [matricule, otpCode, participant.telephone, expirationDate]
        );

        // Envoyer l'OTP par SMS (simulé pour V1)
        const otpSent = await sendOTP(participant.telephone, otpCode);

        res.json({
            success: true,
            message: `Code OTP envoyé au ${participant.telephone ? participant.telephone.replace(/(\d{2})(\d{3})(\d{2})(\d{2})/, '$1 $2 $3 $4') : 'numéro enregistré'}`,
            // En développement, retourner le code (à supprimer en prod)
            ...(process.env.NODE_ENV === 'development' && { otp: otpCode })
        });

    } catch (error) {
        console.error('Erreur request-otp:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur lors de la génération de l\'OTP'
        });
    }
});

// Étape 2: Vérifier l'OTP et créer une session
router.post('/verify-otp', async (req, res) => {
    try {
        const { matricule, code } = req.body;

        if (!matricule || !code) {
            return res.status(400).json({
                success: false,
                message: 'Matricule et code OTP requis'
            });
        }

        // Vérifier l'OTP
        const otpResult = await query(
            `SELECT * FROM perc_otp 
             WHERE matricule = $1 
             AND code = $2 
             AND utilise = FALSE 
             AND date_expiration > NOW()
             ORDER BY date_generation DESC 
             LIMIT 1`,
            [matricule, code]
        );

        if (otpResult.rows.length === 0) {
            // Incrémenter les tentatives
            await query(
                `UPDATE perc_otp 
                 SET tentatives = tentatives + 1 
                 WHERE matricule = $1 AND code = $2`,
                [matricule, code]
            );

            return res.status(401).json({
                success: false,
                message: 'Code OTP invalide ou expiré'
            });
        }

        // Marquer l'OTP comme utilisé
        await query(
            'UPDATE perc_otp SET utilise = TRUE WHERE id = $1',
            [otpResult.rows[0].id]
        );

        // Créer un token de session
        const token = crypto.randomBytes(32).toString('hex');
        const sessionExpiration = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24h

        await query(
            `INSERT INTO perc_sessions (matricule, token, date_expiration, ip_address, user_agent)
             VALUES ($1, $2, $3, $4, $5)`,
            [
                matricule,
                token,
                sessionExpiration,
                req.ip,
                req.get('user-agent')
            ]
        );

        // Récupérer les infos du participant
        const participant = await query(
            `SELECT p.*, a.solde_actuel, a.compte_cgf
             FROM perc_participants p
             LEFT JOIN perc_accounts a ON p.id = a.participant_id
             WHERE p.matricule = $1`,
            [matricule]
        );

        res.json({
            success: true,
            message: 'Authentification réussie',
            token: token,
            user: {
                matricule: participant.rows[0].matricule,
                nom: participant.rows[0].nom,
                email: participant.rows[0].email,
                compte_cgf: participant.rows[0].compte_cgf,
                solde: participant.rows[0].solde_actuel
            }
        });

    } catch (error) {
        console.error('Erreur verify-otp:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur lors de la vérification de l\'OTP'
        });
    }
});

// Vérifier la validité d'un token
router.get('/verify-token', async (req, res) => {
    try {
        const token = req.headers.authorization?.replace('Bearer ', '');

        if (!token) {
            return res.status(401).json({
                success: false,
                message: 'Token manquant'
            });
        }

        const result = await query(
            `SELECT * FROM perc_sessions 
             WHERE token = $1 
             AND date_expiration > NOW()`,
            [token]
        );

        if (result.rows.length === 0) {
            return res.status(401).json({
                success: false,
                message: 'Token invalide ou expiré'
            });
        }

        res.json({
            success: true,
            valid: true,
            matricule: result.rows[0].matricule
        });

    } catch (error) {
        console.error('Erreur verify-token:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur lors de la vérification du token'
        });
    }
});

// Déconnexion
router.post('/logout', async (req, res) => {
    try {
        const token = req.headers.authorization?.replace('Bearer ', '');

        if (token) {
            await query(
                'DELETE FROM perc_sessions WHERE token = $1',
                [token]
            );
        }

        res.json({
            success: true,
            message: 'Déconnexion réussie'
        });

    } catch (error) {
        console.error('Erreur logout:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur lors de la déconnexion'
        });
    }
});

module.exports = router;