# Audit et pistes d'amélioration - RaidLead

Date: 31 mai 2026  
Contexte: passe rapide dans le code, les scènes, les docs, les captures existantes et la suite de tests Godot 4.6.2.

## Résumé court

RaidLead a déjà une base très riche: boucle de temps, personnages simulés, comportements, recrutement, guildes IA, classement, événements, équipement, phases, sponsors, dramas, staff, esport, UI multi-fenêtres et tests automatisés. Le projet n'est plus un simple prototype.

Le risque principal n'est pas le manque de systèmes, mais la dispersion: beaucoup de mécaniques existent, certaines sont vraiment connectées, d'autres restent en placeholder, en fallback ou en "promesse de design". La prochaine grosse valeur viendra probablement moins d'ajouter une nouvelle couche, et plus de fermer la boucle jouable centrale:

```text
recruter -> observer les membres -> composer un groupe -> lancer une activité PvE
-> résoudre le run -> distribuer loot/réputation/progression -> faire évoluer la guilde
```

Si cette boucle devient claire, lisible et satisfaisante, tout le reste pourra s'y greffer proprement.

## Validation effectuée

Commande lancée avec Godot 4.6.2:

```powershell
& "C:\Users\gaeta\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe" --rendering-driver opengl3 --headless --path . "res://tests/TestRunner.tscn"
```

Résultat initial:

```text
TESTS : 36 total | 36 réussis | 0 échoués
```

Résultat après la première passe de corrections:

```text
TESTS : 39 total | 39 réussis | 0 échoués
```

Résultat après les chantiers de stabilisation suivants:

```text
TESTS : 46 total | 46 réussis | 0 échoués
```

Note: le `--check-only` avec Godot 4.5 avait laissé un process suspendu lors de ma première tentative, mais la suite de tests dédiée passe correctement avec la version 4.6.2 indiquée.

## Suivi des corrections

### Bouclé le 31 mai 2026

- Refresh du recrutement: `RecruitmentPool` utilise maintenant un compteur de jours absolus via `GameTime.get_total_days_elapsed()`, ce qui corrige le passage dimanche -> lundi et les changements de semaine/année.
- Tests temps: ajout d'une suite `GameTime` dans `tests/run_tests.gd` pour verrouiller le calcul de jour absolu.
- Guildes IA: suppression du double enregistrement initial dans `AIGuildManager`; `GuildRanking` reste le point d'entrée via le signal `ai_guild_created`.
- Ranking: la guilde du joueur utilise maintenant sa vraie réputation au lieu d'une valeur fixe à `75.0`.
- WindowManager: ajout de `get_window_instance()` et `refresh_window()` comme API publique, puis remplacement des appels directs à `_get_existing_instance()` dans `main.gd`.
- Debug UI: le menu Debug, les raccourcis F1/F2 et le bouton `Next Version` du time display sont maintenant limités aux builds debug.
- Fenêtre Personnage: l'onglet Progression utilise maintenant des blocs d'objectifs stables avec largeur minimale, barre intégrée, détails sous la ligne et scroll vertical pour éviter les textes cassés lettre par lettre.
- PhaseManager/Main: la notification de changement de phase dans le chat passe maintenant par le signal `phase_changed`; `PhaseManager` ne cherche plus `ChatPanel` via un chemin de node UI.
- Main/tests: ajout du flag `--no-save-autoload` pour lancer la scène principale sans charger `user://savegame.json`, et documentation de la commande headless de vérification.
- Scènes: nettoyage des UID invalides signalés dans `Main.tscn` et `Fenetre_Personnage.tscn`; le lancement court de `Main.tscn` ne remonte plus ces warnings.
- CustomProgressBar: le label interne est maintenant positionné par offsets plutôt que par modification directe de taille après ancrage, ce qui supprime le warning d'ancrage au lancement.
- AIGuild: la restauration depuis une save n'appelle plus la génération complète du constructeur; les logs `Ma Guilde` parasites disparaissent et un test verrouille le mode de restauration sans membres temporaires.
- PvE minimal: les clears réels de la guilde joueur sont maintenant enregistrés par `DungeonInstance`, sauvegardés dans `GuildRanking`, exposés au ranking et lus par `PhaseManager.content_cleared_percent`.

### Toujours ouvert

- Le chantier PvE reste le prochain gros morceau: le tracking de clears existe maintenant, mais il manque encore un vrai rapport de run, une vue d'historique et une résolution PvE plus centrale.
- Les chemins UI directs hors `main.gd` restent à auditer plus largement, même si le cas `PhaseManager -> ChatPanel` est bouclé.
- L'UX des fenêtres principales reste à reprendre, mais l'onglet Progression de `Fenetre_Personnage` a reçu une première stabilisation de lisibilité.

### Observations ajoutées en cours de chantier

- Lancement court de `res://scenes/Main.tscn`: les `ext_resource` avec UID invalides ont été nettoyés sur les scènes chargées au démarrage.
- Le lancement de la scène principale chargeait automatiquement `user://savegame.json`, ce qui rendait les vérifications headless dépendantes de la machine locale. Le flag `--no-save-autoload` couvre maintenant ce besoin pour les runs de contrôle.
- Pendant ce chargement, les logs d'`AIGuildManager` affichaient plusieurs créations de guildes IA nommées `Ma Guilde` avant d'enregistrer des noms de guildes IA existantes. La restauration utilise maintenant un constructeur sans génération initiale.
- Le warning d'ancrage dans `custom_progress_bar.gd` vu au lancement de `Main.tscn` est corrigé.

## Impression générale

Le projet a une ambition de jeu de management assez rare: il ne se contente pas de listes et de chiffres, il essaie de simuler une guilde comme un organisme social. C'est une très bonne direction. Les systèmes de relations, de fatigue, de réputation, de médias, de sponsors, de transfert et de legacy peuvent donner une vraie save emergente.

Mais cette richesse a un coût: le joueur risque de voir beaucoup d'informations sans comprendre ce qui est actionnable maintenant. Côté code, plusieurs systèmes sont déjà présents mais pas encore toujours branchés à une source de vérité robuste. La roadmap annonce beaucoup de "100% complet", alors que le code montre encore des placeholders importants sur la progression PvE, le classement national/mondial et certaines transitions de phase.

Dit autrement: le moteur de simulation existe, mais il faut maintenant rendre le jeu lisible, bouclé et décidable.

## Priorité 1 - Fermer la boucle PvE

### Constats

L'organisation de groupe, les donjons, les raids, le loot et les phases existent, mais la jonction gameplay centrale est encore fragile.

Points vus:

- `scripts/systems/activity_manager.gd`: dans `_decide_next_activity()`, les choix `DUNGEON` et `RAID` retombent encore sur du farming.
- `scripts/systems/guild_ranking.gd`: `_get_player_guild_cleared_content()` retournait un placeholder basé sur le niveau de guilde. Corrigé pour la guilde joueur via clears réels.
- `scripts/systems/guild_ranking.gd`: `_get_recent_clears()` retournait toujours un tableau vide. Corrigé pour la guilde joueur; l'IA garde ses données propres via `AIGuild`.
- `scripts/systems/phase_manager.gd`: `content_cleared_percent` retournait encore `0.0`. Corrigé via `GuildRanking.get_player_content_cleared_percent()`.
- `scripts/ui/windows/fenetre_organisation_groupe.gd`: l'UI de composition existe, avec drag/drop et auto-assignation, mais elle devrait devenir le centre de la promesse "raid lead".

### Pistes concrètes

Étendre la source de vérité PvE maintenant amorcée dans `GuildRanking`:

- enregistrer plus que le clear simple: wipes, durée, boss tués, loot obtenu, difficulté, score de performance;
- exposer une vraie vue `get_run_history()`, `get_best_clear(content_id)`, `get_recent_clears(days)`;
- décider si ce tracking reste dans `GuildRanking` ou devient un autoload `PveProgression` quand l'historique devient plus riche;
- brancher une UI de rapport de run et d'historique.

Faire de `Fenetre_OrganisationGroupe` le vrai bouton de jeu:

- sélection donjon/raid;
- prévision de réussite avant lancement;
- avertissements de composition;
- affichage clair des rôles manquants;
- estimation de fatigue/stress;
- lancement qui crée un `DungeonInstance` ou un `DungeonRun`;
- résultat lisible: boss vaincus, wipes, loot, réputation, XP guilde, moral.

Ajouter un "rapport de run" après chaque activité PvE:

- résumé narratif court;
- score de performance;
- membres remarquables;
- erreurs de composition;
- conflits de loot;
- conséquences sociales.

Ce serait probablement le chantier qui transforme le plus le ressenti du jeu.

## Priorité 2 - Reprendre l'UX des fenêtres principales

### Constats visuels

Les captures dans `screen/` montrent plusieurs problèmes:

- texte qui se casse verticalement dans l'onglet progression du personnage;
- grandes zones vides;
- panneaux qui se superposent ou occupent toute la hauteur sans hiérarchie claire;
- chat peu lisible en bas à droite;
- menu debug visible dans l'interface normale;
- beaucoup de texte brut, peu de hiérarchie de décision;
- certaines fenêtres ressemblent encore à des outils de debug internes.

La fenêtre `Personnage > Progression` semble particulièrement prioritaire: les objectifs de phase se lisent mal, alors que c'est une des vues qui devrait guider le joueur.

### Pistes concrètes

Refondre les lignes d'objectifs dans `scripts/ui/windows/fenetre_personnage.gd`:

- remplacer les `HBoxContainer` trop compressés par des lignes fixes ou un `GridContainer`;
- donner une largeur minimale à la description;
- mettre le statut, le label, la barre et la valeur dans une ligne stable;
- placer les détails numériques sous la barre seulement si nécessaire;
- ajouter un `ScrollContainer` si la liste dépasse;
- éviter les labels qui prennent une largeur de 0 et cassent lettre par lettre.

Repenser la hiérarchie écran:

- en haut: temps et actions temporelles;
- au centre: fenêtre active;
- en bas: navigation et/ou log;
- chat/log moins opaque ou repliable;
- debug caché par défaut.

Créer un petit design system interne:

- tailles standard de fenêtres;
- marges;
- couleurs de statut;
- style de titre;
- style de ligne de membre;
- boutons primaires/secondaires/dangereux;
- composants réutilisables pour stat, tag, alerte, requirement.

Le code a déjà `UITheme`, `UIConstants`, `StatDisplay`, `Badge`, `AdvancedTabs`. Il faut probablement pousser cette logique plus loin au lieu de continuer à construire chaque fenêtre à la main.

## Priorité 3 - Clarifier les sources de vérité

### Constats

Plusieurs systèmes calculent ou devinent les mêmes choses:

- la progression PvE est simulée à plusieurs endroits;
- le classement utilise des données calculées localement;
- la phase dépend du classement et du contenu;
- la guilde, les activités et les donjons ont chacun une partie du récit;
- les fenêtres appellent parfois directement des méthodes privées ou des chemins de nodes.

Exemples:

- `scripts/main.gd` appelle `window_manager._get_existing_instance(...)`.
- `scripts/systems/phase_manager.gd` cherche directement `/root/Main/VBoxContainer/ChatPanel`.
- `scripts/systems/guild_ranking.gd` force actuellement une réputation `75.0` dans `_get_player_guild_data()`.

### Pistes concrètes

Définir une responsabilité unique pour chaque donnée:

- `GuildManager`: roster, guilde, recrutement réussi, départs.
- `ActivityManager`: activités courantes et résolution des activités simples.
- `PveProgression` ou `DungeonManager`: historique PvE et contenu clear.
- `GuildRanking`: score et classement, mais pas invention de données.
- `PhaseManager`: lit les compteurs, ne les fabrique pas.
- `NotificationManager`/`EventBus`: diffusion UI, pas chemins de nodes.

Ajouter des APIs publiques au `WindowManager`:

- `get_window_instance(window_name: String) -> Control`
- `refresh_window(window_name: String) -> void`
- `is_window_open(window_name: String) -> bool`

Puis supprimer les appels à `_get_existing_instance()` depuis l'extérieur.

## Priorité 4 - Nettoyer le mode debug

### Constats

Le debug est utile, mais il est actuellement visible et branché dans l'écran principal:

- `_setup_debug_menu()` est appelé directement dans `scripts/main.gd`.
- `TimeDisplay` expose un bouton `Next Version`.
- Beaucoup de `print()` donnent une bonne trace en test, mais pourraient devenir bruyants en session normale.

### Pistes concrètes

Ajouter un flag central:

```gdscript
const DEBUG_UI_ENABLED: bool = OS.is_debug_build()
```

Ou mieux: un autoload/config `DevSettings`.

Ensuite:

- cacher le menu debug hors build debug;
- cacher les boutons de skip serveur/version hors debug;
- remplacer les `print()` importants par un logger léger;
- garder les actions debug accessibles par raccourci ou fenêtre dev.

## Priorité 5 - Corriger les petits bugs de simulation

### Recrutement et calendrier

Dans `scripts/autoloads/recruitment_pool.gd`, le refresh compare:

```gdscript
game_time.current_day - last_refresh_day
```

`current_day` revient à 1 chaque semaine, donc le refresh complet peut devenir incorrect autour du passage dimanche -> lundi.

Piste:

- utiliser `GameTime.get_current_timestamp()`;
- ou ajouter `GameTime.get_total_days_elapsed()`;
- stocker `last_refresh_total_day`.

### Guildes IA enregistrées deux fois

Pendant les tests, chaque guilde IA apparaît deux fois dans les logs d'enregistrement. Le flux semble être:

- `AIGuildManager` appelle `GuildRanking.register_guild(...)`;
- puis émet `ai_guild_created`;
- `GuildRanking._on_ai_guild_created()` rappelle `register_guild(...)`.

Ce n'est pas critique si `register_guild` est idempotent, mais c'est un signe de double ownership.

Piste:

- soit seul `AIGuildManager` enregistre;
- soit seul `GuildRanking` écoute `ai_guild_created`;
- mais pas les deux.

### Frais d'agent et salaires

`attempt_national_recruitment()` accepte un salaire et émet `player_recruited`, mais le coût d'agent est surtout retourné dans `accept_counter_offer()`. Vérifier que l'or est bien dépensé dans tous les chemins d'acceptation, pas seulement le chemin UI.

### Random non déterministe

Beaucoup de systèmes utilisent `randf()`, `randi()`, `pick_random()`. Pour un jeu de simulation, c'est normal. Pour tester et débugger, il serait précieux d'avoir un seed contrôlé:

- `GameRandom` existe déjà dans `scripts/utils/game_random.gd`;
- il faudrait vérifier s'il est utilisé partout ou seulement partiellement;
- les tests E2E et simulations de mois gagneraient à pouvoir rejouer une séquence.

## Priorité 6 - Rendre la roadmap plus honnête et utile

### Constats

`RoadmapComplet.md` indique beaucoup de sections à 100%, mais le code contient encore des TODO importants sur les mêmes sujets.

Exemples:

- Phase 2 et Phase 3 du classement encore TODO dans `GuildRanking`.
- `content_cleared_percent` encore placeholder.
- PvE clear réel pas encore branché au ranking.
- certains flux de national/esport semblent en place mais probablement pas encore équilibrés ni éprouvés.

### Pistes concrètes

Transformer la roadmap en trois statuts:

- `Implémenté`: code présent et branché.
- `Jouable`: accessible dans l'UI et utile au joueur.
- `Validé`: couvert par test ou scénario E2E.

Exemple:

```markdown
| Système | Implémenté | Jouable | Validé | Commentaire |
|---|---:|---:|---:|---|
| Recrutement serveur | Oui | Oui | Partiel | Ajouter tests refus/acceptation |
| Progression PvE | Partiel | Partiel | Non | Tracking réel à centraliser |
| Classement national | Partiel | Non | Partiel | Données de phase à brancher |
```

Ça évite le faux confort du "100%" et donne une carte de production plus fiable.

## Priorité 7 - Typage GDScript

### Constats

La règle projet dit "variables typées systématiquement", mais le code contient encore beaucoup de variables non typées:

- `var background = TextureRect.new()`
- `var guild_manager = GuildManager`
- `var player_character = null`
- beaucoup de `var x = {}` ou `var y = []`

Ce n'est pas dramatique pour avancer vite, mais à mesure que le projet grossit, le typage va aider Godot et l'éditeur à prévenir les erreurs.

### Pistes concrètes

Faire un chantier mécanique progressif:

- ajouter les retours `-> void`, `-> bool`, `-> Dictionary`, etc.;
- typer les variables membres;
- typer les arrays quand raisonnable: `Array[SimulatedPlayer]`, `Array[Dictionary]`;
- éviter `Node` quand on connaît le type réel ou le script;
- garder `Variant` seulement là où c'est assumé.

Priorité aux fichiers centraux:

- `scripts/main.gd`
- `scripts/autoloads/guild_manager.gd`
- `scripts/autoloads/recruitment_pool.gd`
- `scripts/systems/activity_manager.gd`
- `scripts/systems/phase_manager.gd`
- `scripts/systems/guild_ranking.gd`

## Priorité 8 - Réduire la taille des fenêtres/scripts

### Constats

Plusieurs fichiers dépassent une taille où la maintenance devient pénible:

- `scripts/ui/windows/fenetre_monde.gd`
- `scripts/main.gd`
- `scripts/ui/windows/fenetre_personnage.gd`
- `scripts/ui/windows/fenetre_esport.gd`
- `scripts/ui/windows/fenetre_guilde.gd`
- `scripts/resources/simulated_player.gd`

Le risque: chaque ajout devient localement simple mais globalement fragile.

### Pistes concrètes

Découper par responsabilités:

- `fenetre_monde.gd`
  - composant classement;
  - composant recrutement;
  - composant détails de guilde;
  - composant détails de recrue.
- `fenetre_guilde.gd`
  - liste membres;
  - détail membre;
  - historique loot;
  - menu contextuel.
- `main.gd`
  - bootstrap UI;
  - debug menu;
  - popups événements;
  - popups loot/drama;
  - player control.

Le but n'est pas de découper pour découper. Le bon signal: si une fenêtre a plus de deux onglets complexes, chaque onglet mérite souvent son propre script/composant.

## Priorité 9 - Améliorer le feedback joueur

### Constats

Le jeu simule beaucoup de choses, mais le joueur doit comprendre:

- pourquoi un membre refuse une activité;
- pourquoi une recrue accepte/refuse;
- pourquoi un classement change;
- pourquoi un membre part;
- pourquoi une phase n'avance pas;
- quoi faire maintenant.

Le log/chat existe, mais il est surtout chronologique. Un jeu de management a besoin de diagnostics actionnables.

### Pistes concrètes

Ajouter une couche "conseiller" plus centrale:

- 3 alertes prioritaires maximum;
- "problème", "cause probable", "action proposée";
- exemple: "Intégration moyenne trop basse: 42%. Organise une activité fun ou évite les raids difficiles cette semaine."

Ajouter des tooltips de causalité:

- recrutement: facteurs + et - du score d'acceptation;
- run PvE: facteurs de réussite;
- classement: contribution du PvE, réputation, activité, stabilité;
- phase: pourquoi chaque objectif avance ou non.

Créer une vue "Cette semaine":

- activités prévues;
- membres à risque;
- objectifs accessibles;
- événements récents;
- opportunités de recrutement;
- prochain contenu conseillé.

## Priorité 10 - Tests et E2E

### Ce qui est bien

Le repo a déjà un mini framework et 46 tests. C'est une excellente base. Les tests couvrent notamment:

- items/équipement;
- stress et burnout;
- balance;
- advisor;
- save manager;
- phase manager.

Il y a aussi des scripts E2E ciblés:

- screenshots;
- progression nationale;
- recrutement national.

### Pistes concrètes

Ajouter des tests sur la boucle PvE:

- composition valide/invalide;
- run réussi/échoué;
- loot attribué;
- conflit de loot;
- contenu clear enregistré;
- ranking mis à jour après clear;
- phase 0 -> 1 après donjon héroïque.

Ajouter des tests calendrier:

- refresh du recrutement après passage de semaine;
- salaires hebdomadaires;
- events mensuels;
- simulation IA mensuelle.

Ajouter des tests sauvegarde:

- roster complet;
- équipement;
- progression PvE;
- phases;
- sponsors/dramas;
- guildes IA;
- ranking history.

## Priorité 11 - Sauvegarde et compatibilité

Le jeu accumule des systèmes persistants. Dès que la boucle PvE sera branchée, la sauvegarde deviendra critique.

Pistes:

- versionner le format de save;
- ajouter des migrations;
- sérialiser les historiques avec prudence;
- éviter de sauvegarder des instances Godot complexes si un ID suffit;
- avoir un test round-trip pour chaque système majeur.

Questions à trancher:

- Est-ce que les joueurs simulés ont un ID stable?
- Est-ce que les guildes IA ont un ID stable?
- Est-ce que les contenus PvE utilisent des IDs constants?
- Comment migrer une save si un tag ou un item change de nom?

## Priorité 12 - Données et équilibrage

Le projet gagnerait à sortir progressivement les constantes des scripts:

- poids de ranking;
- chances de recrutement;
- coûts de salaire;
- gains de réputation;
- chances d'événements;
- fatigue/stress;
- difficulté donjons/raids;
- seuils de phases.

Pistes:

- ressources `.tres` dédiées;
- fichiers JSON/CSV si besoin;
- `BalanceManager` comme façade centrale;
- presets de difficulté.

Objectif: pouvoir équilibrer sans modifier 15 scripts.

## Priorité 13 - Cohérence Godot/config

### Constats

`project.godot` indique:

- `config/features=PackedStringArray("4.6", "GL Compatibility")`
- `renderer/rendering_method="mobile"`

Le contexte projet parle parfois de Godot 4.5, mais la bonne version actuelle est 4.6.2.

### Pistes concrètes

- mettre AGENTS/Roadmap/docs à jour sur Godot 4.6.2;
- clarifier le renderer attendu sous Windows vs WSL;
- garder la consigne `--rendering-driver opengl3` si elle reste nécessaire;
- documenter le chemin local Godot ou adapter `tests/run_tests.ps1` si besoin.

## Priorité 14 - Ambiance et identité

Le jeu a une idée forte, mais l'interface actuelle ne donne pas encore assez la sensation "manager de guilde vivante".

Pistes d'identité:

- un vrai tableau de bord de guilde à l'ouverture;
- portraits/classes plus visibles;
- événements racontés comme des mini-scènes;
- historique de guilde façon journal;
- membres avec traits révélés progressivement dans une fiche plus humaine;
- moments de tension: avant raid, loot contesté, débauchage rival, drama streamer;
- célébrations: premier clear, montée classement, recrue star, sponsor signé.

Le pixel art généré peut servir ici, mais il faut l'utiliser pour rendre les décisions plus incarnées, pas juste décorer.

## Idées gameplay à explorer

### Préparation de raid

Avant un raid, proposer une phase de préparation:

- assigner stratégie;
- choisir niveau de risque;
- définir priorité loot;
- choisir leader/assistants;
- prévoir remplaçants;
- décider si on pousse malgré fatigue.

Cela donne au joueur de vraies décisions de manager.

### Personnalités plus lisibles

Les tags sont déjà là. Il faudrait les rendre plus actifs dans l'UI:

- "Ce joueur risque de mal vivre les wipes."
- "Ce joueur joue mieux avec X."
- "Ce joueur veut plus de raids."
- "Ce joueur est tenté par une guilde plus compétitive."

Chaque tag devrait idéalement créer une tension ou une opportunité.

### Rivalités entre guildes

Les guildes IA existent. On peut les rendre plus présentes:

- annonces de clears adverses;
- offres de débauchage nommées;
- réputation de chaque guilde;
- historiques de rivalité;
- "ils nous ont pris un joueur";
- "ils ont wipe sur le boss que nous préparons".

### Méta serveur

Très bon terrain pour un jeu inspiré MMO:

- patch notes;
- classe buff/nerf;
- changement de loot;
- nouvelle stratégie découverte;
- boss buggué puis corrigé;
- migration de population serveur;
- drama communautaire.

### Culture de guilde

Le système existe. Il peut devenir une vraie identité de run:

- guilde tryhard;
- guilde familiale;
- guilde loot council stricte;
- guilde streamer-friendly;
- guilde formatrice;
- guilde mercenaire.

Chaque culture pourrait modifier recrutement, moral, sponsors, drama et performance.

## Ordre de chantier recommandé

### Étape 1 - Boucle PvE minimale mais complète

Objectif: composer un groupe, lancer un donjon, obtenir un résultat, enregistrer le clear, mettre à jour progression/ranking/phase.

Livrable idéal:

- une activité donjon fonctionne de bout en bout;
- un rapport s'affiche;
- un test valide la progression;
- `content_cleared_percent` n'est plus placeholder.

### Étape 2 - UX des 4 fenêtres coeur

Fenêtres:

- Personnage;
- Guilde;
- Monde;
- Organisation.

Objectif:

- lisibles;
- sans texte cassé;
- sans debug visible;
- chaque fenêtre répond à "quelle décision je peux prendre ici?".

### Étape 3 - Sources de vérité et signaux

Objectif:

- supprimer appels privés entre UI et manager;
- brancher EventBus/notifications;
- centraliser progression PvE;
- stabiliser ranking/phase.

### Étape 4 - Tests de simulation

Objectif:

- tests sur calendrier;
- tests sur recrutement;
- tests sur PvE;
- tests sur save/load;
- E2E screenshot propre de la boucle principale.

### Étape 5 - National/Esport

Une fois la boucle serveur solide:

- national devient une extension naturelle;
- médias/sponsors/dramas ont des conséquences réelles;
- esport ajoute staff/tournois/stress sans masquer une boucle serveur incomplète.

## Petites actions rapides

Ces tâches sont petites mais utiles:

- [x] cacher le menu debug hors debug build;
- [x] corriger le bug de refresh recrutement hebdomadaire;
- [x] rendre `WindowManager.get_window_instance()` public;
- [x] remplacer le chemin `/root/Main/VBoxContainer/ChatPanel` par un signal;
- [x] corriger le layout des requirements dans `Fenetre_Personnage`;
- [x] ajouter un mode de lancement sans auto-load de save pour les vérifications headless;
- [x] nettoyer les UID invalides signalés par Godot au lancement de `Main.tscn`;
- [x] corriger le warning d'ancrage de `CustomProgressBar`;
- [x] éviter la génération temporaire de guildes IA lors du chargement de save;
- [x] brancher un tracking minimal des clears PvE joueur dans `GuildRanking` et `PhaseManager`;
- [x] faire utiliser la vraie réputation dans `GuildRanking`;
- [x] supprimer le double `register_guild`;
- [x] mettre la doc à jour sur Godot 4.6.2;
- [x] ajouter un test de base pour le compteur de jours absolus utilisé par `RecruitmentPool`;
- [x] ajouter un test pour `PhaseManager.content_cleared_percent` dès que le tracking PvE existe.

## Conclusion

Le projet a une très bonne ossature et une promesse forte. La meilleure prochaine phase n'est pas "plus de features", mais "plus de causalité visible".

Le joueur doit sentir:

- j'ai recruté cette personne pour une raison;
- j'ai composé ce groupe avec une intention;
- le run a réussi ou échoué pour des raisons compréhensibles;
- mes choix ont changé la guilde;
- la guilde a une mémoire;
- le serveur réagit.

Quand cette chaîne sera solide, les systèmes plus ambitieux comme national, médias, sponsors, transferts et esport auront beaucoup plus d'impact.
