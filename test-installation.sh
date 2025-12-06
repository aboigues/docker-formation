#!/bin/bash

# Script de test de l'installation Docker
# À exécuter pour vérifier que votre environnement est prêt pour la formation

set -e  # Arrêter en cas d'erreur

echo "========================================="
echo "Test d'installation Docker"
echo "========================================="
echo ""

# Couleurs pour l'affichage
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction pour afficher un succès
success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Fonction pour afficher une erreur
error() {
    echo -e "${RED}✗${NC} $1"
}

# Fonction pour afficher un avertissement
warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Test 1: Docker est installé
echo "Test 1: Vérification de Docker..."
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    success "Docker est installé: $DOCKER_VERSION"
else
    error "Docker n'est pas installé"
    echo "   → Installez Docker depuis https://docs.docker.com/get-docker/"
    exit 1
fi
echo ""

# Test 2: Docker Compose est disponible
echo "Test 2: Vérification de Docker Compose..."
if docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version)
    success "Docker Compose est disponible: $COMPOSE_VERSION"
else
    error "Docker Compose n'est pas disponible"
    echo "   → Docker Compose devrait être inclus avec Docker Desktop"
    exit 1
fi
echo ""

# Test 3: Docker daemon est en cours d'exécution
echo "Test 3: Vérification du Docker daemon..."
if docker info &> /dev/null; then
    success "Docker daemon est en cours d'exécution"
else
    error "Docker daemon n'est pas en cours d'exécution"
    echo "   → Linux: sudo systemctl start docker"
    echo "   → Windows/Mac: Lancez Docker Desktop"
    exit 1
fi
echo ""

# Test 4: Permissions (pas de sudo nécessaire sur Linux)
echo "Test 4: Vérification des permissions..."
if docker ps &> /dev/null; then
    success "Permissions OK (pas de sudo nécessaire)"
else
    warning "Vous pourriez avoir besoin de sudo"
    echo "   → Linux: sudo usermod -aG docker \$USER"
    echo "   → Puis se déconnecter/reconnecter"
fi
echo ""

# Test 5: Capacité à télécharger et exécuter des images
echo "Test 5: Test d'exécution d'un conteneur..."
if docker run --rm hello-world &> /tmp/docker-test.log; then
    success "Conteneur hello-world exécuté avec succès"
else
    error "Échec de l'exécution du conteneur"
    cat /tmp/docker-test.log
    exit 1
fi
echo ""

# Test 6: Espace disque disponible
echo "Test 6: Vérification de l'espace disque..."
AVAILABLE_SPACE=$(df -h / | awk 'NR==2 {print $4}')
success "Espace disponible: $AVAILABLE_SPACE"
echo "   → Au moins 10 GB recommandés pour la formation"
echo ""

# Test 7: Réseau (capacité à télécharger des images)
echo "Test 7: Test de connectivité Docker Hub..."
if docker pull alpine:latest &> /dev/null; then
    success "Connexion à Docker Hub OK"
    docker rmi alpine:latest &> /dev/null  # Nettoyage
else
    error "Impossible de se connecter à Docker Hub"
    echo "   → Vérifiez votre connexion Internet"
    echo "   → Vérifiez les paramètres proxy si nécessaire"
    exit 1
fi
echo ""

# Test 8: Vérification des ressources système
echo "Test 8: Informations système..."
DOCKER_INFO=$(docker info 2>/dev/null)

# CPU
CPUS=$(echo "$DOCKER_INFO" | grep "CPUs:" | awk '{print $2}')
if [ -n "$CPUS" ]; then
    success "CPUs disponibles: $CPUS"
fi

# RAM
MEMORY=$(echo "$DOCKER_INFO" | grep "Total Memory:" | awk '{print $3 $4}')
if [ -n "$MEMORY" ]; then
    success "Mémoire totale: $MEMORY"
fi

# OS
OS_TYPE=$(echo "$DOCKER_INFO" | grep "Operating System:" | cut -d':' -f2 | xargs)
if [ -n "$OS_TYPE" ]; then
    success "Système: $OS_TYPE"
fi

echo ""

# Résumé
echo "========================================="
echo "Résumé"
echo "========================================="
success "Installation Docker validée !"
echo ""
echo "Vous êtes prêt à commencer la formation !"
echo ""
echo "Prochaines étapes:"
echo "1. Nettoyez les conteneurs de test: docker system prune"
echo "2. Commencez avec le Module 1: cd module-01-virtualisation-docker"
echo "3. Lisez le README.md principal pour la structure complète"
echo ""
echo "Commandes utiles:"
echo "  docker ps          - Voir les conteneurs en cours"
echo "  docker images      - Voir les images téléchargées"
echo "  docker system df   - Voir l'espace utilisé"
echo ""
success "Bonne formation ! 🐳"
