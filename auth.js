// middleware/auth.js - Middleware d'authentification (CORRIGÉ)
const { query } = require('../config/database');

/**
 * Middleware pour vérifier le token de session
 */
async function authMiddleware(req, res, next) {
    try {
        // Récupérer le token du header Authorization
        const authHeader = req.headers.authorization;

        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                success: false,
                message: 'Token d\'authentification manquant'
            });
        }

        const token = authHeader.replace('Bearer ', '');

        // Vérifier le token en base de données
        const result = await query(
            `SELECT s.*, p.matricule, p.nom, p.email 
             FROM perc_sessions s
             JOIN perc_participants p ON s.user_id = p.matricule
             WHERE s.token = $1 
             AND s.user_type = 'agent'
             AND s.date_expiration > NOW()`,
            [token]
        );

        if (result.rows.length === 0) {
            return res.status(401).json({
                success: false,
                message: 'Session invalide ou expirée'
            });
        }

        // Ajouter les infos utilisateur à la requête
        req.user = {
            matricule: result.rows[0].matricule,
            nom: result.rows[0].nom,
            email: result.rows[0].email,
            sessionId: result.rows[0].id
        };

        next();

    } catch (error) {
        console.error('Erreur middleware auth:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur d\'authentification'
        });
    }
}

module.exports = authMiddleware;
