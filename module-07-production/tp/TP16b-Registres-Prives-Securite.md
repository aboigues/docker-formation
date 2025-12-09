# TP16b : Registres privés Docker - Sécurité et authentification

## Objectif

Sécuriser un registre Docker privé avec authentification, HTTPS/TLS, et implémenter des contrôles d'accès.

## Durée estimée

90 minutes

## Prérequis

- TP16a complété (registres privés fondamentaux)
- Compréhension des certificats SSL/TLS
- Accès à un terminal avec droits sudo
- Docker et OpenSSL installés

## Concepts clés

```
┌────────────────────────────────────────────────────────────┐
│       Architecture d'un registre sécurisé                   │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  Client Docker (authentifié)                                │
│  ┌──────────────┐                                          │
│  │ docker login │                                          │
│  │ + TLS cert   │                                          │
│  └──────┬───────┘                                          │
│         │ HTTPS (port 443)                                 │
│         │ + Basic Auth / Token                             │
│         ▼                                                   │
│  ┌────────────────────────────┐                            │
│  │  Registry avec TLS         │                            │
│  │  + htpasswd auth           │                            │
│  └─────────┬──────────────────┘                            │
│            │                                                │
│            ▼                                                │
│  ┌─────────────────┐    ┌──────────────┐                  │
│  │  Storage        │    │  Auth users  │                  │
│  │  /var/lib/      │    │  htpasswd    │                  │
│  │  registry/      │    │  file        │                  │
│  └─────────────────┘    └──────────────┘                  │
│                                                             │
│  Niveaux de sécurité :                                     │
│  1. Authentification (htpasswd, token, LDAP)               │
│  2. TLS/HTTPS (certificats)                                │
│  3. Contrôle d'accès (read/write permissions)              │
│  4. Network isolation                                       │
│  5. Scanning de vulnérabilités                             │
│                                                             │
└────────────────────────────────────────────────────────────┘
```

---

## Exercice 1 : Authentification avec htpasswd

### 1.1 - Créer le fichier htpasswd

```bash
# Nettoyer l'environnement
docker rm -f registry 2>/dev/null || true

# Créer les répertoires nécessaires
mkdir -p ~/docker-registry-secure/{auth,certs,config}
cd ~/docker-registry-secure

# Méthode 1 : Utiliser l'image registry avec htpasswd
docker run --rm --entrypoint htpasswd \
  registry:2 -Bbn admin SecurePass123 > auth/htpasswd

# Ajouter plus d'utilisateurs
docker run --rm --entrypoint htpasswd \
  registry:2 -Bbn developer DevPass456 >> auth/htpasswd

docker run --rm --entrypoint htpasswd \
  registry:2 -Bbn readonly ReadPass789 >> auth/htpasswd

# Voir le fichier créé
cat auth/htpasswd
```

**Notes** :
- `-B` : utilise bcrypt (sécurisé)
- `-b` : batch mode (mot de passe en ligne de commande)
- `-n` : affiche le résultat sur stdout

### 1.2 - Lancer le registre avec authentification

```bash
# Lancer le registre avec auth
docker run -d \
  --name registry \
  -p 5000:5000 \
  -v $(pwd)/auth:/auth \
  -v registry-data:/var/lib/registry \
  -e REGISTRY_AUTH=htpasswd \
  -e REGISTRY_AUTH_HTPASSWD_REALM="Registry Realm" \
  -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
  -e REGISTRY_STORAGE_DELETE_ENABLED=true \
  registry:2

# Vérifier les logs
docker logs registry
```

### 1.3 - Tester l'authentification

```bash
# Tenter d'accéder sans authentification (devrait échouer)
curl http://localhost:5000/v2/

# Résultat : erreur 401 Unauthorized

# Tenter de push sans login (devrait échouer)
docker pull alpine:latest
docker tag alpine:latest localhost:5000/alpine:test
docker push localhost:5000/alpine:test

# Se connecter avec les credentials
docker login localhost:5000 -u admin -p SecurePass123

# Vérifier que le login est enregistré
cat ~/.docker/config.json

# Maintenant le push devrait fonctionner
docker push localhost:5000/alpine:test

# Vérifier
curl -u admin:SecurePass123 http://localhost:5000/v2/_catalog
```

### 1.4 - Gestion des utilisateurs

```bash
# Voir les utilisateurs actuels
echo "Utilisateurs dans le registre :"
cat auth/htpasswd | cut -d: -f1

# Ajouter un nouvel utilisateur
docker run --rm --entrypoint htpasswd \
  registry:2 -Bbn testuser TestPass999 >> auth/htpasswd

# Supprimer un utilisateur (éditer le fichier)
grep -v "^readonly:" auth/htpasswd > auth/htpasswd.tmp
mv auth/htpasswd.tmp auth/htpasswd

# Recharger le registre pour prendre en compte les changements
docker restart registry

# Tester le nouvel utilisateur
docker logout localhost:5000
docker login localhost:5000 -u testuser -p TestPass999
docker push localhost:5000/alpine:test
```

**Questions** :
1. Que contient le fichier config.json après le login ?
2. Les mots de passe sont-ils stockés en clair dans htpasswd ?
3. Comment révoquer l'accès d'un utilisateur ?

---

## Exercice 2 : HTTPS avec certificats auto-signés

### 2.1 - Générer un certificat auto-signé

```bash
cd ~/docker-registry-secure

# Générer une clé privée et un certificat
openssl req -newkey rsa:4096 \
  -nodes -sha256 \
  -keyout certs/domain.key \
  -x509 -days 365 \
  -out certs/domain.crt \
  -subj "/C=FR/ST=IDF/L=Paris/O=MyCompany/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,DNS:registry.local,IP:127.0.0.1"

# Vérifier le certificat
openssl x509 -in certs/domain.crt -text -noout | grep -A1 "Subject:"
openssl x509 -in certs/domain.crt -text -noout | grep -A1 "Subject Alternative Name"

# Voir la date d'expiration
openssl x509 -in certs/domain.crt -noout -dates

# Permissions
chmod 600 certs/domain.key
chmod 644 certs/domain.crt
ls -l certs/
```

### 2.2 - Configurer Docker pour accepter le certificat

```bash
# Créer le répertoire de certificats Docker
sudo mkdir -p /etc/docker/certs.d/localhost:5000

# Copier le certificat
sudo cp certs/domain.crt /etc/docker/certs.d/localhost:5000/ca.crt

# Vérifier
sudo ls -la /etc/docker/certs.d/localhost:5000/
```

### 2.3 - Lancer le registre avec HTTPS

```bash
# Arrêter l'ancien registre
docker rm -f registry

# Lancer avec HTTPS et auth
docker run -d \
  --name registry \
  -p 5000:5000 \
  -v $(pwd)/auth:/auth \
  -v $(pwd)/certs:/certs \
  -v registry-data:/var/lib/registry \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
  -e REGISTRY_AUTH=htpasswd \
  -e REGISTRY_AUTH_HTPASSWD_REALM="Registry Realm" \
  -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
  registry:2

# Vérifier les logs
docker logs registry

# Tester la connexion HTTPS
curl -u admin:SecurePass123 https://localhost:5000/v2/_catalog --cacert certs/domain.crt
```

### 2.4 - Utiliser le registre HTTPS

```bash
# Se déconnecter de l'ancien
docker logout localhost:5000

# Se connecter via HTTPS
docker login localhost:5000 -u admin -p SecurePass123

# Tester push/pull
docker tag nginx:alpine localhost:5000/nginx:secure
docker push localhost:5000/nginx:secure

# Vérifier
curl -u admin:SecurePass123 https://localhost:5000/v2/_catalog --cacert certs/domain.crt
```

---

## Exercice 3 : Registre HTTPS sur port standard (443)

### 3.1 - Configuration avec le port 443

```bash
# Arrêter le registre actuel
docker rm -f registry

# Lancer sur le port 443 (nécessite sudo ou capacités)
docker run -d \
  --name registry \
  -p 443:5000 \
  -v $(pwd)/auth:/auth \
  -v $(pwd)/certs:/certs \
  -v registry-data:/var/lib/registry \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
  -e REGISTRY_AUTH=htpasswd \
  -e REGISTRY_AUTH_HTPASSWD_REALM="Registry Realm" \
  -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
  registry:2

# Copier le certificat pour le nouveau port
sudo mkdir -p /etc/docker/certs.d/localhost
sudo cp certs/domain.crt /etc/docker/certs.d/localhost/ca.crt

# Tester
docker logout localhost
docker login localhost -u admin -p SecurePass123

docker tag redis:alpine localhost/redis:secure
docker push localhost/redis:secure

# Vérifier
curl -u admin:SecurePass123 https://localhost/v2/_catalog --cacert certs/domain.crt
```

---

## Exercice 4 : Configuration avancée avec fichier de config

### 4.1 - Fichier de configuration complet

```bash
cd ~/docker-registry-secure

cat > config/config.yml << 'EOF'
version: 0.1

log:
  level: info
  formatter: json
  fields:
    service: registry
    environment: production

storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
  delete:
    enabled: true
  maintenance:
    uploadpurging:
      enabled: true
      age: 168h
      interval: 24h
      dryrun: false

http:
  addr: :5000
  host: https://localhost:5000
  headers:
    X-Content-Type-Options: [nosniff]
    X-Frame-Options: [deny]
    X-XSS-Protection: [1; mode=block]
  http2:
    disabled: false
  tls:
    certificate: /certs/domain.crt
    key: /certs/domain.key

auth:
  htpasswd:
    realm: "Registry Realm"
    path: /auth/htpasswd

health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3

# Proxy configuration (optionnel)
# proxy:
#   remoteurl: https://registry-1.docker.io
#   username: dockerhubuser
#   password: dockerhubpassword
EOF

# Lancer avec le fichier de config
docker rm -f registry

docker run -d \
  --name registry \
  -p 5000:5000 \
  -v $(pwd)/config/config.yml:/etc/docker/registry/config.yml \
  -v $(pwd)/auth:/auth \
  -v $(pwd)/certs:/certs \
  -v registry-data:/var/lib/registry \
  registry:2

# Vérifier
docker logs registry
```

### 4.2 - Configuration avec limitations

```bash
cat > config/config-limited.yml << 'EOF'
version: 0.1

log:
  level: info

storage:
  filesystem:
    rootdirectory: /var/lib/registry
  delete:
    enabled: true

http:
  addr: :5000
  tls:
    certificate: /certs/domain.crt
    key: /certs/domain.key
  # Limites de requêtes
  headers:
    X-Content-Type-Options: [nosniff]
  # Timeout
  timeouts:
    read: 15s
    write: 15s
    idle: 60s

auth:
  htpasswd:
    realm: "Registry"
    path: /auth/htpasswd

# Middleware pour blocker certaines IPs (exemple)
middleware:
  storage:
    - name: cloudfront
      options:
        baseurl: https://localhost:5000
        privatekey: /etc/cloudfront-key
        keypairid: KEYPAIRID
EOF
```

---

## Exercice 5 : Authentification avec tokens (Bearer)

### 5.1 - Setup d'un serveur d'auth simple

```bash
cd ~/docker-registry-secure
mkdir -p auth-server

# Créer un mini serveur d'authentification (exemple avec Python Flask)
cat > auth-server/auth_server.py << 'EOF'
from flask import Flask, request, jsonify
import jwt
import datetime

app = Flask(__name__)
SECRET_KEY = 'your-secret-key-change-this'

USERS = {
    'admin': 'SecurePass123',
    'developer': 'DevPass456'
}

@app.route('/auth', methods=['GET'])
def auth():
    # Vérifier Basic Auth
    auth_header = request.headers.get('Authorization')
    if not auth_header:
        return jsonify({'error': 'No authorization'}), 401

    # Extraire username/password
    import base64
    auth_decoded = base64.b64decode(auth_header.split(' ')[1]).decode('utf-8')
    username, password = auth_decoded.split(':')

    # Vérifier les credentials
    if username not in USERS or USERS[username] != password:
        return jsonify({'error': 'Invalid credentials'}), 401

    # Générer le token
    payload = {
        'sub': username,
        'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=1),
        'access': [
            {
                'type': 'repository',
                'name': request.args.get('scope', '').split(':')[1] if ':' in request.args.get('scope', '') else '*',
                'actions': ['pull', 'push']
            }
        ]
    }

    token = jwt.encode(payload, SECRET_KEY, algorithm='HS256')

    return jsonify({
        'token': token,
        'expires_in': 3600,
        'issued_at': datetime.datetime.utcnow().isoformat()
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)
EOF

cat > auth-server/requirements.txt << 'EOF'
flask==3.0.0
pyjwt==2.8.0
cryptography==41.0.7
EOF

cat > auth-server/Dockerfile << 'EOF'
FROM python:3.11-alpine
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY auth_server.py .
CMD ["python", "auth_server.py"]
EOF

# Build l'image d'auth
cd auth-server
docker build -t registry-auth-server .
cd ..

# Lancer le serveur d'auth
docker run -d \
  --name registry-auth \
  -p 5001:5001 \
  registry-auth-server
```

**Note** : Ceci est un exemple simplifié. En production, utilisez des solutions comme:
- **Harbor** (registre complet avec UI et auth)
- **Keycloak** (identity provider)
- **Dex** (OIDC identity provider)

---

## Exercice 6 : Docker Compose avec registre sécurisé

### 6.1 - Configuration complète

```bash
cd ~/docker-registry-secure

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  registry:
    image: registry:2
    container_name: secure-registry
    ports:
      - "5000:5000"
    environment:
      REGISTRY_HTTP_TLS_CERTIFICATE: /certs/domain.crt
      REGISTRY_HTTP_TLS_KEY: /certs/domain.key
      REGISTRY_AUTH: htpasswd
      REGISTRY_AUTH_HTPASSWD_REALM: "Registry Realm"
      REGISTRY_AUTH_HTPASSWD_PATH: /auth/htpasswd
      REGISTRY_STORAGE_DELETE_ENABLED: "true"
      REGISTRY_LOG_LEVEL: info
    volumes:
      - ./auth:/auth
      - ./certs:/certs
      - registry-data:/var/lib/registry
    restart: unless-stopped
    networks:
      - registry-network

  registry-ui:
    image: joxit/docker-registry-ui:latest
    container_name: registry-ui
    ports:
      - "8080:80"
    environment:
      REGISTRY_URL: https://registry:5000
      DELETE_IMAGES: "true"
      REGISTRY_TITLE: "My Secure Private Registry"
      NGINX_PROXY_PASS_URL: https://registry:5000
      SINGLE_REGISTRY: "true"
    depends_on:
      - registry
    networks:
      - registry-network

volumes:
  registry-data:
    driver: local

networks:
  registry-network:
    driver: bridge
EOF

# Démarrer la stack
docker-compose up -d

# Voir les logs
docker-compose logs -f

# Tester
docker login localhost:5000 -u admin -p SecurePass123
docker tag busybox:latest localhost:5000/busybox:latest
docker push localhost:5000/busybox:latest

# Accéder à l'UI (noter que l'auth peut nécessiter configuration supplémentaire)
echo "UI disponible sur : http://localhost:8080"
```

---

## Exercice 7 : Contrôle d'accès par repository

### 7.1 - ACL avec configuration avancée

```bash
# Créer un fichier d'ACL
cat > ~/docker-registry-secure/auth/acl.yml << 'EOF'
# Liste des contrôles d'accès
# Format: user:repo:permissions

users:
  admin:
    - repository: "*"
      actions: ["pull", "push", "delete"]

  developer:
    - repository: "dev/*"
      actions: ["pull", "push"]
    - repository: "prod/*"
      actions: ["pull"]

  readonly:
    - repository: "*"
      actions: ["pull"]
EOF

# Note: Pour implémenter de vraies ACL, vous auriez besoin d'un auth server
# qui interprète ces règles (comme Harbor ou Portus)
```

---

## Exercice 8 : Sécurité réseau avec Docker networks

### 8.1 - Isolation réseau

```bash
# Créer un réseau dédié
docker network create --driver bridge registry-secure-net

# Arrêter les conteneurs existants
docker-compose down 2>/dev/null || true
docker rm -f registry registry-ui 2>/dev/null || true

# Lancer le registre sur le réseau isolé
docker run -d \
  --name registry \
  --network registry-secure-net \
  -p 5000:5000 \
  -v ~/docker-registry-secure/auth:/auth \
  -v ~/docker-registry-secure/certs:/certs \
  -v registry-data:/var/lib/registry \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
  -e REGISTRY_AUTH=htpasswd \
  -e REGISTRY_AUTH_HTPASSWD_REALM="Registry" \
  -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
  registry:2

# Application qui peut accéder au registre
docker run -d \
  --name app \
  --network registry-secure-net \
  alpine sleep 3600

# Tester l'accès depuis l'app
docker exec app wget --no-check-certificate -qO- https://registry:5000/v2/

# Application isolée ne peut pas accéder
docker run -d --name isolated alpine sleep 3600
docker exec isolated wget -qO- http://registry:5000/v2/ || echo "Accès refusé (normal)"
```

### 8.2 - Firewall avec iptables (exemple)

```bash
# ATTENTION : Ces commandes modifient le firewall !
# À n'utiliser que si vous comprenez iptables

# Limiter l'accès au registre à certaines IPs
# sudo iptables -A INPUT -p tcp --dport 5000 -s 192.168.1.0/24 -j ACCEPT
# sudo iptables -A INPUT -p tcp --dport 5000 -j DROP

# Voir les règles actuelles
sudo iptables -L -n -v | grep 5000 || echo "Pas de règles pour le port 5000"
```

---

## Exercice 9 : Audit et monitoring de sécurité

### 9.1 - Logs d'authentification

```bash
# Activer les logs détaillés
docker rm -f registry

docker run -d \
  --name registry \
  -p 5000:5000 \
  -v ~/docker-registry-secure/auth:/auth \
  -v ~/docker-registry-secure/certs:/certs \
  -v registry-data:/var/lib/registry \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
  -e REGISTRY_AUTH=htpasswd \
  -e REGISTRY_AUTH_HTPASSWD_REALM="Registry" \
  -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
  -e REGISTRY_LOG_LEVEL=debug \
  registry:2

# Faire quelques tentatives d'authentification
docker login localhost:5000 -u admin -p WrongPassword || true
docker login localhost:5000 -u admin -p SecurePass123

# Analyser les logs
docker logs registry 2>&1 | grep -i auth
docker logs registry 2>&1 | grep -i "401\|403"
docker logs registry 2>&1 | grep -i "unauthorized"

# Créer un script de monitoring
cat > ~/monitor-registry-security.sh << 'EOF'
#!/bin/bash

echo "=== Rapport de sécurité du registre ==="
echo "Date: $(date)"
echo ""

echo "1. Tentatives d'authentification échouées (dernière heure):"
docker logs registry --since 1h 2>&1 | grep -c "401" || echo "0"

echo ""
echo "2. Connexions réussies (dernière heure):"
docker logs registry --since 1h 2>&1 | grep -c "200.*catalog\|200.*manifests" || echo "0"

echo ""
echo "3. Dernières IPs connectées:"
docker logs registry --since 1h 2>&1 | grep -oP '\d+\.\d+\.\d+\.\d+' | sort -u | head -5

echo ""
echo "4. Actions effectuées:"
docker logs registry --since 1h 2>&1 | grep -E "PUT|DELETE" | wc -l

EOF

chmod +x ~/monitor-registry-security.sh
~/monitor-registry-security.sh
```

### 9.2 - Rotation des certificats

```bash
cd ~/docker-registry-secure

# Créer un nouveau certificat (simule renouvellement)
openssl req -newkey rsa:4096 \
  -nodes -sha256 \
  -keyout certs/domain-new.key \
  -x509 -days 365 \
  -out certs/domain-new.crt \
  -subj "/C=FR/ST=IDF/L=Paris/O=MyCompany/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,DNS:registry.local,IP:127.0.0.1"

# Backup de l'ancien certificat
cp certs/domain.crt certs/domain.crt.bak
cp certs/domain.key certs/domain.key.bak

# Remplacer par le nouveau
mv certs/domain-new.crt certs/domain.crt
mv certs/domain-new.key certs/domain.key

# Mettre à jour Docker
sudo cp certs/domain.crt /etc/docker/certs.d/localhost:5000/ca.crt

# Redémarrer le registre
docker restart registry

# Tester
docker login localhost:5000 -u admin -p SecurePass123
```

---

## Exercice 10 : Scénario pratique - Registre d'entreprise

### Objectif : Déployer un registre complet et sécurisé

```bash
# Nettoyer
cd ~
rm -rf ~/docker-registry-enterprise
mkdir -p ~/docker-registry-enterprise
cd ~/docker-registry-enterprise

# Créer la structure
mkdir -p {auth,certs,config,backup}

# 1. Générer certificats
openssl req -newkey rsa:4096 -nodes -sha256 \
  -keyout certs/domain.key \
  -x509 -days 730 \
  -out certs/domain.crt \
  -subj "/C=FR/ST=IDF/L=Paris/O=Enterprise/CN=registry.company.local" \
  -addext "subjectAltName=DNS:registry.company.local,DNS:localhost,IP:127.0.0.1"

# 2. Créer les utilisateurs avec rôles
docker run --rm --entrypoint htpasswd registry:2 -Bbn admin AdminPass123 > auth/htpasswd
docker run --rm --entrypoint htpasswd registry:2 -Bbn devops DevOpsPass456 >> auth/htpasswd
docker run --rm --entrypoint htpasswd registry:2 -Bbn developer DevPass789 >> auth/htpasswd
docker run --rm --entrypoint htpasswd registry:2 -Bbn cicd CiCdPass000 >> auth/htpasswd

# 3. Configuration avancée
cat > config/config.yml << 'EOF'
version: 0.1

log:
  level: info
  formatter: json
  fields:
    service: enterprise-registry
    environment: production

storage:
  filesystem:
    rootdirectory: /var/lib/registry
  delete:
    enabled: true
  maintenance:
    uploadpurging:
      enabled: true
      age: 168h
      interval: 24h

http:
  addr: :5000
  host: https://registry.company.local:5000
  headers:
    X-Content-Type-Options: [nosniff]
    X-Frame-Options: [deny]
    Strict-Transport-Security: [max-age=31536000]
  tls:
    certificate: /certs/domain.crt
    key: /certs/domain.key

auth:
  htpasswd:
    realm: "Enterprise Registry"
    path: /auth/htpasswd

health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
EOF

# 4. Docker Compose avec monitoring
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  registry:
    image: registry:2
    container_name: enterprise-registry
    ports:
      - "5000:5000"
    volumes:
      - ./config/config.yml:/etc/docker/registry/config.yml
      - ./auth:/auth
      - ./certs:/certs
      - registry-data:/var/lib/registry
    restart: unless-stopped
    networks:
      - registry-net
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  registry-ui:
    image: joxit/docker-registry-ui:latest
    container_name: registry-ui
    ports:
      - "8080:80"
    environment:
      REGISTRY_URL: https://registry:5000
      DELETE_IMAGES: "true"
      REGISTRY_TITLE: "Enterprise Registry"
      SINGLE_REGISTRY: "true"
    depends_on:
      - registry
    networks:
      - registry-net

volumes:
  registry-data:

networks:
  registry-net:
    driver: bridge
EOF

# 5. Démarrer
sudo cp certs/domain.crt /etc/docker/certs.d/localhost:5000/ca.crt
docker-compose up -d

# 6. Tester
sleep 5
docker login localhost:5000 -u admin -p AdminPass123

# 7. Pousser des images de base
for image in alpine:latest nginx:alpine redis:alpine; do
    docker pull $image
    docker tag $image localhost:5000/base/$(echo $image | tr ':' '-')
    docker push localhost:5000/base/$(echo $image | tr ':' '-')
done

# 8. Vérifier
curl -u admin:AdminPass123 https://localhost:5000/v2/_catalog --cacert certs/domain.crt | python3 -m json.tool

echo ""
echo "=== Registre d'entreprise déployé ==="
echo "URL: https://localhost:5000"
echo "UI: http://localhost:8080"
echo "Utilisateurs: admin, devops, developer, cicd"
```

---

## 🏆 Validation

À l'issue de ce TP, vous devez savoir :

- [ ] Configurer l'authentification htpasswd
- [ ] Générer et configurer des certificats TLS
- [ ] Déployer un registre avec HTTPS
- [ ] Gérer les utilisateurs et leurs accès
- [ ] Configurer le registre via fichier de configuration
- [ ] Mettre en place l'isolation réseau
- [ ] Monitorer les logs de sécurité
- [ ] Déployer un registre complet avec Docker Compose

---

## 📊 Commandes essentielles

| Commande | Description |
|----------|-------------|
| `htpasswd -Bbn user pass` | Créer hash htpasswd |
| `openssl req -x509 ...` | Générer certificat SSL |
| `docker login registry` | Se connecter au registre |
| `docker logout registry` | Se déconnecter |
| `-e REGISTRY_AUTH=htpasswd` | Activer auth htpasswd |
| `-e REGISTRY_HTTP_TLS_CERTIFICATE` | Configurer TLS |
| `/etc/docker/certs.d/` | Certificats Docker |

---

## 🚀 Aller plus loin

### Harbor - Registre d'entreprise complet

```bash
# Harbor inclut : UI, RBAC, scanning, réplication, etc.
# Installation via Docker Compose

wget https://github.com/goharbor/harbor/releases/download/v2.10.0/harbor-offline-installer-v2.10.0.tgz
tar xvf harbor-offline-installer-v2.10.0.tgz
cd harbor
cp harbor.yml.tmpl harbor.yml

# Éditer harbor.yml avec vos paramètres
# ./install.sh
```

### Intégration LDAP/Active Directory

Configuration dans `config.yml` :
```yaml
auth:
  ldap:
    addr: ldap.company.com:389
    bind_dn: cn=admin,dc=company,dc=com
    bind_password: secret
    base_dn: ou=users,dc=company,dc=com
    filter: "(uid=%s)"
```

---

## 🧹 Nettoyage

```bash
# Arrêter les services
cd ~/docker-registry-enterprise
docker-compose down

# Supprimer les volumes
docker volume rm registry-data

# Nettoyer les certificats Docker
sudo rm -rf /etc/docker/certs.d/localhost:5000

# Nettoyer les fichiers
cd ~
rm -rf ~/docker-registry-secure ~/docker-registry-enterprise
```

---

**[→ Suite : TP16c - Production et haute disponibilité](TP16c-Registres-Prives-Production.md)**

**[→ Voir les solutions](../solutions/TP16b-Solution.md)**

**[← Retour : TP16a - Fondamentaux](TP16a-Registres-Prives-Fondamentaux.md)**

**[← Retour au README du module](../README.md)**
