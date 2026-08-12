# Correctif proposé par Mirador

## Problème
Le scan de vulnérabilités des images a détecté une CVE HIGH (CVE-2026-33630) dans la librairie c-ares embarquée dans l'image `postgres:18-alpine`. Cette image a 33 jours d'âge, ce qui dépasse le seuil toléré (30 jours). L'amont PostgreSQL ne met plus à jour ce tag.

## Solution
Mettre à jour vers une version plus récente du tag postgres:18-alpine ou considérer un passage à postgres:17 ou une autre version maintenue et activement reconstruite.

## Détails de la vulnérabilité
- **CVE** : CVE-2026-33630
- **Sévérité** : HIGH
- **Librairie affectée** : c-ares 1.34.6-r0
- **Version corrigée** : c-ares 1.34.8-r0
- **Type** : Use-after-free / double-free in query-completion handling

## Actions requises
1. Vérifier la disponibilité d'une version plus récente de `postgres:18-alpine` chez l'amont (Docker Hub)
2. Si aucune version plus récente n'existe, envisager un passage à `postgres:17-alpine` ou `postgres:16-alpine`
3. Mettre à jour le Dockerfile ou tout fichier de configuration qui référence cette image
4. Relancer le scan de vulnérabilités pour valider la correction

> Correctif à compléter/appliquer par un responsable (Mirador n'a pas pu le matérialiser automatiquement).
