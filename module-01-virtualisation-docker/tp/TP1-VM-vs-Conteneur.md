# TP1 : Comparaison VM vs Conteneur

## Objectif

Comprendre les différences fondamentales entre virtualisation traditionnelle et conteneurisation.

## Durée estimée

20 minutes

## Contexte

Avant Docker, la virtualisation reposait principalement sur des machines virtuelles (VM). Docker introduit une approche différente avec les conteneurs. Ce TP vous aide à comprendre ces différences.

## Exercices

### Exercice 1 : Analyse théorique

Répondez aux questions suivantes (réponses à vérifier dans les solutions) :

1. Quelle est la principale différence d'architecture entre une VM et un conteneur ?
2. Quels sont les avantages des conteneurs par rapport aux VMs ?
3. Quels sont les cas d'usage où une VM reste préférable ?
4. Qu'est-ce qu'un hyperviseur et a-t-on besoin d'un hyperviseur pour Docker ?
5. Combien de temps faut-il généralement pour démarrer une VM ? Et un conteneur ?

### Exercice 2 : Comparaison de ressources

Analysez le tableau suivant et complétez-le :

| Critère | Machine Virtuelle | Conteneur Docker |
|---------|-------------------|------------------|
| Temps de démarrage | ? | ? |
| Taille sur disque | ? | ? |
| Isolation | ? | ? |
| Performance | ? | ? |
| Portabilité | ? | ? |
| Consommation RAM | ? | ? |

### Exercice 3 : Schématisation

Dessinez ou décrivez :
1. L'architecture d'un serveur avec 3 VMs
2. L'architecture d'un serveur avec 3 conteneurs Docker

Identifiez les composants : Hardware, OS hôte, Hyperviseur/Docker Engine, OS invité, Applications

## Questions de réflexion

1. Pourquoi Docker ne remplace-t-il pas complètement les VMs ?
2. Peut-on faire cohabiter VMs et conteneurs sur un même serveur ?
3. En quoi la conteneurisation facilite-t-elle le DevOps ?

## Validation

- [ ] J'ai compris la différence entre VM et conteneur
- [ ] J'ai identifié les avantages et inconvénients de chaque approche
- [ ] Je sais quand utiliser l'une ou l'autre technologie

## Ressources complémentaires

- [Documentation officielle Docker - Overview](https://docs.docker.com/get-started/overview/)
- Article : "Containers vs VMs: What's the difference?"

---

**[→ Voir les solutions](../solutions/TP1-Solution.md)**

**[→ TP suivant : Installation de Docker](TP2-Installation-Docker.md)**
