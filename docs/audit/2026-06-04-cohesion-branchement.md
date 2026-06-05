# Audit de cohésion & branchement — RaidLead (4 juin 2026)

> Audit ciblé sur le **branchement** (wiring), la **cohérence** et la **jouabilité de bout en bout** des systèmes — pas sur la compilation.
> 96 findings vérifiés un par un par des agents sceptiques indépendants (faux positifs déjà écartés), 102 éléments orphelins, 93 notes mineures. Déduplication par cause racine effectuée ci-dessous.

## Verdict global

Le projet **compile proprement** (`CheckScripts` : 109 scripts, 0 erreur) et la suite de tests **passe intégralement** (`TestRunner` : 240/240 assertions). Les systèmes pris isolément sont riches, ambitieux et majoritairement bien construits : le code dénote un vrai souci d'architecture (autoloads, signaux, séparation modèle/UI). **Mais l'audit révèle un fossé entre « le code existe » et « la boucle de jeu fonctionne »**, sur des chemins que les 240 tests ne couvrent pas.

Le risque #1 est un **soft-lock de progression** : passé la Phase 0→1 (déclenchée par `complete_heroic_dungeon`), **aucun code ne fait avancer Serveur→National→Esport**. `check_phase_progression()` détecte que les objectifs sont remplis, émet un signal, affiche un popup « vous pouvez passer à la phase suivante »… mais ne fournit aucun bouton ni aucune transition réelle. ~50 % du contenu (National, Esport) est donc **injouable en partie normale**, alors que la roadmap déclare les Milestones 3 & 4 « 100 % jouables/validés ». Les tests masquent le bug en utilisant `force_phase_change`.

Au-delà du soft-lock, **plusieurs boucles de gameplay produisent de la valeur que rien ne consomme** : la réputation PvE n'est jamais accordée (les méthodes `on_server_first`/`on_raid_success` sont mortes), le système d'effets (buffs/debuffs) est purement cosmétique (jamais lu en combat), les bonus de guilde ne sont jamais appliqués, et l'effet `injured` ne bloque personne. Enfin, **beaucoup de code « écrit mais jamais branché »** subsiste : ~850 lignes de fast-forward mort, une suite de dialogs en double, une popup de débauchage injoignable, ~30 signaux orphelins.

Les quatre risques majeurs, par ordre de priorité :
1. **Progression bloquée** (critique) — National & Esport inatteignables.
2. **Crash latent du drag&drop d'organisation de groupe** (`get_drag_data` inexistante) et **crash latent `Object.get()` à 2 arguments** dans l'évaluation d'activité.
3. **Boucles de gameplay incomplètes** — réputation, effets, bonus de guilde produits/définis mais jamais consommés.
4. **Sur-déclaration de la roadmap** sur l'axe « jouable/validé », qui crée un faux confort.

## Chiffres clés

| Catégorie | Détail |
|---|---|
| **Findings confirmés** | **96** (après vérification sceptique) |
| — Critiques | **3** (toutes = même cause racine : soft-lock de phase) |
| — Élevés | **9** |
| — Moyens | **32** |
| — Faibles | **52** |
| **Éléments orphelins** | 102 (code mort / signaux non connectés / fonctions sans appelant) |
| **Notes mineures** | 93 |
| **Ground truth — compilation** | `CheckScripts` = 109 scripts, **0 erreur** |
| **Ground truth — tests** | `TestRunner` = **240/240** assertions, 0 échec |
| **Piège CI/onboarding** | Un clone/worktree frais ne compile pas tant que `godot --headless --import` n'a pas régénéré `.godot/global_script_class_cache.cfg` (toutes les `class_name` apparaissent « not declared »). **Le CI le gère déjà** (`.github/workflows/tests.yml:27-29` lance l'import avant `CheckScripts`), mais avec `continue-on-error: true` — à surveiller. |

> **Note méthodologique** : les bugs listés ne sont **pas** des erreurs de compilation. Ce sont des défauts de **branchement**, de **cohérence** et de **jouabilité** sur des chemins non couverts par les 240 tests (cf. `run_tests.gd:610-612` / `:1882` qui ne testent que la valeur de retour de `check_phase_progression`, jamais l'avancement réel de `current_phase`).

## Tableau de bord par sous-système

| Sous-système | Branchement | Remarque courte |
|---|---|---|
| Temps / Save | 🟡 Partiel | Boucle de temps solide ; save/load omet plusieurs états (effets, absences, run en cours, pool, phase_progress écrasé). RNG déterministe jamais activé en prod. |
| Guilde / Membres | 🟡 Partiel | `add_member` écrase integration/days/réputation pour le joueur et les membres initiaux ; pas de signal `gold_changed`. |
| Comportement | 🟡 Partiel | Présence vivante fonctionnelle, mais doublons morts (`should_connect_dynamic`), `bonus_session_active` jamais armé, patterns dormants. |
| Activités / PvE | 🟡 Partiel | Boucle PvE jouable mais **crash latent** `Object.get()` 2 args ; gating serveur ignoré ; `_simulate_dungeon_run` mort. |
| Équipement / Effets | 🔴 Cassé | **Effets jamais lus** (buffs/debuffs cosmétiques) ; bonus de guilde non appliqués ; `injured` ne bloque rien ; stats FOR/AGI/INT décoratives. |
| Recrutement / IA | 🟡 Partiel | Recrutement OK ; **débauchage/contre-offre injouable** (membre retiré avant le signal → popup mort). Refresh « 3 jours » no-op. |
| Progression / Ranking | 🔴 Cassé | **Soft-lock total** des phases ≥1. `days_at_rank_1` partagé serveur/national, jamais reset. Ranking non initialisé au boot. |
| National (médias/sponsors/dramas) | 🟡 Partiel | Back-ends branchés ; `exclusion` peut supprimer le joueur ; signaux `streamer_stopped`/`sponsor_offer_available` morts ; incident `streaming_vs_raid` sans effet. |
| Esport (staff/tournois/transferts/legacy) | 🟡 Partiel | Boucle validée en éditeur ; synergie staff incohérente ; transferts « élite » sans équipement ; tournois/transferts non gatés par phase. |
| Social / Culture / Événements | 🟡 Partiel | Relations/cliques vivantes ; 5 signaux SocialDynamics morts ; **effet `injured` jamais appliqué** (branche manquante dans le consommateur). |
| Conseiller / Équilibrage | 🟡 Partiel | Fonctionnels ; `TOTAL_GUILDS=10` codé en dur fausse le standing en National/Esport ; signaux `advice_pushed`/`catchup_applied` morts. |
| Chat | 🟡 Partiel | Vivant et data-driven ; stimulus `ninja` et `loot_epic` se déclenchent à tort (conflits légitimes / objets RARE) ; suppression fast-forward documentée mais absente. |
| Orchestration / main | 🟡 Partiel | Re-wiring joueur après load incomplet (oublie `fenetre_personnage`) ; double-surface toast+popup ; spam de toasts connexion/déconnexion. |
| UI — fenêtres | 🟡 Partiel | Org. groupe ferme par `hide()` (désync WindowManager) ; popup de phase mensonger ; carte « Phase actuelle » périmée à la réouverture. |
| UI — composants | 🟡 Partiel | **Drag&drop org. crashe au drop** ; suite `dialogs/` morte (doublon) ; toast double cycle de vie ; Tooltip, Badge, StatDisplay très sous-utilisés. |

---

## 🔴 Problèmes critiques

### 1. Soft-lock total de la progression de phase au-delà de Serveur
**Emplacement(s) :** `scripts/systems/phase_manager.gd:157-194` (`check_phase_progression`), `:196` (`unlock_next_phase`), `:242` (`try_advance_phase`), `:266` (`complete_heroic_dungeon`) ; popup mensonger `scripts/ui/windows/fenetre_personnage.gd:802-811` ; helper UI mort `scripts/ui/dialogs/confirm_dialog.gd:349` (`setup_for_phase_transition`) ; tests qui masquent `tests/e2e_progression.gd:36` + `run_tests.gd:610-612`.
*(3 findings critiques + 2 highs fusionnés en une seule cause racine.)*

**Problème :** `check_phase_progression()` — appelé chaque semaine et tous les 7 jours — détecte que les objectifs d'une phase sont remplis, met à jour le dictionnaire de progression et **émet `phase_requirements_met`**, mais **ne fait jamais avancer la phase**. Le seul appelant de `unlock_next_phase()`/`try_advance_phase()` est `complete_heroic_dungeon()`, gardé par `if current_phase == GamePhase.LEVELING`. Donc seule la transition **Phase 0 → 1** fonctionne. **Serveur→National et National→Esport ne sont déclenchés par aucun chemin de jeu normal.**

**Preuve / mécanisme :** Vérification statique + grep exhaustif : `check_phase_progression()` est une lecture pure (n'écrit jamais `current_phase`). Le popup `_on_requirements_met` (fenetre_personnage.gd:802) crée un `AcceptDialog` purement informatif (« Vous pouvez maintenant passer à la phase suivante ») avec un seul bouton « OK » — aucun bouton « Avancer ». Le seul helper UI prévu pour la transition (`setup_for_phase_transition`) n'a **aucun appelant**. Les tests contournent le bug via `force_phase_change` et ne vérifient que le booléen de retour, jamais l'incrément de `current_phase` pour les phases ≥ SERVEUR — d'où les 240 assertions vertes malgré le blocage.

**Correctif :** Faire que la vérification périodique avance réellement la phase : remplacer `check_phase_progression()` par `try_advance_phase()` dans `_on_day_changed`/`_on_week_changed` pour les phases ≥ SERVEUR, **OU** brancher `phase_requirements_met` à un vrai bouton « Passer à la phase suivante » (dans le popup et l'onglet Progression) appelant `PhaseManager.unlock_next_phase()`. Ajouter ensuite un test E2E qui amène une phase ≥1 à remplir ses objectifs et asserte l'incrément de `current_phase` **sans appel debug**.

---

## 🟠 Problèmes élevés

### 2. Le drag&drop d'organisation de groupe crashe au drop (méthode inexistante)
**Emplacement(s) :** `scripts/ui/windows/fenetre_organisation_groupe.gd:418` (`_on_member_dropped`) et `:434` (`_validate_member_drop`) ; `scripts/ui/components/draggable_item.gd` (pas de `get_drag_data`).
**Problème :** Les deux fonctions appellent `item.get_drag_data()`, mais `DraggableItem` n'expose aucune méthode `get_drag_data()` — seulement la propriété `drag_data` et le setter `set_drag_data()`.
**Preuve / mécanisme :** Glisser un membre sur un slot déclenche `DropZone.accept_drop` → `can_accept_drop` → `validation_callback.call(...)` → `_validate_member_drop` → erreur runtime « Invalid call. Nonexistent function `get_drag_data` ». Grep complet : zéro `func get_drag_data`. La composition par drag&drop (feature annoncée comme livrée) est donc inutilisable.
**Correctif :** Remplacer `item.get_drag_data()` par `item.drag_data` aux lignes 418 et 434.

### 3. `Object.get()` appelé avec 2 arguments dans l'évaluation d'activité (crash runtime latent)
**Emplacement(s) :** `scripts/systems/activity_manager.gd:509` et `:520` (`_evaluate_activity_experience`).
**Problème :** Le code appelle `activity.get("start_level", player.personnage_niveau)` et `activity.get("start_mood", player.mood)` sur un objet `Activity` (Resource). En Godot 4, `Object.get(property)` ne prend qu'**un** argument ; en passer 2 lève « Invalid call to function 'get' ». De plus `start_level`/`start_mood` ne sont jamais définis (seuls `start_timestamp`/`planned_duration` le sont via `set_meta`).
**Preuve / mécanisme :** `activity` est toujours un `Activity` instancié via `ActivityScript.new()` (activity_manager.gd:48,410), aucun override `get(...)`. Crash au moment où la qualité d'expérience est évaluée.
**Correctif :** Poser de vraies metas au `start_activity` (`activity.set_meta("start_level", …)`) et lire via `activity.get_meta("start_level", default)` ; ou supprimer ces comparaisons et capturer le delta de mood autrement.

### 4. Popup de débauchage + contre-offre injouable : le membre est retiré avant l'émission du signal
**Emplacement(s) :** `scripts/systems/ai_guild_manager.gd:208` (`_process_successful_poaching_from_player`) ; `scripts/systems/poaching_handler.gd` ; `scripts/ui/windows/poaching_popup.gd` (~438 lignes injoignables).
*(2 highs fusionnés.)*
**Problème :** Quand une guilde IA débauche un membre avec succès, le membre est **retiré immédiatement** de la guilde, puis le signal `poaching_attempt(success=true)` est émis. Le `PoachingHandler` censé ouvrir la popup (contre-offre / laisser partir / ignorer) abandonne car le membre n'est déjà plus dans `guild_members`.
**Preuve / mécanisme :** Le signal est bien connecté (PoachingHandler instancié guild_manager.gd:380-384), mais le seul chemin ouvrant la popup est gardé sur `success == true` alors que le membre est déjà supprimé. Toute la feature de contre-offre (`poaching_popup.gd`, `simulate_counter_offer_response`, `_calculate_final_leave_probability`) est donc **morte** ; le joueur perd un membre sans interaction ni avertissement spécifique.
**Correctif :** Émettre `poaching_attempt(target_member, source_guild, true)` **avant** toute mutation, et déplacer le retrait effectif dans le callback `_on_member_released_to_poaching` du popup (retrait uniquement si le joueur perd/ignore la contre-offre). Le calcul de `leave_probability` et l'ajout à la guilde IA doivent se faire **en aval** de la décision joueur.

### 5. La boucle PvE n'accorde jamais de réputation
**Emplacement(s) :** `scripts/resources/guild.gd:281-340` (`on_server_first` +15, `on_raid_success` +2/+4/+6, `on_raid_failure`) — méthodes sans appelant ; producteurs attendus : `register_server_first` et `dungeon_instance._complete_dungeon`/`_abandon_dungeon`.
**Problème :** Un clear de contenu donne or + XP de guilde + score de classement, **mais pas de réputation**, alors que les trois méthodes dédiées existent précisément pour ça. La réputation pèse 15 % du score de classement et conditionne la difficulté de recrutement — la boucle « réussir des raids → gagner en réputation → recruter mieux » est donc rompue.
**Preuve / mécanisme :** Grep repo-wide : `on_server_first`/`on_raid_success`/`on_raid_failure` ont **zéro appelant** (seuls `on_world_first` et `on_team_stability_bonus` sont appelés ailleurs).
**Correctif :** Appeler `GuildManager.guild.on_server_first(content_id)` dans `register_server_first` (guilde joueur uniquement) et `on_raid_success`/`on_raid_failure` depuis `dungeon_instance._complete_dungeon`/`_abandon_dungeon`.

### 6. Bonus de guilde issus des effets jamais appliqués au combat/recrutement
**Emplacement(s) :** `scripts/resources/guild.gd:175-188` (`get_effective_*`, zéro appelant) ; effets `lucky_streak`/`recruitment_bonus` définis `effects_data.gd:185-200`.
**Problème :** `lucky_streak` (`raid_success_bonus: 0.2`) et `recruitment_bonus` sont appliqués comme effets de guilde mais jamais lus : le combat/recrutement appelle les getters **bruts**, pas les `get_effective_*` (seuls à inclure les modificateurs d'effet). Ces effets n'ont donc **aucun impact**.
**Preuve / mécanisme :** La chaîne d'écriture est complète (EventManager applique les effets), mais aucune lecture ne passe par `get_effective_*` — confirmé statiquement.
**Correctif :** Router les lectures combat/recrutement vers les variantes `get_effective_*`, sinon supprimer ces effets de guilde.

### 7. L'effet `injured` (événement « Membre blessé ») n'est jamais appliqué — branche manquante
**Emplacement(s) :** `scripts/autoloads/event_manager.gd:294` (`_apply_consequences`) ; effet `injured` `effects_data.gd:173` (`TargetType.PLAYER`) ; événement `member_injury` `events_data.gd:270`.
**Problème :** `_apply_consequences` ne route que les effets `GUILD` et `ALL_PLAYERS`. L'effet `injured` (cible `PLAYER`) du choix « Attendre la guérison » tombe entre les deux branches et est **silencieusement ignoré**.
**Preuve / mécanisme :** L'événement est réellement déclenchable (events_data.gd:16) ; son choix référence un effet `PLAYER` qu'aucune branche du consommateur ne traite.
**Correctif :** Ajouter `elif effect.target_type == EffectResource.TargetType.PLAYER:` qui pioche un membre non-joueur aléatoire et lui applique l'effet. *(Voir aussi #M-effets : même si appliqué, `injured.blocks_actions` n'est de toute façon jamais vérifié — double rupture.)*

### 8. Le popup « vous pouvez passer à la phase suivante » est mensonger
**Emplacement(s) :** `scripts/ui/windows/fenetre_personnage.gd:802-811`.
*(Corollaire direct du #1 ; conservé séparément car c'est le symptôme visible côté joueur.)*
**Problème :** `_on_requirements_met` affiche « Vous pouvez maintenant passer à la phase suivante » mais ne fournit **aucun moyen** de le faire — ni bouton dans le popup, ni dans l'onglet Progression.
**Correctif :** Ajouter un bouton « Avancer » appelant `PhaseManager.unlock_next_phase()` (résout aussi le #1 côté UX).

---

## 🟡 Problèmes moyens (regroupés par thème)

### A. Save / load incomplet (round-trip cassé ou états perdus)
- **`phase_progress` sauvegardé puis écrasé au chargement** — `phase_manager.gd:540` : `load_phase_data` assigne `phase_progress` (l.543) puis appelle `_initialize_phase_progress()` (l.549) qui **réinitialise tout** ; achievements, `days_in_phase`, `milestones_reached`, `requirements_progress` sauvegardés sont perdus. *Fix : merge non destructif (ne réinitialiser que les clés absentes), normaliser clés int↔String.*
- **Run de donjon en cours non sérialisé** — `save_manager.gd:408` : une autosave pendant un run (changement de phase, ou toutes les 4 semaines) perd le `DungeonInstance` et oriente une fenêtre orpheline ; `current_activity` n'est pas restauré. *Fix : terminer/abandonner proprement les runs avant save, ou sérialiser un état minimal.*
- **`scheduled_absences` (absences multi-jours) non sauvegardées** — `save_manager.gd:376` : un membre censé être absent se reconnecte après load. *Fix : ajouter au (dé)sérialiseur (+ idéalement `bonus_session_hours`, `recent_events_memory`).*
- **État du système d'effets non sauvegardé** — `save_manager.gd` / `effect_system.gd:8` : `active_effects` (skill_bonus 1 sem., recruitment_bonus 2 sem., injured 48 h) disparaît au load. *Fix : sérialiser id+durée+stack+source+target_id et ré-appliquer après `_deserialize_members`, ou documenter l'éphémère.*
- **fenetre_personnage reste branchée sur l'ancien joueur après load** — `fenetre_personnage.gd:400` : `_rewire_player_after_load` re-câble `main` et `player_control_panel` mais **pas** `fenetre_personnage` ; son garde booléen `_state_signal_connected` n'est jamais remis à false → mises à jour temps réel mortes après chargement. *Fix : suivre la référence du joueur courant, ou se reconnecter sur `SaveManager.load_completed`.*

### B. Compteur de durée de rang (`days_at_rank_1`)
*(4 findings fusionnés autour du même champ `phase_manager.gd:25`.)*
- **Compteur unique partagé serveur/national, jamais reset au changement de phase** — `phase_manager.gd:427`/`:25`/`:266` : les jours au rang 1 serveur (seuil 14) comptent d'office vers le rang 1 national (seuil 30) ; reset brutal dès une seule journée hors top 1 ; ticke dans toutes les phases (y compris LEVELING). *Fix : deux compteurs (`server_days_at_rank_1`/`national_days_at_rank_1`), gate par phase, fenêtre glissante (« N des M derniers jours »), reset dans `unlock_next_phase`.*
- **Incrémenté quotidiennement sur un rang recalculé seulement chaque semaine** — `phase_manager.gd:427` lit une position figée 6 jours sur 7. *Fix : comptabiliser la durée sur l'événement `ranking_updated`, ou recalculer le ranking le jour d'évaluation.*

### C. Équilibrage / valeurs codées en dur
- **`TOTAL_GUILDS = 10` codé en dur** — `balance_manager.gd:36` : fausse le « struggle » en National (14 guildes) et Esport (16), sur-déclenchant le catch-up dans les phases censées être plus dures. *Fix : `(AIGuildManager.ai_guilds.size() + 1)` au runtime, clamp `frac` dans [0,1].*
- **`gold_storage` s'additionne entre paliers de perk** — `guild_perks_data.gd:128` : `get_combined_effects` fait `+=`, donc le cap atteint 257000 au niv 10 au lieu des 200000 annoncés. *Fix : `max` au lieu de `+=` pour les seuils non cumulatifs.*
- **L'or excédentaire est détruit au plafond et signalé une seule fois** — `guild.gd:83` : tant que la trésorerie reste pleine, tout revenu suivant (sponsors, tournois jusqu'à 12000, butin) est perdu silencieusement. *Fix : ne pas plafonner les revenus, ou re-signaler périodiquement via l'AdvisorManager.*
- **Transferts « élite » sans équipement** — `transfer_manager.gd:69` : niveau 60 / skill 78-98 mais équipement de départ basique. *Fix : équiper un set niveau 60 cohérent après fixation du niveau.*
- **`active_members_min` lit les membres EN LIGNE à l'instant du check** — `phase_manager.gd:308` : un snapshot instantané peut être <15 même avec 25 membres. *Fix : compter le roster total ou une moyenne de présence hebdo.*

### D. Boucles de gameplay incomplètes (valeur produite que rien ne consomme)
- **Système d'effets entièrement cosmétique** — `simulated_player.gd:796` : `get_modified_energy/mood/skill/integration`/`get_modified_stat` n'ont **aucun appelant externe** ; le gameplay lit toujours les champs bruts. *Fix : router au moins skill/mood/energy en combat et sélection d'activité vers `get_modified_*`.*
- **Stats d'équipement FOR/AGI/INT décoratives** — `equipment.gd:135` : consommées seulement par `calculate_item_score` (auto-équip), aucune influence sur la puissance de combat/skill/ranking (seul `ilvl` compte). *Fix : intégrer `get_equipment_stats()` au calcul de puissance, ou assumer le rôle de simple préférence.*
- **Synergie de staff incohérente** — `staff_manager.gd:166` : appliquée au combat (`get_total_performance/strategy_bonus`) mais **pas** au bien-être (`morale`/`stress_relief`/`stability`). *Fix : appliquer aux trois agrégats, ou documenter l'intention.*

### E. National — incidents / dramas
- **La résolution de drama « exclusion » peut supprimer le personnage joueur** — `drama_manager.gd:126` : un SCANDAL ne requiert que `celebrity_level > 80` (pas de tag) → peut cibler « Joueur » ; « Exclure » appelle `remove_member` sans garde `is_player`. *Fix : ignorer/rediriger vers « sanctions » si `member.get_meta("is_player")`, ou garde `is_player` en tête de `remove_member`.*
- **L'incident `streaming_vs_raid` n'a aucune conséquence** — `media_manager.gd:99` : émis, mais `DramaManager._on_media_incident` ne gère que `live_incident`/`strategy_leak` → toast cosmétique. *Fix : ajouter un effet (perte moral/intégration ou mini-drama), ou retirer l'incident.*

### F. Chat — déclencheurs mal calibrés
- **Stimulus `ninja` (accusation de vol) sur des conflits de loot légitimes** — `chat_director.gd:566` : tout conflit rare+ pousse un stimulus `ninja` (salience 0.9) → répliques d'accusation + scène « tribunal_ninja », alors qu'aucun vol n'a eu lieu. *Fix : renommer `loot_dispute` + pool non accusatoire, ou réserver `ninja` aux membres taggés `ninja_looter`.*
- **Stimulus `loot_epic` se déclenche aussi pour les objets RARE** — `chat_director.gd:591` : `int(item.rarity) >= 2` inclut RARE (courant). *Fix : `>= 3` (EPIC strict).*

### G. Comportement — modificateurs morts
- **`bonus_session_active` jamais armé par le chemin vivant** — `behavior_system.gd:272` : le bonus de motivation +12 % des événements « temps bonus » ne s'applique jamais (armé seulement dans la fonction morte `apply_event_effects`). *Fix : armer dans `trigger_personal_event` cas `bonus_time`, désarmer à la consommation de `bonus_session_hours`.*
- **`apply_event_effects` est un duplicata mort avec sémantique `start_day` divergente** — `personal_events.gd:406` : écrit `start_day` en jour relatif alors que le consommateur attend l'absolu (piège de maintenance). *Fix : supprimer `apply_event_effects` + `get_random_event`.*
- **Comparaison incohérente jour absolu vs jour de semaine** — `behavior_system.gd:178` : compare `game_time.current_day` (1-7) à `last_raid_success_day` (jours absolus), faussant le bonus « succès récent ». *Fix : `GameTime.get_total_days_elapsed() - last_raid_success_day`.*

### H. UI — désync & doublons
- **fenetre_organisation_groupe ferme par `hide()` au lieu de `close_requested`** — `fenetre_organisation_groupe.gd:730` : l'instance reste dans `open_windows`, z-order/`active_window` non mis à jour, bouton de menu reste surligné. *Fix : déclarer `signal close_requested` et l'émettre dans `_on_close_pressed`.*
- **NotificationToast a un double cycle de vie** — `notification_manager.gd:218` : le toast démarre son propre timer + animations pendant que le manager crée les siens (double timer, double anim concurrente sur le même nœud). *Fix : une seule source d'autorité.*
- **Toast spam sur chaque connexion/déconnexion de membre** — `notification_manager.gd:435` : noie les notifications utiles. *Fix : retirer les abonnements `member_connected`/`member_disconnected` (laisser le chat), ou ne notifier que le joueur.*
- **Suite de dialogs `scripts/ui/dialogs/` = code mort, doublon** — `confirm_dialog.gd:1` : `ModalConfirmDialog`/`InputDialog`/`ProgressDialog`/`BaseDialog` (~57 KB) sans appelant externe ; les vrais usages chargent `components/confirm_dialog.gd` (`ConfirmDialog`, classe distincte). *Fix : trancher le doublon — supprimer `dialogs/` ou rebrancher dessus.*
- **Données de phase périmées à la réouverture de fenetre_personnage** — `fenetre_personnage.gd:191` : carte « Phase actuelle » construite en variable locale, jamais rafraîchie ; refresh seulement `if visible`. *Fix : stocker `ph_name` en membre + exposer `refresh_window()`.*

### I. Cohérence diverse
- **Déterminisme RNG jamais activé en production** — `game_random.gd:16` : `seed_rng()` n'est appelé que dans les tests, `randomize_rng()` jamais au boot. *Fix : `randomize_rng()` au démarrage d'une partie (+ persister la graine si reproductibilité voulue), ou corriger la roadmap.*
- **FastForwardManager + FastForwardDialog entièrement morts (~852 lignes)** — `fast_forward_manager.gd` (279 l.) + `fast_forward_dialog.gd` (573 l.) : toutes les références dans `main.gd:8,37,597` commentées. *Fix : supprimer (.gd + .uid + scènes) ou réintégrer.*
- **Couleurs ACCENT/DIM/GOLD dupliquées en littéraux dans 5 fenêtres** — `fenetre_national.gd:7`, `fenetre_esport.gd:8`, fenetre_social, fenetre_conseils : 4e source de palette en désaccord avec « UITheme = canonique ». *Fix : `const ACCENT := UITheme.ACCENT`, etc.*
- **`server_version.gd:4` `content_unlocked` émis mais jamais connecté** — déblocage serveur sans notif/refresh. *Fix : connecter à un toast/chat, ou retirer.*
- **Couplage `update_rankings()` jusqu'à 3× sur les semaines « mensuelles »** — `ai_guild_manager.gd:317` (rebuild complet + `sort_custom` à chaque appel). *Fix : passer par `_mark_ranking_dirty()` + recalcul unique.*

---

## Branchement & signaux — code orphelin / dormant

### (a) Signaux déclarés non connectés (émis ou non, sans abonné)
*Synthèse dédupliquée — ces signaux apparaissent dans `findings` (low) et dans `orphans`.*

| Signal | Emplacement | État |
|---|---|---|
| `advice_pushed` | `advisor_manager.gd:11` | émis (l.45), 0 connexion |
| `catchup_applied(gold)` | `balance_manager.gd:12` | émis (l.174), 0 connexion → aide en or invisible |
| `content_unlocked` | `server_version.gd:4` | émis (l.208,219), 0 connexion |
| `counter_offer_result` | `poaching_handler.gd:8` | déclaré, jamais émis ni connecté |
| `streamer_stopped` | `media_manager.gd:9` | déclaré (`@warning_ignore`), jamais émis |
| `sponsor_offer_available` | `sponsorship_manager.gd:9` | déclaré (`@warning_ignore`), jamais émis |
| `relationship_formed/changed/broken`, `clique_formed`, `social_conflict` | `social_dynamics.gd:4-8` | émis, 0 connexion (l'UI passe par GuildCultureManager) |
| `relationship_formed` (doublon) | `behavior_system.gd:7` | déclaré sur BehaviorSystem, jamais émis |
| `event_resolved`, `chain_started/continued/ended` | `event_manager.gd:25-28` | émis, 0 connexion (chaînes sans feedback UI) |
| `xp_gained`, `reputation_changed` | `guild.gd:15,18` | émis, 0 connexion (UI par polling) |
| `history_updated` | `notification_manager.gd:54` | émis, 0 connexion |
| `loot_conflict_occurred` (GuildManager) | `guild_manager.gd:16` | `@warning_ignore`, jamais émis côté GuildManager |
| `fast_forward_started/progress/completed/requested` | `fast_forward_manager.gd` | morts (fichier mort) |
| `phase_unlocked` | `phase_manager.gd:8` | émis (l.216), connexion non trouvée (orphelin probable) |

### (b) Fonctions publiques mortes (zéro appelant)
- `phase_manager.gd:233` `get_unlocked_features()` / `:238` `is_feature_unlocked()` — gating de features dormant (le gating réel se fait via `current_phase` direct).
- `phase_manager.gd:242`/`:196` `try_advance_phase`/`unlock_next_phase` — effectivement mortes en jeu normal pour les phases ≥1 (corollaire du #1).
- `simulated_player.gd:714` `get_effective_skill()` / `:508` `get_revealed_tags_count()` — logique de malus Phase 0 commentée → no-op.
- `simulated_player.gd:809-861` `get_modified_*`, `can_perform_action`, `get_available_actions` — zéro appelant externe.
- `guild.gd:175-188` `get_effective_max_members/recruitment_pool_bonus/raid_success_bonus/integration_bonus/reputation` ; `guild.gd:157-161` `get_modified_gold/xp` — morts.
- `guild.gd:281-340` `on_server_first`/`on_raid_success`/`on_raid_failure`/`on_drama_event`/`on_high_turnover_penalty` — morts (cf. #5).
- `behavior_system.gd:90,93` `should_connect_dynamic`/`should_disconnect_dynamic` — doublon de la logique vivante (commentaire l.522 admet « le moteur n'était pas branché »).
- `recruitment_pool.gd:316` `_refresh_pool` (appelé que par les tests), `:220` `_calculate_recruitment_difficulty` (alias).
- `staff_manager.gd:144` `has_role()` ; `drama_manager.gd:160` `_has_tag()` ; `advisor_manager.gd:220` `get_advice_counts()` ; `ai_guild_manager.gd:74` `_setup_simulation_timers()` (vide) ; `game_time.gd:113` `fast_forward_hours()` ; `personal_events.gd:230` `get_random_event()` / `:328` `detect_pattern()`.
- `window_manager.gd:226` `close_all_instances()` / `:175` `hide_window()` — vestiges du multi-fenêtres retiré ; tout le chemin multi-instance (`force_new`, z-order, `bring_to_front`) reste dormant alors que tous les `register_window` passent `allow_multiple=false`.
- `player_control_panel.gd:328` `show_reconnection_dialog()` — non appelée (repos via `main._run_accelerated_rest`).

### (c) Fichiers / features entièrement morts
- **`fast_forward_manager.gd` + `fast_forward_dialog.gd`** (~852 lignes) — instanciés nulle part, références `main.gd` commentées.
- **`scripts/ui/dialogs/`** (base/confirm/input/progress, ~57 KB) — doublon non utilisé de `components/confirm_dialog.gd` ; toutes les factories statiques mortes.
- **`fenetre_organisation_groupe.gd:653` `_simulate_dungeon_run()`** — référence l'API de l'ancien moteur `DungeonRun` supprimé (`instance_data`, `defeated_bosses`, `complete_run`, `simulate_boss_fight`, `loot_collected`, `can_continue`) ; crasherait si appelée.
- **`poaching_popup.gd`** (~438 lignes) — injoignable en pratique (son point d'entrée n'est jamais atteint sur le chemin de succès, cf. #4) ; ses signaux `member_released`/`counter_offer_made`/`poaching_ignored` et `AIGuildManager.simulate_counter_offer_response` sont morts par ricochet.
- **`scripts/ui/components/tooltip.gd`** (`class_name Tooltip`) — jamais instancié (les fenêtres utilisent `tooltip_text` natif).
- Système de **patterns détectables** (`personal_events.gd:328` + `RECURRING_PATTERNS`) — annoncé dans la roadmap, jamais déclenché.

### (d) État mort / non sérialisé
- `simulated_player.gd:43` `relationships` (@export) — jamais lu ni écrit ni sauvegardé (le graphe vit dans `SocialDynamics`).
- `simulated_player.gd:21` `tag_reveal_progress` — jamais incrémenté → le tag `drama_queen` (SPECIAL_EVENT) **ne peut jamais être révélé** (mécanique dormante) ; `player_tags.gd:239` `get_potential_reveals` ne gère que INTEGRATION/TIME.
- `simulated_player.gd:48` `recent_events_memory` — alimenté mais jamais lu ni sauvegardé.
- `guild_ranking.gd:46` `content_achievements` — déclaré, jamais écrit/lu/sauvegardé.
- `player_character.gd:370` `or_actuel` — incrémenté (double-comptage farming) + sauvegardé, mais **jamais lu** pour une décision gameplay ; deux sources de vérité d'or dont une inerte.
- `poaching_popup.gd:381` meta `raid_priority` — write-only.
- `activity.gd:18` `duration_minutes` (@export) — jamais lu (la durée passe par la meta `planned_duration`).

### (e) Orphelins **intentionnels** — à NE PAS supprimer
- **`scripts/systems/chat/chat_backend.gd`** : `generate_reaction()`/`is_available()` jamais appelés, **mais c'est un stub documenté volontaire** (header : « Ce fichier est un stub documenté : il n'est PAS branché ») préparant un backend LLM opt-in (Palier 3). Ne pas confondre avec du code mort à supprimer.
- **`scripts/utils/singletons.gd`** : vivant (~20 usages dans des Resources sans `get_node`). À conserver, documenter qu'il est réservé aux Resources.
- Connexions volontairement no-op pour « rétrocompat » : `guild_manager.gd:44` `_on_minute_changed` (`pass`), `activity_manager.gd:40-42` `_on_hour_changed` (`pass`), `phase_manager.gd:492` `_on_member_disconnected` (`pass`) — inertes mais à nettoyer plutôt qu'à garder.

> **Bonne nouvelle de cohésion globale** (note transverse vérifiée) : **aucun autoload n'est mort** — les 24 autoloads (hors MCP) sont tous référencés/branchés ailleurs que dans leur déclaration.

---

## Cohérence & design (vue d'ensemble)

- **Doubles sources de vérité** : (1) or → `Guild.gold` (réel) vs `PlayerCharacter.or_actuel` (inerte) ; (2) énergie joueur → `player_energy_pool` (pilote la déconnexion/UI) vs `energy` hérité (quasi inerte, mis à jour ×0.1) ; (3) palette de couleurs → `UITheme`/`UIConstants` censés canoniques, mais re-hardcodés dans 5 fenêtres + `BADGE_COLORS`/`TYPE_COLORS` (notification_toast, confirm_dialog, custom_progress_bar, stat_display) ; (4) poids de ranking dupliqués entre `BalanceManager.BALANCE` (miroir documentaire) et `GuildRanking.SCORE_WEIGHTS` (source réelle).
- **Boucles incomplètes** (synthèse) : réputation PvE (#5), effets/bonus de guilde (#6, #D), stats d'équipement (#D), `injured` (#7), contre-offre (#4), patterns comportementaux — toutes définissent un mécanisme dont la valeur n'est consommée par personne.
- **Drapeaux d'équilibrage** : `TOTAL_GUILDS=10` codé en dur (#C) ; `GUILD_COUNT_BY_PHASE` sans clé LEVELING (retombe sur 9 implicite) ; double pénalité de wipe (`dungeon_instance.gd:198` `pow(0.95, wipe_count)` + ponction mood/énergie qui re-alimente `member_score`) ; cap `gold_storage` additif (#C) ; conseil « Places à pourvoir » plafonné à `count < 20` (reliquat early-game) ; `_apply_stipend`/`_pay_staff_salaries` sans garde de phase.
- **Incohérences de style d'accès autoloads** : `ai_guild.gd` et `simulated_player.gd:754` mélangent `Singletons.get_autoload("X")` et l'accès global direct `X` (le second suffit) ; `simulated_player.gd:744` `_max_level = 60 if server_version else 60` est un no-op (devrait lire `ServerVersion.get_max_player_level()`).
- **Timers temps-réel vs temps de jeu** : `event_manager.gd:251` (délai de chaîne 5 s wall-clock) et `poaching_popup.gd:292` se comportent mal à haute vitesse, incohérents avec le pilotage par `GameTime` du reste.
- **Typage statique** : plusieurs fichiers (advisor_manager, window_manager, guild.gd:80) gardent des collections/variables non typées, contraires au mandat CLAUDE.md.

---

## Plan d'action priorisé

### P0 — Débloquer la jouabilité
1. **Corriger le soft-lock de progression de phase** — brancher `unlock_next_phase()` sur `phase_requirements_met` (bouton « Avancer » dans popup + onglet) ou faire avancer via `try_advance_phase()` dans le tick. `phase_manager.gd`, `fenetre_personnage.gd`, `confirm_dialog.gd:349`. **+ test E2E sans `force_phase_change`.**
2. **Corriger le crash drag&drop d'organisation** — `item.get_drag_data()` → `item.drag_data`. `fenetre_organisation_groupe.gd:418,434`.
3. **Corriger `Object.get()` à 2 arguments** — utiliser `set_meta`/`get_meta`. `activity_manager.gd:509,520`.
4. **Brancher la réputation PvE** — appeler `on_server_first`/`on_raid_success`/`on_raid_failure`. `guild.gd`, `dungeon_instance.gd`, `register_server_first`.

### P1 — Boucles incomplètes & branchement
1. **Débauchage / contre-offre** — émettre `poaching_attempt(true)` avant le retrait, déplacer le retrait dans le callback de la popup. `ai_guild_manager.gd:208`, `poaching_handler.gd`, `poaching_popup.gd`.
2. **Effets & bonus de guilde** — router les lectures combat/recrutement vers `get_effective_*`/`get_modified_*`. `guild.gd:175-188`, `simulated_player.gd:796`.
3. **Effet `injured`** — ajouter la branche `TargetType.PLAYER` dans `_apply_consequences` (`event_manager.gd:294`) **et** vérifier `can_perform_action` dans la composition de groupe.
4. **Garde `is_player`** dans la résolution de drama « exclusion » (`drama_manager.gd:126`) et en tête de `GuildManager.remove_member`.
5. **Save/load des états manquants** — `phase_progress` (merge non destructif), run en cours, `scheduled_absences`, `active_effects`, re-wiring de `fenetre_personnage` après load.
6. **`days_at_rank_1`** — séparer serveur/national, fenêtre glissante, reset au changement de phase.
7. **Signaux orphelins utiles** — connecter `content_unlocked`, `catchup_applied`, `reputation_changed`/`gold_changed` (ajouter `signal gold_changed` à `guild.gd`) à des toasts/refresh ; supprimer les signaux purement décoratifs.
8. **Phase 0 — modificateurs** — câbler `skill_malus`/`tag_reveal_rate`/`connection_bonus` ou retirer la config morte et corriger la roadmap.
9. **Chat** — `loot_epic` à `>= 3`, séparer `ninja` de `loot_dispute`. `chat_director.gd:566,591`.
10. **Armer `bonus_session_active`** dans le chemin vivant ; corriger la comparaison jour absolu/semaine (`behavior_system.gd:178,272`).

### P2 — Nettoyage & cohérence
1. **Supprimer le code mort** : `fast_forward_*` (~852 l.), `scripts/ui/dialogs/`, `_simulate_dungeon_run`, `tooltip.gd`, fonctions/signaux orphelins listés. **Préserver** `chat_backend.gd` (stub volontaire) et `singletons.gd`.
2. **Dédupliquer les sources de vérité** : retirer `or_actuel` (ou lui donner un rôle), aligner palette sur `UITheme`, trancher poids de ranking.
3. **Équilibrage** : `TOTAL_GUILDS` au runtime, cap `gold_storage` en `max`, clarifier la double pénalité de wipe, gardes de phase sur tournois/transferts/stipend/staff.
4. **Typage statique** : advisor_manager, window_manager, guild.gd selon le mandat CLAUDE.md.
5. **CI import** : conserver `godot --headless --import` avant `CheckScripts` ; envisager de retirer `continue-on-error: true` sur cette étape (un échec d'import casserait silencieusement le cache de classes).
6. **RNG** : appeler `randomize_rng()` au boot d'une partie, ou corriger la grille « RNG déterministe Oui/Oui » de la roadmap.
7. **Corriger la roadmap** : ramener les Milestones 3, 4 (et les modificateurs Phase 0, patterns, refresh « 3 jours », validation de schéma chat en CI) d'« 100 % jouable/validé » à un statut honnête tant que le soft-lock et les boucles incomplètes ne sont pas corrigés.

---

## Annexe — notes mineures (dédupliquées, ~30 puces)

**PvE / combat**
- `dungeon_instance.gd:71-72` : premier boss à `boss_positions[0]=0.0` → combat dès le premier update (cosmétique).
- `dungeon_instance.gd:230` : `expected_equipment = level_recommended*3` arbitraire ; `LootTables.get_recommended_ilvl_for_dungeon()` serait une meilleure source.
- Gating serveur ignoré : `fenetre_organisation_groupe.gd:215` liste tous les donjons/héroïques en ne verrouillant que par niveau (ServerVersion contourné) ; clears héroïques jamais comptés dans `content_cleared_percent` (`guild_ranking.gd:546`).

**Save / boot**
- Risque de collision d'`player_id` au boot (pool généré avant le load différé) — `save_manager.gd:337`.
- `game_time.gd:180` : défaut d'heure au chargement = 9 alors que l'état initial = 18 (incohérent).
- `main.gd:724` : fermer l'app pendant un repos accéléré persiste `time_speed: 2880`.
- `phase_progress` clés int↔String à normaliser ; `BehaviorProfile.serialize` omet `schedule_variance`/`reaction_patterns`/`social_preferences`.
- `RecruitmentPool` / `AdvisorManager` / `ChatDirector` non sérialisés (éphémères assumés — à confirmer comme choix de design).

**National / Esport**
- `media_manager.gd:29` : `_update_celebrity` avant `_update_streamers` → bonus de célébrité en retard d'une semaine au démarrage du stream.
- `media_manager.gd:168` : ré-appariement streamer par `nom` plutôt que `player_id` (risque homonymes).
- `media_manager.gd:9` : un membre devenu streamer ne le redevient jamais non-streamer.
- `transfer_manager.gd:78` : commission d'agent fixe, non renégociée si l'offre diffère de la demande.
- `staff_manager.gd:106` : départ de staff impayé via RNG global (à garder en tête pour le déterminisme des tests).
- `drama_manager.gd:104` : un drama de loot créé en phase Serveur est invisible (fenêtre National verrouillée) mais reste résoluble par popup.

**Tick / ordonnancement**
- Ordre d'abonnement PhaseManager (#32) avant GuildRanking (#33) → durée de rang lue avec 1 jour de retard (`phase_manager.gd:415`).
- Ranking non initialisé au boot → position = -1 tant qu'aucune semaine / ouverture Fenetre_Monde (`guild_ranking.gd:79`).
- Tournois/transferts tournent chaque semaine sans gate de phase (`tournament_manager.gd:35`, dès Phase 0).
- `game_time.gd:48` : `minute_changed` émis à chaque minute → forte charge à 2400× (atténuée par planchers/`% 5`).

**UI / propreté**
- `event_popup.gd` : ~7 `print()` non gardés (`OS.is_debug_build()`/`GameLog`) qui s'exécutent en release.
- `notification_manager.gd:63` : `print()` au lieu de `GameLog.d`.
- `fenetre_donjon.gd:49` : `ResizableWindow` vestigial (barre de titre fantôme, `close_requested` non connecté).
- `fenetre_monde.gd:417,432,452` : `# TODO` notifications jamais affichées (toasts disponibles) ; `:688` événements adverses « simulés » aléatoires ; `:273` TODO perks avec bonus fixe +5.
- `debug_menu.gd:93` : action « Donner équipement aux membres » est un `pass`/TODO.
- `advanced_tabs.gd:332` : chemin `draggable_tabs=true` latent et casserait `select_tab`/`remove_tab` s'il était activé (`create_closable_tabs` a 0 appelant).
- Composants UI sous-utilisés : `Badge`, `StatDisplay`, `DraggableItem`, `DropZone` exposent de nombreuses méthodes publiques jamais appelées ; `draggable_item.gd:163` calcule un `PhysicsPointQueryParameters2D` inutile.
- `social_dynamics.gd:614` : seuil de clique formation (≥3) ≠ désérialisation (≥2) → load peut recréer une clique de 2 impossible en jeu.
- `event_manager.gd:240` : `resolve_event` ne revalide pas `choice.requirements` (la garde n'existe qu'en UI) ; `add_gold` sans plancher à 0 (or peut devenir négatif).
- `main.gd:212` : `_on_player_recruited` re-appelle `add_member` alors que le recrutement est déjà atomique (garde inoffensive, à simplifier).
- Achievements en double : `phase_manager.gd:483/487` ré-ajoutent sans dédup à chaque level-up / recrutement (≥15).
- `phase_manager.gd:353` : défaut `media_reputation = 50.0` (sentinelle ≠ 0 des autres défauts, peut masquer une absence de système).
- `chat_director.gd:117` : `_process_blackboard` (réactif) s'exécute avant le test `is_paused` → répliques réactives possibles en pause (asymétrique avec le banter ambiant).
