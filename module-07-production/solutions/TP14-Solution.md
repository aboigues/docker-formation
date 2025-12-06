# Solutions - TP14 : Production best practices

## Healthcheck - Patterns recommandés

### API REST
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1
```

### Base de données
```dockerfile
# PostgreSQL
HEALTHCHECK CMD pg_isready -U postgres -d myapp || exit 1

# MySQL
HEALTHCHECK CMD mysqladmin ping -h localhost || exit 1

# MongoDB
HEALTHCHECK CMD echo 'db.runCommand("ping").ok' | mongosh --quiet || exit 1
```

## Logging - Bonnes pratiques

1. **Format JSON** pour les logs
2. **Stdout/Stderr** seulement (pas de fichiers)
3. **Log rotation** configurée
4. **Niveaux de log** appropriés (ERROR, WARN, INFO, DEBUG)
5. **Correlation IDs** pour tracer les requêtes

## Sécurité - Top 10

1. Utiliser utilisateur non-root
2. Scanner les vulnérabilités
3. Multi-stage builds
4. Pas de secrets dans les images
5. Read-only filesystem
6. Drop all capabilities
7. Resource limits
8. Network isolation
9. Mises à jour régulières
10. Monitoring actif

## Resource Limits - Recommandations

### Production API
```yaml
resources:
  limits:
    cpus: '1.0'
    memory: 1G
  reservations:
    cpus: '0.5'
    memory: 512M
```

### Database
```yaml
resources:
  limits:
    cpus: '2.0'
    memory: 4G
  reservations:
    cpus: '1.0'
    memory: 2G
```

**[← Retour au TP](../tp/TP14-Production-Best-Practices.md)**
