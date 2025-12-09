# TP15b : Registres privés Docker - Sécurité et authentification - SOLUTIONS

## Exercice 1 : Authentification avec htpasswd

**Questions** :

1. **Que contient le fichier config.json après le login ?**

Le fichier `~/.docker/config.json` contient:
```json
{
  "auths": {
    "localhost:5000": {
      "auth": "YWRtaW46U2VjdXJlUGFzczEyMw=="
    }
  }
}
```

Le champ `auth` est l'encodage Base64 de `username:password`

Décoder:
```bash
echo "YWRtaW46U2VjdXJlUGFzczEyMw==" | base64 -d
# Résultat: admin:SecurePass123
```

2. **Les mots de passe sont-ils stockés en clair dans htpasswd ?**

Non, ils sont hashés avec bcrypt (flag `-B`):
```
admin:$2y$05$hash...
```

Bcrypt est un algorithme de hashage sécurisé avec:
- Salt automatique
- Facteur de coût configurable
- Résistant aux attaques par rainbow tables

3. **Comment révoquer l'accès d'un utilisateur ?**

Méthode 1: Supprimer la ligne du fichier htpasswd
```bash
grep -v "^username:" auth/htpasswd > auth/htpasswd.tmp
mv auth/htpasswd.tmp auth/htpasswd
docker restart registry
```

Méthode 2: Si utilisation de token, révoquer le token côté serveur d'authentification

## Exercice 2 : HTTPS avec certificats auto-signés

### Comprendre la structure du certificat

```bash
# Voir le contenu du certificat
openssl x509 -in certs/domain.crt -text -noout
```

Informations importantes:
- **Subject**: Identité du certificat (CN=localhost)
- **Issuer**: Qui a signé (auto-signé donc Issuer = Subject)
- **Validity**: Dates de validité
- **Subject Alternative Name (SAN)**: Noms DNS/IP alternatifs

### Pourquoi `/etc/docker/certs.d/` ?

Docker cherche les certificats CA dans:
```
/etc/docker/certs.d/
└── <registry-hostname>:<port>/
    └── ca.crt
```

Le nom du fichier **doit** être `ca.crt` pour être reconnu comme Certificate Authority.

### Différence entre certificats auto-signés et CA

| Auto-signé | CA (Let's Encrypt, DigiCert) |
|------------|------------------------------|
| Gratuit | Gratuit (LE) ou payant |
| Créé instantanément | Nécessite validation |
| Pas de confiance par défaut | Confiance navigateurs/OS |
| OK pour développement/interne | Requis pour production publique |

## Exercice 3 : Registre HTTPS sur port 443

### Pourquoi le port 443 ?

- Port HTTPS standard (pas besoin de spécifier le port dans les commandes)
- Facilite la configuration DNS (registry.company.com au lieu de registry.company.com:5000)
- Compatible avec la plupart des firewalls d'entreprise

Avec le port 443:
```bash
# Au lieu de
docker pull localhost:5000/image:tag

# On peut faire
docker pull localhost/image:tag
```

### Nécessite-t-il des privilèges ?

Oui, les ports < 1024 nécessitent des privilèges root.

Solutions:
1. Utiliser `sudo docker run`
2. Donner la capability CAP_NET_BIND_SERVICE au binaire Docker
3. Utiliser un reverse proxy (nginx) qui écoute sur 443 et forward vers 5000

## Exercice 4 : Configuration avancée avec fichier de config

### Headers de sécurité expliqués

```yaml
headers:
  X-Content-Type-Options: [nosniff]      # Empêche le MIME sniffing
  X-Frame-Options: [deny]                 # Empêche l'embedding en iframe
  X-XSS-Protection: [1; mode=block]      # Active la protection XSS
  Strict-Transport-Security: [max-age=31536000]  # Force HTTPS (HSTS)
```

### Configuration de maintenance

```yaml
maintenance:
  uploadpurging:
    enabled: true
    age: 168h        # 7 jours
    interval: 24h    # Vérifier chaque jour
    dryrun: false    # false = vraiment supprimer
```

Ceci nettoie automatiquement les uploads incomplets de plus de 7 jours.

### Mode read-only

Utile pour:
- Migration de registre
- Maintenance planifiée
- Investigation après incident

```yaml
maintenance:
  readonly:
    enabled: true
```

En mode read-only: pull autorisé, push refusé

## Exercice 5 : Authentification avec tokens (Bearer)

### Flux d'authentification Bearer

```
1. Client demande accès au registre
   ↓
2. Registre répond 401 + header WWW-Authenticate pointant vers auth server
   ↓
3. Client contacte auth server avec Basic Auth
   ↓
4. Auth server valide et génère JWT token
   ↓
5. Client présente le token au registre
   ↓
6. Registre valide le token et autorise l'accès
```

### Structure JWT token

```json
{
  "header": {
    "alg": "HS256",
    "typ": "JWT"
  },
  "payload": {
    "sub": "admin",
    "exp": 1234567890,
    "access": [
      {
        "type": "repository",
        "name": "myapp",
        "actions": ["pull", "push"]
      }
    ]
  },
  "signature": "..."
}
```

### Solutions d'authentification en production

| Solution | Cas d'usage |
|----------|-------------|
| **htpasswd** | Petites équipes, simple |
| **LDAP/AD** | Entreprise avec annuaire existant |
| **OAuth2/OIDC** | SSO, intégration Google/GitHub |
| **Keycloak** | Identity provider complet |
| **Dex** | OIDC léger pour Kubernetes |

## Exercice 6 : Docker Compose avec registre sécurisé

### Troubleshooting Registry UI avec HTTPS

Si Registry UI ne peut pas se connecter au registre HTTPS:

**Problème**: Certificat auto-signé non reconnu

**Solution 1**: Configurer Registry UI pour ignorer les certificats
```yaml
environment:
  REGISTRY_INSECURE: "true"
```

**Solution 2**: Monter le certificat CA dans le conteneur UI
```yaml
volumes:
  - ./certs/domain.crt:/etc/ssl/certs/registry-ca.crt:ro
```

## Exercice 7 : Contrôle d'accès par repository

### Modèle RBAC (Role-Based Access Control)

Exemple de matrice d'accès:

| User/Role | dev/* | prod/* | infra/* |
|-----------|-------|--------|---------|
| developer | R+W | R | R |
| devops | R+W | R+W | R+W |
| readonly | R | R | R |
| admin | R+W+D | R+W+D | R+W+D |

Actions:
- **R** (Read): pull
- **W** (Write): push
- **D** (Delete): supprimer images

### Implémentation avec Harbor

Harbor permet de définir des projets avec RBAC:

```
Projet: myapp-dev
  - developer: Developer role (R+W)
  - admin: Admin role (R+W+D)

Projet: myapp-prod
  - developer: Guest role (R)
  - devops: Developer role (R+W)
  - admin: Admin role (R+W+D)
```

## Exercice 8 : Sécurité réseau avec Docker networks

### Isolation réseau - Concepts

**Bridge network par défaut**: Tous les conteneurs peuvent communiquer

**Custom bridge network**: Isolation + DNS automatique

```bash
# Créer réseau isolé
docker network create --driver bridge --subnet 172.25.0.0/16 registry-secure-net

# Conteneurs sur ce réseau peuvent se parler par nom
docker exec app ping registry  # ✓ Fonctionne

# Conteneurs hors réseau ne peuvent pas
docker exec isolated ping registry  # ✗ Échec
```

### Network policies

Pour une sécurité avancée, utiliser:
- **Docker Swarm** avec ingress network et encryption
- **Kubernetes** avec NetworkPolicies
- **Firewall** (iptables, ufw) pour filtrer au niveau OS

## Exercice 9 : Audit et monitoring de sécurité

### Logs à surveiller

**Tentatives d'authentification échouées**:
```bash
docker logs registry 2>&1 | grep "401 Unauthorized"
```

**Suppressions d'images** (potentiellement malveillant):
```bash
docker logs registry 2>&1 | grep "DELETE.*manifests"
```

**Connexions suspectes** (patterns inhabituels):
```bash
docker logs registry 2>&1 | awk '{print $1}' | sort | uniq -c | sort -rn
```

### Alerting - Règles recommandées

1. **Nombre élevé de 401 en peu de temps** → Tentative de brute force
2. **Suppressions d'images en production** → Nécessite investigation
3. **Connexions depuis IPs inconnues** → Vérifier légitimité
4. **Changement des certificats/config** → Audit requis

### Script de monitoring avancé

```bash
#!/bin/bash

# Variables
THRESHOLD_401=10  # Alerte si > 10 erreurs 401 en 5 min

# Compter erreurs 401 récentes
COUNT_401=$(docker logs registry --since 5m 2>&1 | grep -c "401")

if [ $COUNT_401 -gt $THRESHOLD_401 ]; then
    echo "ALERTE: $COUNT_401 tentatives d'auth échouées (seuil: $THRESHOLD_401)"
    # Envoyer notification (email, Slack, PagerDuty)
fi
```

## Exercice 10 : Scénario pratique - Registre d'entreprise

### Architecture complète

```
                    Internet
                       |
                  [Firewall]
                       |
                  [Reverse Proxy] (nginx/Traefik)
                   HTTPS + Auth
                       |
          +------------+------------+
          |                         |
    [Registry 1]            [Registry 2]
          |                         |
          +------------+------------+
                       |
                [Shared Storage]
                  (S3/NFS/Ceph)
```

### Checklist de sécurité

- [ ] HTTPS activé avec certificats valides
- [ ] Authentification obligatoire
- [ ] RBAC configuré par projets/équipes
- [ ] Logs centralisés et surveillés
- [ ] Alerting en place
- [ ] Certificats avec expiration < 90 jours
- [ ] Scanning de vulnérabilités activé
- [ ] Backups réguliers testés
- [ ] Plan d'incident documenté
- [ ] Accès réseau restreint (firewall)

### Rotation des secrets

**Certificats**: Renouveler tous les 90 jours
```bash
# Générer nouveau certificat
openssl req ...

# Mettre à jour
sudo cp new.crt /etc/docker/certs.d/registry/ca.crt

# Redémarrer
docker restart registry

# Vérifier
openssl s_client -connect localhost:5000 < /dev/null 2>&1 | openssl x509 -noout -dates
```

**Mots de passe**: Changer périodiquement
```bash
# Générer nouveau hash
docker run --rm --entrypoint htpasswd registry:2 -Bbn admin NewPass456 > auth/htpasswd.new
mv auth/htpasswd.new auth/htpasswd

# Redémarrer
docker restart registry
```

## Points clés à retenir

1. **Authentification obligatoire en production** (htpasswd minimum, LDAP/OAuth idéal)
2. **HTTPS toujours** (certificats valides pour production publique)
3. **Séparation des secrets** (pas de secrets dans docker-compose.yml, utiliser .env)
4. **Monitoring continu** (logs, métriques, alertes)
5. **Defense in depth** (plusieurs couches: réseau, auth, encryption)
6. **Rotation régulière** (certificats, mots de passe)
7. **Audit trail** (logger toutes les opérations sensibles)

## Dépannage sécurité

### Problème: "x509: certificate signed by unknown authority"

**Cause**: Docker ne fait pas confiance au certificat auto-signé

**Solution**:
```bash
# Copier le CA dans le bon répertoire
sudo mkdir -p /etc/docker/certs.d/registry.local:5000
sudo cp domain.crt /etc/docker/certs.d/registry.local:5000/ca.crt
sudo systemctl restart docker
```

### Problème: "Authentication required" malgré docker login

**Cause**: Credentials expirées ou mauvais registry

**Solution**:
```bash
# Vérifier le fichier config
cat ~/.docker/config.json

# Forcer re-login
docker logout registry.local:5000
docker login registry.local:5000 -u admin
```

### Problème: Harbor ou Portus ne démarre pas

**Causes courantes**:
1. Port déjà utilisé (80/443)
2. Certificats mal configurés
3. Base de données non initialisée

**Solution**:
```bash
# Vérifier les ports
sudo netstat -tlnp | grep -E ":(80|443)"

# Voir les logs
docker-compose logs -f
```

---

**[← Retour au TP](../tp/TP15b-Registres-Prives-Securite.md)**
