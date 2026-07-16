# Post-mortem — la barrière du scan d'images

**Date :** 16 juillet 2026
**Périmètre :** PR #23 (mergée) puis PR #27 (correctif)
**Résumé en une ligne :** une demande d'une ligne — « fais échouer le scan sur les
HIGH/CRITICAL » — a produit six images maison publiées et cinq TP recâblés, là où
**changer un tag suffisait**. La cause racine n'a été identifiée qu'à la fin.

---

## 1. Le point de départ

Le scan hebdomadaire était en *report-only* : les CVE remontaient dans « Code
scanning », le job restait vert. Demande : le faire échouer sur les CVE
HIGH/CRITICAL.

Premier résultat : **16 images sur 16 en échec.** Un signal qui bloque à 100 %
n'est pas un signal.

## 2. Ce qu'on a appris

### 2.1 « Corrigible » ne veut pas dire « corrigeable par vous »

`--ignore-unfixed` retient les CVE dont un correctif **existe**, pas celles qu'on
peut **appliquer**. Sur une image tierce, une CVE de binaire compilé n'est
corrigeable que par le mainteneur amont.

### 2.2 Les CVE de stdlib Go sont des faux positifs structurels

Un binaire Go est statiquement lié : la version du toolchain est gravée dedans.
Trivy la lit et compare des numéros de version — il ne sait pas si le code
vulnérable est **atteint**.

Sur le `gosu` de `mariadb:11.8` (go1.24.6, gosu v1.19.0) :

| Outil | Verdict |
|---|---|
| Trivy | **15** CVE HIGH/CRITICAL |
| `govulncheck` (atteignabilité officielle Go) | **0** vulnérabilité atteignable |

`gosu` fait un `setuid` puis un `exec`. Il n'appelle jamais `net/http`, où sont la
plupart de ces CVE. D'où la barrière sur `--pkg-types os` uniquement.

### 2.3 Le vrai signal, c'est l'âge du tag — pas le nombre de CVE

Cadence de reconstruction amont des 18 images du dépôt. Deux populations, sans
recouvrement :

| Type | Exemples | Âge | Ses CVE |
|---|---|---|---|
| **Tag glissant** | nginx 0 j, drupal 0 j, httpd 2 j, mysql 6 j, jenkins 6 j, golang 7 j, postgres 8 j, adminer 11 j, mariadb 14 j, node 21 j, redis 22 j, traefik 22 j | médiane **8 j**, max **22 j** | **transitoires** |
| **Version épinglée** | alloy 34 j, grafana 44 j, prometheus 48 j, loki 64 j, registry:2 **516 j** | > 30 j | **permanentes** |

Sur un tag glissant, les CVE s'effacent au rebuild suivant, sans action de notre
part. Sur une version épinglée, personne ne les corrigera jamais.

**Le cas d'école :** `wordpress:6.8-php8.3-apache` portait **606 CVE** de paquets
OS. Pas par fatalité — parce que Docker a cessé de reconstruire ce tag **226 jours**
plus tôt. `wordpress:7.0-php8.5-apache`, reconstruit la veille : **0 CVE**.

> Vos CVE viennent rarement d'une fatalité, souvent d'un épinglage oublié.

### 2.4 La fréquence n'était pas le levier

Espacer les scans ne réduit pas la probabilité qu'un scan tombe pendant une
fenêtre « CVE publiée, amont pas encore reconstruit » : elle vaut (durée de
fenêtre / période de rebuild), **indépendante de l'intervalle**. Espacer réduit
seulement le *nombre* d'alertes, en retardant la détection des vrais problèmes.

La dimension manquante était l'âge. D'où la règle finale : **CVE de paquets OS
ET image de plus de 30 jours** (seuil calé au-dessus du pire tag glissant observé,
22 j). L'hebdomadaire redevient correct.

### 2.5 Pièges d'outillage rencontrés

- **Les images locales périment.** Trivy scanne l'image du démon Docker si elle y
  est déjà, sinon il la tire du registre. Une copie locale vieille de plusieurs
  semaines donne un résultat faux. La CI, qui part d'un runner neuf, est plus
  fiable que le poste du développeur.
- **Les builds reproductibles n'ont pas de date.** distroless, ko et consorts
  figent `created` à l'epoch 1970 pour rendre le digest déterministe :
  `gcr.io/distroless/static-debian12` sort à **20650 jours**. Toute heuristique
  d'âge doit traiter une date antérieure à 2015 comme « inconnue », pas comme
  « abandonnée ».
- **Le multi-arch n'est pas optionnel.** Les images amont publient jusqu'à
  7 architectures. Une image durcie construite sur un poste amd64 est
  mono-architecture : elle enverrait tout stagiaire sur Mac Apple Silicon dans
  l'émulation QEMU — strictement pire que l'officielle qu'elle remplace.

---

## 3. Ce qui a mal tourné

### 3.1 La cause racine n'a jamais été vérifiée (erreur principale)

**La question à poser en premier — « ce tag est-il encore reconstruit ? » — ne l'a
été qu'à la toute fin.** Tout le reste en découle : six images construites,
publiées et maintenues, cinq TP recâblés, alors qu'une bascule de tag réglait le
cas principal.

Le pire : cette vérification avait été commencée, puis interrompue, et **jamais
reprise**. Une piste ouverte et abandonnée vaut une piste jamais vue.

### 3.2 Une preuve retournée à l'envers

`nginx:1.30-alpine` a été présenté comme la démonstration que « le tapis roulant
tourne en direct, il faut tout durcir » : image verte hier, 8 CVE aujourd'hui.

C'était une **copie locale périmée**. Le registre en avait 0 : Docker avait
reconstruit nginx et corrigé `c-ares`, `libexpat` et `curl` tout seul. nginx
démontrait exactement **l'inverse** — la valeur des images officielles. Un argument
à décharge servi comme pièce à charge, faute d'avoir vérifié l'outil de mesure.

### 3.3 Un demi-état, pire que les deux extrêmes

Les images ont été publiées et leurs Dockerfiles committés — **sans que rien ne les
référence**. La barrière scannait toujours les images amont et restait rouge : le
travail ne servait à rien. Par prudence sur un choix pédagogique, on a produit un
état qui n'était ni l'un ni l'autre. Il a fallu que le formateur le signale.

### 3.4 Erreurs de mesure et de méthode

- **« 5 images rouges » alors que la table en montrait 6** : `postgres:18-alpine`
  (1 CVE `c-ares`) oublié en rédigeant. Sans rattrapage, la barrière serait restée
  rouge malgré tout le travail.
- **Les Dockerfiles de `hardened/` réintroduisaient les images amont** dans la
  matrice via leurs lignes `FROM` : la barrière aurait bloqué sur les CVE que ces
  Dockerfiles corrigent. Résolu par le marqueur `# image-scan: ignore` que le dépôt
  prévoyait déjà.
- **Un script de comparaison de digests comparait un manifeste multi-arch à un
  manifeste de plateforme** — deux objets qui ne peuvent pas coïncider. Il a
  déclaré « périmées » sept images qui étaient à jour.
- **Un script de mesure inventait des verdicts** : le scan échouait, la sortie
  était vide, et le test bash affichait quand même « vert ». Un script qui ne sait
  pas échouer bruyamment produit des résultats pires que pas de script du tout.
- **Piège zsh** : `docker build -t "hardened-$n:test"` — zsh interprète `:t` comme
  un modificateur de paramètre. Résultat : des images nommées
  `hardened-adminerest:latest`, avec le tag `latest` que le dépôt s'interdit.
  Écrire `${n}`.
- **Un dépôt public parasite** (`telemachlearning/authcheck`) créé par un test
  d'authentification, là où l'échec du vrai push aurait suffi à diagnostiquer.

### 3.5 Ce qui a fonctionné

- Le refus initial de bloquer sur 16/16 : la première réaction — « ce n'est pas
  une barrière, c'est du bruit » — était juste.
- La vérification systématique **avant** publication : le mono-architecture a été
  attrapé avant que les images ne partent, pas après.
- Le défaut distroless de l'heuristique d'âge, trouvé par une simulation sur la
  matrice complète, avant merge.

---

## 4. Règles retenues

1. **Chercher la cause racine avant de construire le remède.** Devant une image
   qui accumule des CVE, la première question est « son tag est-il encore
   entretenu ? », pas « comment la durcir ? ». Une reprise de tag coûte une ligne ;
   une image maison coûte un cycle de vie.
2. **Une piste interrompue doit être rouverte.** Ce qui a été mis de côté doit
   être noté et repris, pas oublié.
3. **Vérifier l'instrument avant la mesure.** Une image locale périmée, un digest
   comparé à un autre type de digest, un script muet en cas d'échec : chacun
   produit une conclusion fausse avec l'apparence d'une donnée.
4. **Ne jamais laisser un demi-état.** Soit on câble, soit on ne publie pas.
5. **Une barrière ne se met que sur ce qui est actionnable.** Barrière sur ce
   qu'on construit et sur les tags abandonnés ; veille sur ce qu'on consomme et
   qui s'entretient tout seul.
6. **Une règle sans passe-droit.** La barrière traite `telemachlearning/*` comme
   n'importe quelle image : nos propres images rougissent quand elles vieillissent.

---

## 5. État final

| Image | Décision |
|---|---|
| `wordpress:6.8-php8.3-apache` (226 j, 606 CVE) | → `wordpress:7.0-php8.5-apache` (0 CVE) |
| `postgres:18-alpine`, `adminer:5`, `jenkins/jenkins:lts-jdk21` | → officielles : tags entretenus, CVE transitoires |
| `grafana/grafana:13.0.2` (44 j), `gcr.io/cadvisor/cadvisor:v0.55.1` (203 j) | → durcies dans [`hardened/`](hardened/) : versions réellement figées |

**Barrière :** CVE de paquets OS **ET** image > 30 jours. **Veille :** inchangée,
tout remonte dans « Code scanning ».

**Reste ouvert :** les dépôts `telemachlearning/wordpress`, `postgres`, `adminer`
et `jenkins` sont devenus inutiles ; la reconstruction périodique de Grafana et
cAdvisor n'est pas automatisée — la barrière signalera quand elles auront vieilli.

---

<div align="center">

**[Telemach Learning](https://www.telemach-learning.fr)** — Formations DevOps, Cloud & Conteneurs

🌐 [www.telemach-learning.fr](https://www.telemach-learning.fr)

© 2026 Telemach Learning — Code formation DEVOPS-001

</div>
