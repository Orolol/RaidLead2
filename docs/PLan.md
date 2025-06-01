Plan de Développement - MVP - Étapes et User Stories
1. Objectif de ce Document

Ce document vise à découper le développement du MVP (Minimum Viable Product) du jeu de gestion de guilde en étapes logiques et en tâches actionnables (User Stories). L'objectif est de fournir une feuille de route claire pour le développement, permettant d'obtenir des versions jouables incrémentales.
2. Définitions

    Étape (Milestone) : Un jalon majeur du développement aboutissant à une version du jeu avec de nouvelles fonctionnalités significatives et potentiellement testables/jouables. Chaque étape s'appuie sur la précédente.

    User Story (US) : Une description courte et simple d'une fonctionnalité du point de vue de l'utilisateur (le vrai-joueur, le système, ou le développeur). L'objectif est qu'une US soit réalisable par un développeur en environ 1 jour ou moins.

        Format typique : "En tant que [type d'utilisateur], je veux [réaliser une action] afin de [obtenir un bénéfice]."

3. Étapes Proposées pour le MVP

(Objectifs de jouabilité inchangés)

    Étape 1 : Fondation Technique et Interface de Base.

    Étape 2 : Affichage et Recrutement Minimal.

    Étape 3 : Simulation d'Activité Simple (Leveling/Farming) & Stats Dynamiques.

    Étape 4 : Organisation et Simulation de Donjon Basique.

    Étape 5 : Intégration Initiale et Progression Joueur.

4. User Stories Détaillées (par Étape)
Étape 1 : Fondation Technique et Interface de Base

    US 1.1 : Configurer le Projet Godot Initial

        En tant que développeur, je veux configurer le projet Godot initial afin d'avoir un environnement de travail propre.

        Détails : Créer le projet Godot. Définir la résolution d'affichage cible (ex: 1280x720). Configurer les paramètres de base (nom du jeu, icône placeholder). Mettre en place la structure de dossiers (scenes/, scripts/, assets/, resources/). Initialiser un dépôt Git avec un .gitignore adapté à Godot. Configurer les inputs de base pour l'UI (ex: ui_accept, ui_cancel, ui_up, etc.).

    US 1.2 : Créer la Scène Principale et le Fond

        En tant que développeur, je veux créer la scène principale Main.tscn avec un nœud racine Control et un fond visuel statique simple (placeholder pixel art) afin d'établir la structure visuelle de base.

        Détails : Créer Main.tscn. Ajouter un nœud TextureRect pour le fond, lui assigner une texture placeholder importée dans assets/. Configurer l'ancrage (anchor) et les marges pour qu'il remplisse l'écran.

    US 1.3 : Implémenter la Barre de Menu Inférieure

        En tant que développeur, je veux implémenter la barre de menu inférieure fixe (Panel ou HBoxContainer) contenant 4 boutons (Button) placeholders (Personnage, Guilde, Monde, Groupe) afin de fournir les points d'accès à la navigation principale.

        Détails : Ajouter un PanelContainer ou Panel en bas de Main.tscn. À l'intérieur, ajouter un HBoxContainer. Dans ce dernier, ajouter 4 nœuds Button avec les textes correspondants. Configurer l'ancrage et les marges pour fixer la barre en bas. Connecter le signal pressed de chaque bouton à des fonctions placeholders dans le futur script Main.gd.

    US 1.4 : Créer les Scènes de Fenêtres Vides

        En tant que développeur, je veux créer les 4 scènes de fenêtres vides (Fenetre_Personnage.tscn, Fenetre_Guilde.tscn, Fenetre_Monde.tscn, Fenetre_OrganisationGroupe.tscn), chacune avec un nœud racine Window ou PanelContainer, afin d'avoir les conteneurs prêts pour les futures interfaces.

        Détails : Créer 4 nouvelles scènes. Choisir le nœud racine (Window pour des fenêtres déplaçables/redimensionnables, ou PanelContainer pour des panneaux fixes). Donner une taille minimale et un titre (pour Window). Sauvegarder dans scenes/ui/.

    US 1.5 : Gérer l'Affichage/Masquage des Fenêtres

        En tant que développeur, je veux écrire un script (Main.gd) attaché à la scène principale qui gère l'instanciation et l'affichage/masquage de chaque fenêtre vide lorsque le bouton correspondant dans la barre de menu est cliqué, afin de valider le système de fenêtrage de base.

        Détails : Créer Main.gd et l'attacher à Main.tscn. Dans _ready(), précharger (preload) les scènes des fenêtres. Dans les fonctions connectées aux signaux pressed des boutons (US 1.3), instancier (instantiate()) la scène de fenêtre correspondante si elle n'existe pas déjà, l'ajouter comme enfant (add_child()), et l'afficher (show()). Prévoir une logique pour ne pas instancier plusieurs fois la même fenêtre et pour la masquer (hide()) ou la fermer (queue_free()).

Étape 2 : Affichage et Recrutement Minimal

    US 2.1 : Définir la Ressource Joueur de Base

        En tant que développeur, je veux définir une structure de données simple pour un joueur (ex: PlayerResource.gd héritant de Resource) contenant Nom, Classe (enum), Niveau (int), afin de pouvoir représenter les joueurs dans le code.

        Détails : Créer un script PlayerResource.gd dans resources/. Le faire hériter de Resource. Définir un enum Classe { GUERRIER, MAGE, PRETRE }. Ajouter les variables exportées : export var nom: String = "Joueur", export var classe: Classe = Classe.GUERRIER, export var niveau: int = 1. Ajouter @tool en haut pour faciliter l'édition dans l'inspecteur si besoin.

    US 2.2 : Mettre en Place les Données de Guilde Initiales

        En tant que développeur, je veux créer une liste de données de joueurs de test (ex: dans un singleton/autoload GuildData.gd) afin d'avoir des données initiales à afficher.

        Détails : Créer un script GuildData.gd dans scripts/managers/. Déclarer une variable var roster: Array[PlayerResource] = []. Ajouter une fonction _ready() qui crée 2-3 instances de PlayerResource avec des valeurs différentes et les ajoute au roster. Enregistrer ce script comme Autoload (Singleton) dans les paramètres du projet.

    US 2.3 : Afficher le Roster de Guilde

        En tant que développeur, je veux modifier Fenetre_Guilde.tscn pour y inclure une liste (ItemList ou VBoxContainer rempli dynamiquement) qui affiche les noms et classes des joueurs présents dans GuildData.gd, afin de visualiser le roster de base.

        Détails : Ouvrir Fenetre_Guilde.tscn. Ajouter un nœud ItemList. Créer un script Fenetre_Guilde.gd et l'attacher. Dans _ready(), accéder au singleton GuildData. Itérer sur GuildData.roster. Pour chaque PlayerResource, ajouter un item à l'ItemList formaté (ex: player.nom + " (" + str(player.classe) + ") - Nv " + str(player.niveau)). Prévoir une fonction update_roster_display() pour pouvoir rafraîchir la liste plus tard.

    US 2.4 : Simuler un Recrutement Basique

        En tant que développeur, je veux ajouter un bouton "Recruter (Test)" dans Fenetre_Monde.tscn (section Recrutement) qui ajoute un nouveau joueur prédéfini à GuildData.gd, afin de simuler un recrutement très basique.

        Détails : Ouvrir Fenetre_Monde.tscn. Ajouter un Button "Recruter (Test)". Créer/attacher un script Fenetre_Monde.gd. Connecter le signal pressed du bouton à une fonction. Dans cette fonction, créer une nouvelle instance de PlayerResource (avec des valeurs fixes/aléatoires simples) et appeler une fonction add_player(new_player) dans GuildData.gd (à créer).

    US 2.5 : Mettre à Jour l'Affichage du Roster après Recrutement

        En tant que développeur, je veux que la liste dans Fenetre_Guilde.tscn se mette à jour lorsque le joueur de test est ajouté, afin de voir l'effet du recrutement.

        Détails : Dans GuildData.gd, déclarer un signal signal roster_changed. Émettre ce signal (roster_changed.emit()) à la fin de la fonction add_player(). Dans Fenetre_Guilde.gd, connecter ce signal (GuildData.roster_changed.connect(update_roster_display)) dans _ready(). La fonction update_roster_display() (créée en US 2.3) doit vider l'ItemList (clear()) et la remplir à nouveau avec les données à jour de GuildData.roster.

Étape 3 : Simulation d'Activité Simple & Stats Dynamiques

    US 3.1 : Ajouter Humeur et Énergie à la Ressource Joueur

        En tant que développeur, je veux ajouter les stats Humeur et Énergie (int, 0-100) à PlayerResource.gd.

        Détails : Éditer PlayerResource.gd. Ajouter export var humeur: int = 75 et export var energie: int = 100. Ajouter des fonctions set_humeur(value) et set_energie(value) qui utilisent clamp(value, 0, 100) pour s'assurer que les valeurs restent dans les bornes.

    US 3.2 : Afficher Humeur et Énergie dans le Roster

        En tant que développeur, je veux afficher l'Humeur et l'Énergie actuelles des joueurs dans la liste de Fenetre_Guilde.tscn.

        Détails : Modifier la fonction update_roster_display() dans Fenetre_Guilde.gd. Mettre à jour le formatage de l'item dans l'ItemList pour inclure l'humeur et l'énergie (ex: " | Hum: " + str(player.humeur) + " | Ene: " + str(player.energie)).

    US 3.3 : Implémenter le Tick de Simulation de Base

        En tant que développeur, je veux implémenter une fonction de "tick" de simulation simple (ex: appelée toutes les secondes via un Timer dans Main.gd ou un singleton) qui réduit légèrement l'Énergie et l'Humeur de chaque joueur dans GuildData.gd, afin de simuler le passage du temps et l'activité de base.

        Détails : Créer un singleton SimulationManager.gd. Y ajouter un nœud Timer. Configurer le Timer pour se déclencher toutes les X secondes (ex: 5s pour tester). Connecter son signal timeout à une fonction _on_simulation_tick(). Dans cette fonction, itérer sur GuildData.roster. Pour chaque joueur, appeler player.set_energie(player.energie - 1) et player.set_humeur(player.humeur - 1) (valeurs à ajuster). Émettre un signal player_stats_updated(player: PlayerResource) pour chaque joueur modifié. Démarrer le Timer dans _ready().

    US 3.4 : Mettre à Jour l'Affichage des Stats Dynamiques

        En tant que développeur, je veux que l'affichage de l'Humeur et de l'Énergie dans Fenetre_Guilde.tscn se mette à jour périodiquement pour refléter les changements dus à la simulation, afin de visualiser l'impact du temps qui passe.

        Détails : Dans Fenetre_Guilde.gd, connecter le signal SimulationManager.player_stats_updated à une fonction _on_player_stats_updated(player). Cette fonction doit trouver l'item correspondant au player dans l'ItemList (peut nécessiter de stocker l'index ou une référence lors du remplissage initial) et mettre à jour son texte avec les nouvelles valeurs de humeur et energie.

Étape 4 : Organisation et Simulation de Donjon Basique

    US 4.1 : Créer l'Interface d'Organisation de Groupe

        En tant que développeur, je veux concevoir l'interface de Fenetre_OrganisationGroupe.tscn pour permettre la sélection de 5 joueurs depuis la liste de guilde (ex: via des checkboxes ou drag-and-drop simplifié), afin de former un groupe.

        Détails : Ouvrir Fenetre_OrganisationGroupe.tscn. Ajouter un ItemList "Membres Disponibles" et un autre ItemList "Groupe Actuel (5 max)". Remplir la liste des disponibles depuis GuildData.roster. Implémenter la logique (dans Fenetre_OrganisationGroupe.gd) pour ajouter/retirer des joueurs du groupe actuel en cliquant sur les listes, en limitant à 5 joueurs. Afficher un feedback visuel clair (ex: griser le bouton Lancer si groupe incomplet).

    US 4.2 : Ajouter le Bouton de Lancement

        En tant que développeur, je veux ajouter un bouton "Lancer Donjon (Test)" dans Fenetre_OrganisationGroupe.tscn.

        Détails : Ajouter un Button "Lancer Donjon". Le désactiver (disabled = true) initialement. L'activer seulement quand le groupe contient exactement 5 joueurs. Connecter son signal pressed à une fonction _on_lancer_donjon_pressed().

    US 4.3 : Ajouter et Afficher le Niveau d'Équipement

        En tant que développeur, je veux ajouter la stat Niveau_Equipement (int) à PlayerResource.gd et l'afficher dans Fenetre_Guilde.tscn.

        Détails : Éditer PlayerResource.gd, ajouter export var niveau_equipement: int = 10. Mettre à jour Fenetre_Guilde.gd pour inclure cette stat dans l'affichage de la liste du roster.

    US 4.4 : Implémenter la Simulation de Donjon Simple

        En tant que développeur, je veux écrire une fonction de simulation de donjon basique qui prend les 5 joueurs sélectionnés, calcule un score de succès simple (ex: basé sur la moyenne de Niveau_Equipement), et retourne Succès/Échec.

        Détails : Dans SimulationManager.gd, créer func simulate_dungeon(group: Array[PlayerResource]) -> bool. Calculer la somme des niveau_equipement du group. Diviser par 5 pour obtenir la moyenne. Comparer cette moyenne à une valeur de difficulté fixe (ex: var dungeon_difficulty = 15). Retourner true si moyenne >= dungeon_difficulty, sinon false.

    US 4.5 : Implémenter la Récompense de Base (Équipement)

        En tant que développeur, lorsque le donjon simulé est un Succès, je veux augmenter légèrement la stat Niveau_Equipement d'un ou plusieurs joueurs du groupe (aléatoire ou fixe pour le moment), afin d'implémenter la récompense de base.

        Détails : Dans simulate_dungeon, si elle retourne true, choisir 1 joueur aléatoirement dans group (group.pick_random()). Augmenter son niveau_equipement (ex: player.niveau_equipement += 1). Émettre le signal player_stats_updated(player) pour ce joueur.

    US 4.6 : Afficher le Résultat de la Simulation

        En tant que développeur, je veux afficher un message simple indiquant le résultat (Succès/Échec) et la récompense éventuelle après le lancement du donjon, afin de donner un feedback au vrai-joueur.

        Détails : Dans Fenetre_OrganisationGroupe.gd, dans _on_lancer_donjon_pressed(), appeler SimulationManager.simulate_dungeon(groupe_selectionne). Ajouter un Label "ResultatDonjonLabel" à la scène. Mettre à jour le texte de ce label en fonction du booléen retourné (ex: "Donjon Réussi ! [NomJoueur] a gagné +1 Equipement !" ou "Échec du donjon.").

Étape 5 : Intégration Initiale et Progression Joueur

    US 5.1 : Ajouter Intégration et Tags Cachés

        En tant que développeur, je veux ajouter la stat Integration (int, 0-100) et une liste de Tags (Array[String], avec certains marqués comme "cachés") à PlayerResource.gd.

        Détails : Éditer PlayerResource.gd. Ajouter export var integration: int = 10 (avec set_integration utilisant clamp). Ajouter export var tags: Dictionary = {"Loyal": false, "Greedy": true, "Impatient": true} où la clé est le tag et la valeur booléenne indique si le tag est caché (true) ou révélé (false).

    US 5.2 : Afficher la Barre d'Intégration

        En tant que développeur, je veux afficher la barre d'Intégration dans Fenetre_Guilde.tscn.

        Détails : Modifier la fonction update_roster_display() ou la structure de l'item dans Fenetre_Guilde.tscn. Ajouter un nœud ProgressBar pour chaque joueur. Mettre à jour sa valeur (value = player.integration) lors de l'affichage et des mises à jour.

    US 5.3 : Augmenter l'Intégration via Donjons

        En tant que développeur, je veux augmenter légèrement l'Integration des joueurs participant à un donjon réussi (dans la fonction de simulation de l'US 4.4/4.5).

        Détails : Dans SimulationManager.simulate_dungeon, si succès, itérer sur tous les joueurs du group. Appeler player.set_integration(player.integration + 5) (valeur à ajuster). Émettre player_stats_updated(player) pour chacun.

    US 5.4 : Révéler un Tag Caché via Intégration

        En tant que développeur, je veux implémenter une logique simple où si l'Integration d'un joueur dépasse un seuil (ex: 50), un de ses tags cachés devient visible (à afficher dans une vue détaillée du joueur - à créer ou simuler).

        Détails : Dans PlayerResource.gd, ajouter une fonction check_integration_thresholds(). L'appeler dans set_integration. Si integration >= 50, chercher dans tags une clé où la valeur est true (caché). Si trouvée, la passer à false (révélé) et arrêter (ne révéler qu'un tag par seuil pour l'instant). Créer une scène Fenetre_DetailJoueur.tscn très basique. Ajouter une logique dans Fenetre_Guilde.gd pour instancier/afficher cette fenêtre quand on clique sur un joueur, en lui passant le PlayerResource. Fenetre_DetailJoueur.gd affiche les tags dont la valeur est false. (Note: La création/gestion de la fenêtre détail peut complexifier cette US).

    US 5.5a : Implémenter la Sauvegarde du Roster

        En tant que développeur, je veux implémenter une fonction save_game() qui sauvegarde l'état actuel du roster de la guilde dans un fichier JSON.

        Détails : Créer un singleton SaveLoadManager.gd. Créer func save_game(). Itérer sur GuildData.roster. Pour chaque PlayerResource, créer un Dictionary contenant ses propriétés (nom, classe, niveau, humeur, energie, niveau_equipement, integration, tags). Stocker ces dictionnaires dans un tableau. Créer un dictionnaire global de sauvegarde (ex: {"roster": array_de_dicos}). Ouvrir un fichier (FileAccess.open("user://savegame.json", FileAccess.WRITE)). Convertir le dictionnaire global en JSON (JSON.stringify()). Écrire dans le fichier. Fermer le fichier.

    US 5.5b : Implémenter le Chargement du Roster

        En tant que développeur, je veux implémenter une fonction load_game() qui charge l'état du roster depuis un fichier JSON.

        Détails : Dans SaveLoadManager.gd, créer func load_game(). Vérifier si FileAccess.file_exists("user://savegame.json"). Si oui, ouvrir en lecture (FileAccess.READ). Lire le contenu (get_as_text()). Parser le JSON (JSON.parse()). Vérifier que la structure est correcte. Vider GuildData.roster. Itérer sur le tableau "roster" du JSON chargé. Pour chaque dictionnaire, créer une nouvelle instance de PlayerResource. Assigner les propriétés depuis le dictionnaire. Ajouter la nouvelle instance à GuildData.roster. Émettre GuildData.roster_changed après le chargement complet. Gérer les erreurs (fichier inexistant, corrompu).

    US 5.5c : Intégrer Sauvegarde/Chargement dans le Jeu

        En tant que développeur, je veux intégrer les appels save_game() et load_game() dans le flux du jeu.

        Détails : Appeler SaveLoadManager.load_game() au tout début, par exemple dans _ready() de Main.gd ou GuildData.gd, avant que l'UI ne tente d'afficher le roster. Appeler SaveLoadManager.save_game() à des moments clés : potentiellement en quittant le jeu (via _notification(NOTIFICATION_WM_CLOSE_REQUEST)), ou après des événements majeurs (fin de donjon ?), ou via un bouton "Sauvegarder" manuel (plus simple pour commencer).

(Note : Ce découpage est une proposition initiale. Les US peuvent être affinées, ajoutées ou réorganisées au fur et à mesure du développement.)