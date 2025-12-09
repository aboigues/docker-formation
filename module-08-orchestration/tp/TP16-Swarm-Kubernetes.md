# TP16 : Docker Swarm et introduction Kubernetes

## Objectif

Découvrir l'orchestration de conteneurs avec Docker Swarm et Kubernetes.

## Durée estimée

120 minutes

---

## Partie 1 : Docker Swarm

### Exercice 1 : Initialiser un Swarm

```bash
# Initialiser Swarm mode
docker swarm init

# Voir les informations du cluster
docker info | grep -A 10 Swarm

# Lister les nœuds
docker node ls

# Inspecter le nœud manager
docker node inspect self --pretty
```

### Exercice 2 : Déployer des services

```bash
# Créer un service simple
docker service create \
  --name web \
  --replicas 3 \
  --publish 8080:80 \
  nginx:alpine

# Lister les services
docker service ls

# Voir les détails
docker service ps web

# Scaler le service
docker service scale web=5

# Voir les logs
docker service logs web

# Mettre à jour l'image
docker service update --image nginx:latest web

# Supprimer le service
docker service rm web
```

### Exercice 3 : Stack Swarm avec Compose

```bash
mkdir -p ~/docker-tp/swarm-stack
cd ~/docker-tp/swarm-stack

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  web:
    image: nginx:alpine
    deploy:
      replicas: 3
      update_config:
        parallelism: 1
        delay: 10s
      restart_policy:
        condition: on-failure
      placement:
        constraints:
          - node.role == worker
    ports:
      - "8080:80"
    networks:
      - webnet

  visualizer:
    image: dockersamples/visualizer:latest
    ports:
      - "8081:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    deploy:
      placement:
        constraints:
          - node.role == manager
    networks:
      - webnet

  redis:
    image: redis:alpine
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.role == manager
    networks:
      - webnet

networks:
  webnet:
    driver: overlay
EOF

# Déployer la stack
docker stack deploy -c docker-compose.yml myapp

# Lister les stacks
docker stack ls

# Voir les services de la stack
docker stack services myapp

# Voir les tâches
docker stack ps myapp

# Supprimer la stack
docker stack rm myapp
```

### Exercice 4 : Secrets et Configs

```bash
# Créer un secret
echo "supersecretpassword" | docker secret create db_password -

# Lister les secrets
docker secret ls

# Créer une configuration
docker config create nginx_config nginx.conf

# Utiliser dans un service
docker service create \
  --name db \
  --secret db_password \
  -e POSTGRES_PASSWORD_FILE=/run/secrets/db_password \
  postgres:15-alpine

# Stack avec secrets
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  db:
    image: postgres:15-alpine
    secrets:
      - db_password
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    deploy:
      replicas: 1

  app:
    image: myapp:latest
    secrets:
      - db_password
      - api_key
    deploy:
      replicas: 3

secrets:
  db_password:
    external: true
  api_key:
    external: true
EOF
```

### Exercice 5 : Rolling Updates

```bash
# Déployer version 1
docker service create \
  --name myapp \
  --replicas 6 \
  --update-delay 10s \
  --update-parallelism 2 \
  myapp:v1

# Mettre à jour vers v2
docker service update \
  --image myapp:v2 \
  myapp

# Observer le rolling update
watch docker service ps myapp

# Rollback si problème
docker service rollback myapp
```

### Exercice 6 : Scaling automatique avec monitoring

```bash
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  app:
    image: myapp:latest
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
      restart_policy:
        condition: on-failure
        max_attempts: 3

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    deploy:
      placement:
        constraints:
          - node.role == manager

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    deploy:
      placement:
        constraints:
          - node.role == manager
EOF
```

---

## Partie 2 : Introduction à Kubernetes

### Exercice 7 : Concepts Kubernetes

**Architecture Kubernetes** :
```
┌──────────────────────────────────────────────┐
│              Control Plane                   │
│  ┌────────────┐  ┌────────────┐             │
│  │ API Server │  │ Scheduler  │             │
│  └────────────┘  └────────────┘             │
│  ┌────────────┐  ┌────────────┐             │
│  │Controller  │  │    etcd    │             │
│  │ Manager    │  │            │             │
│  └────────────┘  └────────────┘             │
└──────────────┬───────────────────────────────┘
               │
    ┌──────────┴───────────┬─────────────┐
    │                      │             │
┌───▼────┐           ┌─────▼──┐    ┌─────▼──┐
│ Node 1 │           │ Node 2 │    │ Node 3 │
│        │           │        │    │        │
│ Kubelet│           │ Kubelet│    │ Kubelet│
│ Pods   │           │ Pods   │    │ Pods   │
└────────┘           └────────┘    └────────┘
```

### Exercice 8 : Installation avec Minikube

```bash
# Installer Minikube (Linux)
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Démarrer Minikube
minikube start

# Vérifier
kubectl get nodes

# Dashboard
minikube dashboard
```

### Exercice 9 : Premier déploiement Kubernetes

```bash
# Créer un deployment
kubectl create deployment nginx --image=nginx:alpine

# Exposer le service
kubectl expose deployment nginx --port=80 --type=NodePort

# Lister les ressources
kubectl get deployments
kubectl get pods
kubectl get services

# Scaler
kubectl scale deployment nginx --replicas=3

# Voir les détails
kubectl describe deployment nginx
kubectl describe pod nginx-xxx

# Accéder au service
minikube service nginx

# Logs
kubectl logs -f nginx-xxx

# Shell dans un pod
kubectl exec -it nginx-xxx -- sh

# Supprimer
kubectl delete deployment nginx
kubectl delete service nginx
```

### Exercice 10 : Déploiement avec YAML

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  labels:
    app: webapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: webapp
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          limits:
            cpu: "500m"
            memory: "512Mi"
          requests:
            cpu: "250m"
            memory: "256Mi"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: webapp-service
spec:
  selector:
    app: webapp
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: LoadBalancer
```

```bash
# Appliquer
kubectl apply -f deployment.yaml

# Vérifier
kubectl get all

# Mettre à jour
kubectl set image deployment/webapp webapp=nginx:latest

# Rollback
kubectl rollout undo deployment/webapp

# Historique
kubectl rollout history deployment/webapp

# Supprimer
kubectl delete -f deployment.yaml
```

### Exercice 11 : ConfigMap et Secrets

```bash
# Créer un ConfigMap
kubectl create configmap app-config \
  --from-literal=ENV=production \
  --from-literal=LOG_LEVEL=info

# Voir
kubectl get configmap app-config -o yaml

# Créer un Secret
kubectl create secret generic db-secret \
  --from-literal=password=supersecret

# Voir (encodé en base64)
kubectl get secret db-secret -o yaml

# Utiliser dans un Pod
cat > pod-with-config.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  containers:
  - name: myapp
    image: nginx:alpine
    env:
    - name: ENV
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: ENV
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-secret
          key: password
EOF

kubectl apply -f pod-with-config.yaml
kubectl exec myapp -- env | grep -E "ENV|DB_PASSWORD"
```

### Exercice 12 : Persistent Volumes

```yaml
# pv-pvc.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-data
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /data
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-storage
spec:
  containers:
  - name: app
    image: nginx:alpine
    volumeMounts:
    - name: data
      mountPath: /data
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: pvc-data
```

---

## Exercice 13 : Comparaison Swarm vs Kubernetes

| Aspect | Docker Swarm | Kubernetes |
|--------|--------------|------------|
| **Complexité** | Simple | Complexe |
| **Setup** | 1 commande | Multiple étapes |
| **Courbe d'apprentissage** | Faible | Élevée |
| **Scaling** | Bon | Excellent |
| **Écosystème** | Limité | Très riche |
| **Auto-healing** | Basique | Avancé |
| **Load Balancing** | Intégré | Nécessite config |
| **Rolling Updates** | Bon | Excellent |
| **Monitoring** | Basique | Avancé |
| **Use case** | PME, simple | Entreprise, complexe |

### Quand utiliser quoi ?

**Docker Swarm** :
- Petite équipe
- Infrastructure simple
- Besoin rapide
- Déjà familier avec Docker Compose
- < 10 nœuds

**Kubernetes** :
- Grande infrastructure
- Équipe DevOps dédiée
- Besoin avancés (auto-scaling, service mesh, etc.)
- Multi-cloud
- > 10 nœuds

---

## 🏆 Validation

- [ ] Initialisé un cluster Swarm
- [ ] Déployé des services Swarm
- [ ] Utilisé secrets et configs
- [ ] Mis en place rolling updates
- [ ] Installé Minikube
- [ ] Créé des deployments Kubernetes
- [ ] Utilisé ConfigMaps et Secrets K8s
- [ ] Configuré des Persistent Volumes
- [ ] Compris les différences Swarm/K8s

---

## 📊 Cheat Sheet

### Docker Swarm

```bash
# Cluster
docker swarm init
docker swarm join
docker node ls

# Services
docker service create --name web --replicas 3 -p 80:80 nginx
docker service ls
docker service ps web
docker service scale web=5
docker service logs web
docker service update --image nginx:latest web
docker service rm web

# Stack
docker stack deploy -c docker-compose.yml mystack
docker stack ls
docker stack services mystack
docker stack rm mystack

# Secrets
echo "secret" | docker secret create my_secret -
docker service create --secret my_secret nginx
```

### Kubernetes

```bash
# Cluster
minikube start
kubectl get nodes

# Deployments
kubectl create deployment nginx --image=nginx
kubectl get deployments
kubectl scale deployment nginx --replicas=3
kubectl set image deployment/nginx nginx=nginx:latest
kubectl rollout undo deployment/nginx
kubectl delete deployment nginx

# Services
kubectl expose deployment nginx --port=80 --type=NodePort
kubectl get services
kubectl delete service nginx

# Pods
kubectl get pods
kubectl logs pod-name
kubectl exec -it pod-name -- sh
kubectl describe pod pod-name

# YAML
kubectl apply -f deployment.yaml
kubectl delete -f deployment.yaml

# ConfigMap & Secrets
kubectl create configmap my-config --from-literal=key=value
kubectl create secret generic my-secret --from-literal=password=secret
kubectl get configmap/secret
```

---

**[→ Voir les solutions](../solutions/TP15-Solution.md)**

**[← Retour au README du module](../README.md)**
