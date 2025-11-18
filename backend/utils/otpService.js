// utils/otpService.js - Service de génération et envoi OTP
const crypto = require('crypto');

/**
 * Génère un code OTP à 6 chiffres
 */
function generateOTP() {
    return crypto.randomInt(100000, 999999).toString();
}

/**
 * Envoie un OTP par SMS
 * Pour la V1, on simule l'envoi (à remplacer par un vrai service SMS)
 */
async function sendOTP(phoneNumber, code) {
    try {
        // Mode développement: logger dans la console
        if (process.env.NODE_ENV === 'development') {
            console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
            console.log('📱 SMS OTP (MODE DEV)');
            console.log(`Destinataire: ${phoneNumber}`);
            console.log(`Code OTP: ${code}`);
            console.log(`Valide pendant: 5 minutes`);
            console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
            return { success: true, mode: 'development' };
        }

        // Mode production: intégrer un vrai service SMS
        // Exemples de services SMS au Sénégal:
        // - Orange SMS API
        // - Free SMS API
        // - Twilio
        // - Africa's Talking

        if (process.env.SMS_PROVIDER === 'twilio') {
            return await sendViaTwilio(phoneNumber, code);
        } else if (process.env.SMS_PROVIDER === 'orange') {
            return await sendViaOrangeSN(phoneNumber, code);
        } else {
            // Fallback: simuler l'envoi
            console.log(`⚠️ SMS non envoyé (provider non configuré): ${phoneNumber} - Code: ${code}`);
            return { success: true, mode: 'simulated' };
        }

    } catch (error) {
        console.error('Erreur envoi SMS:', error);
        return { success: false, error: error.message };
    }
}

/**
 * Envoi via Twilio (exemple)
 */
async function sendViaTwilio(phoneNumber, code) {
    try {
        const accountSid = process.env.TWILIO_ACCOUNT_SID;
        const authToken = process.env.TWILIO_AUTH_TOKEN;
        const fromNumber = process.env.TWILIO_PHONE_NUMBER;

        const client = require('twilio')(accountSid, authToken);

        const message = await client.messages.create({
            body: `Votre code PERC: ${code}. Valide 5 minutes. Ne partagez ce code avec personne.`,
            from: fromNumber,
            to: phoneNumber
        });

        console.log(`✅ SMS envoyé via Twilio: ${message.sid}`);
        return { success: true, messageId: message.sid, provider: 'twilio' };

    } catch (error) {
        console.error('Erreur Twilio:', error);
        throw error;
    }
}

/**
 * Envoi via Orange Sénégal (exemple - adapter selon leur API)
 */
async function sendViaOrangeSN(phoneNumber, code) {
    try {
        const axios = require('axios');

        const response = await axios.post(
            process.env.ORANGE_SMS_API_URL,
            {
                to: phoneNumber,
                message: `Votre code PERC: ${code}. Valide 5 minutes.`,
                sender: 'PERC'
            },
            {
                headers: {
                    'Authorization': `Bearer ${process.env.ORANGE_API_TOKEN}`,
                    'Content-Type': 'application/json'
                }
            }
        );

        console.log(`✅ SMS envoyé via Orange: ${response.data.messageId}`);
        return { success: true, messageId: response.data.messageId, provider: 'orange' };

    } catch (error) {
        console.error('Erreur Orange SMS:', error);
        throw error;
    }
}

/**
 * Vérifie si un OTP est valide
 */
async function verifyOTP(matricule, code) {
    const { query } = require('../config/database');

    try {
        const result = await query(
            `SELECT * FROM perc_otp 
             WHERE matricule = $1 
             AND code = $2 
             AND utilise = FALSE 
             AND date_expiration > NOW()
             AND tentatives < 3
             ORDER BY date_generation DESC 
             LIMIT 1`,
            [matricule, code]
        );

        return result.rows.length > 0;

    } catch (error) {
        console.error('Erreur vérification OTP:', error);
        return false;
    }
}

/**
 * Nettoie les OTP expirés (à exécuter périodiquement)
 */
async function cleanExpiredOTPs() {
    const { query } = require('../config/database');

    try {
        const result = await query(
            `DELETE FROM perc_otp 
             WHERE date_expiration < NOW() - INTERVAL '1 day'`
        );

        console.log(`🧹 ${result.rowCount} OTP expirés supprimés`);
        return result.rowCount;

    } catch (error) {
        console.error('Erreur nettoyage OTP:', error);
        return 0;
    }
}

/**
 * Configure un job de nettoyage automatique
 */
function startOTPCleanupJob() {
    // Nettoyer les OTP expirés toutes les heures
    setInterval(() => {
        cleanExpiredOTPs();
    }, 60 * 60 * 1000); // 1 heure

    console.log('✅ Job de nettoyage OTP démarré (1x/heure)');
}

module.exports = {
    generateOTP,
    sendOTP,
    verifyOTP,
    cleanExpiredOTPs,
    startOTPCleanupJob
};