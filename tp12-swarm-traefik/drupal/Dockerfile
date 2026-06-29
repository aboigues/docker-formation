# Image Drupal « Telemach Swarm » : Drupal officiel + drush (install non-interactive)
# + un en-tête HTTP qui révèle QUEL réplica a répondu (preuve de répartition de charge).
FROM drupal:11.3-apache

# drush n'est PAS dans l'image officielle : on l'ajoute via composer (au BUILD, réseau OK).
# Retry : les téléchargements de dépendances (dist GitHub) peuvent échouer ponctuellement.
RUN for attempt in 1 2 3; do \
      composer --working-dir=/opt/drupal require drush/drush --no-interaction --no-progress && break; \
      echo "composer require échoué (tentative $attempt) — nouvelle tentative…"; sleep 5; \
    done \
 && test -x /opt/drupal/vendor/bin/drush \
 && ln -sf /opt/drupal/vendor/bin/drush /usr/local/bin/drush

# settings.php « env-driven » : tous les réplicas pointent vers la même BDD.
COPY settings.php /opt/drupal/web/sites/default/settings.php

# En-tête X-Served-By = hostname du conteneur (Docker injecte la variable HOSTNAME).
# Permet de constater que des réplicas DIFFÉRENTS répondent derrière Traefik.
RUN a2enmod headers \
 && printf 'PassEnv HOSTNAME\nHeader set X-Served-By "%%{HOSTNAME}e"\n' \
      > /etc/apache2/conf-available/x-served-by.conf \
 && a2enconf x-served-by

# L'install (drush) doit pouvoir écrire dans sites/default (settings + fichiers générés).
RUN chmod -R 0777 /opt/drupal/web/sites/default
