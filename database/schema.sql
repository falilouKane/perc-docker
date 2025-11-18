-- Schéma de base de données pour le module PERC

-- Table des participants PERC
CREATE TABLE perc_participants (
    id SERIAL PRIMARY KEY,
    matricule VARCHAR(20) UNIQUE NOT NULL,
    compte_cgf VARCHAR(20) UNIQUE NOT NULL,
    nom VARCHAR(255) NOT NULL,
    direction TEXT,
    email VARCHAR(255),
    telephone VARCHAR(20),
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_modification TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table des comptes PERC
CREATE TABLE perc_accounts (
    id SERIAL PRIMARY KEY,
    participant_id INTEGER REFERENCES perc_participants(id) ON DELETE CASCADE,
    compte_cgf VARCHAR(20) UNIQUE NOT NULL,
    solde_actuel DECIMAL(15, 2) DEFAULT 0.00,
    date_ouverture DATE,
    statut VARCHAR(20) DEFAULT 'actif',
    date_maj TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table des contributions
CREATE TABLE perc_contributions (
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

-- Table des mouvements
CREATE TABLE perc_movements (
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

-- Table des fichiers importés
CREATE TABLE perc_import_files (
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

-- Table des logs d'import détaillés
CREATE TABLE perc_import_rows (
    id SERIAL PRIMARY KEY,
    import_file_id INTEGER REFERENCES perc_import_files(id) ON DELETE CASCADE,
    numero_ligne INTEGER,
    matricule VARCHAR(20),
    statut VARCHAR(50),
    erreur TEXT,
    donnees_brutes JSONB
);

-- Table des OTP pour authentification
CREATE TABLE perc_otp (
    id SERIAL PRIMARY KEY,
    matricule VARCHAR(20) NOT NULL,
    code VARCHAR(6) NOT NULL,
    telephone VARCHAR(20),
    date_generation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_expiration TIMESTAMP NOT NULL,
    utilise BOOLEAN DEFAULT FALSE,
    tentatives INTEGER DEFAULT 0
);

-- Table des sessions utilisateurs
CREATE TABLE perc_sessions (
    id SERIAL PRIMARY KEY,
    matricule VARCHAR(20) NOT NULL,
    token VARCHAR(255) UNIQUE NOT NULL,
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_expiration TIMESTAMP NOT NULL,
    ip_address VARCHAR(50),
    user_agent TEXT
);

-- Table des logs de synchronisation
CREATE TABLE perc_sync_logs (
    id SERIAL PRIMARY KEY,
    type_sync VARCHAR(50),
    date_sync TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    statut VARCHAR(50),
    details TEXT,
    nombre_enregistrements INTEGER
);

-- Index pour optimiser les performances
CREATE INDEX idx_participant_matricule ON perc_participants(matricule);
CREATE INDEX idx_account_participant ON perc_accounts(participant_id);
CREATE INDEX idx_contributions_account ON perc_contributions(account_id);
CREATE INDEX idx_contributions_date ON perc_contributions(date_contribution);
CREATE INDEX idx_movements_account ON perc_movements(account_id);
CREATE INDEX idx_otp_matricule ON perc_otp(matricule);
CREATE INDEX idx_sessions_token ON perc_sessions(token);

-- Vue pour consultation rapide des comptes avec solde
CREATE VIEW v_perc_comptes_actifs AS
SELECT 
    p.matricule,
    p.nom,
    p.email,
    p.telephone,
    p.direction,
    a.compte_cgf,
    a.solde_actuel,
    a.date_ouverture,
    a.statut,
    (SELECT COUNT(*) FROM perc_contributions WHERE account_id = a.id) as nombre_contributions,
    (SELECT MAX(date_contribution) FROM perc_contributions WHERE account_id = a.id) as derniere_contribution
FROM perc_participants p
JOIN perc_accounts a ON p.id = a.participant_id
WHERE a.statut = 'actif';

-- Fonction trigger pour mettre à jour date_modification
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

-- Fonction pour calculer le solde d'un compte
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
