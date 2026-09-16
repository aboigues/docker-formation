#!/usr/bin/env bash
# Construit les images durcies, mesure le gain, et les publie multi-arch
# (amd64 + arm64) avec --push.
#
# Le tag reflète celui de l'amont (voir README.md). Sort en échec si une image
# reste avec des CVE OS corrigeables : c'est exactement ce sur quoi la
# barrière de image-scan.yml bloquera au scan suivant.
set -euo pipefail

cd "$(dirname "$0")"

PUSH=false
[[ "${1:-}" == "--push" ]] && PUSH=true

PLATFORMS="linux/amd64,linux/arm64"

# répertoire | image publiée | image amont
IMAGES=(
  "grafana|telemachlearning/grafana:13.0.2|grafana/grafana:13.0.2"
  "cadvisor|telemachlearning/cadvisor:v0.55.1|gcr.io/cadvisor/cadvisor:v0.55.1"
)

# Rend « <corrigeables>/<total> » pour les CVE de paquets OS CRITICAL+HIGH, en
# passant par l'image officielle aquasec/trivy épinglée — même convention que
# .github/workflows/image-scan.yml (pas d'action tierce type
# aquasecurity/setup-trivy, compromise en 2025).
#
# Le socket Docker est monté : sans lui, Trivy (qui tourne dans SON PROPRE
# conteneur, isolé du daemon hôte) ne voit pas l'image "$image" qu'on vient de
# charger en local via `buildx --load` — il retombe silencieusement sur un
# pull distant et mesure l'ANCIENNE image déjà publiée sur le registre, pas
# celle qu'on vient de construire. Bug réel constaté le 2026-09-16 : le
# tableau affichait 14/14 et 18/18 restants alors que les images fraîchement
# reconstruites et publiées étaient à 0/0 une fois scannées directement.
count_os_cves() {
  docker run --rm -e GITHUB_TOKEN \
    -v /var/run/docker.sock:/var/run/docker.sock \
    aquasec/trivy:0.72.0 image \
    --quiet --scanners vuln --pkg-types os --severity CRITICAL,HIGH \
    --format json --no-progress "$1" 2>/dev/null |
    python3 -c '
import json, sys
d = json.load(sys.stdin)
vulns = [v for r in (d.get("Results") or []) for v in (r.get("Vulnerabilities") or [])]
print("%d/%d" % (sum(1 for v in vulns if v.get("FixedVersion")), len(vulns)))
' 2>/dev/null || echo "?/?"
}

failed=0

printf '%-46s %12s %12s\n' "IMAGE" "AMONT" "DURCIE"
printf '%-46s %12s %12s\n' "" "(corr./tot.)" "(corr./tot.)"
for entry in "${IMAGES[@]}"; do
  IFS='|' read -r dir image upstream <<<"$entry"

  # Mesure sur un build mono-arch (amd64, plateforme du runner) chargé en
  # local : buildx --load ne sait pas charger un manifeste multi-plateforme.
  # --no-cache --pull est obligatoire, pas une précaution : sans eux, Docker
  # réutilise le layer `apk upgrade` du build précédent et l'image reconstruite
  # est identique à l'ancienne (no-op silencieux, cf. build.sh de
  # kubernetes-formation, mesuré sur netshoot le 2026-07-27).
  docker buildx build --no-cache --pull --load --platform linux/amd64 -q -t "$image" "$dir" >/dev/null

  before=$(count_os_cves "$upstream")
  after=$(count_os_cves "$image")

  printf '%-46s %12s %12s\n' "$image" "$before" "$after"

  if [[ "${after%%/*}" != "0" ]]; then
    echo "  ⚠️  $image garde des CVE OS corrigeables : la barrière bloquera dessus." >&2
    failed=1
  fi

  if $PUSH; then
    # Rebuild multi-arch réel pour la publication (le build mono-arch --load
    # ci-dessus n'a servi qu'à la mesure).
    docker buildx build --no-cache --pull --platform "$PLATFORMS" -t "$image" --push "$dir" >/dev/null
    echo "  ✅ poussée (amd64+arm64)"
  fi
done

exit "$failed"
