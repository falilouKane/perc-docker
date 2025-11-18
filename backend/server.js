// server.js - Serveur principal Express
const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const fileUpload = require('express-fileupload');
const path = require('path');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(fileUpload());
app.use(express.static('public'));

// Routes
const authRoutes = require('./routes/auth');
const percRoutes = require('./routes/perc');
const importRoutes = require('./routes/import');

app.use('/api/auth', authRoutes);
app.use('/api/perc', percRoutes);
app.use('/api/import', importRoutes);

// Route racine - Page d'accueil
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, '../public', 'index.html'));
});

// Gestion des erreurs globales
app.use((err, req, res, next) => {
    console.error('Erreur:', err.stack);
    res.status(500).json({
        success: false,
        message: 'Erreur serveur',
        error: process.env.NODE_ENV === 'development' ? err.message : 'Erreur interne'
    });
});

// Démarrage du serveur
app.listen(PORT, () => {
    console.log(`🚀 Serveur PERC démarré sur le port ${PORT}`);
    console.log(`📍 URL: http://localhost:${PORT}`);
});

module.exports = app;