// routes/auth.js V2 - Système avec mots de passe
const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const { query } = require('../config/database');
const { generateOTP, sendOTP } = require('../utils/otpService');
const crypto = require('crypto');

// ============================================
// ROUTES AGENTS
// ============================================

// POST /api/auth/agent/check-status
// Vérifier si l'agent a déjà un mot de passe
router.post('/agent/check-status', async (req, res) => {
    try {
        const { matricule } = req.body;

        if (!matricule) {
            return res.status(400).json({
                success: false,
                message: 'Le matricule est requis'
            });
        }

        const result = await query(
            'SELECT matricule, nom, password_set, first_login_done FROM perc_participants WHERE matricule = $1',
            [matricule]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Matricule non trouvé dans le système PERC'
            });
        }

        const participant = result.rows[0];

        res.json({
            success: true,
            data: {
                matricule: participant.matricule,
                nom: participant.nom,
                has_password: participant.password_set,
                first_login_done: participant.first_login_done
            }
        });

    } catch (error) {
        console.error('Erreur check-status:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur lors de la vérification'
        });
    }
});

// POST /api/auth/agent/request-otp
// Demander un OTP (première connexion ou reset mot de passe)
router.post('/agent/request-otp', async (req, res) => {
    try {
        const { matricule, type } = req.body; // type: 'first_login' ou 'password_reset'

        if (!matricule) {
            return res.status(400).json({
                success: false,
                message: 'Le matricule est requis'
            });
        }

        const result = await query(
            'SELECT * FROM perc_participants WHERE matricule = $1',
            [matricule]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Matricule non trouvé'
            });
        }

        const participant = result.rows[0];
        const otpCode = generateOTP();
        const expirationDate = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes

        await query(
            `INSERT INTO perc_otp (matricule, code, telephone, type_otp, date_expiration) 
             VALUES ($1, $2, $3, $4, $5)`,
            [matricule, otpCode, participant.telephone, type || 'first_login', expirationDate]
        );

        await sendOTP(participant.telephone, otpCode);

        res.json({
            success: true,
            message: `Code OTP envoyé au ${participant.telephone}`,
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

// POST /api/auth/agent/verify-otp-and-set-password
// Vérifier OTP ET définir le mot de passe (première connexion)
router.post('/agent/verify-otp-and-set-password', async (req, res) => {
    try {
        const { matricule, otp, password } = req.body;

        if (!matricule || !otp || !password) {
            return res.status(400).json({
                success: false,
                message: 'Matricule, OTP et mot de passe requis'
            });
        }

        // Valider le mot de passe
        if (password.length < 6) {
            return res.status(400).json({
                success: false,
                message: 'Le mot de passe doit contenir au moins 6 caractères'
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
            [matricule, otp]
        );

        if (otpResult.rows.length === 0) {
            return res.status(401).json({
                success: false,
                message: 'Code OTP invalide ou expiré'
            });
        }

        // Hasher le mot de passe
        const passwordHash = await bcrypt.hash(password, 10);

        // Mettre à jour le participant
        await query(
            `UPDATE perc_participants 
             SET password_hash = $1, 
                 password_set = TRUE, 
                 first_login_done = TRUE,
                 last_login = NOW()
             WHERE matricule = $2`,
            [passwordHash, matricule]
        );

        // Marquer l'OTP comme utilisé
        await query(
            'UPDATE perc_otp SET utilise = TRUE WHERE id = $1',
            [otpResult.rows[0].id]
        );

        // Créer une session
        const token = crypto.randomBytes(32).toString('hex');
        const sessionExpiration = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30 jours

        await query(
            `INSERT INTO perc_sessions (user_type, user_id, token, date_expiration, ip_address, user_agent)
             VALUES ($1, $2, $3, $4, $5, $6)`,
            ['agent', matricule, token, sessionExpiration, req.ip, req.get('user-agent')]
        );

        // Récupérer les infos
        const participant = await query(
            `SELECT p.*, a.solde_actuel, a.compte_cgf
             FROM perc_participants p
             LEFT JOIN perc_accounts a ON p.id = a.participant_id
             WHERE p.matricule = $1`,
            [matricule]
        );

        res.json({
            success: true,
            message: 'Mot de passe défini avec succès',
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
        console.error('Erreur verify-otp-and-set-password:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur lors de la création du mot de passe'
        });
    }
});

// POST /api/auth/agent/login
// Connexion normale avec mot de passe
router.post('/agent/login', async (req, res) => {
    try {
        const { matricule, password } = req.body;

        if (!matricule || !password) {
            return res.status(400).json({
                success: false,
                message: 'Matricule et mot de passe requis'
            });
        }

        // Récupérer le participant
        const result = await query(
            'SELECT * FROM perc_participants WHERE matricule = $1',
            [matricule]
        );

        if (result.rows.length === 0) {
            // Log tentative échouée
            await query(
                `INSERT INTO perc_login_attempts (user_type, identifier, success, ip_address, raison_echec)
                 VALUES ($1, $2, $3, $4, $5)`,
                ['agent', matricule, false, req.ip, 'Matricule non trouvé']
            );

            return res.status(401).json({
                success: false,
                message: 'Matricule ou mot de passe incorrect'
            });
        }

        const participant = result.rows[0];

        // Vérifier si un mot de passe est défini
        if (!participant.password_set || !participant.password_hash) {
            return res.status(400).json({
                success: false,
                message: 'Vous devez d\'abord définir un mot de passe',
                needs_password_setup: true
            });
        }

        // Vérifier le mot de passe
        const passwordMatch = await bcrypt.compare(password, participant.password_hash);

        if (!passwordMatch) {
            // Log tentative échouée
            await query(
                `INSERT INTO perc_login_attempts (user_type, identifier, success, ip_address, raison_echec)
                 VALUES ($1, $2, $3, $4, $5)`,
                ['agent', matricule, false, req.ip, 'Mot de passe incorrect']
            );

            return res.status(401).json({
                success: false,
                message: 'Matricule ou mot de passe incorrect'
            });
        }

        // Mettre à jour last_login
        await query(
            'UPDATE perc_participants SET last_login = NOW() WHERE matricule = $1',
            [matricule]
        );

        // Créer une session
        const token = crypto.randomBytes(32).toString('hex');
        const sessionExpiration = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30 jours

        await query(
            `INSERT INTO perc_sessions (user_type, user_id, token, date_expiration, ip_address, user_agent)
             VALUES ($1, $2, $3, $4, $5, $6)`,
            ['agent', matricule, token, sessionExpiration, req.ip, req.get('user-agent')]
        );

        // Log tentative réussie
        await query(
            `INSERT INTO perc_login_attempts (user_type, identifier, success, ip_address)
             VALUES ($1, $2, $3, $4)`,
            ['agent', matricule, true, req.ip]
        );

        // Récupérer les infos complètes
        const fullData = await query(
            `SELECT p.*, a.solde_actuel, a.compte_cgf
             FROM perc_participants p
             LEFT JOIN perc_accounts a ON p.id = a.participant_id
             WHERE p.matricule = $1`,
            [matricule]
        );

        res.json({
            success: true,
            message: 'Connexion réussie',
            token: token,
            user: {
                matricule: fullData.rows[0].matricule,
                nom: fullData.rows[0].nom,
                email: fullData.rows[0].email,
                compte_cgf: fullData.rows[0].compte_cgf,
                solde: fullData.rows[0].solde_actuel
            }
        });

    } catch (error) {
        console.error('Erreur login agent:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur lors de la connexion'
        });
    }
});

// ============================================
// ROUTES ADMIN
// ============================================

// POST /api/auth/admin/login
// Connexion admin avec username + password
router.post('/admin/login', async (req, res) => {
    try {
        const { username, password } = req.body;

        if (!username || !password) {
            return res.status(400).json({
                success: false,
                message: 'Identifiant et mot de passe requis'
            });
        }

        // Récupérer l'admin
        const result = await query(
            'SELECT * FROM perc_admins WHERE username = $1 AND actif = TRUE',
            [username]
        );

        if (result.rows.length === 0) {
            // Log tentative échouée
            await query(
                `INSERT INTO perc_login_attempts (user_type, identifier, success, ip_address, raison_echec)
                 VALUES ($1, $2, $3, $4, $5)`,
                ['admin', username, false, req.ip, 'Username non trouvé']
            );

            return res.status(401).json({
                success: false,
                message: 'Identifiant ou mot de passe incorrect'
            });
        }

        const admin = result.rows[0];

        // Vérifier le mot de passe
        const passwordMatch = await bcrypt.compare(password, admin.password_hash);

        if (!passwordMatch) {
            // Log tentative échouée
            await query(
                `INSERT INTO perc_login_attempts (user_type, identifier, success, ip_address, raison_echec)
                 VALUES ($1, $2, $3, $4, $5)`,
                ['admin', username, false, req.ip, 'Mot de passe incorrect']
            );

            return res.status(401).json({
                success: false,
                message: 'Identifiant ou mot de passe incorrect'
            });
        }

        // Mettre à jour last_login
        await query(
            'UPDATE perc_admins SET last_login = NOW() WHERE username = $1',
            [username]
        );

        // Créer une session longue durée
        const token = crypto.randomBytes(32).toString('hex');
        const sessionExpiration = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 jours

        await query(
            `INSERT INTO perc_sessions (user_type, user_id, token, date_expiration, ip_address, user_agent)
             VALUES ($1, $2, $3, $4, $5, $6)`,
            ['admin', username, token, sessionExpiration, req.ip, req.get('user-agent')]
        );

        // Log tentative réussie
        await query(
            `INSERT INTO perc_login_attempts (user_type, identifier, success, ip_address)
             VALUES ($1, $2, $3, $4)`,
            ['admin', username, true, req.ip]
        );

        res.json({
            success: true,
            message: 'Connexion admin réussie',
            token: token,
            admin: {
                username: admin.username,
                nom_complet: admin.nom_complet,
                email: admin.email,
                role: admin.role
            }
        });

    } catch (error) {
        console.error('Erreur login admin:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur lors de la connexion'
        });
    }
});

// ============================================
// ROUTES COMMUNES
// ============================================

// GET /api/auth/verify-token
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

        const session = result.rows[0];

        res.json({
            success: true,
            valid: true,
            user_type: session.user_type,
            user_id: session.user_id
        });

    } catch (error) {
        console.error('Erreur verify-token:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur lors de la vérification du token'
        });
    }
});

// POST /api/auth/logout
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