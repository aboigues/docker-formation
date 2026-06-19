// Telescope — raccourcisseur d'URL interne.
// POST /shorten {url}  -> crée un code court (stocké dans Postgres)
// GET  /r/:code        -> redirige (302) vers l'URL d'origine (Redis sert de cache)
// GET  /health         -> 200 si Postgres ET Redis répondent, sinon 503
//
// Le code de l'appli est FOURNI : le cœur du TP est le fichier Compose, pas le JS.
import express from 'express';
import pg from 'pg';
import { createClient } from 'redis';

const PORT = process.env.PORT || 3000;
const CACHE_TTL = 60; // secondes : durée de vie d'une entrée en cache

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
const redis = createClient({ url: process.env.REDIS_URL });
redis.on('error', (e) => console.error('[redis]', e.message));

async function init() {
  await redis.connect();
  await pool.query(`
    CREATE TABLE IF NOT EXISTS links (
      code       TEXT PRIMARY KEY,
      url        TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )`);
}

const app = express();
app.use(express.json());

const genCode = () => Math.random().toString(36).slice(2, 8);

app.get('/', (req, res) => {
  res.json({
    service: 'telescope',
    env: process.env.NODE_ENV || 'unknown',
    endpoints: ['POST /shorten {url}', 'GET /r/:code', 'GET /health'],
  });
});

app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    await redis.ping();
    res.json({ status: 'ok' });
  } catch (e) {
    res.status(503).json({ status: 'degraded', error: e.message });
  }
});

app.post('/shorten', async (req, res) => {
  const { url } = req.body || {};
  if (!url || !/^https?:\/\//.test(url)) {
    return res.status(400).json({ error: 'url invalide (http(s) requis)' });
  }
  const code = genCode();
  await pool.query('INSERT INTO links(code, url) VALUES ($1, $2)', [code, url]);
  res.status(201).json({ code, short: `/r/${code}`, url });
});

app.get('/r/:code', async (req, res) => {
  const { code } = req.params;
  const key = `link:${code}`;

  let url = await redis.get(key);
  if (url) {
    res.set('X-Cache', 'HIT'); // servi depuis Redis, sans toucher Postgres
  } else {
    const { rows } = await pool.query('SELECT url FROM links WHERE code = $1', [code]);
    if (rows.length === 0) return res.status(404).json({ error: 'code inconnu' });
    url = rows[0].url;
    await redis.set(key, url, { EX: CACHE_TTL }); // on met en cache pour la prochaine fois
    res.set('X-Cache', 'MISS');
  }
  res.redirect(302, url);
});

init()
  .then(() => app.listen(PORT, () => console.log(`telescope sur :${PORT} (${process.env.NODE_ENV})`)))
  .catch((e) => { console.error('démarrage impossible :', e.message); process.exit(1); });
