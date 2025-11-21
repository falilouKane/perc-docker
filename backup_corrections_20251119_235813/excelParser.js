// utils/excelParser.js - Parser pour fichiers Excel/CSV CGF
const XLSX = require('xlsx');

/**
 * Parse un fichier Excel ou CSV et retourne un tableau d'objets
 * Format attendu selon l'extrait fourni
 */
function parseExcelFile(fileBuffer) {
    try {
        // Lire le fichier
        const workbook = XLSX.read(fileBuffer, { type: 'buffer' });

        // Prendre la première feuille
        const sheetName = workbook.SheetNames[0];
        const worksheet = workbook.Sheets[sheetName];

        // Convertir en JSON
        const rawData = XLSX.utils.sheet_to_json(worksheet, {
            raw: false,
            defval: ''
        });

        if (rawData.length === 0) {
            throw new Error('Fichier vide');
        }

        // Mapper les colonnes selon le format CGF
        const mappedData = rawData.map((row, index) => {
            try {
                // Mapping des colonnes (selon l'extrait fourni)
                // Les noms peuvent varier, on teste plusieurs possibilités
                const matricule = row['Matricule'] || row['matricule'] || row['MATRICULE'];
                const compte = row['Compte N°'] || row['Compte N'] || row['compte'] || row['COMPTE'];
                const nom = row['Nom'] || row['nom'] || row['NOM'];
                const direction = row['Direction'] || row['direction'] || row['DIRECTION'];
                const email = row['E-mail'] || row['Email'] || row['email'] || row['EMAIL'];
                const telephone = row['Tél.'] || row['Tel'] || row['Telephone'] || row['telephone'];
                const montant = row['Montant Versé'] || row['Montant'] || row['montant'] || row['MONTANT'];

                // Nettoyer les données
                const cleanedData = {
                    matricule: String(matricule || '').trim(),
                    compte_cgf: String(compte || '').trim(),
                    nom: String(nom || '').trim(),
                    direction: String(direction || '').trim(),
                    email: String(email || '').trim(),
                    telephone: cleanPhoneNumber(telephone),
                    montant: cleanMontant(montant)
                };

                // Validation basique
                if (!cleanedData.matricule) {
                    throw new Error(`Ligne ${index + 2}: Matricule manquant`);
                }

                if (!cleanedData.compte_cgf) {
                    throw new Error(`Ligne ${index + 2}: Numéro de compte manquant`);
                }

                if (!cleanedData.montant || isNaN(parseFloat(cleanedData.montant))) {
                    throw new Error(`Ligne ${index + 2}: Montant invalide`);
                }

                return cleanedData;

            } catch (error) {
                console.error(`Erreur ligne ${index + 2}:`, error.message);
                throw error;
            }
        });

        console.log(`✅ ${mappedData.length} lignes parsées avec succès`);
        return mappedData;

    } catch (error) {
        console.error('Erreur parsing Excel:', error);
        throw new Error(`Erreur de parsing: ${error.message}`);
    }
}

/**
 * Nettoie un numéro de téléphone
 */
function cleanPhoneNumber(phone) {
    if (!phone) return '';

    // Enlever tous les caractères non numériques sauf le +
    let cleaned = String(phone).replace(/[^\d+]/g, '');

    // Si commence par 00, remplacer par +
    if (cleaned.startsWith('00')) {
        cleaned = '+' + cleaned.substring(2);
    }

    // Si pas de préfixe international et commence par 7, ajouter +221 (Sénégal)
    if (!cleaned.startsWith('+') && cleaned.startsWith('7')) {
        cleaned = '+221' + cleaned;
    }

    return cleaned;
}

/**
 * Nettoie un montant
 */
function cleanMontant(montant) {
    if (!montant) return '';

    // Convertir en string et enlever les espaces
    let cleaned = String(montant).replace(/\s/g, '');

    // Remplacer virgule par point
    cleaned = cleaned.replace(',', '.');

    // Enlever tout sauf chiffres et point
    cleaned = cleaned.replace(/[^\d.]/g, '');

    return cleaned;
}

/**
 * Valide la structure d'un fichier CGF
 */
function validateCGFStructure(data) {
    const requiredColumns = ['matricule', 'compte_cgf', 'nom', 'montant'];
    const errors = [];

    if (!Array.isArray(data) || data.length === 0) {
        errors.push('Fichier vide ou format invalide');
        return { valid: false, errors };
    }

    // Vérifier que toutes les colonnes requises sont présentes
    const firstRow = data[0];
    requiredColumns.forEach(col => {
        if (!(col in firstRow)) {
            errors.push(`Colonne manquante: ${col}`);
        }
    });

    // Vérifier les doublons de matricule
    const matricules = data.map(row => row.matricule);
    const duplicates = matricules.filter((item, index) => matricules.indexOf(item) !== index);

    if (duplicates.length > 0) {
        errors.push(`Matricules en double: ${[...new Set(duplicates)].join(', ')}`);
    }

    return {
        valid: errors.length === 0,
        errors,
        stats: {
            total_lignes: data.length,
            matricules_uniques: new Set(matricules).size
        }
    };
}

module.exports = {
    parseExcelFile,
    cleanPhoneNumber,
    cleanMontant,
    validateCGFStructure
};