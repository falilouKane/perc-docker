// middleware/adminAuth.js - Middleware pour les admins (CORRIGÉ)
const { query } = require('../config/database');

/**
 * Middleware pour vérifier les droits administrateur
 */
async function adminAuthMiddleware(req, res, next) {
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
            `SELECT s.*, a.username, a.nom_complet, a.email, a.role 
             FROM perc_sessions s
             JOIN perc_admins a ON s.user_id = a.username
             WHERE s.token = $1 
             AND s.user_type = 'admin'
             AND s.date_expiration > NOW()
             AND a.actif = TRUE`,
            [token]
        );

        if (result.rows.length === 0) {
            return res.status(401).json({
                success: false,
                message: 'Session invalide ou expirée'
            });
        }

        const admin = result.rows[0];

        // Ajouter les infos admin à la requête
        req.user = {
            username: admin.username,
            nom: admin.nom_complet,
            email: admin.email,
            role: admin.role,
            sessionId: admin.id,
            isAdmin: true
        };

        next();

    } catch (error) {
        console.error('Erreur middleware admin:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur d\'authentification'
        });
    }
}

module.exports = adminAuthMiddleware;
