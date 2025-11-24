/**
 * Script pour générer le hash du mot de passe admin
 *
 * Usage: node scripts/hash-admin-password.js [mot-de-passe]
 *
 * Exemple:
 *   node scripts/hash-admin-password.js Admin123!
 */

const bcrypt = require('bcrypt');

const SALT_ROUNDS = 10;

async function hashPassword(password) {
  if (!password) {
    console.error('\n❌ Erreur: Veuillez fournir un mot de passe');
    console.log('\nUsage: node scripts/hash-admin-password.js [mot-de-passe]');
    console.log('Exemple: node scripts/hash-admin-password.js Admin123!\n');
    process.exit(1);
  }

  try {
    console.log('\n🔐 Hashage du mot de passe admin...\n');

    const hash = await bcrypt.hash(password, SALT_ROUNDS);

    console.log('✅ Hash généré avec succès !\n');
    console.log('='.repeat(80));
    console.log(`Mot de passe   : ${password}`);
    console.log(`Hash (bcrypt)  : ${hash}`);
    console.log('='.repeat(80));

    console.log('\n📝 SQL pour insérer dans la base de données :\n');
    console.log(`INSERT INTO perc_admins (username, password_hash, nom_complet, email, role)`);
    console.log(`VALUES (`);
    console.log(`    'admin',`);
    console.log(`    '${hash}',`);
    console.log(`    'Administrateur Principal',`);
    console.log(`    'admin@perc.sn',`);
    console.log(`    'super_admin'`);
    console.log(`) ON CONFLICT (username) DO UPDATE`);
    console.log(`SET password_hash = EXCLUDED.password_hash;`);
    console.log('');

  } catch (error) {
    console.error('\n❌ Erreur lors du hashage:', error);
    process.exit(1);
  }
}

// Récupérer le mot de passe depuis les arguments
const password = process.argv[2];

hashPassword(password)
  .then(() => {
    console.log('✨ Script terminé\n');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Échec du script:', error);
    process.exit(1);
  });
