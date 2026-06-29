// capture-screens.mjs — génère les captures d'écran du TP11 (observabilité).
//
// Pourquoi ce script ? Les interfaces (Prometheus, cAdvisor, Grafana) sont
// denses et changent souvent : plutôt que de coller des captures qui se
// périment, on les (re)génère automatiquement, la stack du TP démarrée.
//
// Pré-requis :
//   1) la stack tourne :  cd solution && docker compose up -d --build
//      (ports : 9090 Prometheus, 8080 cAdvisor, 3000 Grafana)
//   2) générer un peu de trafic :  for i in $(seq 1 20); do curl -s localhost:8088/ >/dev/null; done
//   3) installer Playwright :  npm install && npx playwright install chromium
//
// Lancer :  node capture-screens.mjs
// Les PNG atterrissent dans docs/img/.
import { chromium } from 'playwright';
import { mkdir } from 'node:fs/promises';

const OUT = new URL('./docs/img/', import.meta.url);
const GRAFANA = process.env.GRAFANA_URL || 'http://localhost:3000';
const PROM = process.env.PROM_URL || 'http://localhost:9090';
const CADVISOR = process.env.CADVISOR_URL || 'http://localhost:8080';

await mkdir(OUT, { recursive: true });

const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
const page = await ctx.newPage();

let ok = 0, ko = 0;

// Capture défensive : un échec ne doit pas interrompre les autres captures.
async function shot(name, fn) {
  try {
    await fn();
    await page.waitForTimeout(1500); // laisse le rendu se stabiliser
    await page.screenshot({ path: new URL(`${name}.png`, OUT).pathname, fullPage: true });
    console.log(`  ✓ ${name}.png`);
    ok++;
  } catch (e) {
    console.warn(`  ✗ ${name} — ${e.message}`);
    ko++;
  }
}

console.log('Prometheus…');
await shot('prometheus-targets', async () => {
  await page.goto(`${PROM}/targets`, { waitUntil: 'networkidle' });
});
await shot('prometheus-query', async () => {
  await page.goto(`${PROM}/graph?g0.expr=telescope_requests_total&g0.tab=1`, { waitUntil: 'networkidle' });
});

console.log('cAdvisor…');
await shot('cadvisor-home', async () => {
  await page.goto(`${CADVISOR}/`, { waitUntil: 'networkidle' });
});

console.log('Grafana…');
// Connexion (admin/admin). Grafana propose ensuite de changer le mot de passe → on saute.
await shot('grafana-login', async () => {
  await page.goto(`${GRAFANA}/login`, { waitUntil: 'networkidle' });
  await page.fill('input[name="user"]', process.env.GF_USER || 'admin');
  await page.fill('input[name="password"]', process.env.GF_PASS || 'admin');
  await page.click('button[type="submit"]');
  await page.waitForLoadState('networkidle');
  // « Skip » l'écran de changement de mot de passe s'il apparaît.
  const skip = page.getByRole('button', { name: /skip/i });
  if (await skip.count()) await skip.first().click().catch(() => {});
});
await shot('grafana-datasources', async () => {
  await page.goto(`${GRAFANA}/connections/datasources`, { waitUntil: 'networkidle' });
});
await shot('grafana-explore-loki', async () => {
  await page.goto(`${GRAFANA}/explore`, { waitUntil: 'networkidle' });
});

await browser.close();
console.log(`\nTerminé : ${ok} capture(s), ${ko} échec(s). → docs/img/`);
process.exit(ko > 0 && ok === 0 ? 1 : 0);
