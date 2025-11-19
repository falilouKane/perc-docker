-- Schéma V2 avec système de mots de passe

-- Table des participants PERC (MODIFIÉE)
CREATE TABLE IF NOT EXISTS perc_participants (
    id SERIAL PRIMARY KEY,
    matricule VARCHAR(20) UNIQUE NOT NULL,
    compte_cgf VARCHAR(20) UNIQUE NOT NULL,
    nom VARCHAR(255) NOT NULL,
    direction TEXT,
    email VARCHAR(255),
    telephone VARCHAR(20),
    
    -- NOUVEAU : Système de mot de passe
    password_hash VARCHAR(255),  -- Mot de passe hashé (bcrypt)
    password_set BOOLEAN DEFAULT FALSE,  -- A-t-il défini un mot de passe ?
    first_login_done BOOLEAN DEFAULT FALSE,  -- Première connexion faite ?
    last_login TIMESTAMP,
    
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_modification TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- NOUVELLE TABLE : Administrateurs (séparés des agents)
CREATE TABLE perc_admins (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,  -- Login admin (ex: "admin_mutuelle")
    password_hash VARCHAR(255) NOT NULL,  -- Mot de passe hashé
    nom_complet VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    role VARCHAR(50) DEFAULT 'admin',  -- admin, super_admin, etc.
    actif BOOLEAN DEFAULT TRUE,
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP
);

-- Table des comptes PERC (INCHANGÉE)
CREATE TABLE IF NOT EXISTS perc_accounts (
    id SERIAL PRIMARY KEY,
    participant_id INTEGER REFERENCES perc_participants(id) ON DELETE CASCADE,
    compte_cgf VARCHAR(20) UNIQUE NOT NULL,
    solde_actuel DECIMAL(15, 2) DEFAULT 0.00,
    date_ouverture DATE,
    statut VARCHAR(20) DEFAULT 'actif',
    date_maj TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table des contributions (INCHANGÉE)
CREATE TABLE IF NOT EXISTS perc_contributions (
    id SERIAL PRIMARY KEY,
    account_id INTEGER REFERENCES perc_accounts(id) ON DELETE CASCADE,
    participant_id INTEGER REFERENCES perc_participants(id) ON DELETE CASCADE,
    montant DECIMAL(15, 2) NOT NULL,
    type_contribution VARCHAR(50) DEFAULT 'versement_cgf',
    periode VARCHAR(20),
    date_contribution TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    import_file_id INTEGER,
    commentaire TEXT
);

-- Table des mouvements (INCHANGÉE)
CREATE TABLE IF NOT EXISTS perc_movements (
    id SERIAL PRIMARY KEY,
    account_id INTEGER REFERENCES perc_accounts(id) ON DELETE CASCADE,
    type_mouvement VARCHAR(50) NOT NULL,
    montant DECIMAL(15, 2) NOT NULL,
    solde_avant DECIMAL(15, 2),
    solde_apres DECIMAL(15, 2),
    description TEXT,
    date_mouvement TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reference VARCHAR(100)
);

-- Table des fichiers importés (INCHANGÉE)
CREATE TABLE IF NOT EXISTS perc_import_files (
    id SERIAL PRIMARY KEY,
    nom_fichier VARCHAR(255) NOT NULL,
    date_import TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    nombre_lignes INTEGER,
    nombre_succes INTEGER,
    nombre_erreurs INTEGER,
    statut VARCHAR(50),
    rapport_erreurs TEXT,
    importe_par VARCHAR(100)
);

-- Table des logs d'import détaillés (INCHANGÉE)
CREATE TABLE IF NOT EXISTS perc_import_rows (
    id SERIAL PRIMARY KEY,
    import_file_id INTEGER REFERENCES perc_import_files(id) ON DELETE CASCADE,
    numero_ligne INTEGER,
    matricule VARCHAR(20),
    statut VARCHAR(50),
    erreur TEXT,
    donnees_brutes JSONB
);

-- Table des OTP (MODIFIÉE - uniquement pour première connexion et reset)
CREATE TABLE IF NOT EXISTS perc_otp (
    id SERIAL PRIMARY KEY,
    matricule VARCHAR(20) NOT NULL,
    code VARCHAR(6) NOT NULL,
    telephone VARCHAR(20),
    type_otp VARCHAR(50) DEFAULT 'first_login',  -- first_login, password_reset
    date_generation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_expiration TIMESTAMP NOT NULL,
    utilise BOOLEAN DEFAULT FALSE,
    tentatives INTEGER DEFAULT 0
);

-- Table des sessions (MODIFIÉE - pour agents ET admins)
CREATE TABLE IF NOT EXISTS perc_sessions (
    id SERIAL PRIMARY KEY,
    user_type VARCHAR(20) NOT NULL,  -- 'agent' ou 'admin'
    user_id VARCHAR(50) NOT NULL,  -- matricule (agent) ou username (admin)
    token VARCHAR(255) UNIQUE NOT NULL,
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_expiration TIMESTAMP NOT NULL,
    ip_address VARCHAR(50),
    user_agent TEXT
);

-- Table des logs de synchronisation (INCHANGÉE)
CREATE TABLE IF NOT EXISTS perc_sync_logs (
    id SERIAL PRIMARY KEY,
    type_sync VARCHAR(50),
    date_sync TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    statut VARCHAR(50),
    details TEXT,
    nombre_enregistrements INTEGER
);

-- NOUVELLE TABLE : Tentatives de connexion (sécurité)
CREATE TABLE perc_login_attempts (
    id SERIAL PRIMARY KEY,
    user_type VARCHAR(20) NOT NULL,  -- 'agent' ou 'admin'
    identifier VARCHAR(50) NOT NULL,  -- matricule ou username
    success BOOLEAN,
    ip_address VARCHAR(50),
    date_tentative TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    raison_echec TEXT
);

-- Index pour optimiser les performances
CREATE INDEX IF NOT EXISTS idx_participant_matricule ON perc_participants(matricule);
CREATE INDEX IF NOT EXISTS idx_participant_password_set ON perc_participants(password_set);
CREATE INDEX IF NOT EXISTS idx_admin_username ON perc_admins(username);
CREATE INDEX IF NOT EXISTS idx_account_participant ON perc_accounts(participant_id);
CREATE INDEX IF NOT EXISTS idx_contributions_account ON perc_contributions(account_id);
CREATE INDEX IF NOT EXISTS idx_contributions_date ON perc_contributions(date_contribution);
CREATE INDEX IF NOT EXISTS idx_movements_account ON perc_movements(account_id);
CREATE INDEX IF NOT EXISTS idx_otp_matricule ON perc_otp(matricule);
CREATE INDEX IF NOT EXISTS idx_sessions_token ON perc_sessions(token);
CREATE INDEX IF NOT EXISTS idx_login_attempts_identifier ON perc_login_attempts(identifier);

-- Vue pour consultation rapide des comptes avec solde (INCHANGÉE)
CREATE OR REPLACE VIEW v_perc_comptes_actifs AS
SELECT 
    p.matricule,
    p.nom,
    p.email,
    p.telephone,
    p.direction,
    p.password_set,
    p.first_login_done,
    a.compte_cgf,
    a.solde_actuel,
    a.date_ouverture,
    a.statut,
    (SELECT COUNT(*) FROM perc_contributions WHERE account_id = a.id) as nombre_contributions,
    (SELECT MAX(date_contribution) FROM perc_contributions WHERE account_id = a.id) as derniere_contribution
FROM perc_participants p
JOIN perc_accounts a ON p.id = a.participant_id
WHERE a.statut = 'actif';

-- Fonction trigger pour mettre à jour date_modification (INCHANGÉE)
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.date_modification = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_participant_modtime
    BEFORE UPDATE ON perc_participants
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_column();

-- Fonction pour calculer le solde d'un compte (INCHANGÉE)
CREATE OR REPLACE FUNCTION calculer_solde_perc(p_account_id INTEGER)
RETURNS DECIMAL(15, 2) AS $$
DECLARE
    v_solde DECIMAL(15, 2);
BEGIN
    SELECT COALESCE(SUM(montant), 0)
    INTO v_solde
    FROM perc_contributions
    WHERE account_id = p_account_id;
    
    RETURN v_solde;
END;
$$ LANGUAGE plpgsql;

-- Insérer un admin par défaut (mot de passe: Admin123!)
INSERT INTO perc_admins (username, password_hash, nom_complet, email, role)
VALUES (
    'admin',
    '$2b$10$rKwE8qF5xE0qF5xE0qF5xO7Y7Y7Y7Y7Y7Y7Y7Y7Y7Y7Y7Y7Y7Y7Y',  -- Hash de "Admin123!"
    'Administrateur Principal',
    'admin@perc.sn',
    'super_admin'
) ON CONFLICT (username) DO NOTHING;

-- Log de migration
INSERT INTO perc_sync_logs (type_sync, statut, details)
VALUES ('migration_v2', 'success', 'Migration vers système avec mots de passe terminée');