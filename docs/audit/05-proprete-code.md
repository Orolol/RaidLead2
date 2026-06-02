## 5. Code — Propreté & Qualité

*Audit statique du dossier `scripts/**` — 93 fichiers `.gd`, ~31 700 lignes (Read/Grep/Glob uniquement, jeu non lancé). Périmètre Godot 4.6.2 / GDScript typé.*

### Synthèse de sévérité

| Sévérité | Nombre de constats | Nature |
|---|---|---|
| 🔴 Critique (bug latent) | ~10 | Ternaire incompatible, divisions entières, narrowing implicite |
| 🟠 Majeur (dette) | ~8 axes | Typage absent (collections + retours), `print()` en prod, duplication, code mort, magic numbers |
| 🟡 Mineur (cosmétique) | ~250 warnings | Paramètres/variables/signaux inutilisés, shadowing, préfixes |

Point notable : **aucun `@warning_ignore` n'est présent dans le projet** — les 273 warnings sont tous bruts, non supprimés. Il y a donc un vrai gisement de nettoyage, mais aussi l'opportunité de tout régler proprement plutôt que de masquer.

---

### 5.1 🔴 Bugs latents (à corriger en priorité)

Ces warnings cachent un comportement potentiellement faux, pas juste cosmétique.

| Fichier:ligne | Catégorie | Détail |
|---|---|---|
| `scripts/systems/guild_ranking.gd:414` | INCOMPATIBLE_TERNARY | `guild_name == GuildManager.guild.name if ... else ""` : précédence piégeuse — `==` lie plus fort que le ternaire, donc l'expression vaut un `bool` **ou** une `String` `""`. Le test « est-ce notre guilde ? » est faux dans un cas. À réécrire avec parenthèses explicites. |
| `scripts/systems/dungeon_instance.gd:448` | INTEGER_DIVISION | `int(gold_reward * 0.2) / member_count` : division int/int → troncature silencieuse de l'or par membre. |
| `scripts/ui/components/chat_panel.gd:224` | INTEGER_DIVISION | `int(int(total_time) / 60)` : double `int()` + division entière (ici probablement voulu, mais à expliciter). |
| `scripts/managers/window_manager.gd:446` | INTEGER_DIVISION | division entière sur calcul de layout. |
| `scripts/ui/windows/fenetre_personnage.gd:717` | INTEGER_DIVISION | idem (barre/segment). |
| `scripts/ui/components/player_control_panel.gd:251` | INTEGER_DIVISION | idem. |
| `scripts/ui/components/chat_panel.gd:149` (zone) | NARROWING_CONVERSION | conversion float→int implicite ; les conversions de couleur voisines (`int(color.r*255)`) sont déjà explicites, mais une affectation reste à typer/`float()`. |

**Recommandation** : ces ~10 lignes méritent une revue manuelle individuelle (et non un fix groupé), car certaines troncatures sont voulues (à confirmer par `@warning_ignore("integer_division")` documenté) et d'autres sont des bugs (le ternaire de `guild_ranking.gd:414` en est clairement un).

---

### 5.2 🟠 Typage statique (CLAUDE.md impose le typage systématique)

Le typage par **inférence** (`var x := ...`) est correct ; le problème est ailleurs.

| Mesure | Compte | Commentaire |
|---|---|---|
| `func ...(...)` **sans** `-> Type` | **757** sur 56 fichiers | inclut les virtuals (`_ready`, `_process`…) qui tolèrent l'absence, mais la majorité sont des fonctions métier non typées. À comparer aux 1194 fonctions **avec** retour typé : ~39 % des fonctions ne déclarent pas leur retour. |
| `var x =` (sans `:` ni `:=`) | **1785** sur 77 fichiers | beaucoup sont inférables (acceptable), mais le style `:=` (306 occurrences) est minoritaire → typage par inférence sous-utilisé. |
| **Collections non typées** `Array` / `Dictionary` sans `[T]` | **~431** sur 74 fichiers | c'est le vrai trou de typage : `Array` au lieu de `Array[Item]`, `Dictionary` partout. Empêche la vérification statique des éléments. |

**Fichiers les plus problématiques (retours non typés)** :
- `scripts/ui/windows/fenetre_personnage.gd` : 23 fonctions sans `-> Type`
- `scripts/managers/window_manager.gd` : 21
- `scripts/ui/windows/fenetre_monde.gd` : 34 (sur les plus gros fichiers)
- `scripts/resources/simulated_player.gd` : 16 (ex. `func _init():`, `func _generate_random_stats():` non typés)

**Collections non typées — pires fichiers** : `guild_ranking.gd` (35), `fenetre_monde.gd` (16), `save_manager.gd` (22), `social_dynamics.gd` (15), `guild_culture_manager.gd` (15), `advisor_manager.gd` (25).

> Exemple représentatif (`simulated_player.gd`) : `@export var tags_comportement: Array = []`, `@export var relationships: Dictionary = {}`, `@export var active_effects: Array = []` — tous devraient être `Array[String]`, `Dictionary` typé via convention, `Array[EffectInstance]`.

---

### 5.3 🟠 Nommage — incohérence FR/EN

Le projet mélange français et anglais **au sein du même objet**, ce qui est la dette la plus visible à la lecture.

Cas emblématique — `scripts/resources/simulated_player.gd` :
- **Français** : `nom`, `tags_comportement`, `tags_caches`, `personnage_classe`, `personnage_role`, `personnage_niveau`, `personnage_xp`, `or_actuel`, `connaissance_donjons`, `connaissance_raids`
- **Anglais** : `mood`, `skill`, `energy`, `integration`, `behavior_profile`, `relationships`, `fatigue_accumulated`, `burnout_level`, `circadian_type`, `stress_level`, `celebrity_level`, `salary_demand`

Le préfixe `personnage_*` (288 occurrences sur 30 fichiers) cohabite avec `character_*` ; `fenetre_*` (fichiers/classes) avec `window_*` (`WindowManager`, `window_name`). snake_case est globalement respecté pour variables/fonctions ; PascalCase respecté pour les 56 `class_name`. **Le problème n'est pas la casse mais le bilinguisme.** Une convention unique (FR pour le domaine métier *ou* EN partout) devrait être tranchée et appliquée — chantier non trivial car `nom`, `niveau`, `or_actuel` sont lus dans 34 fichiers (183 accès).

---

### 5.4 🟠 `print()` résiduels en production

Un `GameLog.d()` (gardé par `OS.is_debug_build()`) existe dans `scripts/utils/game_log.gd`, mais **~28 `print()` ne sont pas gardés** et s'exécuteront dans le build release.

| Fichier | `print()` non gardés | Lignes |
|---|---|---|
| `scripts/ui/windows/event_popup.gd` | 7 | 32, 34, 37, 45, 48, 54, 226 (logs de debug pur : « show_event appelé », « Centrage de la popup ») |
| `scripts/systems/fast_forward_manager.gd` | 5 | 20, 76, 156, 165, 183 |
| `scripts/ui/windows/fast_forward_dialog.gd` | 4 | 328, 448, 525, 540 |
| `scripts/resources/player_character.gd` | 3 non gardés | 201, 263, 348 (les autres lignes sont déjà sous `if OS.is_debug_build()`) |
| `scripts/ui/windows/fenetre_organisation_groupe.gd` | 3 | 724, 727, 730 (**dans du code mort**, cf. 5.6) |
| `scripts/managers/notification_manager.gd` | 1 | 62 (« NotificationManager initialized ») |
| `scripts/resources/random_event.gd` | 1 | 98 |
| `scripts/ui/windows/poaching_popup.gd` | 1 | 384 |
| `scripts/ui/windows/fenetre_guilde.gd` | 1 | 657 |
| `scripts/ui/components/time_display.gd` | 1 | 92 |

À noter : `printerr`/`push_error`/`push_warning` (7 occurrences dans `window_manager.gd` et `save_manager.gd`) sont légitimes (ce sont des erreurs réelles, OK en release). Le correctif type : remplacer chaque `print(...)` par `GameLog.d(...)`, comme déjà fait pour les 132 prints de boucle migrés (cf. RoadmapComplet).

---

### 5.5 🟠 Duplication — candidats à factorisation

Cas concrets repérés (haute confiance) :

1. **Helper `_kv(box, key, value, color)` dupliqué quasi à l'identique** dans 3 fenêtres : `fenetre_conseils.gd:140`, `fenetre_esport.gd:160`, `fenetre_social.gd:143`. Seul l'écart : `custom_minimum_size` à 220 vs 200 px. Plus la variante `_add_stat_row()` (`fenetre_monde.gd:1113`) qui fait la même chose en `GridContainer`. → extraire un `UIHelpers.kv_row(...)` partagé.
2. **Mapping valeur→couleur (seuils)** réimplémenté plusieurs fois : `custom_progress_bar.gd:99 _get_color_for_progress()`, `stat_display.gd:349 _get_color_for_percentage()`, `advisor_manager.gd:217 get_severity_color()`. Logique « <33 % rouge / <66 % orange / sinon vert » dispersée (222 manipulations de couleur sur 29 fichiers UI). → centraliser dans `UITheme` (déjà palette canonique) un `color_for_ratio(value)`.
3. **Conversion `Color → hex string`** copiée verbatim : `chat_panel.gd:127` et `chat_panel.gd:282` (`"#%02x%02x%02x" % [int(color.r*255), ...]`). → helper unique.
4. **Construction de fiches membres** : `_update_member_details()` (`fenetre_guilde.gd:216`, **174 lignes**) et `_member_row()` (`fenetre_conseils.gd:401`) recomposent les mêmes blocs niveau/classe/skill/mood. Candidat à un composant `MemberCard` réutilisable.
5. **Préludes `preload` redondants** (cf. 5.7) : les mêmes `const X = preload(...)` de classes globales sont répétés dans `main.gd`, `events_data.gd`, `event_manager.gd`, `event_popup.gd`, `random_event.gd`.

---

### 5.6 🟠 Code mort

**8 fonctions privées définies mais jamais référencées** (aucun appel, ni direct ni par signal/`call_deferred` — vérifié par recherche globale) :

| Fonction | Fichier:ligne |
|---|---|
| `_simulate_dungeon_run()` | `fenetre_organisation_groupe.gd:672` |
| `_on_run_completed()` | `fenetre_organisation_groupe.gd:726` |
| `_on_player_wiped()` | `fenetre_organisation_groupe.gd:729` |
| `_setup_simulation_timers()` | `ai_guild_manager.gd:71` |
| `_set_displayed_value()` | `custom_progress_bar.gd:239` |
| `_get_instance_id()` | `window_manager.gd:328` |
| `_has_tag()` | `drama_manager.gd:160` |
| `_on_abandon_button_pressed()` | `fenetre_donjon.gd:291` |

> Les 3 fonctions de `fenetre_organisation_groupe.gd` (672/726/729) sont des reliquats du flux PvE refondu : elles contiennent en plus les `print()` non gardés du §5.4. Suppression = double gain.

**Variables mortes (UNUSED_VARIABLE)** confirmées par lecture :
- `simulated_player.gd:98` : `var max_level = 60` assignée (l.98+100) mais jamais lue.
- `ai_guild.gd:103` : `var config = STRATEGY_CONFIG[...]` non utilisée dans `_generate_initial_members`.
- `dungeon_instance.gd:187` : `boss_name` calculé puis ignoré.
- + `ai_guild.gd:307,439`, `window_manager.gd:266`, `draggable_item.gd:165`, `fenetre_personnage.gd:611` (listés par l'éditeur).

**Commentaires `# TODO`** (7, tous réels, aucun `FIXME`/`HACK`) : `main.gd:289`, `fenetre_monde.gd:326, 779, 780, 861, 876`, `poaching_popup.gd:366`. Petite dette fonctionnelle (perks de guilde non implémentés, notifications à brancher). Code commenté laissé en place : `main.gd:9` (`# const FastForwardDialog = preload(...)  # Supprimé`).

---

### 5.7 🟠 Magic numbers

Une façade `BalanceManager.BALANCE` + `tunable()/tunable_float()` existe **mais n'est adoptée que dans 4 fichiers** (9 appels : `balance_manager.gd`, `recruitment_pool.gd`, `dungeon_instance.gd`, `guild_manager.gd`). Partout ailleurs, les constantes de tuning sont en dur.

**~617 littéraux flottants `0.x` en dur** dans `systems/` (385) + `resources/` (232). Pires concentrations :
- `behavior_system.gd` : 75 — seuils de connexion/fatigue/influence sociale
- `ai_guild.gd` : 61 — probabilités de stratégie
- `simulated_player.gd` : 59 — gains/malus de stats
- `dungeon_instance.gd` : 44 (dont de bonnes constantes nommées : `WIPE_TIME_PENALTY`, `MORALE_LOSS_PER_WIPE` — modèle à généraliser)
- `social_dynamics.gd` : 38, `guild_culture_manager.gd` : 29, `tournament_manager.gd` : 19, `media_manager.gd` : 21

Beaucoup sont légitimes (0.5 d'un milieu, etc.), mais les seuils de gameplay (probabilités, multiplicateurs, paliers de moral/stress) devraient migrer vers `BalanceManager.BALANCE` ou des `const` nommées par fichier, sur le modèle déjà présent dans `dungeon_instance.gd`.

---

### 5.8 🟠 Fonctions trop longues (> 60 lignes)

**39 fonctions dépassent 60 lignes**, dont 3 dépassent 100. Les pires :

| Lignes | Fonction |
|---|---|
| 174 | `fenetre_guilde.gd:216 _update_member_details()` |
| 105 | `main.gd:253 _on_debug_menu_pressed()` |
| 101 | `fenetre_personnage.gd:484 _update_requirements_display()` |
| 100 | `main.gd:951 _show_activity_prompt()` |
| 95 | `fenetre_loot.gd:54`, `activity_manager.gd:185 (assignation d'activité)` |
| 94 | `fenetre_monde.gd:979 _display_guild_details()`, `fenetre_loot.gd:149` |
| 91 | `fenetre_personnage.gd:118 _setup_character_info_tab()` |

Concentration sur les fenêtres UI (`fenetre_personnage` à elle seule : 5 fonctions > 80 lignes). Ces fonctions mêlent construction de nodes + logique métier + mise en forme → candidates à découpage (extraire les sous-blocs de construction UI, cf. composant `MemberCard` du §5.5).

---

### 5.9 🟡 Tableau récap des 273 warnings par catégorie

Estimations par heuristique grep (les totaux exacts proviennent de l'éditeur Godot).

| Catégorie | Estimé | Sévérité | Effort de résolution | Méthode de fix groupé |
|---|---|---|---|---|
| UNUSED_PARAMETER | ~110 | 🟡 | Faible (mécanique) | Préfixer `_` les params de callbacks signaux (`_day`, `_week`…). Le gros du volume : `_on_*_changed`, `_on_*` dans `phase_manager`, `ai_guild_manager`, `guild_ranking`, `chat_panel`, `event_manager`. |
| UNUSED_VARIABLE | ~25 | 🟠 (peut cacher du mort) | Faible | Supprimer la variable, ou l'utiliser si oubli (ex. `max_level`). Revue manuelle rapide. |
| SHADOWED_GLOBAL_IDENTIFIER | 13 | 🟡 | Très faible | **Supprimer** les `const X = preload(...)` quand `X` est déjà un `class_name` global (AIGuild, LootTables, EventChoiceResource, RandomEventResource, EventPopupWindow). Le code marche déjà via le global. |
| SHADOWED_VARIABLE_BASE_CLASS | ~10 | 🟡 | Faible | Renommer les locales `name`/`show`/`notification`/`global_position` (ex. `member_name`) dans `social_dynamics.gd:207`, `window_manager.gd:411,587`, `advanced_tabs.gd:108,125`, `stat_display.gd:217`, `fenetre_personnage.gd:609,750`. |
| UNUSED_SIGNAL | ~8 | 🟡 | Faible | Soit brancher le signal, soit le supprimer : `notification_manager.gd:53 history_updated`, `media_manager.gd:7 streamer_stopped`, `sponsorship_manager.gd:7 sponsor_offer_available`, `guild_manager.gd:14 loot_conflict_occurred`, `behavior_system.gd:7 relationship_formed`, `poaching_handler.gd:8 counter_offer_result`. |
| INTEGER_DIVISION | 5 | 🔴 (revue cas par cas) | Moyen | `float()` explicite si fractionnaire voulu, sinon `@warning_ignore("integer_division")` documenté. `dungeon_instance.gd:448`, `window_manager.gd:446`, `chat_panel.gd:222`, `fenetre_personnage.gd:717`, `player_control_panel.gd:251`. |
| NARROWING_CONVERSION | ~1 | 🔴 | Faible | `int(...)`/`float(...)` explicite. `chat_panel.gd:149`. |
| CONFUSABLE_LOCAL_DECLARATION | ~1 | 🟡 | Faible | Renommer le 2e `var toast` (`notification_manager.gd:233` vs `238`). |
| INCOMPATIBLE_TERNARY | 1 | 🔴 (bug) | Faible mais **logique** | Parenthéser le ternaire `guild_ranking.gd:414`. À tester. |
| **Total approximatif** | **~273** | | | |

La très grande majorité (≈ 85 %) sont des warnings cosmétiques réglables par opérations mécaniques par catégorie ; seuls ~10 demandent une revue de logique.

---

### Plan de nettoyage en 5 étapes

1. **Sécuriser les bugs latents (🔴) d'abord** — corriger `guild_ranking.gd:414` (ternaire), trancher chaque INTEGER_DIVISION et le NARROWING_CONVERSION (`float()` explicite vs `@warning_ignore` documenté). ~10 lignes, revue manuelle, à valider par les tests existants (`tests/`).
2. **Purger le code mort** — supprimer les 8 fonctions privées orphelines (dont les 3 de `fenetre_organisation_groupe.gd` qui portent aussi des `print()`), les ~25 variables mortes (`max_level`, `config`, `boss_name`…) et le `preload` commenté. Gain immédiat sur le compteur UNUSED_VARIABLE.
3. **Résoudre les warnings cosmétiques par lots mécaniques** — (a) préfixer `_` les ~110 paramètres de callbacks ; (b) supprimer les 13 `const = preload` de classes globales (SHADOWED_GLOBAL) ; (c) renommer les ~10 locales shadowant la classe de base ; (d) brancher ou supprimer les 8 UNUSED_SIGNAL. Objectif : passer de 273 à < 20 warnings.
4. **Boucler le typage** — typer les ~431 collections (`Array[T]`/`Dictionary`) et ajouter les `-> Type` manquants sur les fonctions métier (prioriser `fenetre_monde.gd`, `fenetre_personnage.gd`, `window_manager.gd`, `simulated_player.gd`). Conforme au mandat CLAUDE.md ; améliore la détection statique.
5. **Réduire la dette structurelle** — (a) factoriser les helpers dupliqués (`_kv`, color-for-value, Color→hex, fiches membres) dans `UITheme`/un `UIHelpers` ; (b) découper les fonctions > 100 lignes ; (c) migrer les magic numbers de gameplay vers `BalanceManager.BALANCE` (élargir l'adoption de la façade existante au-delà des 4 fichiers actuels) ; (d) décider et appliquer une convention de nommage unique FR **ou** EN (chantier le plus lourd, à planifier seul).
