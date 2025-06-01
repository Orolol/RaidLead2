
(Détails inchangés)
4. Moteur Sélectionné

    Godot Engine (avec GDScript comme langage principal envisagé).

5. Prochaines Étapes (Avant Architecture)

    Définir l'architecture de base du projet (gestion des scènes, structure des données de sauvegarde, organisation du code).

6. Architecture Initiale du Projet (Godot)

Cette section décrit la structure envisagée pour les scènes principales et l'interface utilisateur (UI) dans Godot.
6.1. Scène Principale / Racine (Main.tscn)

    C'est la scène chargée au lancement du jeu (après un éventuel menu principal simple).

    Arrière-plan : Contient une zone affichant une représentation visuelle simplifiée (pixel art) de l'activité en cours du "vrai-joueur" dans le MMO fictif (ex: personnage qui combat des monstres en leveling, personnage dans un décor de donjon, etc.). Cette vue est principalement esthétique/d'ambiance.

    Interface Fixe :

        Barre de Menu Inférieure : Une barre fixe en bas de l'écran contenant les boutons principaux pour ouvrir les différentes fenêtres de gestion (Personnage, Guilde, Monde, Organisation Groupe).

        (Placeholder) Zone de Chat : Un espace réservé (ex: sur un côté ou en bas) pour le futur chat défilant. Pour le MVP, cet espace peut être masqué ou afficher des messages système simples.

    Gestionnaire de Fenêtres : Un nœud (ou un script sur le nœud racine) responsable d'instancier, afficher, masquer et gérer les différentes fenêtres/panneaux de l'interface.

6.2. Système de Fenêtrage / Panneaux

    Les interfaces spécifiques (Personnage, Guilde, etc.) ne sont pas toujours visibles. Elles apparaissent sous forme de fenêtres ou panneaux qui s'ouvrent par-dessus la scène principale via les boutons de la barre de menu.

    On peut utiliser les nœuds Window de Godot ou créer un système de panneaux personnalisés (nœuds PanelContainer ou Control qui sont affichés/masqués).

    Chaque fenêtre/panneau sera sa propre scène (.tscn) pour une meilleure organisation.

6.3. Scènes Spécifiques (Fenêtres / Panneaux)

Chacune de ces scènes sera une interface utilisateur (Control node comme racine) conçue pour afficher des informations et permettre des interactions :

    Fenetre_Personnage.tscn : Affiche les informations sur le personnage du vrai-joueur (classe, niveau, équipement simplifié, etc. - à définir plus précisément).

    Fenetre_Guilde.tscn : Affiche la liste des membres de la guilde (PNJ recrutés), avec leurs informations principales (Nom, Classe, Niveau, Humeur, Énergie, Intégration). Permet de sélectionner un membre pour voir plus de détails (potentiellement dans une autre sous-fenêtre/partie de l'UI).

    Fenetre_Monde.tscn :

        Onglet/Section "Classement Guildes" : Liste les guildes concurrentes (simulées) et leur statut/progression (simplifié au début).

        Onglet/Section "Recrutement" : Affiche la liste des joueurs (PNJ) disponibles dans le pool de recrutement (voir Section 9 des specs de jeu). Permet de filtrer et d'envoyer des invitations.

    Fenetre_OrganisationGroupe.tscn : Interface permettant au vrai-joueur de :

        Choisir le type d'activité (Donjon, Raid, Activité Fun).

        Sélectionner l'instance spécifique (ex: Donjon X, Raid Y).

        Composer le groupe en sélectionnant des membres de la guilde (et éventuellement des PUGs si activé).

        Lancer l'activité (qui déclenchera la phase de simulation).

6.4. Navigation / Contrôle

    La barre de menu inférieure est le point d'entrée principal pour accéder aux différentes fonctionnalités de gestion.

    Les fenêtres peuvent être fermées (croix 'X') ou masquées.

    La navigation au sein d'une fenêtre se fait via des boutons, onglets, listes, etc. (éléments UI standard de Godot).

7. Systèmes Implémentés

7.1. Système de Temps (GameTime)
    - Calendrier avec jours de la semaine, semaines (1-52) et années
    - Horloge 24h
    - Vitesse réglable (0.1x à 2400x)
    - Interface de contrôle avec pause et réglage de vitesse
    - Signaux pour les changements d'heure/jour/semaine/année

7.2. Système de Joueurs Simulés (SimulatedPlayer)
    - Génération procédurale de PNJ avec noms, classes, niveaux
    - Système de tags comportementaux avec révélation progressive
    - Tags cachés révélés selon conditions (temps, événements)
    - Planning hebdomadaire pour disponibilité
    - États: énergie, humeur, skill, intégration
    - Méthodes de connexion/déconnexion automatiques

7.3. Système d'Activités (Activity & ActivityManager)
    - Types d'activités: Leveling, Farming, Fun, Donjon, Raid, Offline
    - Gestion automatique des activités selon l'état du joueur
    - Effets sur énergie, humeur, intégration
    - Système de zones de leveling authentiques WoW
    - Calcul de progression XP

7.4. Système de Tags (PlayerTags)
    - Base de données complète de tags comportementaux
    - 6 catégories: Personnalité, Social, Gameplay, Progression, Fiabilité, Spécial
    - Conditions de révélation variées (temps, intégration, conflits, wipes)
    - Tags spéciaux cachés (ninja looter, drama queen)
    - Système de progression pour révélation

7.5. Système de Donjons/Raids (DungeonData & DungeonRun)
    - Base de données complète des donjons/raids WoW Vanilla
    - Simulation de combats de boss avec probabilités de succès
    - Calcul basé sur niveau, équipement, skill, composition
    - Système de loot avec distribution
    - Gestion des wipes et conséquences
    - Compositions de groupe requises (tanks, healers, DPS)

7.6. Système de Recrutement (RecruitmentPool)
    - Pool dynamique de 15-30 joueurs disponibles
    - Actualisation quotidienne avec nouveaux joueurs
    - Refresh complet tous les 3 jours
    - Compétition avec 9 guildes IA
    - Difficulté de recrutement basée sur qualité du joueur
    - Motivations et attentes des recrues
    - Filtrage par classe, niveau, rôle

7.7. Gestionnaire de Guilde (GuildManager)
    - Gestion centralisée des membres
    - Connexion/déconnexion automatique selon horaires
    - Attribution d'activités par défaut
    - Signaux pour changements d'état
    - Intégration avec ActivityManager

7.8. Interface Utilisateur
    - Menu bar fixe en bas avec navigation
    - Fenêtres redimensionnables avec drag & drop
    - Fenêtre Personnage: informations du joueur principal
    - Fenêtre Guilde: liste des membres avec détails et tags
    - Fenêtre Monde: classement guildes et recrutement
    - Fenêtre Organisation: création de groupes pour activités
    - Affichage du temps avec contrôles

8. Structure des Fichiers (à réorganiser)

Actuellement tous les scripts sont dans /scripts/. Proposition de réorganisation:

/scripts/
  /autoloads/       # GameTime, GuildManager, RecruitmentPool
  /resources/       # SimulatedPlayer, Activity
  /data/           # PlayerTags, DungeonData
  /systems/        # ActivityManager, DungeonRun
  /ui/             # Fenêtres et composants UI
    /windows/      # fenetre_*.gd
    /components/   # menu_bar.gd, time_display.gd
  /managers/       # window_manager.gd
  main.gd