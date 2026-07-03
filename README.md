# 🐳 Formation Docker — Travaux Pratiques

> Code formation **DEVOPS-001** — © 2026 Telemach Learning
> Support théorique : présentations Gamma. **Ce dépôt contient uniquement les TP.**

Bienvenue dans les travaux pratiques de la formation Docker (3 jours). Ici, on **apprend en faisant** : chaque TP se construit pas à pas, à partir d'un squelette à compléter — pas de copier/coller passif.

---

## 🎯 Comment fonctionnent les TP

Chaque TP est un dossier autonome organisé ainsi :

```
tpN-nom/
├── README.md      ← le guide pas à pas (commencez TOUJOURS par là)
├── starter/       ← les fichiers À COMPLÉTER (cherchez les « TODO »)
├── solution/      ← la solution de référence (à consulter en dernier recours)
└── verify.sh      ← le script de validation (le même que la CI)
```

### La règle d'or

> **Si ce n'est pas testé par GitHub Actions, ça ne fonctionne pas.**

Chaque TP a une **cible vérifiable** (un site qui répond, une base qui persiste, une image sans vulnérabilité critique...). Le script `verify.sh` automatise cette vérification, et la **CI GitHub Actions** l'exécute sur la `solution/` à chaque push : la pastille verte ✅ prouve que le TP est réalisable de bout en bout.

### Votre méthode de travail

1. **Lisez le `README.md`** du TP en entier avant de taper la moindre commande.
2. **Travaillez dans `starter/`** : complétez les fichiers marqués `# TODO`.
3. **Validez vous-même** : lancez `./verify.sh` depuis le dossier du TP.
4. **Bloqué ?** Relisez la section « Indices », puis seulement en dernier recours, regardez `solution/`.
5. **En avance ?** Faites la section **🚀 Pour aller plus loin** — elle est là pour ça.

---

## 📚 Parcours

| TP | Sujet | Cas réel |
|----|-------|----------|
| TP1 | Premiers pas avec Docker | Lancer et manipuler des conteneurs |
| TP2 | Maîtriser la CLI | Déboguer un conteneur en production |
| TP3 | Stack multi-conteneurs à la main | Héberger un CMS (WordPress + MySQL) |
| TP4 | Construire sa première image | Emballer une landing page (Dockerfile statique) |
| TP5 | Dockerfile : toutes les instructions | Conteneuriser une appli (WORKDIR, ENV, ARG, HEALTHCHECK, USER, ENTRYPOINT…) |
| TP6 | Dockerfile avancé : multi-stage | Compiler une appli et livrer une image minimale (`scratch`) |
| TP7 | La même stack avec Compose | Industrialiser le déploiement |
| TP8 | Compose avancé | API + base + cache (env, healthchecks, override) |
| TP9 | Registry privé | Distribuer ses images en interne |
| TP10 | Sécurité des images | Scanner, durcir, transférer en air-gapped |
| TP11 | Monitoring & logs | Observer une appli (Prometheus, Grafana, Loki) |
| TP12 | Swarm & Traefik | Déployer un Drupal répliqué (3×) + MariaDB derrière Traefik |

> Les TP sont **numérotés dans l'ordre du cours** et la progression est **volontairement graduelle** — *exécuter → construire → orchestrer* : on lance des conteneurs (TP1-TP2), on monte une stack multi-conteneurs à la main (TP3), **puis** on apprend à **construire** ses propres images (TP4 statique → TP5 toutes les instructions → TP6 multi-stage), et **enfin** on **orchestre** le tout avec Docker Compose (TP7 les bases → TP8 avancé). Suivez-les dans l'ordre, quel que soit votre rythme.

📌 **Pour aller plus loin et rester autonome** : [**BONNES-PRATIQUES.md**](BONNES-PRATIQUES.md) — mémo de fin de formation (principes, aide-mémoire commandes, check-list « avant la prod » et anti-patterns à bannir).

---

## ✅ Prérequis

- **Docker Engine 27+** (idéalement la dernière version) et le plugin **Docker Compose v2** (`docker compose version`)
- Un shell **bash** (Linux, WSL2, ou macOS)
- `curl` et `git`
- Pour les TP de fin de parcours (TP11 monitoring, TP12 cluster) : une machine avec assez de RAM (4 Go libres recommandés)

Vérifiez votre environnement :

```bash
docker version
docker compose version
```

---

## 🤖 Tester en local comme la CI

Depuis n'importe quel dossier de TP :

```bash
cd tp01-prise-en-main
./verify.sh        # construit, lance, vérifie, nettoie
```

La CI fait exactement la même chose sur chaque `solution/` — voir [`.github/workflows`](.github/workflows).

---

## 🧭 Conventions

- Les commandes destructrices (`docker system prune`, `down -v`) sont **toujours signalées** dans les README.
- Chaque TP **nettoie ses propres ressources** à la fin (`verify.sh` inclut un `cleanup`).
- Les ports utilisés sont indiqués en début de TP pour éviter les collisions.
- Les mots de passe des TP sont **fictifs** et ne doivent jamais être réutilisés ailleurs.

Bon courage, et surtout : **tapez les commandes vous-même.** 💪
