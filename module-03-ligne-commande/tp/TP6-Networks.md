# TP6 : Réseaux Docker

## Objectif

Maîtriser les réseaux Docker pour permettre la communication entre conteneurs et avec l'extérieur.

## Durée estimée

45 minutes

## Concepts clés

```
┌───────────────────────────────────────────────────────────┐
│            Types de réseaux Docker                        │
├───────────────────────────────────────────────────────────┤
│                                                           │
│  1. BRIDGE (par défaut)                                   │
│     Réseau privé isolé sur l'hôte                         │
│     ✓ Conteneurs communiquent entre eux                   │
│     ✓ Isolation des autres conteneurs                     │
│                                                           │
│  2. HOST                                                  │
│     Partage le réseau de l'hôte                           │
│     ✓ Performance maximale                                │
│     ⚠ Pas d'isolation réseau                              │
│                                                           │
│  3. NONE                                                  │
│     Aucun réseau                                          │
│     ✓ Isolation complète                                  │
│     ⚠ Pas de connectivité                                 │
│                                                           │
│  4. OVERLAY                                               │
│     Réseau multi-hôtes (Swarm)                            │
│     ✓ Communication inter-hôtes                           │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

---

## Exercice 1 : Réseaux par défaut

### 1.1 - Explorer les réseaux existants

```bash
# Lister les réseaux
docker network ls

# Inspecter le réseau bridge par défaut
docker network inspect bridge

# Voir les options
docker network ls --help
```

**Questions** :
1. Combien de réseaux sont créés par défaut ?
2. Quel est le rôle du réseau `bridge` ?
3. Qu'est-ce que le réseau `host` ?

### 1.2 - Comportement par défaut

```bash
# Lancer deux conteneurs sans spécifier de réseau
docker run -d --name web1 nginx:alpine
docker run -d --name web2 nginx:alpine

# Vérifier qu'ils sont sur le réseau bridge
docker network inspect bridge --format '{{json .Containers}}'

# Trouver l'IP de web1
WEB1_IP=$(docker inspect web1 --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
echo "IP de web1: $WEB1_IP"

# Essayer de pinguer depuis web2 (par IP)
docker exec web2 ping -c 3 $WEB1_IP

# Essayer par nom (ne fonctionne PAS sur le réseau bridge par défaut)
docker exec web2 ping -c 3 web1
```

**Questions** :
1. Les conteneurs peuvent-ils communiquer par IP ?
2. Peuvent-ils communiquer par nom sur le réseau bridge par défaut ?
3. Pourquoi la résolution DNS par nom ne fonctionne-t-elle pas ?

---

## Exercice 2 : Créer des réseaux personnalisés

### 2.1 - Réseau bridge personnalisé

```bash
# Créer un réseau bridge personnalisé
docker network create mon-reseau

# Inspecter
docker network inspect mon-reseau

# Lancer des conteneurs sur ce réseau
docker run -d --name app1 --network mon-reseau nginx:alpine
docker run -d --name app2 --network mon-reseau nginx:alpine

# Maintenant la résolution DNS fonctionne !
docker exec app1 ping -c 3 app2
docker exec app2 ping -c 3 app1

# Vérifier avec nslookup
docker exec app1 nslookup app2
```

**Questions** :
1. Pourquoi les conteneurs peuvent-ils se résoudre par nom maintenant ?
2. Quelle est la différence entre le réseau bridge par défaut et un réseau bridge personnalisé ?

### 2.2 - Réseau avec sous-réseau personnalisé

```bash
# Créer un réseau avec configuration spécifique
docker network create \
  --driver bridge \
  --subnet 172.25.0.0/16 \
  --ip-range 172.25.5.0/24 \
  --gateway 172.25.0.1 \
  reseau-custom

# Lancer un conteneur avec IP fixe
docker run -d \
  --name web-fixe \
  --network reseau-custom \
  --ip 172.25.5.10 \
  nginx:alpine

# Vérifier l'IP
docker inspect web-fixe --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
```

**Tâches** :
1. Créer un deuxième conteneur avec l'IP 172.25.5.11
2. Vérifier qu'ils peuvent communiquer
3. Lister tous les conteneurs du réseau

---

## Exercice 3 : Communication entre conteneurs

### 3.1 - Application frontend/backend

```bash
# Créer un réseau pour l'application
docker network create app-network

# Backend : API simple
docker run -d \
  --name backend \
  --network app-network \
  -e PORT=5000 \
  hashicorp/http-echo:latest \
  -text="Hello from backend"

# Frontend : Nginx qui proxy vers le backend
mkdir -p ~/docker-tp/nginx-proxy

cat > ~/docker-tp/nginx-proxy/default.conf << 'EOF'
server {
    listen 80;

    location / {
        proxy_pass http://backend:5000;
        proxy_set_header Host $host;
    }
}
EOF

docker run -d \
  --name frontend \
  --network app-network \
  -p 8080:80 \
  -v ~/docker-tp/nginx-proxy/default.conf:/etc/nginx/conf.d/default.conf:ro \
  nginx:alpine

# Tester
curl http://localhost:8080
```

**Questions** :
1. Comment le frontend trouve-t-il le backend ?
2. Que se passe-t-il si vous changez le nom du conteneur backend ?
3. Comment cela fonctionne-t-il sans connaître l'IP ?

### 3.2 - Application multi-tiers

```bash
# Réseau pour une app complète
docker network create fullstack-net

# 1. Base de données
docker run -d \
  --name database \
  --network fullstack-net \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=myapp \
  postgres:15-alpine

# 2. Backend (API)
docker run -d \
  --name api \
  --network fullstack-net \
  -e DATABASE_URL=postgresql://postgres:secret@database:5432/myapp \
  node:18-alpine \
  sh -c "echo 'API running' && sleep infinity"

# 3. Frontend
docker run -d \
  --name webapp \
  --network fullstack-net \
  -p 3000:80 \
  nginx:alpine

# Vérifier la connectivité
docker exec api ping -c 2 database
docker exec webapp ping -c 2 api
```

---

## Exercice 4 : Connecter des conteneurs à plusieurs réseaux

### 4.1 - Multi-réseau

```bash
# Créer deux réseaux isolés
docker network create frontend-net
docker network create backend-net

# Base de données (seulement backend)
docker run -d \
  --name db \
  --network backend-net \
  postgres:15-alpine \
  -c 'password_encryption=scram-sha-256'

# Application (les deux réseaux)
docker run -d \
  --name app \
  --network backend-net \
  nginx:alpine

# Connecter aussi au frontend
docker network connect frontend-net app

# Proxy web (seulement frontend)
docker run -d \
  --name proxy \
  --network frontend-net \
  -p 8080:80 \
  nginx:alpine

# Vérifier les connexions
echo "=== App peut accéder à DB ==="
docker exec app ping -c 2 db

echo "=== Proxy peut accéder à App ==="
docker exec proxy ping -c 2 app

echo "=== Proxy NE PEUT PAS accéder à DB ==="
docker exec proxy ping -c 2 db  # Devrait échouer
```

**Questions** :
1. Pourquoi utiliser plusieurs réseaux ?
2. Quel est le bénéfice de l'isolation réseau ?
3. Donnez un exemple de cas d'usage réel.

### 4.2 - Déconnecter et reconnecter

```bash
# Voir les réseaux d'un conteneur
docker inspect app --format '{{range $net, $conf := .NetworkSettings.Networks}}{{$net}} {{end}}'

# Déconnecter d'un réseau
docker network disconnect frontend-net app

# Reconnecter
docker network connect frontend-net app

# Connecter avec un alias
docker network connect --alias api-server backend-net app

# Tester l'alias
docker exec db ping -c 2 api-server
```

---

## Exercice 5 : Exposition de ports

### 5.1 - Comprendre la publication de ports

```bash
# Port automatique
docker run -d --name web-auto -P nginx:alpine
docker port web-auto

# Port spécifique (hôte:conteneur)
docker run -d --name web-8080 -p 8080:80 nginx:alpine

# Interface spécifique
docker run -d --name web-localhost -p 127.0.0.1:8081:80 nginx:alpine

# Plusieurs ports
docker run -d --name web-multi \
  -p 8082:80 \
  -p 8443:443 \
  nginx:alpine

# Voir les ports publiés
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

**Questions** :
1. Quelle est la différence entre `-p 8080:80` et `-P` ?
2. Pourquoi utiliser `127.0.0.1:8080:80` ?
3. Que se passe-t-il si deux conteneurs utilisent le même port hôte ?

### 5.2 - Scénario : Multiple instances

```bash
# Lancer plusieurs instances de la même app sur différents ports
for i in {1..3}; do
  docker run -d \
    --name web-$i \
    --network app-network \
    -p 808$i:80 \
    nginx:alpine
done

# Tester
for i in {1..3}; do
  echo "=== Instance $i ==="
  curl -s http://localhost:808$i | grep -i welcome
done

# Load balancer simple avec netcat
docker run -d --name lb -p 8080:8080 alpine sh -c "
  while true; do
    echo 'HTTP/1.1 200 OK\r\n\r\nLoad Balancer' | nc -l -p 8080
  done
"
```

---

## Exercice 6 : Réseau host et none

### 6.1 - Mode host (Linux uniquement)

```bash
# Lancer avec le réseau de l'hôte
docker run -d --name web-host --network host nginx:alpine

# Nginx écoute directement sur le port 80 de l'hôte
# Pas besoin de -p !
curl http://localhost

# Voir la différence
docker exec web-host ip addr show
```

**⚠️ Limitations** :
- Linux uniquement (ne fonctionne pas bien sur Mac/Windows)
- Pas d'isolation réseau
- Conflits de ports possibles
- Utile pour la performance maximale

### 6.2 - Mode none (isolation complète)

```bash
# Conteneur sans réseau
docker run -d --name isolated --network none alpine sleep 3600

# Vérifier : aucune interface réseau (sauf loopback)
docker exec isolated ip addr show

# Pas d'accès réseau
docker exec isolated ping -c 2 8.8.8.8  # Échoue
```

**Use cases** :
- Traitement de données sensibles
- Isolation maximale
- Tests de sécurité

---

## Exercice 7 : Inspection et diagnostic

### 7.1 - Commandes utiles

```bash
# Voir tous les conteneurs d'un réseau
docker network inspect mon-reseau --format '{{range .Containers}}{{.Name}} {{end}}'

# Voir tous les réseaux d'un conteneur
docker inspect app --format '{{range $net, $conf := .NetworkSettings.Networks}}{{$net}}: {{$conf.IPAddress}}{{"\n"}}{{end}}'

# Statistiques réseau
docker stats --no-stream --format "table {{.Name}}\t{{.NetIO}}"

# Capturer le trafic réseau (avec tcpdump)
docker run --rm --net container:web1 nicolaka/netshoot tcpdump -i any -c 10
```

### 7.2 - Troubleshooting

```bash
# Outil de diagnostic réseau
docker run -it --rm \
  --network mon-reseau \
  nicolaka/netshoot

# Dans ce conteneur, vous avez accès à :
# - ping, traceroute
# - nslookup, dig
# - curl, wget
# - netstat, ss
# - tcpdump, nmap
# - etc.
```

**Tâches de diagnostic** :
1. Tester la résolution DNS
2. Vérifier la connectivité vers un service
3. Analyser le trafic réseau
4. Identifier les ports ouverts

---

## Exercice 8 : Scénario pratique - Architecture microservices

### Objectif : Application avec plusieurs services

```bash
# Créer les réseaux
docker network create public-net
docker network create private-net

# 1. Base de données (réseau privé uniquement)
docker run -d \
  --name mongo-db \
  --network private-net \
  -e MONGO_INITDB_ROOT_USERNAME=admin \
  -e MONGO_INITDB_ROOT_PASSWORD=secret \
  mongo:7

# 2. Service d'authentification (les deux réseaux)
docker run -d \
  --name auth-service \
  --network private-net \
  -e DATABASE_URL=mongodb://admin:secret@mongo-db:27017 \
  node:18-alpine \
  sh -c 'echo "Auth Service" && sleep infinity'

docker network connect public-net auth-service

# 3. Service API (les deux réseaux)
docker run -d \
  --name api-service \
  --network private-net \
  -e AUTH_SERVICE=auth-service:3000 \
  -e DATABASE_URL=mongodb://admin:secret@mongo-db:27017 \
  node:18-alpine \
  sh -c 'echo "API Service" && sleep infinity'

docker network connect public-net api-service

# 4. Reverse proxy (réseau public uniquement)
mkdir -p ~/docker-tp/nginx-proxy-advanced

cat > ~/docker-tp/nginx-proxy-advanced/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream auth {
        server auth-service:3000;
    }

    upstream api {
        server api-service:8080;
    }

    server {
        listen 80;

        location /auth/ {
            proxy_pass http://auth/;
        }

        location /api/ {
            proxy_pass http://api/;
        }
    }
}
EOF

docker run -d \
  --name reverse-proxy \
  --network public-net \
  -p 80:80 \
  -v ~/docker-tp/nginx-proxy-advanced/nginx.conf:/etc/nginx/nginx.conf:ro \
  nginx:alpine

# 5. Vérifier l'architecture
echo "=== Architecture réseau ==="
echo "Public network:"
docker network inspect public-net --format '{{range .Containers}}  - {{.Name}}{{"\n"}}{{end}}'
echo ""
echo "Private network:"
docker network inspect private-net --format '{{range .Containers}}  - {{.Name}}{{"\n"}}{{end}}'

# 6. Tests de connectivité
echo ""
echo "=== Tests de connectivité ==="
echo "✓ API peut accéder à DB:"
docker exec api-service ping -c 1 mongo-db > /dev/null && echo "  OK" || echo "  FAIL"

echo "✓ Auth peut accéder à DB:"
docker exec auth-service ping -c 1 mongo-db > /dev/null && echo "  OK" || echo "  FAIL"

echo "✓ Proxy peut accéder à API:"
docker exec reverse-proxy ping -c 1 api-service > /dev/null && echo "  OK" || echo "  FAIL"

echo "✗ Proxy NE PEUT PAS accéder à DB:"
docker exec reverse-proxy ping -c 1 mongo-db > /dev/null && echo "  FAIL (devrait être isolé)" || echo "  OK (bien isolé)"
```

**Architecture obtenue** :
```
┌──────────────────────────┐
│   Reverse Proxy (Nginx)  │ ← Port 80 public
│      (public-net)        │
└────────┬─────────────────┘
         │
    ┌────┴────────────┐
    │                 │
┌───▼────────┐  ┌────▼──────┐
│Auth Service│  │API Service│
│  (2 nets)  │  │  (2 nets) │
└───┬────────┘  └────┬──────┘
    │                │
    └────┬───────────┘
         │
    ┌────▼──────┐
    │  MongoDB  │
    │ (private) │
    └───────────┘
```

---

## Exercice 9 : Nettoyage et maintenance

### 9.1 - Gestion des réseaux

```bash
# Lister les réseaux non utilisés
docker network ls --filter "dangling=true"

# Nettoyer les réseaux non utilisés
docker network prune

# Supprimer un réseau spécifique
docker network rm mon-reseau

# Impossible de supprimer si des conteneurs l'utilisent
docker network rm app-network  # Échoue si des conteneurs sont connectés

# Forcer : arrêter les conteneurs d'abord
docker ps -a --filter network=app-network --format '{{.Names}}' | xargs docker rm -f
docker network rm app-network
```

### 9.2 - Analyse de l'utilisation

```bash
# Voir tous les réseaux avec leurs conteneurs
for net in $(docker network ls --format '{{.Name}}'); do
  echo "=== Réseau: $net ==="
  docker network inspect $net --format '{{range .Containers}}  - {{.Name}}{{"\n"}}{{end}}'
done

# Afficher la configuration réseau de tous les conteneurs
docker ps --format '{{.Names}}' | while read container; do
  echo "=== $container ==="
  docker inspect $container --format '{{range $net, $conf := .NetworkSettings.Networks}}  {{$net}}: {{$conf.IPAddress}}{{"\n"}}{{end}}'
done
```

---

## 🏆 Validation

À l'issue de ce TP, vous devez savoir :

- [ ] Comprendre les différents types de réseaux Docker
- [ ] Créer et configurer des réseaux personnalisés
- [ ] Connecter des conteneurs entre eux
- [ ] Utiliser la résolution DNS automatique
- [ ] Publier des ports et gérer l'exposition
- [ ] Connecter un conteneur à plusieurs réseaux
- [ ] Diagnostiquer les problèmes réseau
- [ ] Implémenter une architecture réseau sécurisée

---

## 📊 Récapitulatif des commandes

| Commande | Description |
|----------|-------------|
| `docker network ls` | Lister les réseaux |
| `docker network create` | Créer un réseau |
| `docker network inspect` | Inspecter un réseau |
| `docker network connect` | Connecter un conteneur |
| `docker network disconnect` | Déconnecter un conteneur |
| `docker network rm` | Supprimer un réseau |
| `docker network prune` | Nettoyer les réseaux |

---

## 🚀 Aller plus loin

```bash
# Créer un réseau avec IPv6
docker network create --ipv6 --subnet 2001:db8:1::/64 ipv6-net

# Réseau avec encryption
docker network create --opt encrypted overlay-encrypted

# Désactiver l'ICC (Inter Container Communication)
docker network create --opt com.docker.network.bridge.enable_icc=false secure-net

# DNS personnalisé
docker run --dns 8.8.8.8 --dns 8.8.4.4 nginx
```

---

**[→ Voir les solutions](../solutions/TP6-Solution.md)**

**[→ TP suivant : Gestion avancée des images](TP7-Gestion-Images.md)**
