# TP15c : Registres privés Docker - Production et haute disponibilité - SOLUTIONS

## Exercice 1 : Storage backend - S3

### Pourquoi S3 pour le storage ?

**Avantages**:
- ✓ **Scalabilité illimitée** : Pas de limite de stockage
- ✓ **Haute disponibilité** : Réplication automatique entre zones
- ✓ **Performance** : Parallélisation des uploads/downloads
- ✓ **Coût** : Pay-as-you-go, pas de sur-provisionnement
- ✓ **Backup intégré** : Versioning, lifecycle policies
- ✓ **Compatibilité** : AWS S3, MinIO, GCS, Azure Blob

**Comparaison storage**:

| Type | HA | Scalabilité | Complexité | Coût |
|------|-----|-------------|------------|------|
| Local | ✗ | Limitée | Faible | Faible |
| NFS | ~~ | Moyenne | Moyenne | Moyen |
| S3 | ✓✓ | Illimitée | Faible | Variable |
| Ceph | ✓✓ | Haute | Élevée | Élevé |

### Configuration S3 - Paramètres importants

```yaml
storage:
  s3:
    # Taille des chunks pour upload multipart
    chunksize: 5242880  # 5 MB

    # Seuil pour utiliser multipart copy
    multipartcopythresholdsize: 33554432  # 32 MB

    # Concurrence pour multipart copy
    multipartcopymaxconcurrency: 100

    # Encryption at rest
    encrypt: true
    keyid: aws-kms-key-id

    # Storage class (optimisation coût)
    storageclass: STANDARD  # ou STANDARD_IA, GLACIER
```

### MinIO vs AWS S3

| Feature | MinIO | AWS S3 |
|---------|-------|--------|
| **Hébergement** | Self-hosted | Cloud managed |
| **API** | Compatible S3 | Native |
| **Coût** | Gratuit (infra) | Pay per use |
| **Latence** | Très faible (local) | Dépend région |
| **Maintenance** | À gérer | Aucune |
| **Use case** | On-premise, dev | Production cloud |

## Exercice 2 : Load Balancing avec nginx

### Algorithmes de load balancing

**Least connections** (utilisé dans l'exercice):
```nginx
upstream docker-registry {
    least_conn;  # Routage vers le serveur avec le moins de connexions actives
    server registry-1:5000;
    server registry-2:5000;
}
```

**Autres algorithmes**:

1. **Round-robin** (par défaut):
```nginx
upstream docker-registry {
    server registry-1:5000;
    server registry-2:5000;
}
```
Distribution égale, rotation circulaire

2. **IP Hash** (sticky sessions):
```nginx
upstream docker-registry {
    ip_hash;
    server registry-1:5000;
    server registry-2:5000;
}
```
Même client → toujours même serveur

3. **Weighted**:
```nginx
upstream docker-registry {
    server registry-1:5000 weight=3;
    server registry-2:5000 weight=1;
}
```
75% du trafic → registry-1, 25% → registry-2

### Health checks et failover

```nginx
upstream docker-registry {
    server registry-1:5000 max_fails=3 fail_timeout=30s;
    server registry-2:5000 max_fails=3 fail_timeout=30s;
}
```

- **max_fails=3**: Après 3 échecs consécutifs, marquer le serveur comme down
- **fail_timeout=30s**: Attendre 30s avant de réessayer un serveur down

### Configuration optimale pour Docker Registry

```nginx
location / {
    # Pas de limite de taille (images volumineuses)
    client_max_body_size 0;

    # Éviter HTTP 411
    chunked_transfer_encoding on;

    # Timeouts longs (layers volumineux)
    proxy_read_timeout 900;
    proxy_send_timeout 900;

    # Buffering désactivé (streaming)
    proxy_buffering off;
    proxy_request_buffering off;
}
```

## Exercice 3 : Monitoring avec Prometheus et Grafana

### Métriques clés à surveiller

**Registry**:
- `registry_http_requests_total`: Nombre total de requêtes
- `registry_http_request_duration_seconds`: Latence
- `registry_storage_cache_total`: Hits/misses cache
- `go_memstats_alloc_bytes`: Utilisation mémoire

**Redis** (cache):
- `redis_connected_clients`: Nombre de clients connectés
- `redis_memory_used_bytes`: Mémoire utilisée
- `redis_keyspace_hits_total`: Efficacité du cache
- `redis_keyspace_misses_total`: Cache misses

**Nginx**:
- `nginx_http_requests_total`: Requêtes totales
- `nginx_http_request_duration_seconds`: Latence
- `nginx_up`: Status up/down

**MinIO/S3**:
- `minio_s3_requests_total`: Requêtes S3
- `minio_disk_storage_used_bytes`: Stockage utilisé
- `minio_s3_time_to_first_byte_seconds`: Performance

### Queries PromQL utiles

```promql
# Taux de requêtes par seconde
rate(registry_http_requests_total[5m])

# Latence P95
histogram_quantile(0.95, rate(registry_http_request_duration_seconds_bucket[5m]))

# Taux d'erreur
rate(registry_http_requests_total{code=~"5.."}[5m]) / rate(registry_http_requests_total[5m])

# Efficacité cache Redis
redis_keyspace_hits_total / (redis_keyspace_hits_total + redis_keyspace_misses_total)

# Distribution de charge entre registres
sum by (instance) (rate(registry_http_requests_total[5m]))
```

### Dashboard Grafana - Panels recommandés

1. **Request Rate**: Graph des requêtes/s par instance
2. **Error Rate**: Pourcentage d'erreurs 5xx
3. **Latency Distribution**: Heatmap P50/P95/P99
4. **Storage Usage**: Gauge de l'espace utilisé
5. **Cache Hit Rate**: Gauge du taux de hit Redis
6. **Active Instances**: Stat du nombre d'instances up
7. **Top Images**: Table des images les plus pullées

## Exercice 4 : Garbage Collection automatique

### Comprendre le GC

**Phase 1 - Mark**:
- Parcourt tous les manifests référencés
- Marque les blobs (layers) utilisés

**Phase 2 - Sweep**:
- Identifie les blobs non marqués
- Supprime les blobs orphelins du storage

**Impact**:
- Le registre doit être en **read-only** pendant le GC
- Durée: Dépend du nombre d'images (quelques minutes à heures)

### Stratégies de GC

**Option 1: GC avec downtime** (simple):
```bash
# Arrêter registre
docker stop registry

# Exécuter GC
docker run --rm -v registry-data:/var/lib/registry registry:2 \
  bin/registry garbage-collect /etc/docker/registry/config.yml

# Redémarrer
docker start registry
```

**Option 2: GC avec read-only** (pas de downtime):
```bash
# Passer en read-only
docker exec registry kill -USR1 1

# Exécuter GC
docker exec registry bin/registry garbage-collect /etc/docker/registry/config.yml

# Redémarrer pour sortir du read-only
docker restart registry
```

**Option 3: GC online avec réplicas** (haute disponibilité):
```bash
# 1. Retirer registry-1 du load balancer
# 2. GC sur registry-1
# 3. Remettre registry-1
# 4. Répéter pour registry-2
```

### Fréquence recommandée

| Taux d'activité | Fréquence GC |
|-----------------|--------------|
| Faible (< 10 push/jour) | 1x/mois |
| Moyen (10-100 push/jour) | 1x/semaine |
| Élevé (> 100 push/jour) | 1x/jour |

### Estimation espace libéré

Dépend de:
- Nombre d'images supprimées
- Partage de layers entre images (ex: images basées sur alpine partagent les layers alpine)
- Politique de rétention

Exemple:
- 100 images supprimées
- Moyenne 50 MB par image
- 30% de layers partagés
- **Espace libéré ≈ 3.5 GB**

## Exercice 5 : Backup et Disaster Recovery

### Stratégies de backup

**Backup complet** (recommandé):
```bash
# 1. Storage S3/MinIO (images)
mc mirror source-bucket backup-bucket

# 2. Configuration
tar czf config-backup.tar.gz config/ nginx/ prometheus/

# 3. Métadonnées (optionnel)
# Base de données si utilisation de Harbor/Portus
```

**Backup incrémental**:
```bash
# Utiliser versioning S3
aws s3api put-bucket-versioning --bucket registry-storage --versioning-configuration Status=Enabled

# Lifecycle policy pour archiver anciennes versions
```

### RTO et RPO

**RTO (Recovery Time Objective)**: Temps max pour restaurer le service

**RPO (Recovery Point Objective)**: Perte de données max acceptable

| Criticité | RTO | RPO | Stratégie |
|-----------|-----|-----|-----------|
| Critique | < 1h | < 15 min | Réplication continue + HA |
| Important | < 4h | < 1h | Backup horaire |
| Normal | < 24h | < 24h | Backup quotidien |

### Test de DR (Disaster Recovery)

**Checklist test DR**:
1. [ ] Simuler perte totale du registre (arrêter tous les services)
2. [ ] Restaurer depuis backup
3. [ ] Vérifier intégrité des images (pull + run)
4. [ ] Mesurer le temps de restauration
5. [ ] Documenter les problèmes rencontrés
6. [ ] Mettre à jour la procédure

**Fréquence**: 1x/trimestre minimum

### Backup vers cloud

**AWS S3**:
```bash
aws s3 sync /local/backup/ s3://my-registry-backups/ --storage-class GLACIER
```

**Azure Blob**:
```bash
az storage blob upload-batch --destination backups --source /local/backup/
```

**GCS**:
```bash
gsutil -m rsync -r /local/backup/ gs://my-registry-backups/
```

## Exercice 6 : Réplication entre registres

### Use cases réplication

1. **Disaster Recovery**: Site primaire + site secondaire
2. **Geo-distribution**: Réduire latence pour équipes distribuées
3. **Air-gapped environments**: Sync vers environnements isolés
4. **Staging → Production**: Promouvoir images testées

### Types de réplication

**Push-based** (Harbor):
```
Registry A (push event) → Webhook → Registry B (pull from A)
```

**Pull-based** (Mirroring):
```
Registry B périodiquement pull depuis Registry A
```

**Bidirectional** (Conflict resolution requis):
```
Registry A ⇄ Registry B
```

### Réplication MinIO

```bash
# Setup réplication
mc replicate add primary/registry-storage \
  --remote-bucket registry-storage \
  --remote-target dr-site \
  --priority 1 \
  --replicate existing-objects \
  --bandwidth "100MB"

# Status réplication
mc replicate status primary/registry-storage

# Metrics
mc replicate stats primary/registry-storage
```

### Réplication avec Harbor

Harbor offre une réplication avancée:
- **Filtres**: Par projet, repository, tag (ex: replicate only prod-*)
- **Triggers**: Manuel, scheduled, event-based
- **Registries externes**: Docker Hub, Quay.io, AWS ECR, GCR
- **Bandwidth control**: Throttling

## Exercice 7 : Optimisation des performances

### Cache Redis - Sizing

**Formule estimation**:
```
Cache Size = (Avg manifest size) × (Nb images) × (Cache factor)

Exemple:
- 1000 images
- Manifest moyen: 10 KB
- Cache factor: 2x (metadata + overhead)
Cache Size = 10 KB × 1000 × 2 = 20 MB

→ Allouer 256 MB pour marge
```

**Politique d'éviction** (maxmemory-policy):
- `allkeys-lru`: Éviction LRU sur toutes les clés (recommandé)
- `volatile-lru`: LRU seulement sur clés avec expiration
- `allkeys-lfu`: LRU Frequency-based (Redis 4.0+)

### Optimisations storage S3

**Multipart upload**:
```yaml
chunksize: 5242880  # 5 MB chunks
```
- Layers > 5 MB uploadés en parallèle
- Performance upload +50% à +200%

**Connection pooling**:
```yaml
pool:
  maxactive: 64
  maxidle: 16
```
- Réutilisation connexions S3
- Réduction latence

### CDN pour accélérer pulls

```
Client → CDN (CloudFront/Cloudflare) → Registry → S3
```

Configuration:
```yaml
middleware:
  - name: cloudfront
    options:
      baseurl: https://d1234.cloudfront.net
      privatekey: /path/to/private-key.pem
      keypairid: KEYPAIRID
```

Bénéfices:
- Cache géographique
- Réduction bande passante registry
- Pull 3-10x plus rapide

### Benchmarking résultats attendus

**Sans optimisation**:
- Push 100 MB image: ~30s
- Pull 100 MB image: ~15s
- API latency: 50-100ms

**Avec optimisations** (Redis + S3 + CDN):
- Push 100 MB image: ~10s (-66%)
- Pull 100 MB image: ~3s (-80%)
- API latency: 10-20ms (-70%)

## Exercice 8 : Sécurité avancée - Vulnerability Scanning

### Trivy - Niveaux de sévérité

```
CRITICAL: Exploitation active, fix disponible
HIGH:     Exploitation probable
MEDIUM:   Exploitation difficile
LOW:      Impact mineur
UNKNOWN:  Pas assez d'info
```

**Politique de gating**:
```bash
# Bloquer push si CRITICAL/HIGH
trivy image --severity HIGH,CRITICAL --exit-code 1 myimage:tag
```

### Scanning automatique

**Webhook flow**:
```
1. Image pushed → Registry
2. Registry → Webhook notification
3. Webhook service → Trigger scan (Trivy)
4. Scan results → Database
5. Alert si vulnérabilités → Slack/Email
```

**Scanning périodique** (cron):
```bash
# Rescanner toutes les images chaque semaine
# (nouvelles CVE découvertes)
0 2 * * 0 /usr/local/bin/scan-all-images.sh
```

### Intégration CI/CD

**GitLab CI**:
```yaml
scan:
  stage: test
  image: aquasec/trivy:latest
  script:
    - trivy image --severity HIGH,CRITICAL myimage:$CI_COMMIT_SHA
  allow_failure: false
```

**GitHub Actions**:
```yaml
- name: Run Trivy scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: 'myimage:${{ github.sha }}'
    severity: 'CRITICAL,HIGH'
    exit-code: '1'
```

### Alternatives à Trivy

| Tool | Avantages | Inconvénients |
|------|-----------|---------------|
| **Trivy** | Rapide, facile, gratuit | Moins de détails |
| **Clair** | Complet, API | Complexe setup |
| **Anchore** | Policies, SBOM | Resource-intensive |
| **Snyk** | Dev-friendly | Commercial |
| **Grype** | Fast, accurate | Récent |

## Exercice 9 : Stack complète de production

### Architecture finale

```
┌─────────────────────────────────────────────────┐
│                  Internet                        │
└─────────────────┬───────────────────────────────┘
                  │
            [Firewall/WAF]
                  │
              [nginx LB] ←─ [Prometheus] ──→ [Grafana]
                  │              ↑
         ┌────────┼────────┐     │
         ↓        ↓        ↓     │
    [Registry1] [Registry2] [Registry3]
         │        │        │
         └────────┼────────┘
                  │
              [Redis Cache]
                  │
            [MinIO/S3 Storage]
                  │
            [Backup System]
```

### High Availability - Points clés

**Single Point of Failure (SPOF)** à éliminer:

1. **Registry**: ✓ Multiple instances + LB
2. **Storage**: ✓ S3 (replicated)
3. **Redis**: ~ Single instance OK (cache, non-critical)
4. **Load Balancer**: ✗ SPOF → Solution: keepalived/HAProxy HA
5. **Network**: Depends on infrastructure

**Availability calculation**:

```
Component availability:
- Registry instance: 99.9%
- S3 storage: 99.99%
- Load balancer: 99.9%
- Redis: 99.5%

With 2 registry instances (active-active):
Registry availability = 1 - (0.001)² = 99.9999% (5 nines)

Overall system: 99.9% × 99.99% × 99.5% ≈ 99.4%
```

### Scalabilité horizontale

**Scaling registres**:
```bash
# Ajouter registry-3
docker-compose up -d --scale registry=3

# Mettre à jour nginx upstream
upstream docker-registry {
    server registry-1:5000;
    server registry-2:5000;
    server registry-3:5000;
}
```

**Quand scaler ?**
- CPU > 70% sustained
- Latency P95 > 500ms
- Requests rate > 1000 req/s per instance

### Production checklist complète

**Infrastructure**:
- [ ] Min 2 registry instances (3 pour 99.99%)
- [ ] Load balancer avec health checks
- [ ] Shared storage (S3/NFS) avec backup
- [ ] Monitoring stack (Prometheus + Grafana)
- [ ] Logging centralisé (ELK/Loki)
- [ ] Alerting configuré (PagerDuty/OpsGenie)

**Sécurité**:
- [ ] HTTPS avec certificats valides
- [ ] Authentification (LDAP/OAuth2)
- [ ] RBAC par projets
- [ ] Scanning vulnérabilités
- [ ] Network isolation
- [ ] Audit logging

**Opérations**:
- [ ] Backup automatique (daily)
- [ ] DR plan testé (quarterly)
- [ ] GC automatique (weekly)
- [ ] Rotation certificats (90 days)
- [ ] Runbooks documentés
- [ ] On-call rotation

**Performance**:
- [ ] Redis cache
- [ ] CDN (si global)
- [ ] Compression
- [ ] Connection pooling

## Points clés à retenir

1. **HA = No SPOF**: Éliminer tous les points de défaillance uniques
2. **Storage partagé obligatoire**: S3/NFS pour multi-instances
3. **Monitoring ≠ optionnel**: Visibilité critique en production
4. **Automation**: Backup, GC, scaling doivent être automatisés
5. **Security in depth**: Multiple layers (network, auth, encryption)
6. **DR plan testé**: Un plan non testé = pas de plan
7. **Documentation vivante**: Runbooks à jour = incident résolu 3x plus vite

## Troubleshooting production

### Problème: Latence élevée

**Diagnostics**:
```bash
# Vérifier latence Redis
redis-cli --latency -h redis

# Vérifier latence S3
time mc ls minio/registry-storage | head -1

# Vérifier load balancing
for i in {1..100}; do curl -s http://lb:5000/v2/ -w "%{remote_ip}\n" -o /dev/null; done | sort | uniq -c
```

**Solutions**:
- Scaler Redis si hit rate < 80%
- Augmenter chunksize S3
- Ajouter registres si CPU > 70%
- Activer CDN

### Problème: Split-brain (réplication)

**Symptômes**:
- Différentes images dans registry-1 vs registry-2
- Inconsistencies lors des pulls

**Cause**: Storage non partagé ou corruption

**Solution**:
```bash
# 1. Identifier la source de vérité
curl http://registry-1:5000/v2/_catalog > r1.json
curl http://registry-2:5000/v2/_catalog > r2.json
diff r1.json r2.json

# 2. Resynchroniser depuis storage
docker restart registry-1 registry-2

# 3. Si persistent, restaurer depuis backup
```

### Problème: Out of disk space

**Immédiat**:
```bash
# GC urgent
docker exec registry bin/registry garbage-collect --delete-untagged /etc/docker/registry/config.yml

# Supprimer vieilles images
# (Attention: avoir backup avant!)
```

**Long terme**:
- Implémenter retention policy
- Migrer vers S3 (illimité)
- Alerting sur disk usage > 70%

---

**[← Retour au TP](../tp/TP15c-Registres-Prives-Production.md)**
