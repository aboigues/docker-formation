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

// Note : on utilise waitUntil:'domcontentloaded' (pas 'networkidle') car les
// UIs comme Prometheus/Grafana rafraîchissent en continu → le réseau n'est
// jamais « idle » et la navigation timeout. On laisse ensuite le rendu se poser.
const NAV = { waitUntil: 'domcontentloaded', timeout: 30000 };

// Capture défensive : un échec ne doit pas interrompre les autres captures.
// opts.fullPage (défaut true) : false = capture du viewport seul (pages très longues).
async function shot(name, fn, opts = {}) {
  try {
    await fn();
    await page.waitForTimeout(2500); // laisse le rendu (graphes, tableaux) se stabiliser
    await page.screenshot({ path: new URL(`${name}.png`, OUT).pathname, fullPage: opts.fullPage !== false });
    console.log(`  ✓ ${name}.png`);
    ok++;
  } catch (e) {
    console.warn(`  ✗ ${name} — ${e.message}`);
    ko++;
  }
}

// Grafana affiche parfois des modales d'annonce (« Grafana Assistant »…) qui
// recouvrent la page. On les ferme (Escape + bouton de fermeture) avant la capture.
async function dismissOverlays() {
  for (let k = 0; k < 2; k++) {
    await page.keyboard.press('Escape').catch(() => {});
    await page.waitForTimeout(300);
  }
  for (const sel of ['button[aria-label="Close"]', 'button[aria-label="Close dialog"]', '[role="dialog"] button[aria-label*="lose"]']) {
    const b = page.locator(sel);
    if (await b.count().catch(() => 0)) await b.first().click({ timeout: 1500 }).catch(() => {});
  }
  await page.waitForTimeout(400);
}

console.log('Prometheus…');
await shot('prometheus-targets', async () => {
  await page.goto(`${PROM}/targets`, NAV);
});
await shot('prometheus-query', async () => {
  await page.goto(`${PROM}/graph?g0.expr=telescope_requests_total&g0.tab=1`, NAV);
});

console.log('cAdvisor…');
// La page cAdvisor est très longue : on ne capture que le viewport (aperçu/jauges du haut).
await shot('cadvisor-home', async () => {
  await page.goto(`${CADVISOR}/`, NAV);
}, { fullPage: false });

console.log('Grafana…');
// Connexion (admin/admin). Grafana propose ensuite de changer le mot de passe → on saute.
await shot('grafana-login', async () => {
  await page.goto(`${GRAFANA}/login`, NAV);
  await page.fill('input[name="user"]', process.env.GF_USER || 'admin');
  await page.fill('input[name="password"]', process.env.GF_PASS || 'admin');
  await page.click('button[type="submit"]');
  await page.waitForLoadState('domcontentloaded');
  await page.waitForTimeout(1500);
  // « Skip » l'écran de changement de mot de passe s'il apparaît.
  const skip = page.getByRole('button', { name: /skip/i });
  if (await skip.count()) await skip.first().click().catch(() => {});
  await dismissOverlays();
});
await shot('grafana-datasources', async () => {
  await page.goto(`${GRAFANA}/connections/datasources`, NAV);
  await page.waitForTimeout(1500);
  await dismissOverlays();
});
await shot('grafana-explore-loki', async () => {
  await page.goto(`${GRAFANA}/explore`, NAV);
  await page.waitForTimeout(1500);
  await dismissOverlays();
  // Sélectionner la source Loki (best-effort : l'UI Explore ouvre la dernière source utilisée).
  try {
    await page.getByTestId('data-testid Data source picker select container').click({ timeout: 4000 });
    await page.getByText('Loki', { exact: true }).first().click({ timeout: 4000 });
    await page.waitForTimeout(1000);
  } catch { /* la source par défaut convient si la sélection échoue */ }
  // Basculer en mode « Code » (éditeur LogQL libre) plutôt que le Builder.
  try {
    for (const loc of [page.getByRole('radio', { name: 'Code' }), page.getByText('Code', { exact: true })]) {
      if (await loc.count().catch(() => 0)) { await loc.first().click({ timeout: 3000 }).catch(() => {}); break; }
    }
    await page.waitForTimeout(800);
  } catch { /* le Builder convient si le toggle est introuvable */ }
  // Saisir une requête LogQL et l'exécuter (best-effort).
  try {
    const editor = page.locator('.monaco-editor').first();
    await editor.click({ timeout: 4000 });
    await page.keyboard.type('{container=~".+"}');
    await page.keyboard.press('Shift+Enter');
    await page.waitForTimeout(3000);
  } catch { /* on capture l'écran Explore même sans requête */ }
});

await browser.close();
console.log(`\nTerminé : ${ok} capture(s), ${ko} échec(s). → docs/img/`);
process.exit(ko > 0 && ok === 0 ? 1 : 0);
