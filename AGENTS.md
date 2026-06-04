# AGENTS.md

Ce fichier donne le contexte projet a Codex et aux agents qui travaillent sur RaidLead.
Il doit rester a jour quand une feature majeure, un autoload, une fenetre ou un workflow de test
change.

## Project Overview

RaidLead est un jeu de simulation/management de guilde MMO construit avec Godot. Le joueur gere une
guilde, son roster, son equipement, sa progression PvE, sa reputation, son passage vers la scene
nationale puis esport, avec une inspiration Football Manager appliquee a un MMORPG fictif.

Technologies et contraintes :

- Engine : Godot Engine 4.6.2 stable.
- Langage principal : GDScript 4, typage statique systematique.
- Renderer : Compatibility / OpenGL3.
- Plateforme cible : PC, distribution Steam envisagee.
- Documentation de design : majoritairement en francais.
- Style de jeu : simulation systemique. Les UI doivent aider le joueur a lire l'etat du monde, pas
  remplacer les systemes.

## Hard Rules

1. Toujours lancer Godot avec `--rendering-driver opengl3`.
2. Ne jamais utiliser de variables GDScript non typees.
3. Ne jamais utiliser de patterns Godot 3.x (`yield`, `tool`, connexions par string, etc.).
4. Ne jamais utiliser de chemin profond du type `get_node("../../../Other")`. Utiliser signaux,
   autoloads, injections simples ou APIs de fenetres.
5. `_ready()` n'est pas rappele lors d'un hot reload : penser aux etats persistants en session.
6. Si une feature de gameplay est implementee, mettre a jour `RoadmapComplet.md`.
7. Si une feature ajoute de la persistence, mettre a jour `SaveManager`, les migrations et les tests.
8. Pour les chiffres d'equilibrage reutilisables, privilegier `BalanceManager` ou une source de
   donnees claire plutot que des constantes dispersees dans l'UI.

## Project Structure

Structure actuelle :

```text
/assets/                 # Assets du jeu, imports Godot, generated assets
/data/chat/              # Corpus JSON du chat de guilde vivant
/docs/                   # Design docs, audits, specs, documentation systemes
/resources/              # Resources Godot eventuelles (.tres, .res)
/scenes/                 # Scenes Godot principales et fenetres
/scripts/
  /autoloads/            # GameTime, GuildManager, RecruitmentPool, SaveManager, etc.
  /data/                 # Donnees statiques : donjons, loot, tags, events
  /managers/             # Managers UI transverses
  /resources/            # Modeles de donnees Resource : joueurs, guildes, items, staff...
  /systems/              # Systemes de simulation et progression
  /systems/chat/         # Backend/scoring/runner du chat
  /ui/components/        # Composants UI reutilisables
  /ui/dialogs/           # Dialogues generiques
  /ui/windows/           # Fenetres principales
  /utils/                # Logging, random, acces singleton
/tests/                  # Test runner, check scripts, smoke/e2e
```

Les anciens sidecars `.gd.uid` peuvent exister dans `scripts/` et sous-dossiers. Ne pas les supprimer
sans raison : Godot peut en regenerer selon l'import/cache.

## Development Commands

### Windows natif, poste courant

Le binaire console courant est :

```powershell
$godot = "C:\Users\gaeta\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
```

Lancer le jeu :

```powershell
& $godot --rendering-driver opengl3 --path .
```

Lancer l'editeur :

```powershell
& $godot --rendering-driver opengl3 --path . -e
```

Valider la compilation des scripts :

```powershell
& $godot --rendering-driver opengl3 --headless --path . "res://tests/CheckScripts.tscn"
```

Lancer les tests :

```powershell
& $godot --rendering-driver opengl3 --headless --path . "res://tests/TestRunner.tscn"
```

Wrapper de tests :

```powershell
powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1
```

Smoke de la scene principale sans charger la save locale :

```powershell
& $godot --rendering-driver opengl3 --headless --path . --scene res://scenes/Main.tscn --quit-after 2 -- --no-save-autoload
```

Important : sous Windows, `--check-only` peut rester suspendu. Utiliser `CheckScripts.tscn` pour la
validation syntaxique.

### WSL2 / Linux

Toujours utiliser OpenGL3 :

```bash
godot --rendering-driver opengl3 --path .
godot --rendering-driver opengl3 --path . -e
godot --rendering-driver opengl3 --headless --path . "res://tests/TestRunner.tscn"
```

Pour les screenshots sous WSL2, ne pas utiliser `--headless`. Utiliser `xvfb-run` si necessaire :

```bash
GALLIUM_DRIVER=d3d12 xvfb-run --auto-servernum godot --rendering-driver opengl3 --path .
```

## Validation Workflow

Workflow recommande pour toute modification de code :

1. Lire les fichiers concernes avant de coder.
2. Si une classe/methode Godot est incertaine, consulter `godot-docs`.
3. Implementer de facon locale, typee, compatible avec les patterns existants.
4. Lancer `CheckScripts.tscn`.
5. Lancer `TestRunner.tscn` si le changement touche gameplay, save, managers, data ou UI runtime.
6. Pour une modification visuelle importante, lancer le jeu via Godot/MCP et verifier par screenshot.
7. Mettre a jour `RoadmapComplet.md` pour toute feature implementee.

`git diff --check` est utile avant de livrer pour detecter whitespace et lignes invalides.

## MCP / Tooling

Le projet est prevu pour un workflow agentique avec :

- `godot-mcp-pro` : manipulation de scenes/nodes/scripts, lancement du jeu, screenshots, input
  simulation, runtime inspection. A privilegier quand il est disponible.
- `godot-docs` : documentation API Godot a jour. A consulter avant d'utiliser une API Godot non
  familiere.
- LSP GDScript / `Codex-gdscript` : diagnostics temps reel, definitions, completions.
- Addon Godot MCP installe dans `addons/godot_mcp`, avec autoloads `MCPScreenshot`,
  `MCPInputService`, `MCPGameInspector`.

Si le MCP n'est pas disponible, utiliser les commandes Godot ci-dessus. Ne pas bloquer le travail
uniquement parce que le MCP est indisponible.

## Current Architecture

### Scene principale et UI

- `scenes/Main.tscn` / `scripts/main.gd` : racine du jeu, fond, barre basse, gestion des fenetres.
- `WindowManager` : ouverture/fermeture/rafraichissement des fenetres. Passer par
  `show_window`, `get_window_instance` et `refresh_window` plutot que manipuler des nodes distants.
- `MenuBar`, `TimeDisplay`, `PlayerControlPanel`, `ChatPanel`, `NotificationToast` : composants
  permanents ou transverses.
- `NotificationManager` : toasts et notifications systeme.
- `UITheme` / `UIConstants` : styles et constantes visuelles partagees.

Fenetres principales existantes :

- `Fenetre_Personnage` : personnage joueur, energie, activites, session, deconnexion/repos.
- `Fenetre_Guilde` : roster, membres, tags, etat social, integration.
- `Fenetre_Monde` : monde, classement, recrutement, pool de candidats.
- `Fenetre_OrganisationGroupe` : composition de groupe, auto-assign, lancement PvE.
- `Fenetre_Donjon` : suivi de run, boss, groupe, log, abandon, rapport.
- `Fenetre_Loot` : resolution de loot, distribution, conflits.
- `Fenetre_Equipement` : equipement joueur/membres, banque de guilde, drag and drop.
- `Fenetre_Conseils` : resume hebdo et recommandations d'`AdvisorManager`.
- `Fenetre_Social` : cohesion, tensions, dynamique sociale.
- `Fenetre_National` : phase nationale, medias, sponsors, recrutement avance.
- `Fenetre_Esport` : staff, tournois, bootcamp, transferts, wellbeing, legacy.
- `EventPopup` / `PoachingPopup` : decisions evenementielles.

Le systeme d'objectifs/quetes est specifie mais pas encore implemente. Voir
`docs/design/2026-06-03-systeme-quetes-guidage.md`.

### Autoloads

Autoloads declares dans `project.godot` :

- `GameTime` : calendrier, horloge, vitesses, signaux de minute/heure/jour/semaine.
- `ServerVersion` : phase de serveur, patches, level cap, hype et contenu disponible.
- `EffectSystem` : effets temporaires/persistants appliques aux joueurs/systemes.
- `ActivityManager` : activites, auto-assign, instances de donjons.
- `GuildManager` : guilde joueur, roster, banque, loot history, salaires, signaux membres.
- `RecruitmentPool` : marche de recrutement vivant, offres, refus, cooldowns, competition IA.
- `EventManager` : evenements aleatoires et choix.
- `PhaseManager` : phases campagne/progression, requirements, transitions.
- `GuildRanking` : classements, progression PvE, server/world firsts.
- `AIGuildManager` : guildes concurrentes, progression IA, poaching.
- `MediaManager` : audience, reputation publique, exposition nationale.
- `SponsorshipManager` : sponsors, contrats, exigences.
- `DramaManager` : dramas, scandales, resolution, impacts.
- `StaffManager` : coach/analyste/psy/manager, bonus et salaires.
- `TournamentManager` : tournois, bootcamp, reputation internationale.
- `TransferManager` : fenetres de transfert, offres, adaptation.
- `LegacyManager` : historique long terme, legacy/hall of fame.
- `NotificationManager` : notifications UI.
- `SaveManager` : sauvegarde versionnee, migrations, backups, load/save managers.
- `AssetLoader` : chargement centralise des assets.
- `GuildCultureManager` : culture de guilde et modificateurs collectifs.
- `AdvisorManager` : conseils tactiques et resume hebdomadaire.
- `BalanceManager` : tunables globaux, difficulte, catch-up/rubber-band.
- `ChatDirector` : orchestration du chat de guilde vivant.
- `MCPScreenshot`, `MCPInputService`, `MCPGameInspector` : services de l'addon MCP.

### Modeles de donnees principaux

- `PlayerCharacter` : joueur controle, energie, session, choix d'activite, deconnexion/repos,
  gains de session.
- `SimulatedPlayer` : NPC joueur de guilde/candidat, classe/role/niveau/skill, tags, planning,
  energie, humeur, integration, equipement, stress, burnout, preferences.
- `Guild` : etat de guilde, membres, gold, reputation, banque, progression.
- `AIGuild` : guilde concurrente, strategie, progression, recrutement, poaching.
- `Item` / `Equipment` : objets, slots, rarete, stats, score.
- `Activity` : activite courante, progression, effets.
- `RandomEventResource` / `EventChoice` : events et choix.
- `Sponsor`, `StaffMember`, `Tournament`, `Drama` : ressources des phases avancees.

## Major Game Systems

### Temps, serveur et hype

`GameTime` porte l'horloge globale. Les systemes reagissent aux signaux temporels plutot qu'a des
timers UI independants. `ServerVersion` gere les patches, le level cap, la hype serveur et le contenu
debloque.

La hype est une variable de simulation : tres haute au lancement, decroissante jusqu'au prochain
patch, puis remontee partielle. Elle influence notamment les connexions et la vitesse de fatigue.

### Planning et comportement des joueurs

`SimulatedPlayer`, `BehaviorProfile`, `BehaviorSystem`, `SocialDynamics` et `PersonalEvents`
pilotent les connexions, deconnexions, preferences d'activite, fatigue, humeur, burnout,
relations/cliques et evenements personnels.

Chaque joueur a son propre calendrier :

- jours actifs probables ;
- archetype horaire ;
- traits nocturne/diurne/hardcore/casual/etc. ;
- jitter et imprevisibilite ;
- contraintes de bon sens pour eviter que tout le monde arrive a 4h du matin ;
- modificateurs de motivation, ambiance de guilde, hype et fatigue.

### Joueur controle et repos accelere

`PlayerCharacter` gere l'energie du joueur et ses sessions. Lors d'une deconnexion/repos, le jeu ne
doit pas simplement skipper l'etat : il avance tres vite pour laisser les ticks normaux s'executer
et permettre au reste de la guilde de continuer a progresser.

Le chemin actif est implemente dans `main.gd` via l'overlay de repos et la vitesse
`REST_ACCELERATION_SPEED`. `FastForwardManager` et `FastForwardDialog` existent encore dans le repo
comme code historique/non branche ; ne pas les reutiliser sans verifier explicitement leur
integration.

### Guilde et roster

`GuildManager` est la source de verite du roster joueur. Toute entree/sortie de membre doit passer
par ses APIs pour garder signaux, UI, save et systemes sociaux synchronises.

Il gere :

- membres et online/offline ;
- salaires et tresorerie ;
- banque et equipement ;
- historique de loot ;
- activites par defaut ;
- integration avec `ActivityManager`, `RecruitmentPool`, `GuildRanking`, `SaveManager`.

### Recrutement

`RecruitmentPool` simule un marche vivant :

- pool dynamique de candidats ;
- candidats qui levelent/s'equipent pendant leur disponibilite ;
- disparition possible vers d'autres guildes ;
- refus grise/cooldown avant nouvelle proposition ;
- difficulte dependante du niveau, skill, traits, equipement, motivation, reputation, salaire,
  phase et concurrence ;
- competition avec guildes IA et mecanismes de poaching/transfert en phases avancees.

Quand un candidat accepte, l'ajout doit etre atomique via `GuildManager` pour eviter les bugs de
candidat accepte mais absent de la guilde.

### Activites et progression PvE

`ActivityManager` et `Activity` gerent les activites :

- leveling ;
- farming ;
- fun/social ;
- donjon ;
- raid ;
- offline/repos.

`DungeonData`, `DungeonInstance`, `PveRunReport`, `LootTables`, `Item` et `Equipment` gerent le
contenu PvE :

- donjons/raids Vanilla-like ;
- compositions requises ;
- boss et wipes ;
- calculs de probabilite selon niveau, skill, equipement, role, synergie ;
- loot, distribution, conflits, envoi banque/equipement ;
- rapports de run et historique ;
- clears utilises par `PhaseManager` et `GuildRanking`.

`DungeonInstance` est le moteur PvE vivant. Les anciennes mentions de `DungeonRun` dans certains
docs historiques ne doivent pas etre traitees comme source de verite sans verification du code.

### Phases campagne

`PhaseManager` est la source de verite des phases et requirements. Ne pas dupliquer ses conditions
dans un autre systeme.

Phases connues :

- `LEVELING` : onboarding, leveling, premier roster, premiers donjons.
- `SERVEUR` : domination serveur, classement, contenu PvE, roster stable.
- `NATIONAL` : reputation publique, medias, sponsors, recrutement plus competitif.
- `ESPORT` : staff, tournois, bootcamps, transferts, pression, legacy.

Tout systeme de quetes/objectifs doit lire `PhaseManager` et orienter le joueur, pas redefinir la
progression canonique.

### Classements et guildes IA

`GuildRanking` et `AIGuildManager` simulent la concurrence :

- rankings serveur/national/mondial ;
- progression PvE des guildes IA ;
- server first/world first ;
- guildes avec strategies differentes ;
- recrutement et poaching.

### National et esport

Les phases avancees combinent plusieurs managers :

- `MediaManager` : audience, couverture, reputation publique.
- `SponsorshipManager` : sponsors, revenus, exigences.
- `DramaManager` : crises publiques/internes, resolution, impact reputation/moral/sponsors.
- `StaffManager` : staff pro et bonus.
- `TournamentManager` : bootcamps, tournois, reputation internationale.
- `TransferManager` : marche international, offres, counter-offers, adaptation.
- `LegacyManager` : accomplissements long terme.

### Conseils et guidage

`AdvisorManager` analyse l'etat actuel et genere des conseils hebdomadaires. Il est tactique et
contextuel.

Le systeme d'objectifs/quetes prevu doit etre une surcouche d'orientation :

- tracker compact ;
- fenetre `Objectifs` eventuelle ;
- bouton "Aller" via `WindowManager` ;
- auto-completion retroactive ;
- densite forte au debut, puis de plus en plus espacee ;
- aucune duplication de `PhaseManager`.

### Chat de guilde vivant

`ChatDirector` orchestre le chat via :

- corpus JSON dans `data/chat/` ;
- `ChatBackend` ;
- `ChatScoring` ;
- `SceneRunner` ;
- signaux reactifs aux events de simulation.

Le chat est data-driven et ne depend pas d'un LLM runtime. Quand on ajoute du contenu, privilegier
les donnees JSON et les triggers propres plutot que des lignes codees en dur partout.

### Save, data et balance

`SaveManager` gere une sauvegarde versionnee avec migrations et tolerance des saves anciennes ou
plus recentes. Toute nouvelle feature persistante doit ajouter :

- bloc de save ;
- load avec valeurs par defaut ;
- migration si necessaire ;
- test round-trip ou smoke.

`BalanceManager` centralise les tunables de difficulte/equilibrage. Eviter les valeurs magiques dans
les fenetres UI.

## UI / UX Conventions

- L'UI doit etre propre, reactive, lisible et fonctionnelle avant d'etre decorative.
- Respecter le style des fenetres existantes : fenetres compactes, onglets, listes scannables,
  boutons clairs, feedback immediat.
- Ne pas imbriquer inutilement des cards dans des cards.
- Eviter les textes explicatifs longs dans l'UI. L'interface doit montrer les actions et l'etat.
- Les boutons d'action doivent appeler des APIs systemes, pas modifier directement des donnees
  profondes.
- Pour les interactions drag/drop, utiliser les composants existants (`DraggableItem`, `DropZone`,
  `EquipDragCell`) et verifier les signaux.
- Les fenetres doivent exposer des methodes semantiques si elles doivent etre pilotees par un futur
  systeme d'objectifs (`highlight_guidance_target(target_id)` par exemple).
- Si une fenetre a besoin d'etre rafraichie apres un changement global, brancher les signaux du
  manager source et/ou passer par `WindowManager.refresh_window`.

## Testing Map

Le projet dispose d'un harnais de tests interne sans dependance externe :

- `tests/CheckScripts.tscn` : charge les scripts via `load()` et valide la compilation.
- `tests/TestRunner.tscn` / `tests/run_tests.gd` : suites d'assertions automatises.
- `tests/test_framework.gd` : mini-framework (`ok`, `eq`, `approx`, `between`).
- `tests/e2e_*.gd` : scenarios E2E/smoke specialises.
- `tests/ChatSoak.tscn` : soak du chat.
- `tests/run_tests.ps1` : wrapper PowerShell.

Couverture actuelle notable :

- GameTime/calendrier ;
- Item/Equipment ;
- SimulatedPlayer stress/burnout/esport ;
- BalanceManager ;
- AdvisorManager ;
- SaveManager et migrations ;
- AIGuild ;
- PvE progression/loop ;
- ActivityManager ;
- PhaseManager ;
- recrutement economie ;
- calendrier/salaires ;
- UI smoke `Fenetre_Conseils`.

Quand ajouter des tests :

- changement de calcul gameplay ;
- changement de save/migration ;
- ajout ou modification d'un manager ;
- bug aleatoire corrige ;
- interaction UI critique comme recrutement, auto-assign, loot, equipement, repos accelere.

## Documentation Map

Docs utiles :

- `docs/GameIdea.md` : intention globale.
- `docs/GameLoop.md` : boucle de jeu.
- `docs/Implementation.md` : notes d'implementation.
- `docs/DungeonSystem.md` : systeme donjon/PvE.
- `docs/audit/*.md` : audits UI/gameplay/architecture/code/tests.
- `docs/design/2026-06-02-chat-guilde-vivant.md` : spec chat.
- `docs/design/2026-06-03-systeme-quetes-guidage.md` : spec objectifs/quetes.
- `docs/design/2026-06-03-ui-architecture-gameplay.md` : spec architecture UI/gameplay.
- `docs/design/2026-06-03-ui-refonte-visuelle-mmo.md` : spec refonte visuelle.
- `RoadmapComplet.md` : roadmap et historique de features. A mettre a jour apres implementation.

## Asset Generation via ComfyUI

Le projet peut utiliser ComfyUI local pour generer des assets pixel art/UI.

Stack :

- ComfyUI : `~/tools/ComfyUI/`.
- Modele : Flux.1-dev FP8.
- LoRA : UmeAiRT Modern Pixel Art.
- Trigger prompt obligatoire : `umempart`.
- Destination : `res://assets/generated/`.
- Resolutions standard : 32 icones, 64 petits sprites, 128 personnages, 256 portraits/boss.
- Generation en 1024x1024 puis downscale via PixelArtDetectorConverter.
- Import Godot : `texture_filter = NEAREST`, `texture_repeat = DISABLED`.

Demarrage :

```bash
~/tools/start-comfyui.sh
tmux new-session -d -s comfyui '~/tools/start-comfyui.sh'
```

## Known Issues / Watchpoints

- `--check-only` peut rester suspendu sous Windows. Utiliser `tests/CheckScripts.tscn`.
- PowerShell peut afficher certains anciens docs avec du mojibake selon la codepage. Preferer UTF-8
  et eviter de reecrire inutilement de gros fichiers historiques.
- Les `class_name` et autoload wrappers peuvent produire des diagnostics de type "hides global
  script class" selon l'outil. Verifier le contexte avant de renommer.
- Les sidecars `.uid` et fichiers d'import Godot peuvent apparaitre ou changer. Ne garder que les
  changements intentionnels.
- Le MCP peut etre indisponible localement. Dans ce cas, utiliser Godot en ligne de commande.
- Les changements UI doivent etre valides visuellement : une compilation seule ne suffit pas.
- Les bugs aleatoires de simulation doivent etre couverts par un test deterministe avec seed ou etat
  controle quand c'est possible.

## Standard Workflows

### Ajouter une feature gameplay

1. Identifier la source de verite existante.
2. Ajouter/adapter les donnees ou le manager.
3. Garder le code type et localise.
4. Brancher UI via signaux/APIs, pas chemins profonds.
5. Ajouter save/migration si l'etat doit persister.
6. Ajouter tests.
7. Lancer `CheckScripts.tscn` puis `TestRunner.tscn`.
8. Mettre a jour `RoadmapComplet.md`.

### Modifier une fenetre

1. Lire la scene `.tscn` et son script `scripts/ui/windows/*.gd`.
2. Verifier les composants UI reutilisables existants.
3. Modifier via API/scene de facon compatible avec `WindowManager`.
4. Tester l'instanciation et les callbacks critiques.
5. Verifier visuellement si le changement est notable.

### Ajouter un systeme d'objectifs/quetes

Suivre la spec `docs/design/2026-06-03-systeme-quetes-guidage.md` :

- `QuestManager` comme autoload ;
- donnees de quetes testables ;
- objectifs retroactifs ;
- bouton "Aller" via `WindowManager` ;
- highlight par cible semantique ;
- save versionnee ;
- aucune duplication de `PhaseManager`.
