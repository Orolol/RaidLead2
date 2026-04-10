# Plan d'Action - Implémentation de la Game Loop en 3 Phases

## 1. Objectif de ce Document

Ce document découpe l'implémentation de la game loop en 3 phases (Serveur → National → Esport) en étapes logiques et tâches actionnables. Il s'appuie sur l'architecture existante du projet et vise à créer une progression naturelle et équilibrée.

## 2. Définitions

**Milestone** : Jalon majeur aboutissant à une version jouable avec de nouvelles fonctionnalités significatives. Chaque milestone s'appuie sur la précédente et peut être testée indépendamment.

**User Story (US)** : Description courte d'une fonctionnalité du point de vue utilisateur, réalisable en 1 jour maximum.

**Format** : "En tant que [utilisateur], je veux [action] afin de [bénéfice]."

## 3. Vue d'Ensemble des Milestones

### Milestone 1 : Infrastructure de Progression (3-5 jours)
Système de base pour la progression entre phases et compétition entre guildes.

### Milestone 2 : Phase 1 - Niveau Serveur (5-7 jours) 
Implémentation complète de la première phase de jeu.

### Milestone 3 : Phase 2 - Niveau National (7-10 jours)
Ajout des mécaniques de célébrité, médiatisation et sponsors.

### Milestone 4 : Phase 3 - Niveau Esport (7-10 jours)
Mécaniques professionnelles et compétition internationale.

### Milestone 5 : Mécaniques Transversales (5-7 jours)
Systèmes de cohésion, moral et dynamiques de groupe.

### Milestone 6 : Polish et Équilibrage (3-5 jours)
Finalisation, tests et équilibrage général.

---

## 4. Détail des Milestones

### Milestone 1 : Infrastructure de Progression

**Objectif** : Créer les systèmes de base pour gérer la progression entre phases, le classement des guildes et la compétition.

#### US 1.1 : Créer le Système de Phases de Jeu

**En tant que** système, **je veux** gérer l'état actuel de la phase de jeu **afin de** débloquer le contenu approprié.

**Détails** : 
- Créer `scripts/systems/phase_manager.gd` (singleton)
- Définir enum `GamePhase { SERVEUR, NATIONAL, ESPORT }`
- Variables : `current_phase`, `phase_progress`, `phase_requirements`
- Signaux : `phase_changed`, `phase_requirements_met`, `phase_unlocked`
- Méthodes : `check_phase_progression()`, `unlock_next_phase()`, `get_current_phase_info()`

#### US 1.2 : Implémenter le Système de Classement des Guildes

**En tant que** joueur, **je veux** voir le classement de ma guilde par rapport aux concurrentes **afin de** comprendre ma position compétitive.

**Détails** :
- Créer `scripts/systems/guild_ranking.gd` (singleton)
- Structure de données pour stocker les guildes concurrentes avec leurs stats
- Méthode `calculate_guild_score()` basée sur progression PvE, membres actifs, réputation
- Méthode `update_rankings()` appelée périodiquement
- Signal `ranking_updated` pour notifier les changements
- Interface dans `Fenetre_Monde.tscn` pour afficher le classement

#### US 1.3 : Créer les Guildes IA Concurrentes

**En tant que** système, **je veux** simuler des guildes concurrentes avec comportements réalistes **afin de** créer une compétition dynamique.

**Détails** :
- Créer `scripts/resources/ai_guild.gd` héritant de `Guild`
- Propriétés : `ai_strategy` (aggressive, balanced, defensive), `reputation`, `success_rate`
- Méthodes : `simulate_monthly_progress()`, `attempt_recruitment()`, `simulate_raids()`
- Intégration avec `GuildRanking` pour mettre à jour scores périodiquement
- Configuration initiale de 9 guildes IA avec stratégies variées

#### US 1.4 : Système de Débauchage de Base

**En tant que** joueur, **je veux** être confronté aux tentatives de recrutement de mes meilleurs membres **afin de** gérer la fidélité de mon équipe.

**Détails** :
- Ajouter méthode `attempt_poaching()` aux guildes IA
- Logique basée sur `integration`, `satisfaction`, `skill` du membre ciblé
- Probabilité de départ basée sur l'offre concurrente vs conditions actuelles
- Événement popup pour informer des tentatives/succès de débauchage
- Possibilité de contre-offre (amélioration salaire, équipement, etc.)

#### US 1.5 : Conditions de Progression entre Phases

**En tant que** joueur, **je veux** connaître clairement les objectifs à atteindre **afin de** progresser vers la phase suivante.

**Détails** :
- Définir critères précis par phase dans `PhaseManager`
- Phase 1→2 : TOP 1 serveur 2 semaines + 15 membres intégrés + 80% contenu cleared
- Phase 2→3 : TOP 1 national 1 mois + max 2 dramas/an + sponsors actifs + 3 world first
- Interface de progression dans `Fenetre_Personnage.tscn`
- Système de notifications pour objectifs atteints

---

### Milestone 2 : Phase 1 - Niveau Serveur

**Objectif** : Implémenter une expérience de jeu complète pour la phase serveur avec tous les systèmes nécessaires.

#### US 2.1 : Améliorer l'Interface de Classement Serveur

**En tant que** joueur, **je veux** voir en détail la progression des guildes concurrentes **afin de** ajuster ma stratégie.

**Détails** :
- Étendre `Fenetre_Monde.tscn` avec onglet "Classement Serveur"
- Affichage détaillé : rang, nom guilde, score, progression récente, spécialités
- Graphiques de progression dans le temps
- Indicateurs visuels pour guildes en montée/descente
- Bouton pour voir détail d'une guilde concurrente (membres publics, achievements)

#### US 2.2 : Système de Réputation de Guilde

**En tant que** joueur, **je veux** que ma réputation impacte le recrutement **afin de** bénéficier de mes succès.

**Détails** :
- Ajouter `reputation` à la classe `Guild`
- Gain de réputation : world/server first, recrutement de qualité, stabilité équipe
- Perte de réputation : échecs répétés, turnover élevé, dramas publics
- Impact sur probabilité d'acceptation des recrues
- Affichage de la réputation dans l'interface avec historique des events

#### US 2.3 : Mécaniques de Fidélité et Satisfaction

**En tant que** joueur, **je veux** gérer activement la satisfaction de mes membres **afin de** prévenir les départs.

**Détails** :
- Ajouter `satisfaction` et `loyalty` à `SimulatedPlayer`
- Facteurs : équipement reçu, temps de jeu accordé, succès de l'équipe, compatibilité sociale
- Événements de fidélité : anniversaire dans guilde, milestone personnel, soutien lors difficultés
- Actions joueur : bonus équipement, temps de parole privilégié, organisation events spéciaux
- Alertes préventives quand satisfaction devient critique

#### US 2.4 : Système d'Événements Serveur

**En tant que** joueur, **je veux** participer à des événements serveur **afin de** augmenter ma visibilité et gagner des récompenses.

**Détails** :
- Créer `scripts/systems/server_events.gd`
- Types d'événements : course au world first, tournois inter-guildes, événements communautaires
- Récompenses : réputation, équipement unique, accès privilégié à contenu
- Participation volontaire avec ressources dédiées
- Impact sur moral des membres et reconnaissance serveur

#### US 2.5 : Amélioration du Pool de Recrutement Serveur

**En tant que** joueur, **je veux** un pool de recrutement plus réaliste **afin de** avoir des choix stratégiques intéressants.

**Détails** :
- Étendre `RecruitmentPool` avec niveaux de qualité (novice, expérimenté, expert)
- Rotation dynamique basée sur performance des guildes
- Meilleurs joueurs plus difficiles à recruter (exigences plus élevées)
- Informations partielles pré-recrutement avec révélation progressive
- Système de recommandations entre joueurs

---

### Milestone 3 : Phase 2 - Niveau National

**Objectif** : Ajouter les mécaniques de célébrité, médiatisation et sponsors pour créer une expérience nationale.

#### US 3.1 : Système de Célébrité des Joueurs

**En tant que** joueur, **je veux** voir certains de mes membres devenir célèbres **afin de** gérer les opportunités et risques associés.

**Détails** :
- Ajouter `celebrity_level` et `public_recognition` à `SimulatedPlayer`
- Conditions de célébrité : performance exceptionnelle, personnalité marquante, events marquants
- Avantages : bonus recrutement, revenus sponsors, influence positive
- Inconvénients : pression médiatique, risque de drama, attention des concurrents
- Interface pour gérer l'exposition médiatique de chaque membre

#### US 3.2 : Mécaniques de Streaming et Médias

**En tant que** joueur, **je veux** gérer les activités de streaming de mes membres **afin de** optimiser visibilité et revenus.

**Détails** :
- Créer `scripts/systems/media_manager.gd`
- Propriété `is_streamer` pour les joueurs avec audience, revenus, planning stream
- Conflits potentiels : divulgation de stratégies, temps partagé, pression performance
- Gestion éditoriale : choix du contenu streamé, gestion des incidents live
- Revenus partagés guilde/joueur selon contrat négocié
- Événements médiatiques aléatoires (interviews, collaborations)

#### US 3.3 : Système de Sponsors

**En tant que** joueur, **je veux** négocier des contrats de sponsoring **afin de** financer l'équipement et les salaires.

**Détails** :
- Créer `scripts/systems/sponsorship_manager.gd`
- Types de sponsors : équipementiers, marques gaming, plateformes streaming
- Contrats avec obligations : utilisation équipement spécifique, quotas d'exposition, exclusivités
- Négociation basée sur performance, audience, réputation
- Conflits entre sponsors concurrents à gérer
- Impact sur budget guilde et satisfaction membres

#### US 3.4 : Gestion des Dramas et Crises

**En tant que** joueur, **je veux** gérer les crises médiatiques **afin de** protéger ma réputation.

**Détails** :
- Créer `scripts/systems/drama_manager.gd`
- Types de dramas : conflits internes publics, scandales personnels, polémiques gameplay
- Système de réponse : silence, démentis, sanctions, communication de crise
- Impact sur recrutement, sponsors, moral équipe
- Mécaniques de récupération de réputation dans le temps
- Événements de crisis management avec choix multiples

#### US 3.5 : Pool de Recrutement National

**En tant que** joueur, **je veux** accéder à un pool de joueurs nationaux **afin de** recruter des talents de plus haut niveau.

**Détails** :
- Étendre `RecruitmentPool` pour phase nationale (50-100 joueurs)
- Joueurs semi-professionnels avec agents, exigences salariales, clauses spéciales
- Négociations complexes avec durée, contre-propositions, conditions spéciales
- Joueurs avec historique public, réputation, préférences d'équipe
- Système de scouting pour identifier talents émergents

---

### Milestone 4 : Phase 3 - Niveau Esport

**Objectif** : Créer l'expérience esport complète avec staff professionnel et compétition internationale.

#### US 4.1 : Système de Staff Professionnel

**En tant que** joueur, **je veux** recruter du staff spécialisé **afin d** d'optimiser les performances de mon équipe.

**Détails** :
- Créer `scripts/resources/staff_member.gd`
- Rôles : coach stratégique, analyste performance, psychologue sportif, manager équipe
- Compétences spécialisées impactant différents aspects (moral, stratégie, performance)
- Salaires et budgets dédiés au staff
- Interface de recrutement et gestion du staff
- Synergies entre différents types de staff

#### US 4.2 : Système de Tournois Internationaux

**En tant que** joueur, **je veux** participer à des tournois internationaux **afin de** prouver ma domination mondiale.

**Détails** :
- Créer `scripts/systems/tournament_manager.gd`
- Types : World Championship annuel, Regional Qualifiers, Invitationals privés
- Format de tournois avec phases, brackets, prize pools
- Préparation intensive (bootcamps, stratégies spéciales, composition optimale)
- Pression médiatique et attentes élevées
- Récompenses prestige et financières significatives

#### US 4.3 : Gestion du Burnout et Pression

**En tant que** joueur, **je veux** gérer la pression sur mes joueurs **afin d** d'éviter les burnouts.

**Détails** :
- Ajouter `stress_level` et `burnout_risk` à `SimulatedPlayer`
- Facteurs de stress : charge d'entraînement, pression médiatique, attentes performance
- Mécaniques de prévention : rotation, vacances, support psychologique
- Conséquences burnout : performances dégradées, risque départ, problems de santé
- Staff spécialisé pour gestion du bien-être
- Équilibre performance vs durabilité carrière

#### US 4.4 : Système de Transferts Internationaux

**En tant que** joueur, **je veux** accéder au marché international **afin de** recruter les meilleurs talents mondiaux.

**Détails** :
- Pool de recrutement mondial avec joueurs de tous continents
- Complexités : visas, adaptation culturelle, barrières linguistiques
- Agents professionnels avec négociations poussées
- Fenêtres de transfert limitées dans l'année
- Salary cap et fair-play financier
- Adaptation et intégration des joueurs internationaux

#### US 4.5 : Système de Legacy et Recognition

**En tant que** joueur, **je veux** laisser une marque durable **afin de** créer un héritage dans l'histoire du jeu.

**Détails** :
- Hall of Fame des achievements exceptionnels
- Stratégies innovantes copiées par d'autres guildes
- Formation de la prochaine génération (système de mentoring)
- Impact sur l'évolution du meta-game
- Reconnaissance communautaire et historique
- Unlocks cosmétiques et titres permanents

---

### Milestone 5 : Mécaniques Transversales

**Objectif** : Implémenter les systèmes de cohésion, dynamiques de groupe et moral qui enrichissent toutes les phases.

#### US 5.1 : Système de Dynamiques de Groupe

**En tant que** joueur, **je veux** gérer les relations interpersonnelles **afin d** d'optimiser la cohésion d'équipe.

**Détails** :
- Créer `scripts/systems/group_dynamics.gd`
- Formation de cliques et sous-groupes dans la guilde
- Leaders naturels émergents avec influence sur autres membres
- Conflits de personnalité basés sur tags comportementaux incompatibles
- Système de relations individuelles (amitié, rivalité, indifférence)
- Impact sur performances collectives et stabilité équipe

#### US 5.2 : Moral Collectif et Ambiance de Guilde

**En tant que** joueur, **je veux** maintenir une bonne ambiance générale **afin de** maximiser les performances.

**Détails** :
- Métrique `guild_morale` globale calculée à partir des moral individuels
- Contagion émotionnelle : propagation des états d'esprit positifs/négatifs
- Événements d'ambiance : célébrations, défaites collectives, crises internes
- Actions pour améliorer moral : team building, récompenses, communication
- Impact visible sur performances en raid et cohésion générale

#### US 5.3 : Système d'Événements Team-Building

**En tant que** joueur, **je veux** organiser des activités de cohésion **afin de** renforcer les liens entre membres.

**Détails** :
- Types d'événements : sorties virtuelles, challenges inter-équipes, célébrations
- Coût en temps et ressources vs bénéfices sur cohésion
- Préférences individuelles selon personnalités
- Événements spéciaux saisonniers ou liés aux succès
- Création de traditions et culture de guilde unique
- Mémorisation des événements marquants par les membres

#### US 5.4 : Système de Rituels et Traditions

**En tant que** joueur, **je veux** créer une culture de guilde unique **afin de** renforcer l'identité collective.

**Détails** :
- Rituels pré-raid : habitudes, porte-bonheur, discours motivants
- Traditions de célébration pour les succès
- Codes internes et références partagées
- Onboarding personnalisé pour nouveaux membres
- Impact sur intégration et sentiment d'appartenance
- Évolution des traditions dans le temps

#### US 5.5 : Gestion Avancée des Conflits

**En tant que** joueur, **je veux** résoudre les conflits internes **afin de** maintenir la stabilité de l'équipe.

**Détails** :
- Détection précoce des tensions (moral baissant, interactions négatives)
- Options de résolution : médiation, sanctions, séparation, rotation
- Conflits de leadership et gestion de l'autorité
- Impact des décisions sur perception des autres membres
- Réconciliation possible et reconstruction des relations
- Formation en gestion de conflits via staff spécialisé

---

### Milestone 6 : Polish et Équilibrage

**Objectif** : Finaliser l'expérience avec une courbe de progression équilibrée et des aides au joueur.

#### US 6.1 : Système de Conseils et Tutoriels Adaptatifs

**En tant que** joueur, **je veux** recevoir des conseils contextuels **afin de** progresser efficacement.

**Détails** :
- IA de conseil analysant l'état actuel (membres, performance, phase)
- Suggestions personnalisées selon contexte et objectifs
- Tutoriels intégrés pour nouvelles mécaniques par phase
- Alertes prédictives sur risques à venir (moral bas, débauchage probable)
- Système d'aide désactivable pour joueurs expérimentés

#### US 6.2 : Outils d'Analyse et Statistiques

**En tant que** joueur, **je veux** analyser mes performances **afin de** identifier les axes d'amélioration.

**Détails** :
- Dashboard de métriques détaillées par membre et global
- Graphiques d'évolution dans le temps (performance, moral, progression)
- Comparaisons avec moyennes de phase et guildes similaires
- Projections basées sur tendances actuelles
- Export de données pour analyse externe
- Alertes sur déviations significatives

#### US 6.3 : Système de Sauvegarde de Progression

**En tant que** joueur, **je veux** sauvegarder ma progression entre phases **afin de** ne pas perdre mes achievements.

**Détails** :
- Étendre `SaveLoadManager` pour gérer les données de phases
- Sauvegarde de l'historique des achievements et milestones
- Continuité des relations et réputation entre phases
- Système de backup automatique aux moments critiques
- Possibilité de multiple saves pour expérimenter
- Migration de données entre versions du jeu

#### US 6.4 : Équilibrage de la Courbe de Difficulté

**En tant que** joueur, **je veux** une progression challenging mais fair **afin de** rester engagé sur la durée.

**Détails** :
- Analyse des données de playtest pour ajuster difficultés
- Système de scaling adaptatif basé sur performance joueur
- Mécaniques de catch-up pour joueurs en difficulté
- Défis optionnels pour joueurs avancés
- Feedback loops pour maintenir engagement optimal
- Possibilité d'ajuster difficulté selon préférence joueur

#### US 6.5 : Tests et Validation Finale

**En tant que** développeur, **je veux** valider toutes les mécaniques **afin de** garantir une expérience de qualité.

**Détails** :
- Suite de tests automatisés pour mécaniques principales
- Validation de l'équilibrage sur différents styles de jeu
- Tests d'intégration entre tous les systèmes
- Performance et optimisation pour sessions longues
- Validation UX avec playtests externes
- Correction des bugs critiques et polish final

---

## 5. Planning et Dépendances

### Phase d'implémentation recommandée :

1. **Semaines 1-2** : Milestone 1 (Infrastructure)
2. **Semaines 3-4** : Milestone 2 (Phase Serveur) 
3. **Semaines 5-7** : Milestone 3 (Phase Nationale)
4. **Semaines 8-10** : Milestone 4 (Phase Esport)
5. **Semaines 11-12** : Milestone 5 (Transversales - en parallèle des précédentes)
6. **Semaines 13-14** : Milestone 6 (Polish et Tests)

### Dépendances critiques :
- Milestone 1 requis avant tous les autres
- Milestone 2 doit être stable avant Milestone 3
- Milestone 5 peut être développé en parallèle des phases
- Milestone 6 nécessite tous les autres terminés

### Points de validation :
- Test complet de la Phase 1 avant passage à la Phase 2
- Validation de l'équilibrage à chaque milestone
- Playtest externe en fin de chaque phase majeure

---

## 6. Critères de Réussite

**Milestone 1** : Système de classement fonctionnel avec progression mesurable
**Milestone 2** : Expérience Phase 1 complète et satisfaisante sur 10+ heures
**Milestone 3** : Mécaniques de célébrité/sponsors engageantes et équilibrées  
**Milestone 4** : Sensation d'accomplissement et prestige pour la réussite finale
**Milestone 5** : Dynamiques de groupe perceptibles et influentes sur gameplay
**Milestone 6** : Jeu prêt pour release avec courbe de difficulté optimisée

L'implémentation suivra une approche itérative avec validations régulières pour garantir que chaque phase apporte une valeur ludique significative avant de passer à la suivante.