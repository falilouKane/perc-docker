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
            `SELECT s.*, p.matricule, p.nom, p.email, p.password_set, p.first_login_done
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
            sessionId: result.rows[0].id,
            password_set: result.rows[0].password_set,
            first_login_done: result.rows[0].first_login_done
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

/**
 * Middleware pour vérifier si l'agent doit changer son mot de passe
 * À utiliser après authMiddleware
 */
async function requirePasswordChange(req, res, next) {
    try {
        // Vérifier si l'utilisateur a été authentifié
        if (!req.user) {
            return res.status(401).json({
                success: false,
                message: 'Authentification requise'
            });
        }

        // Si le mot de passe n'est pas encore défini ou si c'est la première connexion
        if (!req.user.password_set || !req.user.first_login_done) {
            return res.status(403).json({
                success: false,
                message: 'Vous devez changer votre mot de passe',
                require_password_change: true,
                redirect: '/change-password'
            });
        }

        next();

    } catch (error) {
        console.error('Erreur middleware requirePasswordChange:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur de vérification du mot de passe'
        });
    }
}

/**
 * Middleware pour vérifier l'authentification admin
 */
async function authAdminMiddleware(req, res, next) {
    try {
        const authHeader = req.headers.authorization;

        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                success: false,
                message: 'Token d\'authentification manquant'
            });
        }

        const token = authHeader.replace('Bearer ', '');

        // Vérifier le token admin
        const result = await query(
            `SELECT s.*, a.username, a.nom_complet, a.email, a.role
             FROM perc_sessions s
             JOIN perc_admins a ON s.user_id = a.username
             WHERE s.token = $1
             AND s.user_type = 'admin'
             AND s.date_expiration > NOW()`,
            [token]
        );

        if (result.rows.length === 0) {
            return res.status(401).json({
                success: false,
                message: 'Session admin invalide ou expirée'
            });
        }

        req.admin = {
            username: result.rows[0].username,
            nom_complet: result.rows[0].nom_complet,
            email: result.rows[0].email,
            role: result.rows[0].role,
            sessionId: result.rows[0].id
        };

        next();

    } catch (error) {
        console.error('Erreur middleware auth admin:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur d\'authentification admin'
        });
    }
}

module.exports = {
    authMiddleware,
    authAdminMiddleware,
    requirePasswordChange
};
