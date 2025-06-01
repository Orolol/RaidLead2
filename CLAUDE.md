# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RaidLead is a guild management simulation game built with Godot Engine. Players manage a high-level guild in a fictional MMORPG world, inspired by sports management games like Football Manager.

**Key Technologies:**
- Engine: Godot Engine (4.x expected)
- Primary Language: GDScript
- Platform: PC (Steam distribution planned)
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
# In Godot Editor:
# F5 - Run project
# F6 - Run current scene
# Ctrl+S - Save scenes/scripts

# Command line (if Godot is in PATH):
godot                    # Open editor
godot --headless         # Run without window
```

### Building/Exporting
```bash
# Through Godot Editor: Project → Export
# Command line:
godot --export "Windows Desktop" build/game.exe
godot --export "Linux/X11" build/game.x86_64
```

### Testing
No test framework is currently set up. When implementing tests, consider using GUT (Godot Unit Test) framework.

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
3. Godot 4.4 is being used with GDScript
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