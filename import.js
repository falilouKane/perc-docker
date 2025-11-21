// routes/import.js - Routes d'import des fichiers CGF (AMÉLIORÉ)
const express = require('express');
const router = express.Router();
const { query, transaction } = require('../config/database');
const { parseExcelFile } = require('../utils/excelParser');
const adminAuthMiddleware = require('../middleware/adminAuth');

// Middleware admin pour les imports
router.use(adminAuthMiddleware);

// POST /api/import/cgf - Importer un fichier CGF
router.post('/cgf', async (req, res) => {
    try {
        if (!req.files || !req.files.file) {
            return res.status(400).json({
                success: false,
                message: 'Aucun fichier fourni'
            });
        }

        const file = req.files.file;
        const importedBy = req.user?.username || 'admin';

        console.log(`📥 Début import: ${file.name} par ${importedBy}`);

        // Vérifier l'extension du fichier
        const validExtensions = ['.xlsx', '.xls', '.csv'];
        const fileExt = file.name.substring(file.name.lastIndexOf('.')).toLowerCase();

        if (!validExtensions.includes(fileExt)) {
            return res.status(400).json({
                success: false,
                message: 'Format de fichier non supporté. Utilisez Excel (.xlsx, .xls) ou CSV'
            });
        }

        // Parser le fichier Excel/CSV - VERSION AMÉLIORÉE
        const parseResult = parseExcelFile(file.data);

        if (!parseResult.success || !parseResult.data || parseResult.data.length === 0) {
            return res.status(400).json({
                success: false,
                message: 'Fichier vide ou format invalide',
                details: parseResult.errors
            });
        }

        const parsedData = parseResult.data;
        const parseErrors = parseResult.errors || [];

        console.log(`✅ Parsing OK: ${parsedData.length} lignes valides, ${parseErrors.length} erreurs de parsing`);

        // Créer un enregistrement d'import
        const importFileResult = await query(
            `INSERT INTO perc_import_files 
             (nom_fichier, nombre_lignes, importe_par, statut) 
             VALUES ($1, $2, $3, $4) 
             RETURNING id`,
            [file.name, parseResult.stats.total, importedBy, 'en_cours']
        );

        const importFileId = importFileResult.rows[0].id;

        // Traiter chaque ligne
        const results = {
            succes: 0,
            erreurs: parseErrors.length, // Inclure les erreurs de parsing
            details: []
        };

        // Ajouter les erreurs de parsing au rapport
        parseErrors.forEach(err => {
            results.details.push({
                ligne: err.ligne,
                matricule: err.matricule,
                statut: 'ERREUR_PARSING',
                erreur: err.erreur
            });
        });

        // Traiter les lignes valides
        for (let i = 0; i < parsedData.length; i++) {
            const row = parsedData[i];
            const rowNumber = row._lineNumber;

            try {
                await transaction(async (client) => {
                    // Validation des données
                    if (!row.matricule || !row.compte_cgf || !row.montant) {
                        throw new Error('Données manquantes (matricule, compte ou montant)');
                    }

                    // Nettoyer le montant
                    const montant = parseFloat(row.montant);

                    if (isNaN(montant) || montant <= 0) {
                        throw new Error('Montant invalide');
                    }

                    // 1. Créer ou mettre à jour le participant
                    const participantResult = await client.query(
                        `INSERT INTO perc_participants 
                         (matricule, compte_cgf, nom, direction, email, telephone)
                         VALUES ($1, $2, $3, $4, $5, $6)
                         ON CONFLICT (matricule) 
                         DO UPDATE SET 
                            nom = EXCLUDED.nom,
                            direction = EXCLUDED.direction,
                            email = EXCLUDED.email,
                            telephone = EXCLUDED.telephone,
                            date_modification = CURRENT_TIMESTAMP
                         RETURNING id`,
                        [
                            row.matricule,
                            row.compte_cgf,
                            row.nom || 'Nom non fourni',
                            row.direction || '',
                            row.email || '',
                            row.telephone || ''
                        ]
                    );

                    const participantId = participantResult.rows[0].id;

                    // 2. Créer ou mettre à jour le compte
                    const accountResult = await client.query(
                        `INSERT INTO perc_accounts 
                         (participant_id, compte_cgf, date_ouverture, statut)
                         VALUES ($1, $2, CURRENT_DATE, 'actif')
                         ON CONFLICT (compte_cgf) 
                         DO UPDATE SET date_maj = CURRENT_TIMESTAMP
                         RETURNING id, solde_actuel`,
                        [participantId, row.compte_cgf]
                    );

                    const accountId = accountResult.rows[0].id;
                    const soldeAvant = parseFloat(accountResult.rows[0].solde_actuel || 0);

                    // 3. Créer la contribution
                    await client.query(
                        `INSERT INTO perc_contributions 
                         (account_id, participant_id, montant, type_contribution, periode, import_file_id)
                         VALUES ($1, $2, $3, $4, $5, $6)`,
                        [
                            accountId,
                            participantId,
                            montant,
                            'versement_cgf',
                            new Date().toISOString().substring(0, 7),
                            importFileId
                        ]
                    );

                    // 4. Créer un mouvement
                    const soldeApres = soldeAvant + montant;

                    await client.query(
                        `INSERT INTO perc_movements 
                         (account_id, type_mouvement, montant, solde_avant, solde_apres, description)
                         VALUES ($1, $2, $3, $4, $5, $6)`,
                        [
                            accountId,
                            'contribution',
                            montant,
                            soldeAvant,
                            soldeApres,
                            `Import CGF - ${file.name}`
                        ]
                    );

                    // 5. Mettre à jour le solde du compte
                    await client.query(
                        'UPDATE perc_accounts SET solde_actuel = $1, date_maj = CURRENT_TIMESTAMP WHERE id = $2',
                        [soldeApres, accountId]
                    );

                    // Enregistrer la ligne comme succès
                    await client.query(
                        `INSERT INTO perc_import_rows 
                         (import_file_id, numero_ligne, matricule, statut, donnees_brutes)
                         VALUES ($1, $2, $3, $4, $5)`,
                        [importFileId, rowNumber, row.matricule, 'succes', JSON.stringify(row)]
                    );

                    results.succes++;
                    results.details.push({
                        ligne: rowNumber,
                        matricule: row.matricule,
                        statut: 'OK',
                        montant: montant
                    });
                });

            } catch (error) {
                results.erreurs++;

                // Enregistrer l'erreur
                await query(
                    `INSERT INTO perc_import_rows 
                     (import_file_id, numero_ligne, matricule, statut, erreur, donnees_brutes)
                     VALUES ($1, $2, $3, $4, $5, $6)`,
                    [
                        importFileId,
                        rowNumber,
                        row.matricule || 'INCONNU',
                        'erreur',
                        error.message,
                        JSON.stringify(row)
                    ]
                );

                results.details.push({
                    ligne: rowNumber,
                    matricule: row.matricule || 'INCONNU',
                    statut: 'ERREUR',
                    erreur: error.message
                });

                console.error(`❌ Erreur ligne ${rowNumber}:`, error.message);
            }
        }

        // Mettre à jour le fichier d'import
        await query(
            `UPDATE perc_import_files 
             SET nombre_succes = $1, 
                 nombre_erreurs = $2, 
                 statut = $3,
                 rapport_erreurs = $4
             WHERE id = $5`,
            [
                results.succes,
                results.erreurs,
                results.erreurs === 0 ? 'complet' : 'partiel',
                JSON.stringify(results.details.filter(d => d.statut !== 'OK')),
                importFileId
            ]
        );

        console.log(`✅ Import terminé: ${results.succes} succès, ${results.erreurs} erreurs`);

        res.json({
            success: true,
            message: `Import terminé: ${results.succes} succès, ${results.erreurs} erreurs`,
            data: {
                import_id: importFileId,
                fichier: file.name,
                total_lignes: parseResult.stats.total,
                lignes_parsees: parsedData.length,
                erreurs_parsing: parseErrors.length,
                succes: results.succes,
                erreurs: results.erreurs,
                details: results.details.filter(d => d.statut !== 'OK').slice(0, 20) // Max 20 premières erreurs
            }
        });

    } catch (error) {
        console.error('❌ Erreur import CGF:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur lors de l\'import du fichier',
            error: error.message
        });
    }
});

// GET /api/import/history - Historique des imports
router.get('/history', async (req, res) => {
    try {
        const { limit = 20 } = req.query;

        const imports = await query(
            `SELECT 
                id,
                nom_fichier,
                date_import,
                nombre_lignes,
                nombre_succes,
                nombre_erreurs,
                statut,
                importe_par
             FROM perc_import_files
             ORDER BY date_import DESC
             LIMIT $1`,
            [limit]
        );

        res.json({
            success: true,
            data: imports.rows
        });

    } catch (error) {
        console.error('Erreur historique imports:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur lors du chargement de l\'historique'
        });
    }
});

// GET /api/import/:id/details - Détails d'un import
router.get('/:id/details', async (req, res) => {
    try {
        const { id } = req.params;

        const importDetails = await query(
            `SELECT * FROM perc_import_files WHERE id = $1`,
            [id]
        );

        if (importDetails.rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Import non trouvé'
            });
        }

        const rows = await query(
            `SELECT * FROM perc_import_rows WHERE import_file_id = $1 ORDER BY numero_ligne`,
            [id]
        );

        res.json({
            success: true,
            data: {
                import: importDetails.rows[0],
                rows: rows.rows
            }
        });

    } catch (error) {
        console.error('Erreur détails import:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur lors du chargement des détails'
        });
    }
});

module.exports = router;
