# Plan d'implémentation — Audit cohésion & branchement

> Plan dérivé de [`2026-06-04-cohesion-branchement.md`](2026-06-04-cohesion-branchement.md).
> Constats P0/P1 **re-vérifiés dans le code réel** (4 agents indépendants) avant rédaction : tous confirmés.
> Les numéros de ligne ci-dessous sont les numéros **actuels** (légèrement décalés de l'audit).
>
> **Décision verrouillée avec le dev :** l'avance de phase se fait par **bouton manuel** (pas d'avance automatique).
> **Décisions encore ouvertes :** disposition du code mort fast-forward (suppr. recommandée) ; stats équipement FOR/AGI/INT fonctionnelles vs simple préférence (préférence recommandée).

## Principes directeurs

1. **Test-first sur les chemins cassés.** Les 240 tests passent parce qu'ils contournent les bugs (`force_phase_change`, vérif du seul booléen de retour). Chaque lot ajoute le test E2E qui aurait dû attraper le bug, **sans appel debug**.
2. **Lots livrables.** Chaque lot laisse le jeu jouable et compile (`CheckScripts` 109 scripts + `TestRunner`). Commit par lot.
3. **Jouabilité d'abord, branchement ensuite, nettoyage en dernier** — pour ne pas masquer une régression sous un gros diff de suppression.

---

## LOT 0 — Débloquer la jouabilité (critique) 🔴

Sans ce lot : ~50 % du contenu (National, Esport) injouable + deux actions courantes crashent. Premier PR, à valider soigneusement.

### 0.1 — Soft-lock de progression de phase *(le pivot)*

**Confirmé :** `phase_manager.gd:265-266` — `complete_heroic_dungeon()` est le **seul** appelant de `try_advance_phase()`, gardé par `if current_phase == GamePhase.LEVELING`. `check_phase_progression()` (`:157`) ne fait qu'émettre `phase_requirements_met`. Le popup `fenetre_personnage.gd:802` annonce « vous pouvez passer » mais n'offre **aucun** moyen de le faire. `setup_for_phase_transition()` (`confirm_dialog.gd:349`) est défini mais **mort** (0 appelant). `get_requirements_progress()` (`:447`) existe pour l'affichage UI.

- **Approche retenue : bouton manuel.**
  - Exposer un helper propre `PhaseManager.can_advance_phase() -> bool` (lecture pure, sans effet de bord).
  - Popup `_on_requirements_met` : remplacer l'`AcceptDialog` informatif par un `components/confirm_dialog.gd` configuré via `setup_for_phase_transition(...)`, dont le callback appelle `PhaseManager.unlock_next_phase()`.
  - Onglet Progression : ajouter un bouton « Passer à la phase suivante », activé quand `can_advance_phase()` est vrai (rafraîchi sur `phase_requirements_met`).
- **Fichiers :** `scripts/systems/phase_manager.gd`, `scripts/ui/windows/fenetre_personnage.gd`, `scripts/ui/dialogs/confirm_dialog.gd` (réutilisé).
- **Vérif :** nouveau `tests/e2e_phase_advance.gd` — amener une phase ≥ SERVEUR à remplir ses objectifs, déclencher l'avance **sans `force_phase_change`**, asserter l'incrément de `current_phase`.
- **Taille :** M.

### 0.2 — Crash drag&drop d'organisation de groupe

**Confirmé :** `fenetre_organisation_groupe.gd:424` et `:441` appellent `item.get_drag_data()` — méthode **inexistante** sur `DraggableItem` (seule la propriété `drag_data` existe, + setter `set_drag_data`). Le crash survient au drop (callback de validation `:352`).

- **Changement :** `item.get_drag_data()` → `item.drag_data` (2 occurrences).
- **Vérif :** E2E orga existant + smoke : glisser un membre sur un slot sans erreur runtime.
- **Taille :** XS (2 lignes).

### 0.3 — Crash `Object.get()` à 2 arguments

**Confirmé :** `activity_manager.gd:509` et `:520` — `activity.get("start_level", …)` / `activity.get("start_mood", …)` sur un `Activity` (Resource ; `Object.get()` ne prend qu'un argument). `start_level`/`start_mood` ne sont jamais initialisés (seuls `start_timestamp`/`planned_duration` le sont via `set_meta`).

- **Changement :** poser `activity.set_meta("start_level", player.personnage_niveau)` et `set_meta("start_mood", player.mood)` au démarrage de l'activité (`start_activity`, ~`:44-87`) ; lire via `activity.get_meta("start_level", défaut)`.
- **Vérif :** test unitaire de `_evaluate_activity_experience` couvrant chaque `ActivityType`.
- **Taille :** S.

### 0.4 — Brancher la réputation PvE

**Confirmé :** `guild.gd:294-335` — `on_server_first` (+15), `on_raid_success` (+2/+4/+6), `on_raid_failure` (-1.5/-3) ont **0 appelant**. `dungeon_instance.gd:429-495` (`_complete_dungeon`/`_abandon_dungeon`) accorde or + XP mais **aucune réputation**. `register_server_first` (`guild_ranking.gd:415`) n'émet qu'un signal, n'accorde rien.

- **Changement :** `_complete_dungeon` → `GuildManager.guild.on_raid_success(difficulté)` ; `_abandon_dungeon` → `on_raid_failure(wipes)` ; `register_server_first` → `on_server_first(content_id)` **pour la guilde joueur uniquement**.
- **Vérif :** suite PvE — asserter que `guild.reputation` augmente après un clear et un server first, baisse après abandon.
- **Taille :** S.

---

## LOT 1 — Boucles de gameplay & branchement 🟠

De la valeur produite que rien ne consomme + états perdus à la sauvegarde. Sous-groupes largement parallélisables.

### 1.1 — Débauchage / contre-offre injouable

**Confirmé :** `ai_guild_manager.gd:211` retire le membre (`remove_member`) **avant** d'émettre `poaching_attempt(…, true)` (`:217`). `poaching_handler.gd:22` fait `if target_member not in GuildManager.guild_members: return` → toujours vrai → la popup (`poaching_popup.gd`, 437 l.) ne s'ouvre **jamais**. Contre-offre entièrement morte.

- **Changement :** émettre `poaching_attempt(member, guild, true)` **avant** toute mutation ; déplacer `remove_member` + ajout à la guilde IA dans le callback `_on_member_released_to_poaching` du popup (retrait seulement si le joueur laisse partir / ignore). Le calcul de `leave_probability` et l'ajout IA se font **en aval** de la décision joueur.
- **Vérif :** test simulant un débauchage → popup ouverte, membre conservé tant que non tranché ; contre-offre acceptée → membre reste.
- **Taille :** M.

### 1.2 — Effets & bonus de guilde jamais lus

**Confirmé :** `guild.gd:188-201` (`get_effective_*`) et `simulated_player.gd:796-861` (`get_modified_*`, `can_perform_action`, `get_available_actions`) ont **0 appelant externe**. Effets `lucky_streak` (`raid_success_bonus:0.2`) et `recruitment_bonus` écrits par EventManager mais jamais relus.

- **Changement :** router les lectures combat/recrutement vers `get_effective_*` / `get_modified_skill/mood/energy`.
- **Vérif :** test appliquant `lucky_streak` → `get_effective_raid_success_bonus()` reflète le modificateur ; idem `recruitment_bonus`.
- **Taille :** M. *(Lié à la décision « stats équipement ».)*

### 1.3 — Effet `injured` jamais appliqué

**Confirmé :** `event_manager.gd:278-300` `_apply_consequences` ne route que `GUILD` et `ALL_PLAYERS`. L'effet `injured` (`effects_data.gd:166`, `TargetType.PLAYER`, `blocks_actions = ["raid","dungeon"]`) du choix « Attendre la guérison » (`events_data.gd:270`) tombe entre les branches → silencieusement ignoré. De plus `blocks_actions` n'est jamais vérifié en compo.

- **Changement :** ajouter `elif effect.target_type == EffectResource.TargetType.PLAYER:` (membre non-joueur aléatoire) **et** vérifier `can_perform_action("raid"/"dungeon")` dans la composition de groupe (`fenetre_organisation_groupe.gd`).
- **Vérif :** test événement `member_injury` → membre marqué injured → exclu de la compo.
- **Taille :** M.

### 1.4 — Garde `is_player` (résolution de drama « exclusion »)

**Confirmé :** `drama_manager.gd:126` — un SCANDAL ne requiert que `celebrity_level > 80` (sans tag) → peut cibler « Joueur » ; « Exclure » appelle `remove_member` sans garde.

- **Changement :** `if member.get_meta("is_player", false): return` **en tête de `GuildManager.remove_member`** (catch-all robuste) + rediriger l'exclusion vers « sanctions » si le membre est le joueur.
- **Taille :** S.

### 1.5 — Save/load des états perdus

**Confirmé :** `phase_manager.gd:543` charge `phase_progress` puis `:549` `_initialize_phase_progress()` **l'écrase** (achievements, `days_in_phase`, `milestones_reached`, `requirements_progress` perdus). `scheduled_absences`, `active_effects`, `current_activity` **non (dé)sérialisés** (`save_manager.gd:344-463`). Le re-wiring après load (dans `main.gd`) ne re-câble pas `fenetre_personnage` (son garde `_state_signal_connected` reste à true).

- **Changement :** merge non destructif de `phase_progress` (ne réinitialiser que les clés absentes ; normaliser clés int↔String) ; (dé)sérialiser `scheduled_absences` + `active_effects` (id/durée/stack/source/target_id, ré-appliqués après `_deserialize_members`) ; gérer le run en cours (terminer/abandonner proprement avant save, ou état minimal) ; reconnecter `fenetre_personnage` sur `SaveManager.load_completed`.
- **Vérif :** round-trip save/load assertant la conservation de `phase_progress`, des effets actifs et des absences.
- **Taille :** L.

### 1.6 — `days_at_rank_1` (compteur unique)

**Confirmé :** `phase_manager.gd:25` + `:427` (`_update_rank_duration`) — compteur unique partagé serveur/national, jamais reset au changement de phase, ticke dans **toutes** les phases (y compris LEVELING), incrémenté quotidiennement sur un rang recalculé seulement chaque semaine.

- **Changement :** deux compteurs (`server_days_at_rank_1` / `national_days_at_rank_1`), gate par phase, fenêtre glissante « N des M derniers jours », reset dans `unlock_next_phase`, comptabilisation sur l'événement `ranking_updated` (ou recalcul du ranking le jour d'évaluation).
- **Taille :** M.

### 1.7 — Signaux orphelins utiles + `gold_changed`

**Confirmé :** `advice_pushed`, `catchup_applied(gold)` (**aide en or invisible**), `content_unlocked`, `reputation_changed`, `xp_gained` émis avec **0 connexion**. Pas de `signal gold_changed` sur `Guild` (UI par polling).

- **Changement :** ajouter `signal gold_changed(old_gold, new_gold)` à `guild.gd` (émis sur `add_gold`/`spend_gold`/`set_gold`) ; connecter `content_unlocked`, `catchup_applied`, `reputation_changed`/`gold_changed` à des toasts/refresh ; supprimer les signaux purement décoratifs.
- **Taille :** M.

### 1.8 — Modificateurs Phase 0

**Confirmé (audit) :** `skill_malus` / `tag_reveal_rate` / `connection_bonus` configurés mais non câblés (logique commentée dans `simulated_player.gd`, ex. `get_effective_skill()` no-op).

- **Changement :** câbler les trois modificateurs **ou** retirer la config morte et corriger la roadmap.
- **Taille :** S–M.

### 1.9 — Chat (déclencheurs mal calibrés)

**Confirmé (audit) :** `chat_director.gd:591` `loot_epic` se déclenche pour RARE (`>= 2`) ; `:566` `ninja` (accusation de vol) sur tout conflit de loot légitime.

- **Changement :** `loot_epic` → `int(item.rarity) >= 3` (EPIC strict) ; séparer `ninja` (réservé aux membres taggés `ninja_looter`) d'un nouveau stimulus `loot_dispute` non accusatoire.
- **Taille :** S.

### 1.10 — Comportement (modificateurs morts)

**Confirmé (audit) :** `behavior_system.gd:272` `bonus_session_active` jamais armé par le chemin vivant ; `:178` compare jour absolu vs jour de semaine (bonus « succès récent » faussé).

- **Changement :** armer `bonus_session_active` dans `trigger_personal_event` cas `bonus_time` (désarmer à la consommation de `bonus_session_hours`) ; corriger la comparaison via `GameTime.get_total_days_elapsed() - last_raid_success_day`.
- **Taille :** S.

---

## LOT 2 — Nettoyage & cohérence 🧹

Risque faible, après stabilisation pour ne pas mélanger suppression et corrections.

| # | Action | Détail | Taille |
|---|---|---|---|
| 2.1 | Supprimer le code mort | `fast_forward_manager.gd` (280 l.) + `fast_forward_dialog.gd` (574 l.) (réfs `main.gd` commentées) ; `scripts/ui/dialogs/` (base/confirm/input/progress — doublon de `components/confirm_dialog.gd`) ; `_simulate_dungeon_run()` (`fenetre_organisation_groupe.gd:671-720`, API morte) ; `tooltip.gd` (47 l., jamais instancié) ; fonctions/signaux orphelins listés. **Préserver `chat/chat_backend.gd` (stub volontaire) et `utils/singletons.gd`.** | M |
| 2.2 | Dédupliquer les sources de vérité | trancher `PlayerCharacter.or_actuel` (inerte) vs `Guild.gold` ; aligner la palette sur `UITheme` canonique (5 fenêtres + `BADGE_COLORS`/`TYPE_COLORS`) ; trancher poids de ranking (`BalanceManager.BALANCE` miroir vs `GuildRanking.SCORE_WEIGHTS` réel). | M |
| 2.3 | Équilibrage | `TOTAL_GUILDS` au runtime (`ai_guilds.size()+1`, clamp [0,1]) ; cap `gold_storage` en `max` au lieu de `+=` ; clarifier la double pénalité de wipe ; gardes de phase sur tournois/transferts/stipend/staff. | M |
| 2.4 | Typage statique | `advisor_manager`, `window_manager`, `guild.gd` (mandat CLAUDE.md). | S |
| 2.5 | CI | conserver `godot --headless --import` avant `CheckScripts` ; envisager de retirer `continue-on-error: true` sur l'import. | XS |
| 2.6 | RNG | `randomize_rng()` au boot d'une partie, **ou** corriger la grille « RNG déterministe Oui/Oui » de la roadmap. | XS |
| 2.7 | Roadmap honnête | ramener Milestones 3/4 (et modificateurs Phase 0, patterns, refresh « 3 jours ») d'« 100 % jouable/validé » à un statut réel tant que le soft-lock et les boucles ne sont pas corrigés. | XS |

L'annexe « notes mineures » de l'audit (~30 puces) se traite à la marge en fin de Lot 2.

---

## Séquencement & dépendances

```
Lot 0 (0.1 → 0.2 / 0.3 / 0.4)   ← bloquant, en premier, un seul PR
   │
   ├─ Lot 1.1–1.4  (boucles)         ┐ parallélisables
   ├─ Lot 1.5–1.6  (save + rang)     ┘ (1.6 dépend un peu de 0.1)
   └─ Lot 1.7–1.10 (signaux / calage)
            │
         Lot 2 (nettoyage, en dernier)
```

**Effort indicatif :** Lot 0 ≈ 1–1,5 j · Lot 1 ≈ 3–4 j · Lot 2 ≈ 2–3 j.

## Vérification (à chaque lot)

- `tests/run_tests.ps1` (`CheckScripts` 109 scripts + `TestRunner`).
- Nouveaux E2E ciblant le chemin réparé (au minimum `e2e_phase_advance.gd` pour 0.1).
- Validation runtime MCP (screenshots) pour les changements visibles (popup d'avance, drag&drop, popup débauchage).

## Décisions

| # | Sujet | Statut |
|---|---|---|
| D1 | Avance de phase | ✅ **Verrouillé : bouton manuel.** |
| D2 | Code mort fast-forward (~852 l.) | ⏳ Ouvert — **suppression recommandée**. |
| D3 | Stats équipement FOR/AGI/INT | ⏳ Ouvert — **simple préférence recommandée** (moins risqué pour l'équilibrage). |
