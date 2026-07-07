# TP13 — Image Jenkins « clé en main » :
#   • Jenkins LTS + JDK 21 (image officielle)
#   • un client Docker pour piloter le daemon de l'HÔTE (« Docker-out-of-Docker »)
#   • les plugins nécessaires, pré-installés
#   • une configuration 100 % décrite en fichier (JCasC) : AUCUN clic d'installation
FROM jenkins/jenkins:lts-jdk21

# ------------------------------------------------------------------------------
# 1) Outillage : client Docker + curl
#    Jenkins ne fabrique pas les images lui-même : il envoie les commandes
#    `docker build/push` au daemon Docker de l'hôte (socket monté au runtime).
#    On n'a donc besoin QUE du CLIENT docker, pas d'un daemon dans le conteneur.
# ------------------------------------------------------------------------------
USER root
ARG DOCKER_CLI_VERSION=29.6.1
RUN set -eux; \
    case "$(uname -m)" in \
      x86_64)  arch=x86_64 ;; \
      aarch64|arm64) arch=aarch64 ;; \
      *) echo "architecture non gérée: $(uname -m)"; exit 1 ;; \
    esac; \
    curl -fsSL "https://download.docker.com/linux/static/stable/${arch}/docker-${DOCKER_CLI_VERSION}.tgz" \
      | tar -xz -C /usr/local/bin --strip-components=1 docker/docker; \
    docker --version

# ------------------------------------------------------------------------------
# 2) Plugins Jenkins (les dépendances sont résolues automatiquement)
# ------------------------------------------------------------------------------
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugins -f /usr/share/jenkins/ref/plugins.txt

# ------------------------------------------------------------------------------
# 3) Configuration as Code (JCasC)
#    Tout l'état de Jenkins (sécurité, job du pipeline…) est décrit dans casc.yaml.
#    Résultat : un Jenkins reproductible, versionnable, sans configuration manuelle.
# ------------------------------------------------------------------------------
COPY casc.yaml /var/jenkins_conf/casc.yaml
ENV CASC_JENKINS_CONFIG=/var/jenkins_conf/casc.yaml
# On saute l'assistant de première connexion : tout est déjà dans casc.yaml.
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"

USER jenkins
