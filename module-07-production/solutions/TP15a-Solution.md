# TP15a : Registres privés Docker - Fondamentaux - SOLUTIONS

## Exercice 1 : Déploiement d'un registre basique

**Questions** :

1. **Que signifie le port 5000 ?**
   - Le port 5000 est le port par défaut utilisé par le registre Docker pour exposer son API HTTP
   - Il permet aux clients Docker de communiquer avec le registre pour push/pull d'images

2. **Pourquoi utilise-t-on l'image `registry:2` ?**
   - `registry:2` correspond à la version 2 du registre Docker
   - Cette version implémente l'API Registry v2 qui est l'API standard actuelle
   - Elle supporte des fonctionnalités avancées comme la suppression d'images, les manifests multi-architecture, etc.

3. **Comment vérifier que le registre est accessible ?**
   - Via l'API: `curl http://localhost:5000/v2/` (devrait retourner `{}`)
   - Via Docker: `docker ps | grep registry` (vérifie que le conteneur tourne)
   - Via les logs: `docker logs registry`

## Exercice 2 : Push et Pull d'images

### Observation des logs

Pendant le push, vous devriez voir dans les logs:
```
time="..." level=info msg="response completed" http.request.method=PUT http.request.uri="/v2/my-alpine/manifests/latest"
```

Les logs montrent:
- Les requêtes HTTP (PUT pour push, GET pour pull)
- Les layers uploadés
- Les manifests créés

## Exercice 3 : Gestion de la persistance

**Constat** : Sans volume, les données sont perdues car:
- Par défaut, le registre stocke dans `/var/lib/registry` à l'intérieur du conteneur
- Quand le conteneur est supprimé, son système de fichiers est détruit
- Les images pushées sont donc perdues

**Questions** :

1. **Quelle est la différence entre volume et bind mount ?**
   - **Volume Docker**: Géré par Docker, stocké dans `/var/lib/docker/volumes/`, isolation complète
   - **Bind mount**: Monte un répertoire hôte directement, accès direct au filesystem hôte

2. **Quand utiliser l'un ou l'autre ?**
   - **Volume**: Production, portabilité, facilite les backups Docker
   - **Bind mount**: Développement, besoin d'accéder directement aux fichiers depuis l'hôte

3. **Où sont stockés les layers des images ?**
   - Dans `/var/lib/registry/docker/registry/v2/`
   - Structure:
     - `blobs/sha256/`: Les layers et configurations (blobs)
     - `repositories/`: Métadonnées des repositories et tags

## Exercice 4 : Configuration du registre

Les deux méthodes de configuration sont équivalentes:
- **Fichier config.yml**: Plus flexible, meilleur pour configuration complexe
- **Variables d'environnement**: Plus simple, idéal pour Docker Compose et conteneurs

Variables d'environnement importantes:
- `REGISTRY_STORAGE_DELETE_ENABLED`: Permet la suppression d'images
- `REGISTRY_LOG_LEVEL`: Niveau de verbosité des logs (error, warn, info, debug)
- `REGISTRY_HTTP_TLS_CERTIFICATE`: Certificat SSL pour HTTPS

## Exercice 5 : Gestion des images dans le registre

### API du registre - Endpoints principaux

```bash
# Catalogue des repositories
GET /v2/_catalog

# Tags d'un repository
GET /v2/<name>/tags/list

# Manifest d'une image (métadonnées)
GET /v2/<name>/manifests/<reference>

# Supprimer une image (avec digest)
DELETE /v2/<name>/manifests/<digest>
```

Le **digest** est un hash SHA256 unique qui identifie une image de manière immuable, contrairement aux tags qui peuvent changer.

## Exercice 6 : Scénario pratique

Le workflow complet démontre:
1. **Build local** → Image construite
2. **Tag** → Préparation pour le registre
3. **Push** → Upload vers le registre privé
4. **Pull** → Déploiement depuis le registre
5. **Versioning** → Gestion de multiples versions
6. **Rollback** → Retour à version précédente

**Best practice**: Toujours utiliser des tags explicites en production (pas seulement `latest`)

## Exercice 7 : Monitoring et diagnostics

### Health checks

Le registre est en bonne santé si:
- API répond sur `/v2/` avec `{}`
- Les logs ne montrent pas d'erreurs
- Le storage backend est accessible

### Analyse logs

```bash
# Voir les erreurs
docker logs registry 2>&1 | grep -i error

# Voir les push/pull
docker logs registry 2>&1 | grep -E "PUT|GET"

# Statistiques
docker logs registry 2>&1 | grep -c "PUT"  # Nombre de push
```

## Exercice 8 : Bonnes pratiques

### Stratégie de naming recommandée

```
registry.company.com/project/service:version-variant
```

Exemples:
- `localhost:5000/mycompany/webapp:1.2.3-alpine`
- `localhost:5000/project-x/api:2.0.0-prod`
- `localhost:5000/infrastructure/nginx:1.25-alpine`

### Versioning sémantique

```
MAJOR.MINOR.PATCH

MAJOR: Changements incompatibles
MINOR: Nouvelles fonctionnalités compatibles
PATCH: Corrections de bugs
```

### Backup - Méthodes

**Méthode 1** (Volume backup):
- ✓ Rapide
- ✓ Complet (métadonnées incluses)
- ✗ Nécessite accès au host

**Méthode 2** (Export images):
- ✓ Portable
- ✓ Peut être fait à distance
- ✗ Plus lent
- ✗ Plus volumineux

## Points clés à retenir

1. **Persistance obligatoire** : Toujours utiliser un volume en production
2. **API REST** : Le registre expose une API complète pour la gestion
3. **Pas de GUI par défaut** : Utiliser des outils externes (Registry UI, Harbor)
4. **Suppression en 2 étapes** : Soft delete (API) puis garbage collection
5. **Tags vs Digests** : Tags mutables, digests immuables
6. **Configuration flexible** : Fichier ou variables d'environnement

## Commandes essentielles mémorisées

```bash
# Lancer registre avec volume
docker run -d -p 5000:5000 -v registry-data:/var/lib/registry registry:2

# Tag et push
docker tag image:tag localhost:5000/image:tag
docker push localhost:5000/image:tag

# Lister images
curl http://localhost:5000/v2/_catalog

# Voir tags
curl http://localhost:5000/v2/<image>/tags/list

# Backup volume
docker run --rm -v registry-data:/data -v ~/backup:/backup alpine tar czf /backup/registry.tar.gz /data
```

## Dépannage courant

### Problème: "connection refused" lors du push

**Solution**:
```bash
# Vérifier que le registre tourne
docker ps | grep registry

# Vérifier les logs
docker logs registry

# Tester l'API
curl http://localhost:5000/v2/
```

### Problème: "server gave HTTP response to HTTPS client"

**Solution**:
Ajouter le registre comme insecure (développement seulement):

```bash
# /etc/docker/daemon.json
{
  "insecure-registries": ["localhost:5000"]
}

# Redémarrer Docker
sudo systemctl restart docker
```

### Problème: Espace disque plein

**Solution**:
```bash
# Voir l'espace utilisé
docker system df

# Nettoyer les images inutilisées
docker image prune -a

# Garbage collection du registre
docker exec registry bin/registry garbage-collect /etc/docker/registry/config.yml
```

---

**[← Retour au TP](../tp/TP15a-Registres-Prives-Fondamentaux.md)**
