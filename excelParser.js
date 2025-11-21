// utils/excelParser.js - Parser AMÉLIORÉ pour fichiers Excel/CSV CGF
const XLSX = require('xlsx');

/**
 * Parse un fichier Excel ou CSV et retourne un tableau d'objets
 * VERSION AMÉLIORÉE : Plus tolérant, ne bloque pas pour des erreurs mineures
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

        console.log(`📊 Fichier chargé: ${rawData.length} lignes à parser`);

        // Mapper les colonnes selon le format CGF
        const mappedData = [];
        const parseErrors = [];

        rawData.forEach((row, index) => {
            const lineNumber = index + 2; // +2 car ligne 1 = headers

            try {
                // Mapping des colonnes (selon l'extrait fourni)
                const matricule = extractValue(row, ['Matricule', 'matricule', 'MATRICULE', 'N° Matricule']);
                const compte = extractValue(row, ['Compte N°', 'Compte N', 'compte', 'COMPTE', 'Numero Compte', 'N°Compte']);
                const nom = extractValue(row, ['Nom', 'nom', 'NOM', 'Nom Complet', 'Nom et Prenom']);
                const direction = extractValue(row, ['Direction', 'direction', 'DIRECTION', 'Service']);
                const email = extractValue(row, ['E-mail', 'Email', 'email', 'EMAIL', 'Mail']);
                const telephone = extractValue(row, ['Tél.', 'Tel', 'Telephone', 'telephone', 'TEL', 'Téléphone']);
                const montant = extractValue(row, ['Montant Versé', 'Montant', 'montant', 'MONTANT', 'Montant Verse', 'Versement']);

                // Nettoyer les données
                const cleanedData = {
                    matricule: String(matricule || '').trim(),
                    compte_cgf: String(compte || '').trim(),
                    nom: String(nom || '').trim(),
                    direction: String(direction || '').trim(),
                    email: String(email || '').trim(),
                    telephone: cleanPhoneNumber(telephone),
                    montant: cleanMontant(montant),
                    _lineNumber: lineNumber
                };

                // Validation basique
                if (!cleanedData.matricule) {
                    throw new Error(`Matricule manquant`);
                }

                if (!cleanedData.compte_cgf) {
                    throw new Error(`Numéro de compte manquant`);
                }

                // Validation du montant avec plus de tolérance
                const montantParsed = parseFloat(cleanedData.montant);
                if (!cleanedData.montant || isNaN(montantParsed) || montantParsed < 0) {
                    // Log détaillé pour debug
                    console.log(`⚠️ Ligne ${lineNumber}: Montant invalide: "${montant}" → "${cleanedData.montant}"`);
                    throw new Error(`Montant invalide: "${montant}"`);
                }

                mappedData.push(cleanedData);

            } catch (error) {
                // Collecter l'erreur mais continuer le parsing
                parseErrors.push({
                    ligne: lineNumber,
                    matricule: row['Matricule'] || row['matricule'] || 'INCONNU',
                    erreur: error.message,
                    donnees_brutes: row
                });
                console.warn(`⚠️ Ligne ${lineNumber} ignorée: ${error.message}`);
            }
        });

        console.log(`✅ Parsing terminé: ${mappedData.length} lignes valides, ${parseErrors.length} erreurs`);

        // Si TOUTES les lignes ont échoué, c'est un vrai problème
        if (mappedData.length === 0) {
            throw new Error(`Aucune ligne valide trouvée. ${parseErrors.length} erreurs de parsing.`);
        }

        return {
            success: true,
            data: mappedData,
            errors: parseErrors,
            stats: {
                total: rawData.length,
                valides: mappedData.length,
                erreurs: parseErrors.length
            }
        };

    } catch (error) {
        console.error('❌ Erreur parsing Excel:', error);
        throw new Error(`Erreur de parsing: ${error.message}`);
    }
}

/**
 * Extrait une valeur en testant plusieurs noms de colonnes possibles
 */
function extractValue(row, possibleKeys) {
    for (const key of possibleKeys) {
        if (row[key] !== undefined && row[key] !== null && row[key] !== '') {
            return row[key];
        }
    }
    return '';
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
    if (!cleaned.startsWith('+') && cleaned.startsWith('7') && cleaned.length === 9) {
        cleaned = '+221' + cleaned;
    }

    return cleaned;
}

/**
 * Nettoie un montant - VERSION AMÉLIORÉE
 */
function cleanMontant(montant) {
    if (!montant) return '';

    // Convertir en string
    let cleaned = String(montant).trim();

    // Si vide après trim
    if (!cleaned) return '';

    // Enlever les espaces (y compris espaces insécables)
    cleaned = cleaned.replace(/\s+/g, '');
    cleaned = cleaned.replace(/\u00A0/g, ''); // Espace insécable

    // Gérer les formats européens (virgule = décimale)
    // Exemples: "1 500,50" → "1500.50"
    //           "1.500,50" → "1500.50"
    //           "1 500" → "1500"
    
    // Détecter le format
    const hasComma = cleaned.includes(',');
    const hasDot = cleaned.includes('.');
    
    if (hasComma && hasDot) {
        // Format mixte: détecter lequel est le séparateur décimal
        const lastComma = cleaned.lastIndexOf(',');
        const lastDot = cleaned.lastIndexOf('.');
        
        if (lastComma > lastDot) {
            // Virgule est le séparateur décimal: "1.500,50"
            cleaned = cleaned.replace(/\./g, '').replace(',', '.');
        } else {
            // Point est le séparateur décimal: "1,500.50"
            cleaned = cleaned.replace(/,/g, '');
        }
    } else if (hasComma && !hasDot) {
        // Seulement virgule: "1500,50"
        cleaned = cleaned.replace(',', '.');
    }
    // Si seulement point, on garde tel quel

    // Enlever tout sauf chiffres et point
    cleaned = cleaned.replace(/[^\d.]/g, '');

    // Gérer les points multiples (garder seulement le dernier)
    const parts = cleaned.split('.');
    if (parts.length > 2) {
        cleaned = parts.slice(0, -1).join('') + '.' + parts[parts.length - 1];
    }

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

/**
 * Fonction helper pour analyser un fichier sans l'importer
 */
function analyzeExcelFile(fileBuffer) {
    try {
        const result = parseExcelFile(fileBuffer);
        
        return {
            success: true,
            stats: result.stats,
            sample: result.data.slice(0, 5), // Premiers 5 enregistrements
            errors: result.errors.slice(0, 10) // Premières 10 erreurs
        };
    } catch (error) {
        return {
            success: false,
            error: error.message
        };
    }
}

module.exports = {
    parseExcelFile,
    cleanPhoneNumber,
    cleanMontant,
    validateCGFStructure,
    analyzeExcelFile
};
