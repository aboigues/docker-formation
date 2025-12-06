# TP6 : Solutions - Réseaux Docker

## Exercice 1 : Réseaux par défaut

### 1.1 - Réponses aux questions

**1. Combien de réseaux sont créés par défaut ?**

Trois réseaux par défaut :
- **bridge** : réseau par défaut pour les conteneurs
- **host** : partage le réseau de l'hôte
- **none** : aucun réseau

```bash
docker network ls
# NETWORK ID     NAME      DRIVER    SCOPE
# xxxxxxxxxxxx   bridge    bridge    local
# xxxxxxxxxxxx   host      host      local
# xxxxxxxxxxxx   none      null      local
```

**2. Quel est le rôle du réseau `bridge` ?**

C'est le réseau par défaut où les conteneurs sont connectés quand aucun réseau n'est spécifié. Il permet :
- Communication entre conteneurs via IP
- Isolation des conteneurs des autres réseaux
- NAT vers l'extérieur via l'hôte

**3. Qu'est-ce que le réseau `host` ?**

Le conteneur partage directement le stack réseau de l'hôte :
- Pas d'isolation réseau
- Performance maximale (pas de NAT)
- Le conteneur voit toutes les interfaces de l'hôte
- Linux uniquement (comportement différent sur Mac/Windows)

### 1.2 - Réponses aux questions

**1. Les conteneurs peuvent-ils communiquer par IP ?**

Oui, sur le réseau bridge par défaut, les conteneurs peuvent communiquer par IP :

```bash
docker exec web2 ping -c 3 172.17.0.2  # Fonctionne
```

**2. Peuvent-ils communiquer par nom sur le réseau bridge par défaut ?**

Non ! C'est une limitation importante du réseau bridge par défaut. La résolution DNS automatique n'est PAS disponible.

```bash
docker exec web2 ping web1  # ÉCHOUE
# ping: bad address 'web1'
```

**3. Pourquoi la résolution DNS par nom ne fonctionne-t-elle pas ?**

Le réseau bridge par défaut est legacy et n'inclut pas le service DNS embarqué de Docker. C'est pour cette raison qu'on doit créer des réseaux bridge personnalisés.

---

## Exercice 2 : Créer des réseaux personnalisés

### 2.1 - Réponses aux questions

**1. Pourquoi les conteneurs peuvent-ils se résoudre par nom maintenant ?**

Les réseaux bridge personnalisés incluent un serveur DNS embarqué qui :
- Résout automatiquement les noms de conteneurs
- Met à jour les enregistrements dynamiquement
- Supporte les alias réseau

```bash
# Le DNS Docker résout app1 -> 172.18.0.2
docker exec app2 nslookup app1
# Server:    127.0.0.11
# Address:   127.0.0.11:53
# Name:      app1
# Address:   172.18.0.2
```

**2. Quelle est la différence entre le réseau bridge par défaut et un réseau bridge personnalisé ?**

| Caractéristique | Bridge par défaut | Bridge personnalisé |
|-----------------|-------------------|---------------------|
| **DNS automatique** | ❌ Non | ✅ Oui |
| **Isolation** | ⚠️ Partielle | ✅ Complète |
| **Configuration** | ❌ Limitée | ✅ Flexible |
| **Recommandation** | ❌ Legacy | ✅ Production |
| **Hot-attach** | ⚠️ Possible | ✅ Facile |

Toujours utiliser des réseaux personnalisés en production !

### 2.2 - Solution complète

```bash
# Créer un réseau avec configuration personnalisée
docker network create \
  --driver bridge \
  --subnet 172.25.0.0/16 \
  --ip-range 172.25.5.0/24 \
  --gateway 172.25.0.1 \
  --opt com.docker.network.bridge.name=custom-br0 \
  --label environment=production \
  reseau-custom

# Conteneur 1 avec IP fixe
docker run -d \
  --name web-fixe \
  --network reseau-custom \
  --ip 172.25.5.10 \
  nginx:alpine

# Conteneur 2 avec IP fixe
docker run -d \
  --name web-fixe-2 \
  --network reseau-custom \
  --ip 172.25.5.11 \
  nginx:alpine

# Vérifier la communication
docker exec web-fixe ping -c 2 172.25.5.11
docker exec web-fixe ping -c 2 web-fixe-2

# Lister tous les conteneurs du réseau
docker network inspect reseau-custom \
  --format '{{range .Containers}}{{.Name}}: {{.IPv4Address}}{{"\n"}}{{end}}'
```

---

## Exercice 3 : Communication entre conteneurs

### 3.1 - Réponses aux questions

**1. Comment le frontend trouve-t-il le backend ?**

Via le DNS Docker embarqué :
1. Nginx fait une requête pour `backend`
2. Le DNS Docker (127.0.0.11:53) résout `backend` en IP du conteneur
3. Nginx se connecte à cette IP sur le port 5000
4. Pas besoin de connaître l'IP à l'avance !

**2. Que se passe-t-il si vous changez le nom du conteneur backend ?**

La configuration Nginx doit être mise à jour :

```nginx
# Si vous renommez en "api-server"
location / {
    proxy_pass http://api-server:5000;  # Mettre à jour ici
}
```

C'est pourquoi on utilise des alias réseau ou docker-compose.

**3. Comment cela fonctionne-t-il sans connaître l'IP ?**

DNS dynamique ! Docker maintient automatiquement :
- Une table DNS name -> IP
- Mise à jour quand les conteneurs démarrent/s'arrêtent
- Résolution via le resolver 127.0.0.11

### 3.2 - Architecture complète

```bash
# Script complet pour application 3-tiers
#!/bin/bash

# Nettoyage
docker rm -f database api webapp 2>/dev/null || true
docker network rm fullstack-net 2>/dev/null || true

# Création du réseau
docker network create fullstack-net

# 1. Couche données
echo "Démarrage de la base de données..."
docker run -d \
  --name database \
  --network fullstack-net \
  --network-alias db \
  --network-alias postgres \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=myapp \
  -e POSTGRES_USER=appuser \
  -v db-data:/var/lib/postgresql/data \
  postgres:15-alpine

# 2. Couche API
echo "Démarrage de l'API..."
cat > api.js << 'EOF'
const http = require('http');
const { Client } = require('pg');

const server = http.createServer(async (req, res) => {
  const client = new Client({
    connectionString: process.env.DATABASE_URL
  });

  try {
    await client.connect();
    const result = await client.query('SELECT NOW()');
    res.writeHead(200, {'Content-Type': 'application/json'});
    res.end(JSON.stringify({
      status: 'ok',
      database: 'connected',
      time: result.rows[0].now
    }));
  } catch (err) {
    res.writeHead(500);
    res.end(JSON.stringify({ error: err.message }));
  } finally {
    await client.end();
  }
});

server.listen(3000, () => console.log('API on port 3000'));
EOF

docker run -d \
  --name api \
  --network fullstack-net \
  -e DATABASE_URL=postgresql://appuser:secret@database:5432/myapp \
  -v $(pwd)/api.js:/app/api.js \
  -w /app \
  node:18-alpine \
  sh -c "npm install pg && node api.js"

# 3. Couche présentation
echo "Démarrage du frontend..."
mkdir -p nginx-conf

cat > nginx-conf/default.conf << 'EOF'
server {
    listen 80;

    location /api/ {
        proxy_pass http://api:3000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location / {
        root /usr/share/nginx/html;
        index index.html;
    }
}
EOF

cat > nginx-conf/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Fullstack App</title>
</head>
<body>
    <h1>Application 3-tiers</h1>
    <button onclick="testAPI()">Test API</button>
    <pre id="result"></pre>
    <script>
    async function testAPI() {
        const res = await fetch('/api/');
        const data = await res.json();
        document.getElementById('result').textContent = JSON.stringify(data, null, 2);
    }
    </script>
</body>
</html>
EOF

docker run -d \
  --name webapp \
  --network fullstack-net \
  -p 3000:80 \
  -v $(pwd)/nginx-conf/default.conf:/etc/nginx/conf.d/default.conf:ro \
  -v $(pwd)/nginx-conf/index.html:/usr/share/nginx/html/index.html:ro \
  nginx:alpine

echo ""
echo "Application disponible sur http://localhost:3000"
echo "Testez l'API : curl http://localhost:3000/api/"
```

---

## Exercice 4 : Connecter des conteneurs à plusieurs réseaux

### 4.1 - Réponses aux questions

**1. Pourquoi utiliser plusieurs réseaux ?**

Principe de séparation des responsabilités (Separation of Concerns) :
- **Sécurité** : Limiter l'accès entre services
- **Organisation** : Regrouper logiquement les services
- **Isolation** : Éviter les communications non nécessaires

Exemple : Dans une architecture web, le proxy ne devrait pas accéder directement à la base de données.

**2. Quel est le bénéfice de l'isolation réseau ?**

- **Sécurité renforcée** : Réduction de la surface d'attaque
- **Compliance** : Respect des normes (PCI-DSS, HIPAA, etc.)
- **Performance** : Moins de trafic broadcast
- **Clarté** : Architecture plus claire et maintenable

**3. Exemple de cas d'usage réel**

Architecture e-commerce typique :

```
┌─────────────┐
│   Internet  │
└──────┬──────┘
       │
┌──────▼──────────┐  public-net
│  Load Balancer  │───────────┐
└─────────────────┘           │
                              │
┌─────────────────┐  ┌────────▼────────┐
│  Admin Panel    │──┤   Web Servers   │
└─────────────────┘  └────────┬────────┘
    admin-net                 │
                   ┌──────────┴──────────┐
                   │                     │
              backend-net           backend-net
                   │                     │
         ┌─────────▼────────┐  ┌────────▼───────┐
         │   API Services   │  │  Auth Service  │
         └─────────┬────────┘  └────────┬───────┘
                   │                    │
                   └──────────┬─────────┘
                         database-net
                              │
                   ┌──────────▼──────────┐
                   │   Database Cluster  │
                   └─────────────────────┘
```

### 4.2 - Alias réseau

```bash
# Utilisation d'alias pour la flexibilité
docker network create backend-net

# Service avec plusieurs alias
docker run -d \
  --name api-v1 \
  --network backend-net \
  --network-alias api \
  --network-alias api-server \
  --network-alias api-v1 \
  myapi:1.0

# Les clients peuvent utiliser n'importe quel alias
docker run --rm --network backend-net alpine ping -c 1 api
docker run --rm --network backend-net alpine ping -c 1 api-server
docker run --rm --network backend-net alpine ping -c 1 api-v1

# Utile pour les migrations de version
docker run -d \
  --name api-v2 \
  --network backend-net \
  --network-alias api-v2 \
  myapi:2.0

# On peut basculer l'alias "api" vers v2
docker network disconnect backend-net api-v1
docker network connect backend-net api-v2 --alias api
```

---

## Exercice 5 : Exposition de ports

### 5.1 - Réponses aux questions

**1. Quelle est la différence entre `-p 8080:80` et `-P` ?**

```bash
# -p (minuscule) : Mapping manuel explicite
docker run -p 8080:80 nginx
# L'hôte:8080 -> conteneur:80

# -P (majuscule) : Mapping automatique de TOUS les ports EXPOSE
docker run -P nginx
# L'hôte:<port-aléatoire> -> tous les ports exposés dans le Dockerfile

# Voir le port assigné
docker port mon-conteneur
```

**2. Pourquoi utiliser `127.0.0.1:8080:80` ?**

Pour limiter l'accès au localhost uniquement :

```bash
# Accessible depuis n'importe quelle interface
docker run -p 8080:80 nginx
# Accessible via: localhost:8080, <ip-publique>:8080, etc.

# Accessible SEULEMENT en local
docker run -p 127.0.0.1:8080:80 nginx
# Accessible via: localhost:8080 UNIQUEMENT

# Use cases
- Services internes (bases de données)
- APIs de développement
- Proxies locaux
```

**3. Que se passe-t-il si deux conteneurs utilisent le même port hôte ?**

Erreur ! Docker ne peut pas binder deux fois le même port :

```bash
docker run -d -p 8080:80 --name web1 nginx
docker run -d -p 8080:80 --name web2 nginx
# Error: driver failed programming external connectivity:
# Bind for 0.0.0.0:8080 failed: port is already allocated
```

Solution : Utiliser des ports différents ou un load balancer.

### 5.2 - Load Balancer simple avec Nginx

```bash
# Script pour déployer plusieurs instances avec load balancing
#!/bin/bash

# Créer un réseau
docker network create lb-net

# Démarrer 3 instances backend
for i in {1..3}; do
  docker run -d \
    --name backend-$i \
    --network lb-net \
    hashicorp/http-echo:latest \
    -text="Backend $i"
done

# Configuration load balancer
mkdir -p lb-config

cat > lb-config/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream backend {
        server backend-1:5678;
        server backend-2:5678;
        server backend-3:5678;
    }

    server {
        listen 80;

        location / {
            proxy_pass http://backend;
            add_header X-Backend-Server $upstream_addr;
        }
    }
}
EOF

# Démarrer le load balancer
docker run -d \
  --name load-balancer \
  --network lb-net \
  -p 8080:80 \
  -v $(pwd)/lb-config/nginx.conf:/etc/nginx/nginx.conf:ro \
  nginx:alpine

# Tester la distribution des requêtes
echo "Testing load balancing..."
for i in {1..10}; do
  curl -s http://localhost:8080
done
```

---

## Exercice 6 : Réseau host et none

### 6.1 - Mode host expliqué

**Limitations importantes** :

```bash
# ✓ Linux : Fonctionne comme attendu
docker run -d --network host nginx
# Nginx écoute sur port 80 de l'hôte directement

# ⚠️ Mac/Windows : Comportement différent !
# Sur Docker Desktop, "host" est la VM, pas votre Mac/Windows
# Utilisez plutôt -p pour publier les ports
```

**Cas d'usage du mode host** :

1. **Performance maximale** (pas de NAT)
2. **Services système** (monitoring, logging)
3. **Multicast/Broadcast** nécessaire
4. **Tests de performance réseau**

**Inconvénients** :

- Pas d'isolation réseau
- Conflits de ports possibles
- Moins portable
- Complexité du firewall

### 6.2 - Mode none - Cas d'usage

```bash
# 1. Traitement de données sensibles
docker run -d --network none --name data-processor \
  -v secure-data:/data \
  myapp-processor

# 2. Conteneur de calcul pur (batch processing)
docker run --network none \
  -v $(pwd)/input:/input:ro \
  -v $(pwd)/output:/output \
  image-processor /input /output

# 3. Test de sécurité (isolation complète)
docker run -it --network none --name isolated \
  --cap-drop ALL \
  alpine sh

# 4. Copie de données entre volumes
docker run --rm --network none \
  -v source-vol:/source:ro \
  -v dest-vol:/dest \
  alpine cp -r /source/. /dest/
```

---

## Exercice 7 : Inspection et diagnostic

### 7.1 - Scripts de diagnostic

```bash
#!/bin/bash
# network-diagnostic.sh - Outil de diagnostic réseau complet

function show_all_networks() {
    echo "=== Tous les réseaux ==="
    docker network ls --format "table {{.Name}}\t{{.Driver}}\t{{.Scope}}"
}

function show_network_details() {
    local network=$1
    echo "=== Détails du réseau: $network ==="

    # Subnet et Gateway
    docker network inspect $network \
        --format 'Subnet: {{range .IPAM.Config}}{{.Subnet}}{{end}}'
    docker network inspect $network \
        --format 'Gateway: {{range .IPAM.Config}}{{.Gateway}}{{end}}'

    # Conteneurs connectés
    echo "Conteneurs:"
    docker network inspect $network \
        --format '{{range .Containers}}  - {{.Name}}: {{.IPv4Address}}{{"\n"}}{{end}}'
}

function show_container_networks() {
    local container=$1
    echo "=== Réseaux du conteneur: $container ==="

    docker inspect $container \
        --format '{{range $net, $conf := .NetworkSettings.Networks}}{{$net}}: {{$conf.IPAddress}}{{"\n"}}{{end}}'
}

function test_connectivity() {
    local from=$1
    local to=$2

    echo "=== Test de connectivité: $from -> $to ==="

    # Par nom
    if docker exec $from ping -c 1 $to &>/dev/null; then
        echo "✓ Ping par nom réussi"
    else
        echo "✗ Ping par nom échoué"
    fi

    # DNS
    docker exec $from nslookup $to 2>&1 | grep -q "Address" && \
        echo "✓ Résolution DNS réussie" || \
        echo "✗ Résolution DNS échouée"
}

function network_topology() {
    echo "=== Topologie réseau complète ==="

    for net in $(docker network ls --format '{{.Name}}' | grep -v bridge | grep -v host | grep -v none); do
        echo ""
        echo "Réseau: $net"
        docker network inspect $net \
            --format '{{range .Containers}}  └─ {{.Name}} ({{.IPv4Address}}){{"\n"}}{{end}}'
    done
}

# Utilisation
case $1 in
    networks)
        show_all_networks
        ;;
    network)
        show_network_details $2
        ;;
    container)
        show_container_networks $2
        ;;
    test)
        test_connectivity $2 $3
        ;;
    topology)
        network_topology
        ;;
    *)
        echo "Usage: $0 {networks|network <name>|container <name>|test <from> <to>|topology}"
        ;;
esac
```

### 7.2 - Utilisation de netshoot

```bash
# Netshoot : conteneur avec tous les outils réseau

# 1. Diagnostic d'un réseau
docker run -it --rm --network mon-reseau nicolaka/netshoot

# Dans le conteneur netshoot :
# - ping web-server
# - nslookup web-server
# - dig web-server
# - curl http://web-server
# - traceroute web-server
# - nmap web-server
# - tcpdump -i eth0

# 2. Sniffer le trafic d'un conteneur
docker run -it --rm \
  --network container:web-app \
  nicolaka/netshoot \
  tcpdump -i any -n port 80

# 3. Scanner les ports ouverts
docker run -it --rm \
  --network app-network \
  nicolaka/netshoot \
  nmap -sT web-server

# 4. Test de bande passante
# Terminal 1 (serveur)
docker run -it --rm --network test-net --name iperf-server \
  nicolaka/netshoot iperf3 -s

# Terminal 2 (client)
docker run -it --rm --network test-net \
  nicolaka/netshoot iperf3 -c iperf-server
```

---

## Exercice 8 : Architecture microservices

### Architecture complète annotée

```bash
#!/bin/bash
# microservices-architecture.sh

set -e

echo "=== Déploiement architecture microservices ==="

# Nettoyage
docker rm -f mongo-db auth-service api-service reverse-proxy 2>/dev/null || true
docker network rm public-net private-net 2>/dev/null || true
docker volume rm mongo-data 2>/dev/null || true

# 1. Créer les réseaux
echo "1. Création des réseaux..."
docker network create public-net \
  --subnet 172.20.0.0/16 \
  --gateway 172.20.0.1

docker network create private-net \
  --subnet 172.21.0.0/16 \
  --gateway 172.21.0.1 \
  --internal  # Pas d'accès internet !

# 2. Base de données (PRIVÉ uniquement)
echo "2. Démarrage MongoDB..."
docker volume create mongo-data

docker run -d \
  --name mongo-db \
  --network private-net \
  --ip 172.21.0.10 \
  -v mongo-data:/data/db \
  -e MONGO_INITDB_ROOT_USERNAME=admin \
  -e MONGO_INITDB_ROOT_PASSWORD=secret \
  mongo:7

# 3. Service d'authentification (PRIVÉ + PUBLIC)
echo "3. Démarrage service d'authentification..."
mkdir -p services/auth

cat > services/auth/server.js << 'EOF'
const http = require('http');
const url = require('url');

const users = {
  'admin': 'password123',
  'user': 'secret456'
};

const server = http.createServer((req, res) => {
  const parsedUrl = url.parse(req.url, true);

  if (parsedUrl.pathname === '/login' && req.method === 'POST') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      const { username, password } = JSON.parse(body);

      if (users[username] === password) {
        res.writeHead(200, {'Content-Type': 'application/json'});
        res.end(JSON.stringify({
          token: Buffer.from(username).toString('base64'),
          user: username
        }));
      } else {
        res.writeHead(401);
        res.end(JSON.stringify({ error: 'Invalid credentials' }));
      }
    });
  } else if (parsedUrl.pathname === '/verify') {
    const token = req.headers['authorization'];
    res.writeHead(200, {'Content-Type': 'application/json'});
    res.end(JSON.stringify({
      valid: !!token,
      user: token ? Buffer.from(token, 'base64').toString() : null
    }));
  } else {
    res.writeHead(404);
    res.end();
  }
});

server.listen(3000, () => console.log('Auth service on 3000'));
EOF

docker run -d \
  --name auth-service \
  --network private-net \
  --ip 172.21.0.20 \
  -v $(pwd)/services/auth:/app \
  -w /app \
  node:18-alpine \
  node server.js

# Connecter aussi au réseau public
docker network connect public-net auth-service --ip 172.20.0.20

# 4. Service API (PRIVÉ + PUBLIC)
echo "4. Démarrage service API..."
mkdir -p services/api

cat > services/api/server.js << 'EOF'
const http = require('http');

const server = http.createServer((req, res) => {
  if (req.url === '/api/data') {
    res.writeHead(200, {'Content-Type': 'application/json'});
    res.end(JSON.stringify({
      data: ['item1', 'item2', 'item3'],
      timestamp: new Date().toISOString()
    }));
  } else if (req.url === '/api/health') {
    res.writeHead(200);
    res.end('OK');
  } else {
    res.writeHead(404);
    res.end();
  }
});

server.listen(8080, () => console.log('API service on 8080'));
EOF

docker run -d \
  --name api-service \
  --network private-net \
  --ip 172.21.0.30 \
  -v $(pwd)/services/api:/app \
  -w /app \
  node:18-alpine \
  node server.js

docker network connect public-net api-service --ip 172.20.0.30

# 5. Reverse Proxy (PUBLIC uniquement)
echo "5. Démarrage reverse proxy..."
mkdir -p services/proxy

cat > services/proxy/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    # Timeouts
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;

    # Upstream services
    upstream auth {
        server auth-service:3000 max_fails=3 fail_timeout=30s;
    }

    upstream api {
        server api-service:8080 max_fails=3 fail_timeout=30s;
    }

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=auth_limit:10m rate=5r/s;
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;

    server {
        listen 80;

        # Auth endpoints
        location /auth/ {
            limit_req zone=auth_limit burst=10;

            proxy_pass http://auth/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }

        # API endpoints
        location /api/ {
            limit_req zone=api_limit burst=20;

            # Vérification d'auth (simplifié)
            # En production, utiliser auth_request

            proxy_pass http://api/api/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        # Health check
        location /health {
            access_log off;
            return 200 "OK\n";
        }

        # Default
        location / {
            return 404;
        }
    }
}
EOF

docker run -d \
  --name reverse-proxy \
  --network public-net \
  --ip 172.20.0.2 \
  -p 80:80 \
  -v $(pwd)/services/proxy/nginx.conf:/etc/nginx/nginx.conf:ro \
  nginx:alpine

# 6. Attendre le démarrage
echo "6. Attente du démarrage des services..."
sleep 5

# 7. Tests de connectivité
echo ""
echo "=== Tests de connectivité ==="

# API peut accéder à MongoDB
echo -n "✓ API -> MongoDB: "
docker exec api-service ping -c 1 mongo-db &>/dev/null && echo "OK" || echo "FAIL"

# Auth peut accéder à MongoDB
echo -n "✓ Auth -> MongoDB: "
docker exec auth-service ping -c 1 mongo-db &>/dev/null && echo "OK" || echo "FAIL"

# Proxy peut accéder à API
echo -n "✓ Proxy -> API: "
docker exec reverse-proxy ping -c 1 api-service &>/dev/null && echo "OK" || echo "FAIL"

# Proxy NE PEUT PAS accéder à MongoDB (isolation)
echo -n "✗ Proxy -> MongoDB: "
docker exec reverse-proxy ping -c 1 mongo-db &>/dev/null && echo "FAIL (devrait être isolé)" || echo "OK (bien isolé)"

echo ""
echo "=== Tests fonctionnels ==="

# Test de login
echo "Test login:"
curl -X POST http://localhost/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"password123"}'

echo ""
echo "Test API:"
curl http://localhost/api/data

echo ""
echo "=== Architecture déployée ==="
echo "Réseaux:"
docker network ls | grep -E "(public-net|private-net)"

echo ""
echo "Services:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "Topologie réseau:"
echo "Public Network (172.20.0.0/16):"
docker network inspect public-net --format '{{range .Containers}}  - {{.Name}} ({{.IPv4Address}}){{"\n"}}{{end}}'

echo "Private Network (172.21.0.0/16):"
docker network inspect private-net --format '{{range .Containers}}  - {{.Name}} ({{.IPv4Address}}){{"\n"}}{{end}}'
```

---

## Exercice 9 : Nettoyage et maintenance

### Scripts d'administration réseau

```bash
#!/bin/bash
# network-cleanup.sh

function list_unused_networks() {
    echo "=== Réseaux non utilisés ==="
    docker network ls --filter "type=custom" --format "{{.Name}}" | while read net; do
        count=$(docker network inspect $net --format '{{len .Containers}}')
        if [ "$count" -eq 0 ]; then
            echo "$net (0 conteneurs)"
        fi
    done
}

function remove_unused_networks() {
    echo "=== Suppression des réseaux non utilisés ==="
    docker network prune -f
}

function network_usage_report() {
    echo "=== Rapport d'utilisation des réseaux ==="

    for net in $(docker network ls --format '{{.Name}}'); do
        echo ""
        echo "Réseau: $net"

        # Nombre de conteneurs
        count=$(docker network inspect $net --format '{{len .Containers}}' 2>/dev/null || echo "0")
        echo "  Conteneurs: $count"

        # Subnet
        subnet=$(docker network inspect $net --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null || echo "N/A")
        echo "  Subnet: $subnet"

        # Driver
        driver=$(docker network inspect $net --format '{{.Driver}}' 2>/dev/null || echo "N/A")
        echo "  Driver: $driver"

        # Conteneurs connectés
        if [ "$count" -gt 0 ]; then
            echo "  Conteneurs connectés:"
            docker network inspect $net --format '{{range .Containers}}    - {{.Name}}{{"\n"}}{{end}}' 2>/dev/null
        fi
    done
}

# Utilisation
case $1 in
    list-unused)
        list_unused_networks
        ;;
    clean)
        remove_unused_networks
        ;;
    report)
        network_usage_report
        ;;
    *)
        echo "Usage: $0 {list-unused|clean|report}"
        ;;
esac
```

---

## Checklist de validation

- [x] Compris les 4 types de réseaux Docker
- [x] Créé des réseaux bridge personnalisés
- [x] Utilisé la résolution DNS automatique
- [x] Connecté des conteneurs à plusieurs réseaux
- [x] Publié des ports avec différentes syntaxes
- [x] Implémenté une isolation réseau sécurisée
- [x] Diagnostiqué des problèmes réseau
- [x] Déployé une architecture microservices complète

---

## Bonnes pratiques réseau

### 1. Toujours utiliser des réseaux personnalisés

```bash
# ✗ MAL
docker run nginx

# ✓ BIEN
docker network create app-net
docker run --network app-net nginx
```

### 2. Appliquer le principe du moindre privilège

```bash
# ✓ BIEN : Isolation par couche
docker network create frontend-net
docker network create backend-net
docker network create database-net

# Chaque service seulement sur les réseaux nécessaires
```

### 3. Utiliser des alias pour la flexibilité

```bash
# ✓ BIEN
docker network connect app-net db --alias database --alias postgres
```

### 4. Documentation et labels

```bash
# ✓ BIEN
docker network create \
  --label environment=production \
  --label project=myapp \
  --label tier=backend \
  production-backend-net
```

---

**[← Retour au TP](../tp/TP6-Networks.md)**
