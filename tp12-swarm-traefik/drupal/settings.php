<?php
// settings.php « cloud-native » : la connexion BDD vient de l'ENVIRONNEMENT, pas
// d'un fichier figé. Du coup, les 3 réplicas Drupal partagent EXACTEMENT la même
// configuration (même BDD) sans étape d'installation par réplica.
// (Fichier fourni par l'image — démo de formation. En prod : secrets, pas d'env en clair.)

$databases['default']['default'] = [
  'driver'    => 'mysql',
  'host'      => getenv('DRUPAL_DB_HOST') ?: 'db',
  'port'      => getenv('DRUPAL_DB_PORT') ?: '3306',
  'database'  => getenv('DRUPAL_DB_NAME') ?: 'drupal',
  'username'  => getenv('DRUPAL_DB_USER') ?: 'drupal',
  'password'  => getenv('DRUPAL_DB_PASSWORD') ?: 'drupal',
  'prefix'    => '',
  'collation' => 'utf8mb4_general_ci',
];

// Sel de hachage : doit être IDENTIQUE sur tous les réplicas (sinon sessions/CSRF cassés).
$settings['hash_salt'] = getenv('DRUPAL_HASH_SALT') ?: 'telemach-swarm-demo-hash-salt-please-change';

// Démo : on accepte n'importe quel Host (Traefik route déjà). En prod : liste blanche.
$settings['trusted_host_patterns'] = ['^.+$'];

$settings['config_sync_directory'] = 'sites/default/files/config_sync';
$settings['update_free_access'] = FALSE;
