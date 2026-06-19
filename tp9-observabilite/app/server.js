// Appli d'exemple INSTRUMENTÉE pour le TP observabilité.
// - expose des métriques Prometheus sur /metrics (format texte, sans dépendance)
// - écrit un log JSON sur stdout à chaque requête (récupéré ensuite par Loki)
import http from 'node:http';

let requests = 0;
const started = Date.now();

const server = http.createServer((req, res) => {
  if (req.url === '/metrics') {
    const uptime = Math.round((Date.now() - started) / 1000);
    res.writeHead(200, { 'Content-Type': 'text/plain; version=0.0.4' });
    res.end(
      '# HELP telescope_requests_total Nombre total de requêtes servies.\n' +
      '# TYPE telescope_requests_total counter\n' +
      `telescope_requests_total ${requests}\n` +
      '# HELP telescope_uptime_seconds Uptime du service en secondes.\n' +
      '# TYPE telescope_uptime_seconds gauge\n' +
      `telescope_uptime_seconds ${uptime}\n`
    );
    return;
  }

  requests++;
  // Log structuré sur stdout : c'est CE flux que Docker capte et qu'Alloy enverra à Loki.
  console.log(JSON.stringify({
    level: 'info', msg: 'requête servie', path: req.url,
    ts: new Date().toISOString(),
  }));

  if (req.url === '/health') { res.writeHead(200); res.end('ok\n'); return; }

  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end('telescope demo — métriques sur /metrics\n');
});

server.listen(3000, () => console.log('demo app à l\'écoute sur :3000'));
