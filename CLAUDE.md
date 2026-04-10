# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RaidLead is a guild management simulation game built with Godot Engine. Players manage a high-level guild in a fictional MMORPG world, inspired by sports management games like Football Manager.

**Key Technologies:**
- Engine: Godot Engine 4.5 (stable)
- Primary Language: GDScript (static typing systématique)
- Renderer: Compatibility / OpenGL3 (obligatoire en WSL2)
- Platform: PC (Steam distribution planned)
- Dev Environment: WSL2 / Ubuntu
- Documentation Language: French (GameIdea.md, Implementation.md)

## Project Structure

```
/assets/      # Game assets (sprites, sounds, fonts)
/resources/   # Godot resource files (.tres, .res)
/scenes/      # Godot scene files (.tscn)
/scripts/     # GDScript files (.gd)
```

## Development Commands

### Running the Game
```bash
# IMPORTANT: Toujours utiliser --rendering-driver opengl3 en WSL2
# Lancer l'éditeur
godot --rendering-driver opengl3 --path . -e

# Lancer le jeu
godot --rendering-driver opengl3 --path .

# Lancer une scène spécifique
godot --rendering-driver opengl3 --path . --scene res://scenes/Main.tscn

# Valider la syntaxe sans lancer
godot --rendering-driver opengl3 --path . --check-only --headless

# E2E silencieux (pas de fenêtre visible)
xvfb-run --auto-servernum godot --rendering-driver opengl3 --path . -s res://tests/e2e_main.gd
```

### Building/Exporting
```bash
# Through Godot Editor: Project → Export
# Command line:
godot --rendering-driver opengl3 --export "Windows Desktop" build/game.exe
godot --rendering-driver opengl3 --export "Linux/X11" build/game.x86_64
```

### Testing
No test framework is currently set up. When implementing tests, consider using GUT (Godot Unit Test) framework.

## MCP Servers & Tooling

Ce projet utilise plusieurs MCP servers pour le workflow agentique :

- **godot-mcp-pro** : Contrôle de l'éditeur Godot (167 outils) — manipulation de scènes/nodes/scripts, exécution du jeu, screenshots, input simulation, runtime inspection. **À privilégier pour toute action sur le projet Godot.**
- **godot-docs** : Documentation API Godot à jour. **À utiliser systématiquement avant d'écrire du code utilisant une classe ou méthode Godot inconnue, pour éviter les hallucinations.**
- **LSP GDScript** : Plugin `claude-code-gdscript` pour diagnostics temps réel, go-to-definition, completions, hover sur fichiers `.gd`.

### Workflow recommandé pour toute tâche de code
1. Lire ce CLAUDE.md pour le contexte.
2. Si tâche sur une classe Godot non familière : interroger `godot-docs` d'abord.
3. Lire les fichiers concernés du projet.
4. Écrire le code en respectant les conventions.
5. Valider via LSP (diagnostics) et `--check-only`.
6. Si changement visuel : lancer le jeu via le MCP, prendre un screenshot, vérifier.

## Rendu WSL2 — piège critique

Ce projet tourne en WSL2. Le driver Vulkan `dzn` de Mesa n'est PAS conforme et provoque des crashes.
- **Toujours** lancer Godot avec `--rendering-driver opengl3`.
- **Jamais** utiliser `--headless` si tu veux des screenshots — utiliser `xvfb-run` à la place.
- Variable d'environnement requise : `GALLIUM_DRIVER=d3d12`.

## Interdictions strictes

1. **Ne jamais lancer Godot sans `--rendering-driver opengl3`** dans ce projet (WSL2).
2. **Ne jamais utiliser de variables non typées.** GDScript 4 est typé, utilise-le.
3. **Ne jamais utiliser de pattern Godot 3.x.** (`yield`, `tool`, connexions par string, etc.)
4. **Ne jamais utiliser `get_node("../../../Other")`.** Utiliser des signaux ou un autoload.
5. **`_ready()` n'est pas rappelé lors d'un hot reload** — le code change, l'état persiste.

## Architecture Overview

The game uses a window-based UI system with a fixed bottom menu bar for navigation. Main windows include:

1. **Main.tscn** - Root scene with background and window management
2. **Fenetre_Personnage.tscn** - Player character information
3. **Fenetre_Guilde.tscn** - Guild member management with tag system
4. **Fenetre_Monde.tscn** - World view with guild rankings and recruitment pool
5. **Fenetre_OrganisationGroupe.tscn** - Group composition for raids/dungeons

### Autoloads
- **GameTime** - Global time system with calendar and clock
- **GuildManager** - Central guild member management
- **RecruitmentPool** - Dynamic player recruitment system

## Core Game Systems

### NPC System (SimulatedPlayer)
Simulated players have:
- Behavioral tags with progressive revelation
- Hidden tags revealed through time and events
- Energy and mood states affecting availability
- Skill levels and specialization preferences
- Integration mechanics tracking guild membership
- Weekly planning for availability

### Guild Management (GuildManager)
- Central management of all guild members
- Automatic connection/disconnection based on schedules
- Default activity assignment
- Integration with ActivityManager for member activities

### Tag System (PlayerTags)
- Comprehensive behavioral tag database
- 6 categories: Personality, Social, Gameplay, Progression, Reliability, Special
- Progressive revelation based on multiple conditions
- Hidden special tags (ninja_looter, drama_queen)
- Tag visibility based on integration, time, events

### Activity System (Activity & ActivityManager)
- 6 activity types: Leveling, Farming, Fun, Dungeon, Raid, Offline
- Automatic activity selection based on player state
- Effects on energy, mood, and integration
- Authentic WoW leveling zones
- XP progression calculation

### Content System (DungeonData & DungeonRun)
- Complete database of WoW Vanilla dungeons and raids
- Boss fight simulation with success probabilities
- Calculations based on level, equipment, skill, composition
- Loot distribution system
- Wipe management and consequences
- Required group compositions (tanks, healers, DPS)

### Recruitment System (RecruitmentPool)
- Dynamic pool of 15-30 available players
- Daily updates with new players
- Complete refresh every 3 days
- Competition with 9 AI guilds
- Recruitment difficulty based on player quality
- Player motivations and expectations
- Filtering by class, level, role

## Important Notes

1. The project has core systems implemented - UI, time, NPCs, activities, dungeons, recruitment
2. Documentation (GameIdea.md, Implementation.md) is in French
3. Godot 4.5 is being used with GDScript (static typing)
4. Follow Godot's scene-based architecture patterns
5. Use GDScript naming conventions (snake_case for variables/functions, PascalCase for classes)

## Current File Organization (to be improved)

All scripts are currently in `/scripts/`. Proposed reorganization:
```
/scripts/
  /autoloads/       # GameTime, GuildManager, RecruitmentPool
  /resources/       # SimulatedPlayer, Activity
  /data/           # PlayerTags, DungeonData
  /systems/        # ActivityManager, DungeonRun
  /ui/             # Windows and UI components
    /windows/      # fenetre_*.gd
    /components/   # menu_bar.gd, time_display.gd
  /managers/       # window_manager.gd
  main.gd
```

## Known Issues

1. Some class_name declarations conflict with autoloads
2. Variable naming consistency (character_* vs personnage_*)
3. All scripts in one folder - needs organization
4. Some unused signals declared
- N'oublie pas de mettre a jour @RoadmapComplet.md après chaque avoir implémenter une feature.