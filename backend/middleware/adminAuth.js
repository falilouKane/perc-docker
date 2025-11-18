// middleware/adminAuth.js - Middleware pour les admins
const { query } = require('../config/database');

/**
 * Middleware pour vérifier les droits administrateur
 * Pour la V1, on utilise une liste de matricules admin en environnement
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
            `SELECT s.*, p.nom, p.email 
             FROM perc_sessions s
             JOIN perc_participants p ON s.matricule = p.matricule
             WHERE s.token = $1 
             AND s.date_expiration > NOW()`,
            [token]
        );

        if (result.rows.length === 0) {
            return res.status(401).json({
                success: false,
                message: 'Session invalide ou expirée'
            });
        }

        const user = result.rows[0];

        // Vérifier si l'utilisateur est admin
        const adminMatricules = (process.env.ADMIN_MATRICULES || '').split(',');

        if (!adminMatricules.includes(user.matricule)) {
            return res.status(403).json({
                success: false,
                message: 'Accès refusé. Droits administrateur requis.'
            });
        }

        // Ajouter les infos utilisateur à la requête
        req.user = {
            matricule: user.matricule,
            nom: user.nom,
            email: user.email,
            sessionId: user.id,
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