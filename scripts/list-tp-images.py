#!/usr/bin/env python3
"""Liste les images Docker TIERCES (pullables) référencées par les TP.

Source de vérité unique : les fichiers des TP eux-mêmes. On agrège les images
citées dans les Dockerfile (`FROM`), les fichiers Compose/Swarm (`image:` d'un
service sans `build:`) et les scripts shell (`docker run|create|pull`).

On ne garde que des références d'image VALIDES (nom Docker en minuscules), ce
qui élimine le bruit des lignes shell (`-p $PORT:80`, placeholders `______`…).
Les images construites localement (non pullables) n'ont PAS besoin d'être
listées ici : le workflow les saute via `docker manifest inspect` avant de
scanner. On exclut tout de même celles qu'on détecte simplement (services
Compose avec `build:`) pour garder la matrice propre.

Usage :
  list-tp-images.py            # une image par ligne (trié, dédupliqué)
  list-tp-images.py --format json   # tableau JSON des images
  list-tp-images.py --format matrix # [{image, categorie}] pour la matrice GitHub Actions
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

try:
    import yaml
except ImportError:  # pragma: no cover
    yaml = None

# Une référence d'image AVEC tag explicite : repo[:port]/chemin:tag
IMAGE_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9._/-]*(?::[0-9]+)?(?:/[A-Za-z0-9._/-]+)*:[A-Za-z0-9][A-Za-z0-9._-]*")


def tracked_files() -> list[Path]:
    root = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
    out = subprocess.check_output(["git", "-C", root, "ls-files"], text=True)
    return [Path(root) / line for line in out.splitlines() if line]


def is_dockerfile(p: Path) -> bool:
    return p.name == "Dockerfile" or p.name.endswith(".Dockerfile")


def is_yaml(p: Path) -> bool:
    # Tout YAML sauf les workflows GitHub ; on ne traitera que ceux ayant `services:`
    # (Compose OU Swarm stack.yml — dont le nom ne contient pas « compose »).
    return p.suffix in {".yml", ".yaml"} and ".github/" not in p.as_posix()


def is_script(p: Path) -> bool:
    return p.suffix == ".sh"


def valid_image(ref: str) -> bool:
    """Vrai si `ref` ressemble à une vraie image Docker (nom en minuscules).

    Écarte les mappings de ports (`PORT:80`, `TP5_PORT:3000`) et les placeholders,
    car le composant « nom » d'une image Docker est obligatoirement en minuscules.
    """
    name = ref.rsplit(":", 1)[0]  # retire le tag éventuel
    return re.fullmatch(r"[a-z0-9][a-z0-9._/-]*", name) is not None


# --- Catégories SARIF ---------------------------------------------------------
# Une alerte de code scanning ne se ferme que si la MÊME catégorie est renvoyée
# sans elle. Avec le tag dans la catégorie, chaque montée de version laissait
# les alertes de l'ancienne version ouvertes à vie (alertes « fantômes »).
# La catégorie est donc le nom de l'image, SANS tag.
#
# Piège : une même image peut être scannée en plusieurs tags dans un même run
# (registry 2/3, loki 3.7.2/3.7.8…) ; une catégorie partagée ferait s'écraser
# leurs uploads. Dans ce cas seulement, on suffixe un RANG (tags triés par
# version) : le bump d'un tag réutilise son rang, donc sa catégorie.
# Cas résiduel : si un des tags disparaît, le dernier rang devient orphelin et
# ses alertes sont à fermer à la main.


def _nom_et_tag(ref: str) -> tuple[str, str]:
    ref = ref.split("@", 1)[0]  # digest éventuel
    nom, _, tag = ref.rpartition(":")
    if not nom or "/" in tag:  # pas de tag (le « : » était celui d'un port de registre)
        return ref, "latest"
    return nom, tag


def _cle_version(tag: str) -> tuple:
    # « 1.10 » après « 1.9 », « 18 » avant « 18-alpine »
    return tuple(
        (0, int(t), "") if t.isdigit() else (1, 0, t) for t in re.findall(r"\d+|\D+", tag)
    )


def categories_sarif(images: list[str]) -> dict[str, str]:
    """Catégorie SARIF STABLE (sans tag) de chaque image, unique dans le lot."""
    groupes: dict[str, list[str]] = {}
    for image in images:
        groupes.setdefault(_nom_et_tag(image)[0], []).append(image)
    categories = {}
    for nom, refs in groupes.items():
        base = "trivy-image-" + re.sub(r"[^A-Za-z0-9._-]", "-", nom)
        if len(refs) == 1:
            categories[refs[0]] = base
            continue
        refs.sort(key=lambda r: (_cle_version(_nom_et_tag(r)[1]), r))
        for rang, ref in enumerate(refs, start=1):
            categories[ref] = f"{base}-rang-{rang}"
    return categories


def main() -> int:
    candidates: set[str] = set()   # images potentiellement à scanner
    local_built: set[str] = set()  # images construites localement → à exclure
    aliases: set[str] = set()      # alias de stage (FROM … AS x)

    for path in tracked_files():
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue

        if is_dockerfile(path):
            # Un commentaire `# image-scan: ignore` sur sa propre ligne exclut le
            # PROCHAIN FROM de la veille (Docker n'autorise pas de commentaire en
            # fin de ligne FROM). Sert aux bases volontairement vulnérables
            # (support pédagogique) pour ne pas polluer « code scanning ».
            ignore_next_from = False
            for line in text.splitlines():
                if re.search(r"#\s*image-scan:\s*ignore", line, re.IGNORECASE):
                    ignore_next_from = True
                    continue
                m = re.match(r"\s*FROM\s+(.*)", line, re.IGNORECASE)
                if not m:
                    continue
                parts = [t for t in m.group(1).split() if not t.startswith("--")]
                if not parts:
                    continue
                image = parts[0]
                # FROM <image> AS <alias>
                if len(parts) >= 3 and parts[1].upper() == "AS":
                    aliases.add(parts[2])
                skip = ignore_next_from or image.lower() == "scratch"
                ignore_next_from = False
                if skip:
                    continue
                candidates.add(image)

        elif is_yaml(path) and yaml is not None:
            try:
                doc = yaml.safe_load(text) or {}
            except yaml.YAMLError:
                continue
            if not isinstance(doc, dict) or "services" not in doc:
                continue
            for svc in (doc.get("services") or {}).values():
                if not isinstance(svc, dict):
                    continue
                image = svc.get("image")
                if not image:
                    continue
                (local_built if "build" in svc else candidates).add(str(image))

        elif is_script(path):
            for line in text.splitlines():
                # cibles construites/retaggées → à exclure
                for m in re.finditer(r"docker\s+build\b.*?-t\s+(\S+)", line):
                    local_built.add(m.group(1))
                m = re.search(r"docker\s+tag\s+\S+\s+(\S+)", line)
                if m:
                    local_built.add(m.group(1))
                # images tirées/lancées → candidates (dernier token image-like de la commande)
                if re.search(r"docker\s+(run|create|pull)\b", line):
                    for tok in IMAGE_RE.findall(line):
                        candidates.add(tok)

    # Résolution des variables shell triviales impossible : on ne garde que les
    # refs littérales (celles contenant un « $ » sont ignorées par IMAGE_RE).
    images = sorted(
        img for img in candidates
        if img not in local_built and img not in aliases
        and "$" not in img and valid_image(img)
    )

    if "--format" in sys.argv and "matrix" in sys.argv:
        categories = categories_sarif(images)
        print(json.dumps([{"image": i, "categorie": categories[i]} for i in images]))
    elif "--format" in sys.argv and "json" in sys.argv:
        print(json.dumps(images))
    else:
        print("\n".join(images))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
