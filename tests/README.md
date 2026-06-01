# Tests automatisés — RaidLead

Harnais de tests léger (Milestone 6, US 6.5), sans dépendance externe.

## Lancer les tests

**Wrapper PowerShell (recommandé)** — détecte Godot automatiquement :

```powershell
powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1
```

**Commande directe** (headless, scène principale = autoloads disponibles) :

```powershell
& "C:\chemin\vers\Godot_v4.6.2-stable_win64_console.exe" --rendering-driver opengl3 --headless --path . res://tests/TestRunner.tscn
```

Le code de sortie vaut `0` si tous les tests passent, `1` sinon — pratique pour un pipeline CI.

> Important : on lance **la scène `TestRunner.tscn`**, pas le script via `-s`. Un script
> `-s` (SceneTree) est compilé avant l'enregistrement des autoloads, qui deviennent alors
> introuvables. En passant par une scène normale, les singletons globaux sont disponibles.

**Validation de syntaxe (alternative à `--check-only`)** — `--check-only` peut rester suspendu
sous Windows. `CheckScripts.tscn` charge tous les scripts `.gd` via `load()` (autoloads
disponibles car c'est une scène) et sort `0` si tout compile, `1` sinon :

```powershell
& "C:\chemin\vers\Godot_v4.6.2-stable_win64_console.exe" --rendering-driver opengl3 --headless --path . res://tests/CheckScripts.tscn
```

**Vérification courte de la scène principale sans charger la save locale** :

```powershell
& "C:\chemin\vers\Godot_v4.6.2-stable_win64_console.exe" --rendering-driver opengl3 --headless --path . --scene res://scenes/Main.tscn --quit-after 2 -- --no-save-autoload
```

## Structure

- `test_framework.gd` — mini-framework d'assertions (`eq`, `approx`, `between`, `ok`) + rapport.
- `run_tests.gd` — exécute toutes les suites au `_ready`, imprime le rapport, quitte avec le bon code.
- `TestRunner.tscn` — scène hôte (un simple Node).

## Couverture

| Suite | Vérifie |
|-------|---------|
| GameTime | compteur de jours absolus, passage de semaine/année |
| Item/Equipment | construction d'objets, iLvl total, cumul des stats |
| SimulatedPlayer | stress (bornes/paliers), risque de burnout, facteur de performance esport |
| BalanceManager | presets de difficulté, multiplicateurs bornés, catch-up, rubber-band, save round-trip |
| AdvisorManager | tri par priorité, libellés de sévérité, alerte trésorerie |
| SaveManager | sérialisation/désérialisation d'un membre (round-trip) |
| AIGuild | construction de restauration sans génération de membres temporaires |
| PvE Progression | clears joueur, historique de run, meilleur clear, pourcentage de contenu clear, lecture par PhaseManager, score groupe vide, rankings national/mondial, score d'activité guilde vide, score de rapport PvE partagé |
| ActivityManager | activité Donjon automatique sans fallback farming |
| PhaseManager | valeurs d'enum, objectifs de phase, sémantique du rang (plus petit = meilleur) |
| SaveManager Migration | migration v1→v2 (blocs systèmes normalisés), tolérance d'une save plus récente |
| PvE Loop | composition valide/invalide, run reproductible (graine fixe), loot, phase 0→1 après héroïque |
| GameRandom | déterminisme `seed_rng` (même graine = même séquence), `randomize_rng` |
| Recrutement (économie) | commission d'agent prélevée sur tous les chemins, contrôle de solvabilité |
| Calendrier | salaires hebdomadaires (payés / impayés → moral & réputation), refresh sur jour absolu |
| UI Smoke | instanciation de `Fenetre_Conseils` + onglet « Cette semaine » au runtime |

## Ajouter un test

Ajoutez une assertion dans la suite concernée de `run_tests.gd`, ou créez une nouvelle
fonction `_suite_xxx(tf)` et appelez-la depuis `_run_all()`.
