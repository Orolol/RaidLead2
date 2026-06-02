## 6. Code — Tests, Tooling & Performance

> Audit statique (Read/Grep/Glob, **sans lancer le jeu**) du harnais de tests, du tooling
> de validation et des coûts de simulation en sessions longues / haute vitesse.
> Sévérités : 🔴 Critique (gel/perf inacceptable, ou système critique non testé) · 🟠 Majeur · 🟡 Mineur.

### 6.0 Synthèse du diagnostic

Le harnais de tests maison (`tests/test_framework.gd` + `run_tests.gd`, **~98 assertions / 21 suites**) est **honnête et utile** : il couvre bien les fondations déterministes (GameTime, équipement, save round-trip + migration, RNG seedé, économie de recrutement, PvE, balance). Mais il souffre de deux faiblesses structurelles : (1) **les tests partagent l'état global des 26 autoloads** — ils sauvegardent/restaurent manuellement chaque variable touchée, ce qui est fragile et déjà incomplet ; (2) **des pans entiers du jeu (≈40 % des managers) ne sont pas testés** : Media, Sponsorship, Staff, Tournament, Transfer, Legacy, le système social/contagion, l'IA de débauchage, et toute l'UI au-delà d'un smoke test.

Côté **performance**, l'architecture « tout sur signal `GameTime` » est globalement saine (la simulation suit la vitesse de jeu au lieu de timers temps-réel), mais trois points sont des bombes à retardement à 2400x avec 30 membres + 99 guildes IA : le **fan-out non borné des minutes par frame**, le **système social en O(membres × relations × membres)** appelé dans la boucle des 5 minutes, et le **recalcul du classement de 100 guildes déclenché par des `create_timer` qui s'empilent** à chaque fin de donjon. Aucune limite de budget par frame n'existe.

---

### 6.1 Couverture de tests — les trous

**Ce qui EST testé (21 suites, ~98 assertions)** : GameTime, Item/Equipment, SimulatedPlayer (stress/burnout), PlayerCharacter (flow d'oisiveté), simulation depth (connexion dynamique + PersonalEvents), banque & équipement, BalanceManager, AdvisorManager, SaveManager (round-trip + migration v1→v2→v3), AIGuild (construction/dédup/progression XP), PvE Progression, PvE Loop (compo/loot/phase 0→1), ActivityManager, PhaseManager, GameRandom (déterminisme), recrutement national (économie d'agent), calendrier (salaires), économie (cap d'or), façades (gating de phase média/drama/tournoi/sponsor), UI Smoke (1 fenêtre).

**🔴 Systèmes critiques NON testés (back-ends Milestones 3-4 « 100 % »)** :
- **MediaManager** — croissance célébrité, revenus streaming (30 % reversés à l'or). Aucune assertion sur le calcul de revenu hebdo ni la croissance. `media_manager.gd`.
- **SponsorshipManager** — un seul test indirect (`sponsor.gd.tick_week` satisfaction ±). Pas de test du `SponsorshipManager` lui-même (signature de contrats, revenus versés, conflits de sponsors concurrents).
- **StaffManager** — **zéro test**. Embauche, masse salariale hebdo, synergies (+5 %/rôle), bien-être (`_process_wellbeing`) : tout est non couvert alors que c'est une mécanique économique avec prélèvement d'or.
- **TournamentManager** — uniquement le gating de phase + sérialisation des offres. La **simulation de bracket** (force roster + staff − stress), les récompenses or/prestige, le bootcamp : non testés.
- **TransferManager** — **zéro test**. Fenêtres de transfert (semaines 1-4/26-29), prime de transfert (4× salaire + commission), adaptation culturelle. C'est pourtant un sink d'or majeur, donc à fort risque de régression économique.
- **LegacyManager** — **zéro test**. Hall of Fame, paliers de points, titres permanents.
- **Système social** (`SocialDynamics` + `GuildCultureManager`) — seul un round-trip d'amitié est testé (`_suite_save`). La **formation de relations**, la **contagion d'humeur**, le **moral collectif**, les **cliques**, la **médiation de conflits** ne sont jamais exercés. Vu que c'est aussi le code le plus coûteux (cf. 6.4), c'est le trou le plus grave.
- **IA de débauchage** (`ai_guild_manager.gd`) — `_calculate_member_leave_probability`, `_attempt_poaching_by_guild`, `simulate_counter_offer_response` : non testés. **Bug latent repéré** (cf. 6.9) dans une branche non couverte.
- **EventManager** — uniquement la sérialisation. La sélection pondérée MTTH, le gating `events_today`, l'éligibilité : non testés (or c'est la source de l'auto-pause à haute vitesse).
- **NotificationManager, WindowManager, ReportPvE end-to-end** : non couverts (au-delà du smoke).

**🟠 UI quasi non testée** : 1 seule fenêtre instanciée en smoke (`Fenetre_Conseils`). Les fenêtres Esport/National/Social (6 onglets chacune, code de rebuild lourd) ne sont jamais instanciées en test → régressions visuelles/runtime invisibles au CI.

---

### 6.2 Qualité du harnais — couplage à l'état global

**🟠 Isolation par save/restore manuel, fragile et incomplète.**
- Le framework (`test_framework.gd`) est un simple compteur d'assertions sur `RefCounted` — **aucune notion de setup/teardown ni d'isolation**. Chaque suite manipule directement les autoloads vivants (`GuildManager.guild`, `GuildRanking.player_cleared_content`, `BalanceManager`, `PhaseManager.current_phase`…) et doit **sauvegarder puis restaurer à la main** chaque champ touché.
- Exemples de cette gymnastique : `_suite_pve_progression` sauvegarde/restaure **8 variables** de `GuildRanking` (`run_tests.gd:388-437`) ; `_suite_pve_loop` en sauvegarde 6 de plus (`:524-538`) ; `_suite_economy` duplique encore les mêmes (`:698-710`). C'est du copier-coller à haut risque : **un `return` anticipé ou une assertion qui throw laisse l'état global pollué** pour toutes les suites suivantes.
- **Ordre-dépendance réelle** : `_suite_bank` modifie `GuildManager.guild.bank_items` et le `equipment` de membres réels du roster ; `_suite_calendar` modifie `member.set_meta("salary")` et `guild.gold`. Si une restauration est oubliée (ex. `connection_probability_cache` du behavior system n'est jamais nettoyé après les `SimulatedPlayer.new()` créés à la volée), les suites suivantes héritent d'un état faussé. Les tests **passent aujourd'hui par chance d'ordonnancement**, pas par construction.
- **Déterminisme partiel** : `GameRandom.seed_rng` existe et est testé, **mais `run_tests.gd` ne fixe jamais la graine en début de suite**. Les suites qui font `randf()`/`SimulatedPlayer.new()` (génération procédurale) sont donc **non reproductibles** entre exécutions — un test flaky passera/échouera selon le tirage. Le déterminisme est *disponible* mais *pas appliqué au harnais*.

**Recommandation** : introduire un vrai `before_each`/`after_each` (ou au minimum un `GameRandom.seed_rng(N)` en tête de `_run_all` + un snapshot/restore global unique), et faire travailler les suites sur des **instances isolées** (`SimulatedPlayer.new()`, `Guild.new()`, `DungeonInstance.new()`) plutôt que sur les autoloads vivants dès que possible — ce qui est déjà le cas pour `_suite_item_equipment`, à généraliser.

---

### 6.3 E2E — robustesse

**🟡 E2E utiles mais fragiles (timing par compteur de frames).**
- 5 E2E `SceneTree` : `e2e_player_flow` (pause→choix→drain), `e2e_player_organize` (Donjon/Raid→fenêtre), `e2e_equipment` (drag&drop banque↔slot), `e2e_national_recruit`, `e2e_progression`. Plus `e2e_screenshot`.
- **Bonne pratique** : ils chargent `Main.tscn` (autoloads réels) et appellent les vrais callbacks (`_on_prompt_organize_chosen`, `_on_equip_dropped`) au lieu de simuler des clics pixel → résistant au layout.
- **Fragilité** : la synchronisation repose sur des **seuils de frames magiques** (`if _frames >= 120`) pour « laisser les `call_deferred` s'exécuter » (`e2e_player_flow.gd:33`, `e2e_player_organize.gd:38`). Sur une machine CI lente ou un build chargé, 120 frames peuvent ne pas suffire → faux négatifs. Préférer une **attente sur condition** (`await` d'un signal, ou polling d'un prédicat avec timeout) plutôt qu'un compteur fixe.
- **Couverture E2E manquante** : aucun E2E ne valide une **transition de phase complète** (1→2→3) ni une **boucle de simulation longue à haute vitesse** (justement le scénario perf à risque). Le drag&drop d'équipement contourne le vrai drag Godot en appelant `_on_equip_dropped` directement → le `_can_drop_data`/`_get_drag_data` natif n'est pas exercé.

---

### 6.4 Perf simulation — fan-out par tick & complexité

**Combien de ticks/seconde à 2400x ?** `GameTime._process` (`game_time.gd:34-44`) accumule `delta * time_speed` puis `while accumulated_time >= 60: advance_minute()`. À 60 fps et 2400x : `2400/60 = 40` minutes de jeu accumulées **par frame** → **40 `advance_minute()` par frame, soit ~2400 minutes/s**. Chaque `advance_minute` émet `minute_changed`, qui réveille **3 abonnés** (`GuildManager`, `ActivityManager`, `BehaviorSystem`). Le `% 5` interne ne filtre que partiellement.

**🟠 Fan-out temps non borné par frame.** `game_time.gd:42` — `while accumulated_time >= 60` n'a **aucun plafond**. Si une frame tombe à 5 fps (pic GC ou rebuild UI), `accumulated_time` peut représenter des centaines de minutes traitées **synchronement dans la même frame**, qui rallonge encore la frame → spirale. `fast_forward_hours` (`:100-103`) enchaîne `60 × heures` `advance_minute` synchrones (8h de repos = 480 émissions × 3 abonnés en un appel). **Fix** : plafonner les minutes traitées par frame (budget, ex. ≤ 30) et reporter le reste ; pour le repos, sauter directement l'état au lieu d'émettre minute par minute.

**🔴 Système social en O(membres × relations × membres), dans la boucle des 5 minutes.**
- `social_dynamics.get_social_circle(player)` et `get_friends(player)` (via `_get_relations_of_type`) **itèrent tout le dictionnaire `relationships`** (jusqu'à O(M²) paires), et pour chaque correspondance appellent `_get_player_by_id` qui fait une **recherche linéaire sur tous les membres** (`social_dynamics.gd:160-168, 360-385`). Coût par appel : **O(R × M)**.
- `get_online_friends(player)` (`:145`) est appelé **par membre, toutes les 5 minutes** depuis `behavior_system._connection_state_modifier` (`behavior_system.gd:567`) et dans `should_connect/disconnect_dynamic`. À haute vitesse, c'est O(R × M) × M × (fréquence des ticks) → en pratique **O(M² × R)** récurrent, avec R pouvant atteindre O(M²) ⇒ **jusqu'à O(M⁴)** dans le pire cas.
- `guild_culture_manager._apply_contagion` (`guild_culture_manager.gd:106-128`, hebdo) appelle `get_social_circle` par membre → O(M² × R) chaque semaine.
- **Fix** : maintenir un **index d'adjacence** `player_id -> Array[relations]` mis à jour à `form/break_relationship`, et un `id -> member` en Dictionary (au lieu du scan linéaire `_get_player_by_id`). Cela ramène `get_social_circle`/`get_online_friends` à O(degré) au lieu de O(R × M).

**🟠 Recalcul du classement de 100 guildes déclenché par des timers qui s'empilent.**
- `GuildRanking.update_rankings` reconstruit les données de **toutes** les guildes (joueur + 9/49/99 IA), chaque `get_guild_data_for_ranking` itérant membres + `recent_achievements` (`ai_guild.gd:530`), puis trie O(N log N), calcule `_calculate_rank_change` et met à jour l'historique (`guild_ranking.gd:191-234, 248-261, 367-384`). Coût hebdomadaire : acceptable.
- **Problème** : `_on_activity_completed` (`guild_ranking.gd:580-584`) crée un **`get_tree().create_timer(2.0)` à chaque donjon/raid terminé**, et `_on_member_recruited` un `create_timer(1.0)`. À 2400x, de nombreuses activités se terminent par seconde réelle → **dizaines de timers en vol, chacun rappelant `update_rankings()`** sur 100 guildes. C'est un recalcul O(N log N) potentiellement déclenché plusieurs fois par frame. **Fix** : debounce (un seul recalcul « sale » par tick de jour/semaine) au lieu d'un timer par événement.

**🟡 `_check_personal_events` + `_update_fatigue_levels` parcourent tous les membres chaque heure** (`behavior_system.gd:450-501`) et `_check_scheduled_connections` toutes les 5 min (`:597-650`). C'est O(M) borné et correct en soi, mais s'additionne au fan-out non plafonné ci-dessus.

---

### 6.4b Auto-pause sur événements à haute vitesse

**🟠 Pause modale en rafale à haute vitesse.** `EventManager._on_hour_changed → _check_for_events` (`event_manager.gd:54-81`) tire un événement potentiel **chaque heure de jeu**. À 2400x, ~40 heures de jeu passent par seconde réelle → jusqu'à 40 tirages/s. Le quota `events_today >= daily_event_target` (= 1/jour, `:87`) limite à **1 événement/jour**, mais la popup déclenchée passe `GameTime.pause()` (`event_popup.gd:44`) et `process_mode = PAUSABLE` gèle l'EventManager. Concrètement : le jeu **se met en pause sans cesse** dès qu'un jour de jeu s'écoule (constaté dans le playtest du RoadmapComplet). Le throttle existe (1/jour) mais **rien ne lisse l'irruption** : à 2400x, l'utilisateur subit une pause modale par « jour », soit toutes les ~0,6 s réelle.
- **Throttle proposé** : (a) **désactiver les tirages d'événements au-dessus d'un seuil de vitesse** (ex. `time_speed > 300` → file d'attente, pas de popup) et ne présenter l'événement qu'au retour à vitesse normale ; (b) ou **auto-résoudre** les événements à faible enjeu en mode accéléré (choix par défaut) avec une notification toast au lieu d'une modale ; (c) **gater les médias/dramas/sponsors par phase** (déjà partiellement fait via `_suite_facades`, à généraliser) pour ne pas spammer en Phase 0.

---

### 6.5 Allocations par frame

**🟡 Allocations dans les callbacks fréquents (pas dans `_process` direct, mais dans les ticks signal).**
- `activity_manager._update_all_activities` (`activity_manager.gd:104-112`) alloue `active_activities.keys()` (nouvel Array) **à chaque tick 5 min**, plus le découpage en « batches » de 10 qui est un **faux gain** : la boucle reste synchrone dans la même frame, donc le `batch_size` n'étale rien (pure illusion d'optimisation, à supprimer ou à transformer en vrai étalement sur plusieurs frames).
- `GuildRanking._update_*` duplique des Arrays (`old_rankings = ...duplicate()`) et reconstruit un Array de Dictionaries de 100 entrées à chaque mise à jour (`guild_ranking.gd:224, 238, 244`).
- `social_dynamics._get_relationship_key` fait un `"%d:%d" % [...]` (allocation de String) **à chaque lookup de relation** (`:349-358`) — multiplié par le fan-out social ci-dessus, c'est un volume de Strings temporaires notable. Envisager une clé entière encodée (`id1 * BIG + id2`) ou un Dictionary imbriqué.

**Strings UI formatées chaque tick** : cf. 6.6 (les rebuilds reconstruisent tous les labels).

---

### 6.6 Rafraîchissements UI redondants

**🟡 Fenêtres 6 onglets reconstruites intégralement à chaque `week_changed`.**
- `fenetre_esport.gd:120-130` — `_on_changed` (branché sur `week_changed` + ~10 signaux managers) appelle `_refresh_all()` qui `queue_free` **tous** les enfants de **tous** les onglets puis les recrée (`_clear` = boucle `queue_free`, `_build_*` × 6). Même schéma dans `fenetre_national.gd:105`, `fenetre_social.gd:100`, `fenetre_conseils.gd:91`.
- **Garde présente** : `if visible` (`fenetre_esport.gd:121`) évite le coût quand la fenêtre est fermée — bien. Mais quand elle est **ouverte** à haute vitesse, chaque semaine de jeu (≈ toutes les 0,2 s réelle à 2400x) détruit/recrée toute l'UI : churn d'allocations, **le SpinBox d'offre en cours est recréé sous les doigts**, scroll et onglet actif réinitialisés. C'est à la fois un coût et un bug d'ergonomie.
- **Fix** : rafraîchir **seulement l'onglet visible**, faire de la **mise à jour in-place** des labels (set `.text`) au lieu de `queue_free`+rebuild, et **suspendre le refresh pendant une interaction** (focus dans un SpinBox/offre).

---

### 6.7 Tooling CI

**🟠 Détection de Godot fonctionnelle mais fragile ; pas de pipeline CI.**
- `run_tests.ps1` cherche `Godot_v*_console.exe` par `Get-ChildItem -Recurse -Depth 3` dans Downloads/LocalAppData/Desktop (`run_tests.ps1:10-15`) et trie `Sort-Object Name -Descending` — un scan disque récursif à chaque run, et le tri par **nom** ne garantit pas la version la plus récente (ex. `4.6.2` vs `4.10.0` triés lexicographiquement). Code de sortie correct (`exit $LASTEXITCODE`, `2` si introuvable). Acceptable en local, **non hermétique pour un CI** (dépend de l'arborescence utilisateur).
- **`CheckScripts.tscn`** (`tests/check_scripts.gd`) est une bonne idée (validateur terminant, contournant le `--check-only` qui se suspend sous Windows) et sort 0/1 — c'est l'outil de lint syntaxique du projet.
- **Aucun `.github/workflows`** : pas de CI réelle. Les tests/E2E ne tournent qu'à la main. Un milestone affiché « validé » repose donc sur une exécution locale ponctuelle, pas sur une garantie continue.
- **🟠 Warnings non bloqués.** `project.godot` ne configure **aucun** `[debug] gdscript/warnings/*` (vérifié : aucune section warnings). Les ~273 warnings annoncés ne sont donc ni listés ni bloquants. Recommandation : activer un set minimal en `error` (au moins `unused_variable`, `unassigned_variable`, `incompatible_ternary`, `return_value_discarded` ciblé) et faire échouer `CheckScripts` ou un job CI dessus.
- **Recommandation CI** : un workflow GitHub Actions (ou script local versionné) qui (1) télécharge une version Godot épinglée, (2) lance `CheckScripts.tscn` (lint), (3) lance `TestRunner.tscn` (unit), (4) lance les `e2e_*.gd` en headless, et échoue sur tout code ≠ 0.

---

### 6.8 Scalabilité — ce qui explose à 30 membres + 99 guildes IA

| Système | Déclencheur | Coût | Échelle (30 membres / 99 IA) |
|---|---|---|---|
| Classement (`update_rankings`) | `create_timer` par fin de donjon/raid | O(N log N) + data de N guildes | **N=100** → recalculé potentiellement plusieurs fois/frame à 2400x ⇒ 🔴 |
| Social (`get_social_circle`/`get_online_friends`) | par membre, tous les 5 min | O(R × M), R≤O(M²) | **O(M³)→O(M⁴)** ⇒ 🔴 (30 membres = pire cas ~810k itérations/contagion) |
| Fan-out temps | `_process` à 2400x | 40 min/frame × 3 abonnés, non plafonné | spirale si frame longue ⇒ 🟠 |
| Simulation mensuelle IA | `week_changed % 4` | O(N) × (membres IA + achievements) + débauchage | N=100, hebdo ⇒ 🟡 (acceptable, ponctuel) |
| Rebuild UI 6 onglets | `week_changed` si visible | destruction/recréation totale | ≈ toutes les 0,2 s réelle à 2400x ⇒ 🟡 |
| EventManager auto-pause | `hour_changed` | 1 popup modale/jour | pause incessante à haute vitesse ⇒ 🟠 |

---

### 6.9 Zone à risque non couverte — l'IA de débauchage

**🟠 Tout le chemin de débauchage tourne sans filet.** `_calculate_member_leave_probability` (`ai_guild_manager.gd:207-234`), `_attempt_poaching_by_guild` (`:152-180`), `_process_successful_poaching_from_player` (`:182-205`) et `simulate_counter_offer_response` (`:317-342`) ne sont **jamais appelés par le harnais**. Or ce code **mute l'état global** (`GuildManager.remove_member`, `member.integration += 5`, ajout de membres aux guildes IA) et lit des méthodes optionnelles (`member.get_celebrity_poaching_risk()` via le garde `target_member_has_celebrity_risk`, `:231-237`). Une régression ici (signature de `remove_member`, méthode renommée sur `SimulatedPlayer`, branche de célébrité) ne se manifesterait qu'**en jeu**, lors d'une tentative de débauchage réelle — pas au CI. **Action** : couvrir `_calculate_member_leave_probability` (bornes [0.05, 0.85], membre célèbre vs anonyme) et un `_attempt_poaching_by_guild` sur un roster joueur factice, avec restauration d'état. C'est aussi le seul endroit où la mécanique de célébrité (Milestone 3) influence réellement le gameplay et n'est pas exercée.

---

### Top 5 quick wins tests/perf

1. **Debounce du classement** (🔴→🟠, ~1 h) : remplacer les `create_timer(1.0/2.0)` de `guild_ranking.gd:573,584` par un flag « ranking dirty » consommé une seule fois par `day_changed`/`week_changed`. Supprime les recalculs O(100 log 100) empilés à haute vitesse — le gain perf le plus rentable.
2. **Indexer le graphe social** (🔴, ~3 h) : ajouter `id -> member` (Dictionary) et `player_id -> Array[other]` mis à jour dans `form/break_relationship`, et réécrire `get_social_circle`/`get_online_friends`/`_get_player_by_id` dessus. Fait tomber le coût social de O(M⁴) à O(degré) — débloque les sessions longues.
3. **Plafonner le fan-out temps** (🟠, ~30 min) : borner le `while` de `game_time.gd:42` à N minutes/frame (reporter le reste) et faire de `fast_forward_hours` un saut d'état direct. Évite la spirale de frame.
4. **Seeder + isoler le harnais** (🟠, ~2 h) : `GameRandom.seed_rng(N)` en tête de `_run_all`, et un snapshot/restore global unique (au lieu du save/restore par-variable copié-collé). Rend les tests reproductibles et non ordre-dépendants, prérequis avant d'ajouter des suites.
5. **Tester les managers Esport/National + le débauchage** (🔴 couverture, ~1 jour) : suites unitaires Staff (masse salariale/synergies), Tournament (bracket/récompenses), Transfer (prime/fenêtre), Legacy (paliers), et l'IA de débauchage `_calculate_member_leave_probability`/`_attempt_poaching_by_guild` (cf. 6.9) — ces systèmes « 100 % » du roadmap n'ont aucun filet alors qu'ils mutent l'état global et l'or. En complément : un job CI minimal (GitHub Actions) lançant `CheckScripts` + `TestRunner` + `e2e_*` sur une version Godot épinglée, avec warnings en `error`.
