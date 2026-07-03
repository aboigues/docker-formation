// Telemach Cloud — portail interne (appli de démonstration du TP6).
// Le code est FOURNI : le cœur du TP est le `Dockerfile`, pas le JavaScript.
//
//   GET /         → page d'accueil HTML (affiche « Telemach Cloud » + la version)
//   GET /healthz  → 200 {status:"ok"}  (cible du HEALTHCHECK)
//   GET /version  → la version injectée AU BUILD via l'ARG APP_VERSION
import express from 'express';

const PORT = process.env.PORT || 3000;
const VERSION = process.env.APP_VERSION || 'inconnue';
const ENVNAME = process.env.NODE_ENV || 'unknown';

const app = express();

app.get('/', (req, res) => {
  res.type('html').send(`<!doctype html>
<html lang="fr">
  <head><meta charset="utf-8"><title>Telemach Cloud</title></head>
  <body style="font-family:system-ui;max-width:40rem;margin:4rem auto">
    <h1>☁️ Telemach Cloud — portail interne</h1>
    <p>Conteneurisé avec un <strong>Dockerfile complet</strong> (TP6).</p>
    <ul>
      <li>Version : <code>${VERSION}</code> (injectée au build)</li>
      <li>Environnement : <code>${ENVNAME}</code></li>
    </ul>
  </body>
</html>`);
});

app.get('/healthz', (req, res) => res.json({ status: 'ok' }));

app.get('/version', (req, res) => res.json({ version: VERSION }));

app.listen(PORT, () => {
  console.log(`Portail Telemach Cloud à l'écoute sur :${PORT} (v${VERSION}, ${ENVNAME})`);
});
