# Solutions - TP16 : Swarm et Kubernetes

## Docker Swarm - Points clés

### Initialisation multi-node (simulation)

```bash
# Créer 3 VMs avec Docker Machine (ou VMs réelles)
docker-machine create --driver virtualbox manager
docker-machine create --driver virtualbox worker1
docker-machine create --driver virtualbox worker2

# Sur le manager
docker swarm init --advertise-addr <MANAGER-IP>

# Récupérer le token
docker swarm join-token worker

# Sur les workers (utiliser le token)
docker swarm join --token <TOKEN> <MANAGER-IP>:2377

# Vérifier
docker node ls
```

### Stack complète avec base de données

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password
    volumes:
      - db-data:/var/lib/postgresql/data
    networks:
      - backend
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.role == manager

  api:
    image: myapi:latest
    secrets:
      - db_password
      - api_key
    networks:
      - backend
      - frontend
    deploy:
      replicas: 3
      update_config:
        parallelism: 1
        delay: 10s
      restart_policy:
        condition: on-failure

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    networks:
      - frontend
    deploy:
      replicas: 2
      placement:
        constraints:
          - node.role == worker

secrets:
  db_password:
    external: true
  api_key:
    external: true

volumes:
  db-data:

networks:
  frontend:
    driver: overlay
  backend:
    driver: overlay
    internal: true
```

---

## Kubernetes - Déploiement complet

### Application 3-tiers

```yaml
# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: myapp
---
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: myapp
data:
  ENV: "production"
  LOG_LEVEL: "info"
---
# secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
  namespace: myapp
type: Opaque
data:
  password: c3VwZXJzZWNyZXQ=  # base64: supersecret
---
# database.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: myapp
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: myapp
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        env:
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: password
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: postgres-storage
        persistentVolumeClaim:
          claimName: postgres-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: myapp
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
  clusterIP: None
---
# api.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: api
        image: myapi:latest
        envFrom:
        - configMapRef:
            name: app-config
        env:
        - name: DB_HOST
          value: postgres
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: password
        ports:
        - containerPort: 3000
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: myapp
spec:
  selector:
    app: api
  ports:
  - port: 3000
---
# frontend.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: myapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: myapp
spec:
  selector:
    app: frontend
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 80
```

Déploiement:
```bash
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f secret.yaml
kubectl apply -f database.yaml
kubectl apply -f api.yaml
kubectl apply -f frontend.yaml

kubectl get all -n myapp
```

---

## Commandes de troubleshooting

### Docker Swarm

```bash
# Logs d'un service
docker service logs <service> --tail 50 -f

# Inspect un service
docker service inspect <service> --pretty

# Voir les tâches échouées
docker service ps <service> --filter "desired-state=shutdown"

# Forcer update
docker service update --force <service>

# Vider un nœud
docker node update --availability drain <node>

# Réactiver un nœud
docker node update --availability active <node>
```

### Kubernetes

```bash
# Logs
kubectl logs <pod> -f
kubectl logs <pod> -c <container>
kubectl logs -l app=myapp --all-containers=true

# Describe
kubectl describe pod <pod>
kubectl describe deployment <deployment>
kubectl describe node <node>

# Events
kubectl get events --sort-by='.lastTimestamp'

# Exec
kubectl exec -it <pod> -- sh

# Port-forward
kubectl port-forward <pod> 8080:80

# Restart deployment
kubectl rollout restart deployment/<deployment>

# Debugging
kubectl run debug --image=busybox --rm -it -- sh
```

---

## Best Practices

### Swarm

1. Toujours 3+ managers pour HA
2. Utiliser overlay networks
3. Secrets pour données sensibles
4. Resource limits sur tous services
5. Health checks configurés
6. Placement constraints appropriés
7. Update config pour zero-downtime

### Kubernetes

1. Utiliser namespaces pour isolation
2. Resource requests/limits obligatoires
3. Liveness + Readiness probes
4. ConfigMaps pour configuration
5. Secrets pour données sensibles
6. PersistentVolumes pour données
7. RBAC pour sécurité
8. Network Policies pour isolation
9. Labels et selectors cohérents
10. GitOps pour déploiements

---

**[← Retour au TP](../tp/TP15-Swarm-Kubernetes.md)**
