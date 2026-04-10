# Spécification de la Game Loop - RaidLead

## Vue d'ensemble

RaidLead est conçu comme un jeu de gestion de guilde MMORPG avec une progression en trois phases distinctes, inspiré des jeux de management sportif comme Football Manager. Le joueur gère une guilde dans un environnement compétitif où il doit recruter, former et gérer des joueurs simulés pour atteindre l'excellence.

### Concept Central
- **Gestion stratégique** : Recrutement, formation, équipement des membres
- **Gestion humaine** : Relations interpersonnelles, cohésion d'équipe, gestion des conflits
- **Compétition progressive** : 3 niveaux de jeu avec complexité croissante
- **Évolution temporelle** : Nouvelles extensions, équipements, mécaniques par phase

## Architecture de Progression

### Phase 1 : Niveau Serveur (Early Game)
**Durée estimée** : 20-40 heures de jeu

#### Objectifs
- Établir une guilde compétitive sur le serveur local
- Maîtriser les mécaniques de base
- Atteindre le TOP 1 du classement serveur
- Débloquer l'accès au niveau national

#### Mécaniques Principales
- **Pool de recrutement local** : 15-30 joueurs disponibles
- **Compétition avec 9 guildes IA** de niveau similaire
- **Contenu PvE** : Donjons et raids de base (style WoW Vanilla)
- **Système de réputation simple** : Basé sur les succès en raid
- **Économie de base** : Gestion de l'or, équipement simple

#### Défis Spécifiques
- Apprentissage des personnalités des joueurs
- Gestion de l'intégration et de la cohésion
- Optimisation des compositions de groupe
- Équilibrage entre progression et moral

#### Condition de Victoire
- **TOP 1 serveur** pendant au moins 2 semaines consécutives
- **Guilde stable** : Minimum 15 membres actifs avec intégration > 70%
- **Progression PvE** : Avoir clearing au moins 80% du contenu disponible

---

### Phase 2 : Niveau National (Mid Game)
**Durée estimée** : 40-80 heures de jeu

#### Nouveaux Enjeux
- Pool de recrutement national (50-100 joueurs)
- Compétition avec 50+ guildes nationales
- Mécaniques de célébrité et médiatisation
- Système de sponsors et contrats
- Gestion des dramas publics

#### Nouvelles Mécaniques

##### Système de Célébrité
- **Streamers** : Certains joueurs deviennent populaires, attirent l'attention
- **Influence publique** : Les actions de la guilde sont plus visibles
- **Fans et détracteurs** : Système de popularité publique
- **Gestion d'image** : Impact des décisions sur la réputation

##### Mécaniques de Streaming et Médias
- **Joueurs streamers** : Membres qui diffusent leurs activités
  - Avantages : Visibilité accrue, revenus supplémentaires
  - Inconvénients : Pression, risque de drama, divulgation de stratégies
- **Interviews et apparitions** : Événements médiatiques à gérer
- **Réseaux sociaux** : Impact des posts et réactions des membres

##### Système de Sponsors
- **Contrats de sponsoring** : Accords avec marques fictives
- **Obligations contractuelles** : Utilisation d'équipement spécifique, apparitions
- **Revenus supplémentaires** : Financement d'équipement premium
- **Conflits d'intérêts** : Gestion entre sponsors concurrents

##### Dramas et Gestion de Crise
- **Scandales publics** : Révélation de comportements problématiques
- **Conflits médiatisés** : Disputes internes qui deviennent publiques
- **Gestion de la communication** : Réponses aux controverses
- **Impact sur le recrutement** : Les dramas affectent l'attractivité

#### Pool de Recrutement National
- **Joueurs semi-professionnels** : Plus exigeants, plus talentueux
- **Agents et représentants** : Négociations plus complexes
- **Clauses de départ** : Contrats avec conditions spéciales
- **Rivalités entre guildes** : Débauchage actif et contre-offres

#### Nouveau Contenu PvE
- **Extensions simulées** : Burning Crusade, Wrath of the Lich King
- **Raids héroïques** : Difficultés supplémentaires
- **Méta évolutive** : Changements d'équilibrage simulés
- **Contenu exclusif** : Accès prioritaire pour les meilleures guildes

#### Condition de Victoire
- **TOP 1 national** pendant au moins 1 mois
- **Gestion médiatique réussie** : Pas plus de 2 dramas majeurs par an
- **Stabilité économique** : Contrats de sponsoring actifs
- **Excellence PvE** : World First ou Top 3 sur au moins 3 raids majeurs

---

### Phase 3 : Niveau Esport (End Game)
**Durée estimée** : 80+ heures de jeu

#### Vision d'Excellence
- Compétition mondiale avec les meilleures guildes
- Mécaniques de coaching et staff élargi
- Tournois internationaux officiels
- Gestion de la pression extrême

#### Nouvelles Mécaniques Esport

##### Structure Professionnelle
- **Staff élargi** : Coachs, analystes, managers, psychologues sportifs
- **Bootcamps** : Périodes d'entraînement intensif
- **Analyse de performance** : Métriques avancées et optimisation
- **Stratégies méta** : Développement de tactiques uniques

##### Tournois Internationaux
- **World Championship** : Tournoi annuel principal
- **Regional Qualifiers** : Compétitions par continent
- **Invitational Events** : Tournois privés prestigieux
- **Prize Pools** : Récompenses financières importantes

##### Gestion de la Pression
- **Burnout** : Risque accru avec la pression
- **Support psychologique** : Nécessité de staff spécialisé
- **Gestion du stress** : Événements de décompression
- **Rotation des joueurs** : Banc de remplaçants

##### Transferts Internationaux
- **Marché mondial** : Joueurs de tous les continents
- **Négociations complexes** : Agents, clauses, visas
- **Période de transfert** : Fenêtres limitées dans l'année
- **Salary Cap** : Limitations budgétaires

#### Mécaniques Avancées

##### Intelligence Artificielle Adaptative
- **IA évolutive** : Les guildes concurrentes s'adaptent aux stratégies du joueur
- **Méta-game** : Évolution constante des stratégies optimales
- **Scouting avancé** : Espionnage et contre-espionnage

##### Système de Legacy
- **Hall of Fame** : Reconnaissance des achievements
- **Influence sur le jeu** : Impact des réussites sur l'univers
- **Successeurs** : Formation de la prochaine génération

#### Condition de Victoire
- **World Champion** : Remporter le championnat mondial
- **Dynastie** : Maintenir le niveau pendant plusieurs saisons
- **Innovation** : Développer des stratégies copiées par d'autres guildes
- **Legacy** : Laisser une marque durable dans l'histoire du jeu

---

## Mécaniques Transversales

### Système de Compétition Entre Guildes

#### Classements Dynamiques
- **Points de progression** : Basés sur les clears de contenu
- **Timing** : Bonus pour les world/server first
- **Consistance** : Points de stabilité pour régularité
- **Innovation** : Bonus pour stratégies créatives

#### Débauchage et Contre-Offres
- **Tentatives de recrutement** : Les guildes rivales chassent vos meilleurs éléments
- **Loyauté** : Impact de l'intégration et de la satisfaction
- **Négociations** : Système de surenchères et contre-propositions
- **Clauses de non-concurrence** : Protections contractuelles

### Gestion de la Cohésion d'Équipe

#### Dynamiques de Groupe
- **Cliques** : Formation de sous-groupes dans la guilde
- **Leaders naturels** : Émergence de joueurs influents
- **Conflits de personnalité** : Gestion des incompatibilités
- **Événements team-building** : Activités pour renforcer les liens

#### Système de Moral Collectif
- **Ambiance générale** : Métrique globale de l'humeur de guilde
- **Contagion émotionnelle** : Propagation des états d'esprit
- **Rituel et traditions** : Création de culture de guilde
- **Gestion des échecs** : Impact des wipes sur le groupe

### Évolution du Contenu

#### Timeline de Contenu
- **Phase 1** : Vanilla WoW (MC, BWL, AQ, Naxx)
- **Phase 2** : BC + Wrath (Kara, TK, SSC, BT, ICC...)
- **Phase 3** : Contenu moderne et competitive (Mythic+, etc.)

#### Méta-Game Évolutif
- **Patches simulés** : Changements d'équilibrage périodiques
- **Découverte de stratégies** : Émergence de nouvelles tactiques
- **Adaptation forcée** : Nécessité de s'adapter aux changements

---

## Courbe de Difficulté et Équilibrage

### Progression de la Complexité

#### Phase 1 : Apprentissage
- **Tutoriels intégrés** : Découverte progressive des mécaniques
- **Marge d'erreur** : Possibilité de récupération après erreurs
- **Feedback clair** : Indication des raisons d'échec
- **Objectifs atteignables** : Progression visible et régulière

#### Phase 2 : Maîtrise
- **Multitasking requis** : Gestion simultanée de plusieurs aspects
- **Décisions à long terme** : Impact des choix sur plusieurs mois
- **Gestion de crise** : Résolution de problèmes complexes
- **Optimisation fine** : Recherche de l'excellence

#### Phase 3 : Excellence
- **Perfection requise** : Marge d'erreur minimale
- **Innovation nécessaire** : Création de nouvelles approches
- **Pression temporelle** : Décisions rapides sous stress
- **Adaptation constante** : Évolution permanente des défis

### Mécaniques d'Aide à la Progression

#### Système de Conseils
- **IA consultante** : Suggestions basées sur la situation
- **Historique des décisions** : Analyse des patterns réussis
- **Benchmark** : Comparaison avec les meilleures pratiques
- **Alertes prédictives** : Warnings sur les risques à venir

#### Outils d'Analyse
- **Statistiques détaillées** : Métriques de performance
- **Graphiques de progression** : Visualisation des tendances
- **Comparaisons historiques** : Évolution dans le temps
- **Projections** : Prédictions basées sur les données

---

## Mécaniques de Fin de Jeu

### Rejouabilité
- **Nouvelles guildes** : Recommencer avec différents défis
- **Modes alternatifs** : Variantes de règles (hardcore, budget limité...)
- **Défis communautaires** : Objectifs partagés entre joueurs
- **Saisons** : Cycles de contenu avec classements

### Système de Prestige
- **Achievements permanents** : Déblocables uniquement une fois
- **Cosmétiques exclusifs** : Récompenses visuelles rares
- **Reconnaissance communautaire** : Hall of fame des légendes
- **Influence sur l'univers** : Impact permanent sur le monde du jeu

---

## Implémentation Technique Suggérée

### Phase de Développement
1. **Phase 1 complète** : Base solide avant d'ajouter la complexité
2. **Prototype Phase 2** : Test des nouvelles mécaniques
3. **Intégration progressive** : Ajout graduel de la complexité
4. **Beta testing** : Validation de l'équilibrage

### Données et Persistance
- **Système de sauvegarde évolutif** : Compatible avec les futures phases
- **Métriques de télémétrie** : Collecte de données pour équilibrage
- **Base de données extensible** : Structure prête pour nouveaux contenus

Cette spécification pose les bases d'un système de jeu évolutif et engageant qui peut tenir le joueur en haleine sur de nombreuses heures tout en offrant une progression satisfaisante et des défis renouvelés.