# TP5 — Dockerfile à compléter
# Objectif : emballer la landing page (dossier site/) dans une image autonome.
# Complétez les TODO ci-dessous, puis : docker build -t telemach-landing:1.0 .

# TODO 1 : choisir l'image de base (un serveur web léger).
#          Indice : nginx en variante alpine, version épinglée.
FROM ______

# TODO 2 : ajouter un LABEL d'auteur (l'instruction MAINTAINER est dépréciée).
LABEL maintainer="______"

# TODO 3 : copier le contenu du dossier site/ dans le répertoire servi par nginx
#          (/usr/share/nginx/html/).
COPY ______ ______

# TODO 4 : documenter le port sur lequel le serveur écoute.
EXPOSE ______

# La commande de démarrage de nginx est déjà fournie par l'image de base :
# pas besoin de CMD ici.
