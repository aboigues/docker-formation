# Solutions - TP13 : Portainer et interfaces

## Configuration Grafana - Dashboards recommandés

### Docker Dashboard (ID: 193)
```
Dashboard > Import > 193
```
Métriques:
- CPU usage par conteneur
- Memory usage par conteneur
- Network I/O
- Disk I/O

### Node Exporter (ID: 1860)
Métriques système de l'hôte.

### cAdvisor Dashboard (ID: 14282)
Métriques détaillées des conteneurs.

## Portainer - Cas d'usage

**1. Déploiement rapide**:
- Stacks > Add stack > Upload docker-compose.yml
- Environment variables via UI
- Deploy avec un clic

**2. Gestion d'images**:
- Images > Pull : Télécharger nouvelles images
- Images > Build : Builder depuis Dockerfile via UI
- Images > Push : Push vers registry privé

**3. Monitoring en temps réel**:
- Container stats en direct
- Resource usage graphs
- Quick actions (stop, restart, kill)

## Prometheus Queries utiles

```promql
# CPU usage par conteneur
rate(container_cpu_usage_seconds_total[1m])

# Memory usage par conteneur
container_memory_usage_bytes

# Network RX/TX
rate(container_network_receive_bytes_total[1m])
rate(container_network_transmit_bytes_total[1m])

# Disk I/O
rate(container_fs_reads_bytes_total[1m])
rate(container_fs_writes_bytes_total[1m])

# Conteneurs actifs
count(container_last_seen{name!=""})
```

## Best Practices

1. **Sécurité**:
   - Utiliser HTTPS pour Portainer
   - Créer des utilisateurs avec rôles limités
   - Ne jamais exposer Prometheus/Grafana sans authentification

2. **Performance**:
   - Limiter la rétention Prometheus (15 jours max)
   - Utiliser des dashboards optimisés
   - Pas trop de métriques en temps réel

3. **Organisation**:
   - Nommer les dashboards clairement
   - Utiliser des tags dans Grafana
   - Créer des dossiers par projet

**[← Retour au TP](../tp/TP13-Portainer-Interfaces.md)**
