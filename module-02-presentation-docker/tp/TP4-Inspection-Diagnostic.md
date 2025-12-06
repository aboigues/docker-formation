# TP4 : Inspection et diagnostic des conteneurs

## Objectif

Apprendre à diagnostiquer et débugger des conteneurs Docker.

## Durée estimée

45 minutes

---

## Exercice 1 : Anatomie d'un conteneur

### 1.1 - Créer un conteneur de test

```bash
# Lancer un conteneur nginx
docker run -d --name diagnostic-web -p 8080:80 nginx

# Vérifier qu'il tourne
docker ps
curl http://localhost:8080
```

### 1.2 - Explorer le système de fichiers

```bash
# Entrer dans le conteneur
docker exec -it diagnostic-web bash

# Explorer
pwd
ls -la
cd /etc/nginx
cat nginx.conf
ls /usr/share/nginx/html
exit
```

**Questions** :
1. Où se trouve la page HTML par défaut ?
2. Où est la configuration nginx ?
3. Combien de processus tournent ? (`ps aux` dans le conteneur)

---

## Exercice 2 : Analyse des processus

### 2.1 - Processus dans le conteneur vs sur l'hôte

```bash
# Voir les processus dans le conteneur
docker exec diagnostic-web ps aux

# Voir les mêmes processus depuis l'hôte
docker top diagnostic-web

# Trouver le PID sur l'hôte
ps aux | grep nginx
```

**Questions** :
1. Les PIDs sont-ils les mêmes dans le conteneur et sur l'hôte ?
2. Quel est le processus parent (PID 1) dans le conteneur ?

### 2.2 - Inspection détaillée

```bash
# Inspection complète
docker inspect diagnostic-web

# Extraire des informations spécifiques
docker inspect diagnostic-web | grep IPAddress
docker inspect -f '{{.NetworkSettings.IPAddress}}' diagnostic-web
docker inspect -f '{{.State.Pid}}' diagnostic-web
docker inspect -f '{{.Config.Image}}' diagnostic-web
```

**Tâches** :
1. Trouvez l'adresse IP du conteneur
2. Trouvez le PID du processus principal sur l'hôte
3. Trouvez la date de création du conteneur

---

## Exercice 3 : Debugging d'un conteneur qui ne démarre pas

### 3.1 - Simuler un problème

```bash
# Créer un conteneur avec une commande qui échoue
docker run -d --name broken-container nginx bash -c "exit 1"

# Vérifier le statut
docker ps -a | grep broken

# Voir les logs
docker logs broken-container

# Voir pourquoi il s'est arrêté
docker inspect broken-container | grep -A 5 "State"
```

### 3.2 - Débugger avec --entrypoint

```bash
# Forcer un shell pour débugger
docker run -it --entrypoint /bin/bash nginx

# Une fois dedans, tester la commande qui pose problème
exit
```

**Questions** :
1. Pourquoi le conteneur s'est arrêté ?
2. Comment forcer un shell même si le conteneur crashe ?

---

## Exercice 4 : Analyser la consommation de ressources

### 4.1 - Créer des conteneurs avec différentes charges

```bash
# Conteneur avec stress CPU
docker run -d --name cpu-stress alpine sh -c "while true; do :; done"

# Conteneur normal
docker run -d --name web-normal nginx

# Voir les stats
docker stats
```

### 4.2 - Limiter les ressources

```bash
# Limiter la RAM
docker run -d --name limited-nginx --memory="100m" nginx

# Limiter le CPU
docker run -d --name cpu-limited --cpus="0.5" nginx

# Vérifier avec stats
docker stats --no-stream
```

**Questions** :
1. Quelle est la différence de consommation CPU ?
2. Que se passe-t-il si un conteneur dépasse sa limite de RAM ?

---

## Exercice 5 : Réseau et connectivité

### 5.1 - Tester la connectivité

```bash
# Créer deux conteneurs sur le même réseau
docker network create mon-reseau
docker run -d --name web1 --network mon-reseau nginx
docker run -d --name web2 --network mon-reseau nginx

# Tester la connectivité entre conteneurs
docker exec web1 ping -c 3 web2
docker exec web1 curl http://web2
```

### 5.2 - Inspecter le réseau

```bash
# Voir les réseaux
docker network ls

# Inspecter un réseau
docker network inspect mon-reseau

# Voir les conteneurs connectés
docker network inspect -f '{{range .Containers}}{{.Name}} {{end}}' mon-reseau
```

**Questions** :
1. Les conteneurs peuvent-ils communiquer par nom ?
2. Quelle est la plage IP du réseau créé ?

---

## Exercice 6 : Volumes et données

### 6.1 - Voir les modifications du filesystem

```bash
# Créer un conteneur et modifier des fichiers
docker run -d --name data-test nginx
docker exec data-test bash -c "echo 'test' > /tmp/test.txt"
docker exec data-test rm /usr/share/nginx/html/index.html

# Voir les différences
docker diff data-test
```

**Légende** :
- `A` = Ajouté
- `C` = Modifié
- `D` = Supprimé

### 6.2 - Commit un conteneur (créer une image à partir d'un conteneur)

```bash
# Modifier un conteneur
docker exec data-test bash -c "echo '<h1>Custom</h1>' > /usr/share/nginx/html/index.html"

# Créer une image à partir de ce conteneur
docker commit data-test custom-nginx

# Vérifier
docker images | grep custom

# Tester la nouvelle image
docker run -d -p 8081:80 --name test-custom custom-nginx
curl http://localhost:8081
```

**Note** : `docker commit` est déconseillé en production. Préférer les Dockerfiles.

---

## Exercice 7 : Scénario de debugging réel

### Problème : Un conteneur MySQL ne démarre pas

```bash
# Tentative de lancement (va échouer)
docker run -d --name mysql-broken mysql:8.0

# Vérifier le statut
docker ps -a | grep mysql-broken

# Voir les logs (le plus important !)
docker logs mysql-broken
```

**Analyse** : L'erreur dit qu'il manque une variable d'environnement.

**Solution** :
```bash
# Supprimer le conteneur cassé
docker rm mysql-broken

# Relancer avec la variable d'environnement
docker run -d --name mysql-ok \
  -e MYSQL_ROOT_PASSWORD=secret123 \
  mysql:8.0

# Vérifier
docker ps | grep mysql-ok
docker logs mysql-ok
```

---

## 🏆 Validation

Vous devez maintenant savoir :

- [ ] Inspecter un conteneur avec `docker inspect`
- [ ] Analyser les logs avec `docker logs`
- [ ] Voir les processus avec `docker top` et `ps aux`
- [ ] Monitorer les ressources avec `docker stats`
- [ ] Débugger un conteneur qui ne démarre pas
- [ ] Utiliser `docker exec` pour entrer dans un conteneur
- [ ] Comprendre le système de fichiers d'un conteneur
- [ ] Tester la connectivité réseau entre conteneurs

---

## Commandes de diagnostic essentielles

```bash
docker ps -a              # Voir tous les conteneurs et leur statut
docker logs <container>   # Logs (souvent la clé du problème)
docker inspect <container> # Informations détaillées
docker exec -it <container> sh # Entrer dans le conteneur
docker stats              # Monitoring des ressources
docker top <container>    # Processus
docker diff <container>   # Modifications filesystem
```

---

**[→ Voir les solutions](../solutions/TP4-Solution.md)**

**[→ Module suivant : Ligne de commande avancée](../../module-03-ligne-commande/README.md)**
