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
TESTS : 57 total | 57 réussis | 0 échoués
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
- ActivityManager: les préférences automatiques `DUNGEON`/`RAID` créent maintenant des activités PvE dédiées au lieu de retomber sur du farming.
- Historique PvE: `GuildRanking` conserve aussi un historique des runs joueur avec durée, wipes, récompense et accès au meilleur clear connu.
- UI Progression: `Fenetre_Personnage` affiche maintenant les derniers runs PvE dans l'onglet Progression.
- Chat: la fin d'un donjon affiche maintenant un mini rapport avec nom du contenu, durée, boss, wipes et or.
- UI Progression: le meilleur clear du dernier contenu PvE joue est maintenant affiche depuis `GuildRanking.get_player_best_clear(content_id)`.
- DungeonInstance: le signal `boss_defeated` respecte maintenant son arite declaree pendant les conflits de loot.
- Organisation de groupe: la composition PvE affiche maintenant un apercu de run avec score estime, roles manquants et moyennes niveau/equipement/skill.
- DungeonData: `calculate_difficulty_score()` retourne maintenant `0.0` pour un groupe vide au lieu de risquer une division par zero.
- GuildRanking: les classements National et Mondial ne sont plus des `pass`; ils produisent un ranking base sur les donnees existantes avec un multiplicateur de phase.
- GuildRanking: le score d'activite retourne maintenant `0.0` pour une guilde vide au lieu de diviser par zero.
- Rapport PvE: `Fenetre_Loot` devient un rapport de run avec duree, boss, wipes, participants, butin et score de performance.
- Rapport PvE: le calcul de score est partage via `pve_run_report.gd`, persiste dans l'historique `GuildRanking` et s'affiche dans `Fenetre_Personnage`.

### Toujours ouvert

- Le chantier PvE reste le prochain gros morceau: le tracking, l'historique, le meilleur clear, le résumé chat et un rapport de run dédié sont visibles; il manque encore une résolution PvE plus centrale.
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

- `scripts/systems/activity_manager.gd`: dans `_decide_next_activity()`, les choix `DUNGEON` et `RAID` retombaient encore sur du farming. Corrigé en activité PvE dédiée; le vrai lancement automatique d'un groupe reste à concevoir.
- `scripts/systems/guild_ranking.gd`: `_get_player_guild_cleared_content()` retournait un placeholder basé sur le niveau de guilde. Corrigé pour la guilde joueur via clears réels.
- `scripts/systems/guild_ranking.gd`: `_get_recent_clears()` retournait toujours un tableau vide. Corrigé pour la guilde joueur; l'IA garde ses données propres via `AIGuild`.
- `scripts/systems/phase_manager.gd`: `content_cleared_percent` retournait encore `0.0`. Corrigé via `GuildRanking.get_player_content_cleared_percent()`.
- `scripts/ui/windows/fenetre_organisation_groupe.gd`: l'UI de composition existe, avec drag/drop et auto-assignation, mais elle devrait devenir le centre de la promesse "raid lead".

### Pistes concrètes

Étendre la source de vérité PvE maintenant amorcée dans `GuildRanking`:

- enrichir encore le run: loot obtenu, difficulté, score de performance, incidents sociaux;
- brancher `get_player_best_clear(content_id)` dans une UI de détail ou de rapport de run;
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

- Phase 2 et Phase 3 du classement avaient encore des `pass` dans `GuildRanking`. Corrige par un ranking de base reutilisant les donnees existantes; l'equilibrage fin reste a faire.
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

Le repo a déjà un mini framework et 57 tests. C'est une excellente base. Les tests couvrent notamment:

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
- [x] empêcher les préférences automatiques Donjon/Raid de retomber sur du farming;
- [x] enregistrer un historique minimal des runs PvE joueur;
- [x] afficher les derniers runs PvE joueur dans `Fenetre_Personnage`;
- [x] enrichir le message de fin de donjon dans le chat;
- [x] afficher le meilleur clear connu du dernier contenu PvE dans `Fenetre_Personnage`;
- [x] corriger l'emission de `boss_defeated` pendant les conflits de loot;
- [x] ajouter un apercu de preparation dans `Fenetre_OrganisationGroupe`;
- [x] proteger `DungeonData.calculate_difficulty_score()` contre les groupes vides;
- [x] brancher un classement National/Mondial minimal dans `GuildRanking`;
- [x] proteger le score d'activite de `GuildRanking` contre les guildes vides;
- [x] transformer la fenetre de butin en rapport PvE dedie avec score de performance;
- [x] persister et afficher le score de performance dans l'historique PvE;
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

---

# Audit approfondi — passe multi-agents (1er juin 2026)

Méthode : 6 sous-agents en parallèle, chacun creusant un aspect (simulation/comportements, boucle PvE, économie/recrutement/IA/classement, national/esport, UI/UX, architecture/santé du code). Toutes les trouvailles sont **vérifiées dans le code** (réf. `fichier:ligne`). La suite de tests reste verte (101/101, Godot 4.6.2) — fait notable : **plusieurs bugs majeurs sont masqués par les tests**, qui écrivent l'état en dur (ex. `guild.gold = 5000`) au lieu de passer par les API réelles.

Sévérité : 🔴 critique (casse une boucle/feature annoncée) · 🟠 majeur · 🟡 mineur.

## Synthèse — nœuds systémiques (à traiter en priorité)

Ces problèmes ont été **confirmés indépendamment par plusieurs agents** et forment la racine de la plupart des autres symptômes :

1. **Économie non finançable** : `complete_run` ne verse **aucun or** (que de l'XP/loot), et `Guild.add_gold()` **plafonne l'or à 1000** dès le niveau 3 de guilde. Les prix de tournoi (12000), masses salariales staff (~2200/sem) et primes de transfert (6000–10500) sont littéralement impayables/instockables. → voir A1, A2, E?.
2. **Double moteur PvE** : `DungeonRun` (mort) et `DungeonInstance` (vivant) coexistent avec des maths différentes et des **signaux homonymes de signatures incompatibles**. Le moteur vivant a perdu au passage l'équité de loot, la connaissance de donjon, les réactions de tags et l'application des perks. → B1.
3. **Compétition IA factice** : les guildes IA sont simulées sur des **`Timer` en temps mural** (300 s/10 s réelles) découplés de `GameTime` ; à vitesse > 1x elles gèlent pendant que le joueur fonce. En plus leur score PvE compte les **clears en double**. → C1, C2.
4. **Persistance manquante** : tout le **graphe social** (relations, cliques, profils comportementaux), l'**état d'EventManager** (cooldowns, one-time, chaînes) et les **runs/tournois en cours** ne sont **pas sauvegardés** ; les clés relationnelles utilisent `get_instance_id()` (non stable entre sessions). → D?, G1, G2.
5. **Conséquences calculées mais jamais lues (façades)** : célébrité→recrutement/débauchage, perks de guilde→combat, staff→PvE, stabilité→réputation, circadien→performance, évolution des profils… tout est codé puis jamais branché. → transversal.
6. **Pas de gating de phase** : médias/dramas/sponsors tournent dès la Phase 0 (Leveling), déclenchant des popups modaux hors contexte. → E3.
7. **Code mort structurel** : `EventBus` (330 l., non autoloadé, 0 référence), tout le moteur de connexion dynamique du `BehaviorSystem`, les helpers `GameRandom`, `scenes/Main_old.tscn`. → G?, D1.

## A. Économie, recrutement, classement, guildes IA

- **Le PvE ne rapporte aucun or** — `Gameplay` 🔴 — `dungeon_run.gd:251-254` (et `DungeonInstance._complete_dungeon` distribue `gold_reward` mais via `add_gold` plafonné). La guilde démarre à 0 (`guild.gd:23`) ; seules sources : farming (niv 60 + perk niv 3, 1-8 or/5 min) et sponsors (phase nationale). → Verser de l'or à chaque clear (proportionnel au contenu/difficulté/boss), via `BalanceManager`.
- **L'or est plafonné à 1000 à vie** — `Code`/`Gameplay` 🔴 — `add_gold` clampe à `gold_storage` (`guild.gd:80-84`) qui vaut 1000 et n'est défini qu'au niveau 3 (`guild_perks_data.gd:17`), jamais augmenté ensuite. Avant le niveau 3 `max_gold=0` → illimité, donc le cap **apparaît en montant de niveau** (contre-intuitif). L'or gagné au-delà est jeté sans feedback. → Faire croître `gold_storage` par paliers (1k→5k→20k→100k) ou supprimer le cap dur ; notifier les débordements. Ajouter un test qui passe par `add_gold()` (pas `=`).
- **Guildes IA sur timers temps réel, découplées de `GameTime`** — `Gameplay`/`Code` 🔴 — `ai_guild_manager.gd:77-87` (`Timer` 300 s / 10 s `autostart`). À 2400x, des mois passent pour 1 tick IA. → Déclencher la simulation sur `GameTime.month_changed`/`day_changed`.
- **Score PvE des IA gonflé par re-clear (asymétrie joueur/IA)** — `Code`/`Gameplay` 🔴 — `ai_guild.gd:539-545` `_get_cleared_content_ids()` n'a **aucune déduplication** ; `guild_ranking.gd:129-135` compte chaque doublon (40/100 pts), alors que le joueur est indexé par `Dictionary` (dédupliqué, `guild_ranking.gd:492`). → Dédupliquer côté IA ; plafonner `recent_clears`.
- **Les IA ne montent jamais de niveau** — `Gameplay` 🟠 — XP cumulatif L5=2000/L10=9000 (`guild_perks_data.gd:72-75`) vs IA démarrant à ~500-740 (`ai_guild.gd:96`) +50-150/succès rare. Elles plafonnent niv 3-4, donc le terme `guild_level*20` (20 % du score) devient un avantage joueur permanent. → Donner aux IA une progression de niveau crédible adossée à réputation/stratégie.
- **Aucune protection contre la faillite, aucun levier de sortie** — `Gameplay` 🟠 — `_pay_salaries` impayé applique juste un malus moral/réput (`guild_manager.gd:88-108`) sans dette ni game-over ; impossible de licencier/renégocier une recrue nationale (seul le staff a `fire_staff`). Combiné à l'absence de revenu PvE → spirale sans issue (masquée par le catch-up en Normal, entière en Difficile). → Permettre de renvoyer/renégocier une recrue ; départ si salaires impayés ; condition d'échec lisible.
- **`server_rank_duration` et `national_rank_duration` partagent `days_at_rank_1`** — `Code`/`Gameplay` 🟠 — `phase_manager.gd:306` & `:335` renvoient le même compteur, incrémenté chaque jour (`_on_day_changed`) sur une position recalculée **seulement chaque semaine** (`guild_ranking.gd:566`). → Deux compteurs distincts, reset au changement de phase ; recalculer le rang le jour de l'évaluation.
- **Réputation comptée deux fois en phases avancées** — `Code`/`Gameplay` 🟡 — `_calculate_reputation_score` (15 % du poids, `guild_ranking.gd:157-168`) **et** `_get_phase_score_multiplier` (`:280-294`) ; en plus `max(0,...)` écrase le départage sous 50. → Un seul canal ; autoriser des valeurs bornées négatives.
- **Refus de recrue = raison aléatoire déconnectée du vrai calcul** — `UI`/`Gameplay` 🟠 — `recruitment_pool.gd:284-286` tire une phrase au hasard, sans lien avec les facteurs réels (réput `:263`, difficulté `:242`, hardcore `:257`, catch-up `:274`). → Exposer un breakdown (chance finale + contributions ±) avant l'invitation et dans le refus.
- **Débauchage invisible et non anticipable** — `Gameplay`/`UI` 🟠 — déclenché seulement dans les simulations sur timer mural (`ai_guild_manager.gd:161,279`) ; seul un succès ouvre un popup, un échec ne fait qu'un `print` (`poaching_handler.gd:29-33`). → Piloter par `GameTime` + alerte anticipée « X (intégration<30) est lorgné ».
- **Double `register_guild` persistant au chargement** — `Code` 🟡 — `ai_guild_manager.gd:452-453` appelle `register_guild` au load alors que `_on_ai_guild_created` (`guild_ranking.gd:597`) le fait à la création. Idempotent mais double-ownership. → Tout passer par le signal `ai_guild_created` (émis aussi au load).
- **Pool national : scouting coûteux à l'aveugle, pas de projection de soutenabilité** — `Gameplay`/`UI` 🟡 — `scout_player` coûte 2 réput/scout pour ~50 % des tags (`recruitment_pool.gd:445-463`) ; l'UI ne montre pas « combien de semaines de runway au salaire demandé ». → Projection de soutenabilité + scouting déterministe/remboursable.

## B. Boucle PvE (donjons, raids, loot, équipement)

- **Deux systèmes de combat parallèles dont un mort** — `Code` 🔴 — `DungeonRun` (`dungeon_run.gd`, 282 l.) n'est appelé que par `_simulate_dungeon_run()` (`fenetre_organisation_groupe.gd:654`), lui-même jamais invoqué ; le jeu passe par `DungeonInstance` (`activity_manager.gd:387`). Signaux homonymes incompatibles (`boss_defeated(boss_name, loot)` vs `(boss_index, boss_name, winner)`) — source des bugs de signature récurrents. → Choisir un seul moteur ; migrer les bonnes idées de `DungeonRun` (connaissance, raisons de wipe, réactions de tags) dans `DungeonInstance`, supprimer l'autre.
- **Raids injouables : roster ≤ 20, compos exigeant 40** — `Gameplay` 🔴 — `max_members` plafonne à 20 (`guild_perks_data.gd:31`) mais MC/BWL/Onyxia demandent 40 (`dungeon_data.gd:319-324`) et l'UI exige tous les slots remplis (`fenetre_organisation_groupe.gd:436-442`). 3 raids sur 4 sont inatteignables. → Découpler « roster » et « groupe de raid » (lancement à effectif partiel avec malus) ou relever `max_members` à 40.
- **Un run en cours ne survit pas à une sauvegarde** — `Code` 🔴 — `SaveManager` ne sérialise ni `ActivityManager.active_dungeons` ni l'état d'un `DungeonInstance`. Save pendant un donjon (F5/auto toutes les 4 sem.) → run perdu, membres potentiellement bloqués en activité `DUNGEON`. → Terminer les runs avant save, ou sérialiser l'instance ; a minima libérer les membres sans donjon au load.
- **Perks de guilde jamais appliqués au combat** — `Gameplay` 🔴 — `get_raid_success_bonus()`, `get_loot_conflict_reduction()`, `get_availability_bonus()` (`guild.gd:64-74`) ne sont lus nulle part dans `DungeonInstance` (`_calculate_boss_success_chance:206`, `_on_boss_defeated:286`). Les perks « Ventrilo +5 % », « DKP -20 % conflits » sont cosmétiques. → Multiplier la chance par les bonus et réduire la proba de conflit.
- **Le combat boss attend un timer temps réel** — `Code` 🟠 — `await create_timer(2.0)` (`dungeon_instance.gd:182`) en secondes réelles, hors `is_paused` ; à 2400x le donjon est déjà « fini » ; reprise possible sur une Resource invalide. → Compter en temps de jeu dans `_update_boss_fight` (déjà vide, `:384`) + garde `is_active`/index.
- **Attribution de loot purement aléatoire dans le moteur vivant** — `Gameplay` 🟠 — hors conflit, `group_members.pick_random()` (`dungeon_instance.gd:319`), sans tenir compte de l'iLvl ni de l'upgrade ; `try_auto_equip` jette ensuite l'objet → loot perdu pour tous. L'équité « priorité aux sous-équipés » n'existe que dans le code mort. → Pondérer par `would_be_upgrade`/plus bas iLvl éligible.
- **`calculate_item_score` ignore le rôle (tank/heal)** — `Gameplay` 🟠 — score basé sur la stat préférée de **classe** (`simulated_player.gd:359`), pas du rôle ; un objet d'iLvl +20 « off-stat » n'est jamais un upgrade (`would_be_upgrade:400`). → Plancher d'iLvl dans le score, ou préférence dérivée du rôle.
- **`calculate_difficulty_score` : sémantique floue et saturation** — `Gameplay` 🟠 — dans le code mort `success_chance = difficulty_score` (200 % possible, `dungeon_run.gd:60`) ; plafond dur à 2.0 (`dungeon_data.gd:364`) atteint très tôt ; `expected_equipment = level_recommended*3` arbitraire. → Clarifier (facteur de force → proba bornée comme `DungeonInstance`), référencer `get_recommended_ilvl_for_dungeon()*5`.
- **`connaissance_donjons` sauvée mais jamais incrémentée en jeu** — `Code` 🟠 — lue/écrite uniquement par le code mort `DungeonRun` (`:232`). → Brancher dans `DungeonInstance` ou retirer le champ + sa sérialisation.
- **Malus de wipe appliqué deux fois** — `Code` 🟠 — `success_chance *= pow(0.95, wipe_count)` (`dungeon_instance.gd:198`) **et** moral/énergie déjà ponctionnés par `_on_boss_failed` (`:361`). Compounding géométrique sans plafond avant `MAX_WIPES=10`. → Un seul canal de pénalité, ou borner.
- **Conflits de loot : seul un sous-ensemble arbitré, butin perdu** — `Gameplay` 🟠 — conflit seulement si item `≥ RARE` et `≥ 2` upgrades (`dungeon_instance.gd:286-292`) ; les UNCOMMON (30 % des drops) partent en `pick_random` + auto-equip, détruits si non voulus. Pas de priorité (DKP/council). → Banque de guilde réattribuable + système need/greed/DKP.
- **Aucune décision de manager avant le run** — `Gameplay` 🟠 — l'Organisation compose puis « Lance » ; aperçu purement informatif (`fenetre_organisation_groupe.gd:455`). Stratégie/risque/priorité loot/remplaçants absents ; `stress_level`/`get_esport_performance_factor()` non injectés dans la proba. → Phase de préparation (curseurs prudence↔agressivité, priorité loot) + brancher stress/esport.
- **Rapport de run non causal ; delta d'équipement trompeur** — `UI` 🟡 — `Fenetre_Loot` (`:243-255`) montre le score sans le décomposer ni lister les MVP/erreurs de compo/conséquences sociales promises ; `fenetre_equipement.gd:171` compare l'item au slot **vide** (`item.strength` vs 0), pas à l'objet équipé. → Décomposer le score, lister 1-2 MVP, delta réel vs item équipé.
- **`reset_days` raid jamais implémenté (pas de lock-out)** — `Gameplay` 🟡 — `dungeon_data.gd` définit `reset_days` mais il n'est lu nulle part → spam de Molten Core (2750 or/run). → Lock-out hebdo via `GameTime.get_total_days_elapsed` + dernier clear par contenu (déjà dans `GuildRanking`).
- **`progress_percent` non monotone + division par zéro possible** — `Code` 🟡 — `_complete_dungeon` divise `gold_reward / group_members.size()` (`dungeon_instance.gd:395`, 0 si vide) ; barre qui recule entre boss (`:137-139`). → `max(1, size)` ; base de progression monotone.

## C. Simulation des joueurs & comportements

- **Moteur de connexion dynamique mort** — `Code` 🔴 — `should_connect_dynamic()`/`should_disconnect_dynamic()` (`behavior_system.gd:79,141`) calculent la présence à partir de fatigue/burnout/humeur/amis en ligne mais ne sont **appelés nulle part** ; la présence réelle suit `_check_scheduled_connections()` (créneaux fixes + variance, `:515`). Fatigue/burnout/social n'influencent donc pas la présence. → Brancher ces fonctions dans la boucle `minute_changed`, ou injecter leurs modificateurs dans `_get_base_connection_probability`.
- **`apply_circadian_modifier` mort → type circadien sans impact perf** — `Gameplay` 🟠 — `behavior_system.gd:265` (±30 %) jamais appelé ; `circadian_type` ne décale que l'heure de connexion. → Appliquer au skill effectif pendant le PvE selon l'heure.
- **`BehaviorProfile.adjust_from_experience` mort → profils figés** — `Gameplay` 🟠 — `behavior_profile.gd:251` jamais appelé ; la « mémoire émotionnelle/apprentissage » est une façade. → Appeler depuis `trigger_raid_success`/`trigger_wipe`/`trigger_loot_conflict`.
- **`PersonalEvents` à moitié mort + API invalide** — `Code` 🟠 — `behavior_system` n'utilise que 3 ids en dur dont `planned_obligation` **inexistant** dans la DB (sortie silencieuse) ; `should_trigger_event`/`apply_event_effects` (`personal_events.gd:263,422`) utilisent `player.has(...)` qui n'existe pas sur `Resource`. ~18 événements jamais tirés. → Router vers `get_event_for_player()`, corriger `has()`→`in`/`get()`, fixer l'id.
- **Absences planifiées & temps bonus stockés jamais consommés** — `Gameplay` 🟠 — `scheduled_absences`/`bonus_session_hours` remplis (`behavior_system.gd:305,311`) mais **aucune lecture**. Une absence prévue n'a aucun effet le jour J. → Vérifier `scheduled_absences` (jour absolu) dans le chemin de connexion ; appliquer `bonus_session_hours` à la durée de session.
- **Jour mémorisé en 1-7 au lieu du jour absolu** — `Code` 🟡 — `simulated_player._get_current_day()` (`:707`) renvoie `current_day` (remis à 1 chaque semaine) ; comparaisons `current_day - last_wipe_day` faussées au passage de semaine (`behavior_system.gd:124,223`, `social_dynamics.gd:404`). Même classe de bug que celui corrigé pour `RecruitmentPool`. → Utiliser `GameTime.get_total_days_elapsed()`.
- **`STUDENT` : influence sociale nulle** — `Code` 🟡 — `get_influence_on_player` (`social_dynamics.gd:170`) ne gère que FRIEND/MENTOR/RIVAL/ENEMY ; l'élève ne reçoit aucune influence de son mentor (casse la symétrie + désignation de leader de clique). → Ajouter le cas `STUDENT`.
- **Inventaire de tags trompeur** — `Gameplay` 🟡 — `TAG_DATABASE` a ~14 tags / 5 catégories (doc : « 6 catégories, 50+ tags ») ; `perfectionniste`/`ponctuel`/`retardataire` sans effet ; `impatient`/`patient`/`leader`/`organise` **référencés dans le code mais absents de la DB** → jamais attribuables aux PNJ (branche `impatient` morte). → Étoffer la DB et donner un effet aux tags inertes, ou corriger la doc.
- **États de simulation invisibles dans la fiche membre** — `UI` 🟡 — `Fenetre_Guilde` (`:290-388`) n'affiche pas fatigue/burnout/stress ni relations ; ils ne sont visibles qu'en Esport/Conseils, donc invisibles en phases 0-2 où ils pilotent la présence. → Jauge Fatigue + badge Burnout + mini-bloc Relations (réutiliser `Badge`/`StatDisplay`/`CustomProgressBar`).
- **Tags sans causalité lisible** — `UI` 🟡 — tooltip = description statique (`fenetre_guilde.gd:362`), pas l'effet mécanique réel (`rage_quitter`→quitte après 2 wipes, `ninja_looter`→vole du loot). → Enrichir le tooltip avec l'effet + colorer les tags problématiques.

## D. National & Esport (Milestones 3-4)

- **Célébrité non branchée (façade) + logique dupliquée** — `Gameplay` 🔴 — `get_celebrity_bonus_recruitment()`/`get_celebrity_poaching_risk()` (`simulated_player.gd:417-427`) jamais appelés ; `tick_celebrity_weekly()` (`:429`) mort et doublonne `MediaManager._update_celebrity()`. Un membre célèbre n'a ni bonus de recrutement ni surrisque de débauchage. → Brancher dans `RecruitmentPool`/`PoachingHandler` ; supprimer le doublon.
- **Médias/dramas/sponsors actifs dès la Phase 0** — `Gameplay`/`Code` 🔴 — `_on_week_changed` inconditionnels (`media_manager.gd:23`, `drama_manager.gd:26`, `sponsorship_manager.gd:39`) ; un drama (10 %/sem) ouvre un popup modal avec pause auto dès la semaine 1 en Leveling. → Gater à `phase >= NATIONAL` (sauf drama de loot appelé depuis le PvE).
- **`drama_queen` (tag caché) déclenche des dramas avant révélation** — `Gameplay` 🟠 — `_has_tag` couvre `tags_caches` (`drama_manager.gd:151`) ; le joueur subit l'effet d'un trait qu'il ne peut pas voir. → Ne considérer que les tags révélés, ou révéler le tag au 1er drama.
- **Boucle audience↔célébrité non bornée → revenus runaway** — `Gameplay`/`Code` 🟠 — `_update_streamers` ajoute `randi(0,500)+celebrity*10` sans plafond (`media_manager.gd:74`), `_update_celebrity` réinjecte `audience/1500` (`:41`). Une fois le cap d'or corrigé, revenu infini. → Plafonner l'audience (courbe logistique) + rendement décroissant.
- **`on_team_stability_bonus()` et `on_drama_event()` morts** — `Code` 🟠 — `guild.gd:275,285` jamais appelés (DramaManager applique sa propre perte de réput en dur, `:93`). → Brancher ou supprimer ; unifier la perte de réputation drama.
- **Soft-lock sponsors** — `Gameplay` 🟠 — exigence `no_scandal_weeks` (défaut 4, `sponsor.gd:17`) rarement tenue vu la fréquence des dramas → aucun contrat signable ; et `satisfaction -= 10`/sem sous seuil (`:37`) → un scandale fait -40 sur 4 semaines = résiliation + -10 réput. → Adoucir (satisfaction qui remonte, pénalité graduée) ; ne proposer que des sponsors atteignables.
- **Tournois sans garde-fou** — `Gameplay`/`Code` 🟠 — `participate()` (`tournament_manager.gd:120`) ne vérifie ni roster, ni phase, ni cooldown ; roster vide → 5 % de victoire par chance ; gratuit, spammable toutes les 3 sem. → Exiger phase Esport + roster minimum ; frais d'inscription/risque de réputation.
- **Transferts : joueurs générés sans classe/rôle/nom/tags** — `Code`/`Gameplay` 🟠 — `_generate_international_player()` (`transfer_manager.gd:69-83`) ne fixe que niveau/skill/salaire/région ; recruté, ce joueur casse la composition PvE. → Réutiliser le chemin de génération procédurale du pool national.
- **`last_results` de tournoi jamais réinitialisé** — `Code`/`UI` 🟡 — affiche « 🏆 Champion » indéfiniment (`fenetre_esport.gd:395`). → Horodater / estomper après quelques semaines.
- **Fenêtres 6 onglets reconstruites à chaque tick** — `Code`/`UI` 🟡 — `_refresh_all()` `queue_free` + rebuild tous les onglets sur `week_changed` (`fenetre_esport.gd:118,124`) ; le SpinBox d'offre en cours est recréé sous les doigts, scroll/onglet réinitialisés ; churn permanent à haute vitesse. → Rafraîchir seulement l'onglet visible, mise à jour in-place, pas de rebuild pendant une interaction.
- **Le staff n'a aucun effet hors tournoi/Esport** — `Gameplay` 🟡 — bonus lus seulement par `tournament_manager` et `_process_wellbeing` (gaté Esport) ; aucun impact sur le PvE serveur. ~2000 or/sem pour un bénéfice quasi invisible. → Lire les bonus staff dans le calcul de run PvE.
- **`streaming_vs_raid` cosmétique** — `Gameplay` 🟡 — n'émet qu'un message chat (`main.gd:587`), aucun effet mécanique. → Coût réel (malus perf/dispo) ou retirer.

## E. UI / UX

- **Le multi-fenêtres est mort : `show_window()` cache tout sauf une** — `Code` 🔴 — `window_manager.gd:153` `.hide()` toutes les autres ; toute la navigation menu passe par là (`main.gd:177-198`). `cycle_windows` (Alt+Tab), `arrange_cascade/tile` (Ctrl+Shift+C/T) et la taskbar de minimisation (~200 l.) sont morts. → Assumer le mono-fenêtre et retirer le code mort, ou exposer un vrai mode multi (Maj+clic = `open_window` sans masquage).
- **Le chat chevauche la barre de menu** — `UI` 🟠 — chat ancré bas-droite `offset_bottom=-20` (`main.gd:93`) vs barre de 80 px en bas (`menu_bar.gd:19`). → Remonter le chat (`offset_bottom=-90`) ou l'ancrer au-dessus de la barre dans le `VBoxContainer`.
- **Animation d'ouverture vs taille minimale → effet de pop** — `Code`/`UI` 🟠 — `_animate_window_open` met `size = ZERO` (`window_manager.gd:646`) mais les fenêtres forcent `custom_minimum_size` 800×600+ → pas de grossissement, juste un saut. → Animer `scale` (0.96→1) + `modulate:a`.
- **Fenêtre d'équipement sans drag & drop** — `UI` 🟠 — `AcceptDialog` lecture seule (`fenetre_equipement.gd:48-109`) alors que `DraggableItem`/`DropZone` existent. → Slots en `DropZone`, inventaire en `DraggableItem`.
- **Seuils de couleur iLvl décalés des tables de loot** — `Code` 🟠 — couleur sur l'iLvl **total** (Épique ≥200, `fenetre_equipement.gd:125`) alors qu'un endgame fait 250-425 et le early <100 → tout « Commun » puis saut direct « Épique ». → Couleur sur l'iLvl moyen par pièce.
- **Données factices affichées comme réelles (Monde)** — `UI`/`Code` 🟠 — `_populate_recent_events()` (`fenetre_monde.gd:1126`) injecte « Clear de Scholomance » en dur pour la guilde **du joueur** ; « points forts » `shuffle()` aléatoires. → Brancher sur `GuildRanking.get_player_run_history()` / vraie réputation, ou marquer « estimation ».
- **Navigation par index de nodes en dur** — `Code` 🟠 — `tab.get_child(0).get_child(0)...get_child(1)` (5 niveaux, `fenetre_monde.gd:484`), idem `:1092`, `:807`. Toute insertion casse le filtrage. → Garder des références membres posées à la construction.
- **Les 4 fenêtres cœur réimplémentent header/drag (ResizableWindow inutilisé)** — `Code` 🟠 — `_setup_header`/`_on_header_drag` dupliqués ~6× ; `resizable_window.gd` (avec `class_name`) jamais instancié ; seule `fenetre_guilde` gère le resize. → Hériter d'une base commune / `ResizableWindow`.
- **Composant `Badge` buggé, contourné partout** — `Code` 🟡 — `_animate_appear()` met `scale = ZERO` (`badge.gd:286`) ; `fenetre_conseils` réimplémente une pastille maison, national/esport posent `animate_appearance=false` sur chaque badge. → Animer `modulate:a` seul ; retirer les contournements.
- **Raccourcis Ctrl+P/G/M/O/N/E/K/A invisibles** — `UI` 🟡 — aucun `tooltip_text` sur les boutons de menu (`menu_bar.gd:73`). → `tooltip = "%s (Ctrl+%s)"` + rappel Espace/Échap.
- **Pas de tooltip de causalité sur les actions clés** — `UI` 🟡 — ~0 tooltip dans les fenêtres cœur ; « Envoyer une invitation », score de classement, « Lancer l'activité » sans explication. → Tooltips de causalité (facteurs d'acceptation, parts du score, malus déjà calculés).
- **`DropZone` refuse hors-rôle sans explication ni override** — `UI`/`Code` 🟡 — `_can_fill_role` strict (`fenetre_organisation_groupe.gd:747`), rejet silencieux, rôle affiché en simple icône. → Avertissement au lieu de rejet, rôle écrit en clair.
- **3 sources de vérité pour les couleurs** — `Code` 🟡 — `chat_panel.MESSAGE_COLORS` (`:8`), `UIConstants`, `UITheme` divergent ; les fenêtres récentes redéclarent encore `ACCENT/DIM/GOLD` localement. → `UITheme` source unique, dériver le reste.
- **TimeDisplay : slider continu sans paliers** — `UI` 🟡 — `HSlider` 0.1→2400 step 0.1 (`time_display.gd:30`), vitesse précise impossible. → Boutons de paliers (Pause/1x/10x/60x/Max) à la Football Manager.
- **Requirements de phase sans StatDisplay/CustomProgressBar** — `UI` 🟡 — `fenetre_personnage.gd:492` reconstruit chaque carte à la main ; barres XP/énergie en Labels bruts (`:241`). → Réutiliser les composants existants.

> Note transversale UI : les 4 fenêtres cœur (`personnage`/`guilde`/`monde`/`organisation`) datent d'avant la lib de composants (Labels bruts, ~0 tooltip, peu de Badge) ; les fenêtres récentes (`national`/`esport`/`social`/`conseils`) utilisent `_kv`/`_card`/Badge. Le plus gros gain UX serait d'**aligner les 4 cœur sur ce standard**.

## F. Architecture, save/load, santé du code

- **`EventBus` : 330 lignes de code 100 % mort, même pas autoloadé** — `Code` 🔴 — `event_bus.gd` (26 signaux, API complète) a **0 référence** et **n'est pas dans `[autoload]`** de `project.godot`. Fausse piste pour tout contributeur. → Supprimer (ou réintégrer réellement).
- **Le graphe social entier n'est pas sauvegardé** — `Code` 🔴 — `social_dynamics.gd` n'a aucun `serialize/deserialize` ; `GuildCultureManager.serialize()` ne sauve que moral/traditions. Relations/cliques perdues au reload ; indexées par `get_instance_id()` non stable. → `id` stable par joueur + `SocialDynamics.serialize` + bloc `"social"` dans SaveManager (recoupe « persistance » de la synthèse).
- **L'état d'EventManager n'est jamais sauvegardé** — `Code` 🔴 — pas de bloc `events` (`save_manager.gd`) ; `event_history` (cooldowns/one-time), `active_chains`, `pending_event` perdus → un événement `one_time_only` peut re-déclencher. → `serialize/deserialize` EventManager + bloc `"events"` + migration v2→v3.
- **`GameRandom.seed_rng()` jamais appelé en prod ; helpers morts** — `Code` 🟠 — seuls les tests l'appellent ; `main.gd` ne fixe jamais la graine, 267 appels directs `randf/randi/pick_random/shuffle` dans 35 fichiers ; les helpers `GameRandom.chance/weighted_pick/variance/...` ont 0 appelant hors tests. → Appeler `seed_rng`/`randomize_rng` au boot (+ persister la graine), adopter ou retirer les helpers.
- **Fuite de références : `player_scheduled_times` jamais purgé** — `Code` 🟠 — indexé par objet membre, jamais nettoyé au départ (`behavior_system.gd:21`, ajouts `:591,633`) ; `remove_member` ne notifie pas le BehaviorSystem. → `forget_player(player)` appelé depuis `remove_member`.
- **Fan-out temps non borné à haute vitesse** — `Code` 🟠 — `game_time.gd:42` `while accumulated_time >= 60: advance_minute()` ; chaque minute → boucles complètes membres × (GuildManager + BehaviorSystem + EventManager + IA). O(membres × boucles)/heure sans budget ; `fast_forward_hours` fait 60 `advance_minute` synchrones (`:100`). → Plafonner les minutes par frame, regrouper les recalculs lourds sur `hour_changed`/`week_changed`.
- **Tournois (offres/résultats) non sauvegardés ; matching par nom non unique** — `Code` 🟠 — `tournament_manager.gd:184` ne sauve que des compteurs ; `media`/`transfer`/`sponsor` ré-associent par `member.nom` (`media_manager.gd:165`) — clé non unique. → Sauver les offres en cours ; matching par `id` membre stable.
- **37 `get_node("/root/...")` en dur + chemins enfants fragiles** — `Code` 🟠 — 18 fichiers, dont UI (`fenetre_monde.gd:120,320`, `chat_panel.gd:81`) et `activity_manager.gd:195` qui cible `"/root/GuildManager/BehaviorSystem"` ; `Singletons.get_autoload()` existe (31 usages). → Référencer les autoloads par leur nom global ; exposer `GuildManager.behavior_system` au lieu d'un chemin enfant.
- **Cluster de signaux orphelins** — `Code` 🟡 — émis sans listener : `clique_formed`, `social_conflict`, `relationship_broken`, `poaching_attempt` (×2), `monthly_simulation_completed`, `content_unlocked`, `effect_stack_changed` ; déclarés sans emit ni connect : `counter_offer_result`, `sponsor_offer_available`. → Brancher des consommateurs (ex. notif « guilde rivale tente de débaucher X ») ou retirer.
- **`expectations.hardcore` sans `.get()` (crash latent)** — `Code` 🟡 — `recruitment_pool.gd:257,259,293,295` sur une meta défaut `{}` sans clé `hardcore`. → `expectations.get("hardcore", false)`.
- **`window_manager._load_layouts` sans garde de type** — `Code` 🟡 — `save_data.get("layouts", {})` sans `is Dictionary` (`window_manager.gd:638`) ; plante si JSON corrompu. → Garde de type comme `save_manager.gd:138`.
- **`scenes/Main_old.tscn` : scène morte versionnée** — `Code` 🟡 — 0 référence. → Supprimer.
- **~194 `print()` dont 19 dans EventManager (boucle horaire)** — `Code` 🟡 — chantier debug (Priorité 4) partiel ; `event_manager.gd` spamme plusieurs lignes/heure. → Logger gardé par `OS.is_debug_build()`, en priorité dans EventManager.

## Ordre de chantier suggéré (passe 2)

1. **Débloquer l'économie** : verser de l'or au PvE + lever/relever le cap `gold_storage` (A1, A2). Sans ça, tout le national/esport reste théorique.
2. **Unifier le PvE** : choisir `DungeonInstance`, brancher perks/connaissance/équité de loot, supprimer `DungeonRun` ; débloquer les raids (roster vs compo) (B1, B2, B4).
3. **Rendre la compétition réelle** : IA pilotées par `GameTime`, score dédupliqué, progression de niveau crédible (C1, C2, A?).
4. **Boucler la persistance** : social + events + runs/tournois, avec `id` membre stable (synthèse #4).
5. **Brancher les façades** : célébrité→recrut/débauchage, staff→PvE, gating de phase (synthèse #5/#6).
6. **Aligner l'UI cœur** sur le standard récent + corriger le multi-fenêtres mort et le chevauchement chat (E).

## Suivi d'implémentation — passe 2 (1er juin 2026)

Implémenté et validé (suite de tests passée de 57 → **123 assertions**, 100 % vertes ; `Main.tscn` démarre sans erreur ; 96 scripts compilent) :

- ✅ **Économie** : l'or PvE est versé à la guilde à chaque clear (tunable `pve.gold_reward_mult`) ; `gold_storage` croît avec le niveau (1k→250k) au lieu du cap dur à 1000 ; débordement notifié.
- ✅ **Moteur PvE unifié** : `DungeonRun` (mort) supprimé ; perks de guilde (réussite raid, réduction conflits DKP), connaissance de donjon et équité de loot branchés dans `DungeonInstance` ; XP de guilde au clear restaurée.
- ✅ **Raids jouables** : compos réduites à un noyau (40→15, 20→10) ; lancement à effectif partiel pour les raids.
- ✅ **Robustesse PvE** : résolution de boss en temps de jeu (plus d'`await` temps-réel) ; progression monotone ; plancher de réussite ; division par zéro corrigée.
- ✅ **Guildes IA** : pilotées par `GameTime` (plus de timers muraux) ; score de contenu dédupliqué ; progression de niveau crédible.
- ✅ **Persistance** : `player_id` stable ; graphe social (relations/cliques), profils comportementaux et état d'`EventManager` (cooldowns/one-time) sauvegardés ; `save_version` 2→3 + migrations.
- ✅ **Façades branchées** : staff→PvE, célébrité→débauchage/recrutement, stabilité→réputation ; `tick_celebrity_weekly` mort supprimé.
- ✅ **Gating de phase** : médias/sponsors/dramas gatés à la phase Nationale ; `drama_queen` caché ne déclenche plus de drama avant révélation.
- ✅ **Comportements** : `_get_current_day` en jour absolu ; mémoire émotionnelle (évolution des profils) ; influence `STUDENT` ; purge des caches au départ d'un membre.
- ✅ **National/Esport** : audience plafonnée (anti-runaway) ; tournois gardés (phase Esport + roster ≥ 5) ; pénalité d'élimination précoce.
- ✅ **Nettoyage** : `EventBus` (mort, non autoloadé) et `Main_old.tscn` supprimés ; crash latent `expectations.hardcore` corrigé ; garde de type sur le chargement de layout.
- ✅ **UI** : chat ne chevauche plus la barre de menu ; couleur d'iLvl sur la moyenne par pièce ; tooltips de raccourcis sur les boutons de menu.

Reportés (notés dans les commits, valeur/risque moindre) : migration des ~37 `get_node("/root/..")`, `print()`→logger, enrichissement de la base de tags ; refonte complète de la connexion dynamique, circadien→perf, refonte `PersonalEvents` ; soft-lock sponsors, persistance des offres de tournoi ; multi-fenêtres mort, drag&drop d'équipement, unification `UIConstants`/`UITheme`, données factices de la fenêtre Monde.

### Lot reporté — traité ensuite (1er juin 2026, suite)

La majorité des reportés ci-dessus a été reprise dans une seconde passe (suite de tests **123 → 131 assertions**, vertes) :

- ✅ **Sponsors** : soft-lock assoupli (pénalité -10→-6, récup +2→+4, `no_scandal_weeks` 4→2) ; **offres de tournoi persistées** (+ `last_results`).
- ✅ **Données factices** : la fenêtre Monde affiche désormais les vrais derniers runs/réputation/moral pour la guilde du joueur (les IA gardent des estimations, normal pour un concurrent).
- ✅ **Tags** : `impatient` ajouté à la base (sa branche de recrutement était morte).
- ✅ **Circadien → PvE** : le modificateur matin/soir s'applique à la réussite de combat.
- ✅ **Absences planifiées** : consommées par le système de connexion (un membre en « absence » ne se connecte plus) ; `start_day` en jour absolu.
- ✅ **Santé du code** : chemin enfant fragile `"/root/GuildManager/BehaviorSystem"` remplacé par `GuildManager.behavior_system` ; prints horaires d'`EventManager` gardés en build debug.

Restent volontairement reportés (à faire avec validation **visuelle** via l'éditeur/MCP, ou design à trancher) : refonte complète de la connexion dynamique (`should_connect_dynamic`) et routage de la pool `PersonalEvents` ; **drag&drop d'équipement**, unification `UIConstants`/`UITheme`, décision sur le code multi-fenêtres mort ; migration de masse des `get_node("/root/..")` restants et `print()`→logger complet.

### Lot reporté — repris (2 juin 2026, passe « reprise des améliorations »)

Suite de tests **131 → 155 assertions** vertes, + E2E. Reste uniquement le **drag&drop d'équipement** (= construire un inventaire/banque, vraie feature).

> **MàJ 2 juin 2026 — drag&drop d'équipement LIVRÉ** (171 assertions vertes + E2E 5/5). `Guild.bank_items` est une vraie banque d'`Item` (cap + trim, sérialisée) ; le loot non-équipé et les swaps vont en banque (`GuildManager.route_loot`) au lieu d'être jetés ; la fenêtre « Banque & Équipement » est réécrite en `PanelContainer` thémé avec **drag&drop natif** (composant `EquipDragCell`, `equip_from_bank`/`unequip_to_bank`). **Tous les lots de l'audit sont désormais traités.**

- ✅ **Connexion dynamique (C1)** : `_connection_state_modifier()` (fatigue/burnout/humeur/amis) injecté dans `_check_scheduled_connections` (chance de connexion + proba de déconnexion) ; déconnexion forcée sur épuisement/burnout sévère. Présence enfin pilotée par l'état.
- ✅ **PersonalEvents** : `_check_personal_events` route via `should_trigger_event()` + `get_event_for_player()` (toute la base) ; `player.has(...)` (crash Resource) corrigé ; `trigger_personal_event` applique humeur/énergie + tous les types d'effet ; **temps bonus consommé** (rallonge la session).
- ✅ **`get_node("/root/..")` → autoloads** : 38 sites migrés (managers/systèmes/UI/resources) ; `singletons.gd` intact.
- ✅ **`print()` → logger** : `GameLog.d()` gardé par `OS.is_debug_build()`, 132 prints de boucle migrés.
- ✅ **Multi-fenêtres mort (E)** : mono-fenêtre assumé ; `cycle_windows`/`arrange_cascade`/`arrange_tile`/minimisation/taskbar/layouts nommés + signaux/consts orphelins retirés ; mémorisation des positions rendue réellement persistante.
- ✅ **Couleurs (E)** : `UITheme` = palette unique ; `UIConstants` et `chat_panel.MESSAGE_COLORS` en dérivent (plus de 3 sources divergentes).
