/**
 * Script pour hasher les mots de passe générés
 *
 * Ce script lit les mots de passe en clair depuis la table temporaire
 * et les hash avec bcrypt avant de les stocker dans password_hash
 *
 * Usage: node scripts/hash-passwords.js
 */

const bcrypt = require('bcrypt');
const { Pool } = require('pg');

// Configuration de la connexion PostgreSQL
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'perc_db',
  user: process.env.DB_USER || 'perc_user',
  password: process.env.DB_PASSWORD || 'perc_password',
});

const SALT_ROUNDS = 10;

async function hashPasswords() {
  const client = await pool.connect();

  try {
    console.log('🔐 Démarrage du hashage des mots de passe...\n');

    // Récupérer tous les mots de passe en clair
    const result = await client.query(`
      SELECT matricule, password_clear, type_generation
      FROM temp_passwords_to_send
      ORDER BY type_generation DESC, matricule
    `);

    if (result.rows.length === 0) {
      console.log('⚠️  Aucun mot de passe à hasher.');
      console.log('Vérifiez que le script SQL generate-passwords.sql a été exécuté.');
      return;
    }

    console.log(`📊 ${result.rows.length} mots de passe à hasher\n`);

    let successCount = 0;
    let errorCount = 0;
    let avecTelephoneCount = 0;
    let sansTelephoneCount = 0;

    // Hasher et mettre à jour chaque mot de passe
    for (const row of result.rows) {
      try {
        const { matricule, password_clear, type_generation } = row;

        // Hash du mot de passe avec bcrypt
        const passwordHash = await bcrypt.hash(password_clear, SALT_ROUNDS);

        // Mise à jour dans la base de données
        await client.query(`
          UPDATE perc_participants
          SET
            password_hash = $1,
            password_set = FALSE,
            first_login_done = FALSE
          WHERE matricule = $2
        `, [passwordHash, matricule]);

        successCount++;

        if (type_generation === 'avec_telephone') {
          avecTelephoneCount++;
          console.log(`✅ ${matricule} - Mot de passe unique hashé`);
        } else {
          sansTelephoneCount++;
          console.log(`✅ ${matricule} - Mot de passe commun hashé`);
        }

      } catch (err) {
        errorCount++;
        console.error(`❌ ${row.matricule} - Erreur:`, err.message);
      }
    }

    console.log('\n' + '='.repeat(60));
    console.log(`\n🎉 Hashage terminé !`);
    console.log(`   ✅ Réussis : ${successCount}`);
    console.log(`   ❌ Échecs  : ${errorCount}`);
    console.log(`\n   Détails :`);
    console.log(`   📱 Avec téléphone (mot de passe unique) : ${avecTelephoneCount}`);
    console.log(`   ⚠️  Sans téléphone (mot de passe commun) : ${sansTelephoneCount}`);
    console.log('\n' + '='.repeat(60));

    if (sansTelephoneCount > 0) {
      console.log('\n⚠️  ATTENTION :');
      console.log(`   ${sansTelephoneCount} participants SANS téléphone ont le mot de passe commun : "MDS2024!"`);
      console.log('   Ces participants doivent être informés par un autre moyen (email, courrier, etc.)');
    }

    console.log('\n📝 PROCHAINES ÉTAPES :');
    console.log('   1. Exporter les mots de passe depuis temp_passwords_to_send');
    console.log('   2. Envoyer les mots de passe aux agents :');
    console.log('      - Par SMS pour ceux avec téléphone (mot de passe unique)');
    console.log('      - Par email/courrier pour ceux sans téléphone (MDS2024!)');
    console.log('   3. Supprimer la table temporaire :');
    console.log('      DROP TABLE temp_passwords_to_send;\n');

  } catch (error) {
    console.error('\n❌ Erreur fatale:', error);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

// Exécuter le script
hashPasswords()
  .then(() => {
    console.log('✨ Script terminé avec succès\n');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Échec du script:', error);
    process.exit(1);
  });
