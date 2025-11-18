# Dockerfile pour le backend PERC
FROM node:18-alpine

# Créer le répertoire de l'application
WORKDIR /app

# Copier les fichiers package
COPY package*.json ./

# Installer les dépendances
RUN npm install --production

# Copier le code source
COPY backend/ ./backend/
COPY public/ ./public/

# Exposer le port
EXPOSE 3000

# Variable d'environnement par défaut
ENV NODE_ENV=production

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/api/auth/verify-token', (r) => {process.exit(r.statusCode === 200 || r.statusCode === 401 ? 0 : 1)})"

# Démarrer l'application
CMD ["node", "backend/server.js"]