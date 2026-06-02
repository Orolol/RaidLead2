## 4. Code — Architecture & Autoloads

*Audit statique (Read/Grep/Glob, jeu non lancé). Godot 4.6.2 / GDScript.
Périmètre : 23 autoloads projet (+3 MCP), `singletons.gd`, `save_manager.gd`,
`main.gd`, `project.godot`.*

### 4.0 Vue d'ensemble

L'architecture repose sur un **bus d'autoloads** : 23 singletons-nœuds enregistrés
dans `project.godot` (l.25-50), pilotés par les signaux temporels de `GameTime`
(`minute_changed`/`hour_changed`/`day_changed`/`week_changed`/`year_changed`).
La quasi-totalité des systèmes s'abonnent à `GameTime.week_changed` dans leur
`_ready()` et exécutent leur logique de tick là. `main.gd` (la scène racine) joue
le rôle de **façade UI + câblage de tous les signaux jeu→UI**.

Le couplage est **majoritairement par appels directs** (`GuildManager.guild_members`,
`PhaseManager.get_current_phase()`...) et secondairement par signaux. C'est un modèle
cohérent et lisible, mais le **couplage entrant sur `GuildManager` et `GameTime` est
extrême** (hubs), et quelques zones (god objects `main`/`fenetre_monde`, résolveur
`singletons.gd` redondant, save monolithique) constituent la dette structurelle.

Aucune dépendance circulaire de **scènes**. En revanche le graphe **autoload→autoload**
contient des cycles fonctionnels (ex. `GuildRanking ↔ PhaseManager`, `GuildRanking ↔ AIGuildManager`)
résolus en pratique par `if X:` + `call_deferred` — fragile mais fonctionnel.

---

### 4.1 Graphe de couplage autoload → autoload 🟠

Comptage des références sortantes (grep des identifiants globaux dans chaque autoload).
Lecture : `A → B (n)` = A référence B n fois.

| Autoload (ordre) | Dépend de (sortant) |
|---|---|
| `GameTime` (25) | *(aucun)* — **racine du graphe** ✅ |
| `ServerVersion` (26) | GameTime(15) |
| `EffectSystem` (27) | GameTime(2) |
| `ActivityManager` (28) | GuildManager(7), GameTime(1) |
| `GuildManager` (29) | GameTime(4), ServerVersion(3), ActivityManager(2), AIGuildManager(2), BalanceManager(2), NotificationManager(1) |
| `RecruitmentPool` (30) | GuildManager(11), ServerVersion(5), BalanceManager(4), PhaseManager(3), TransferManager(1), GameTime(1) |
| `EventManager` (31) | GameTime(7), GuildManager(3), EffectSystem(1) |
| `PhaseManager` (32) | GuildManager(15), GuildRanking(11), GameTime(7), TournamentManager(6), NotificationManager(6), StaffManager(5), MediaManager(3), DramaManager(3), SponsorshipManager(2) |
| `GuildRanking` (33) | GuildManager(30), PhaseManager(20), GameTime(15), AIGuildManager(8), ActivityManager(2) |
| `AIGuildManager` (34) | PhaseManager(10), GameTime(7), GuildRanking(5), GuildManager(5) |
| `MediaManager` (35) | GuildManager(13), PhaseManager(3), GameTime(2) |
| `SponsorshipManager` (36) | GuildManager(10), MediaManager(4), PhaseManager(3), GameTime(2) |
| `DramaManager` (37) | GuildManager(14), MediaManager(4), GameTime(4), SponsorshipManager(3), PhaseManager(3) |
| `StaffManager` (38) | GuildManager(9), PhaseManager(3), GameTime(3), NotificationManager(1) |
| `TournamentManager` (39) | GuildManager(11), StaffManager(4), PhaseManager(3), GameTime(3), NotificationManager(1) |
| `TransferManager` (40) | GameTime(7), GuildManager(6) |
| `LegacyManager` (41) | PhaseManager(4), TournamentManager(3), GameTime(3), NotificationManager(2) |
| `NotificationManager` (42) | PhaseManager(5), RecruitmentPool(2), GuildManager(2), EventManager(2), ActivityManager(2) |
| `SaveManager` (43) | **TOUS** (façade de sérialisation, ~20 systèmes) |
| `AssetLoader` (44) | *(aucun)* ✅ |
| `GuildCultureManager` (48) | GuildManager(23), GameTime(3) |
| `AdvisorManager` (49) | GuildManager(13), PhaseManager(12), GuildRanking(3), GameTime(3), RecruitmentPool(2), GuildCultureManager(2), NotificationManager(1) |
| `BalanceManager` (50) | GuildManager(10), GuildRanking(4), GameTime(3), GuildCultureManager(2), RecruitmentPool(1) |

**Hubs (couplage entrant massif)** :
- `GameTime` : source de vérité temporelle, dépendance entrante de ~tous. Sain (root, zéro sortant).
- `GuildManager` : ~**180 références entrantes**. C'est le **god-hub de données** (membres, guilde, banque, loot). Tout le monde lit `GuildManager.guild_members` et `GuildManager.guild`. Refactor difficile mais c'est le point de fragilité n°1.
- `PhaseManager` : hub de **gating** (quelle phase → quelle mécanique active). Sain en lecture, mais voir cycles.

**Cycles fonctionnels** (pas des cycles de *types*, donc pas de crash de compile, mais couplage bidirectionnel) :
- `GuildRanking (33) ↔ PhaseManager (32)` : GuildRanking lit PhaseManager(20×) **et** PhaseManager lit GuildRanking(11×). 🟠
- `GuildRanking (33) ↔ AIGuildManager (34)` : mutuel. 🟠
- `MediaManager ↔ SponsorshipManager ↔ DramaManager` : chaîne National couplée (sponsors lit médias, dramas lit médias+sponsors).

#### Risques d'ordre d'initialisation 🔴/🟠

L'ordre des autoloads est l'ordre de `project.godot`. Plusieurs `_ready()` lisent un
autre autoload — **OK seulement si le dépendu est déclaré avant**. Constats :

- 🟠 **`GuildRanking._ready()` lit `GuildManager.guild`** (`guild_ranking.gd:80`). GuildManager(29) < GuildRanking(33) → **OK**. Mais c'est implicite et non documenté ; déplacer GuildRanking au-dessus de GuildManager casserait l'init silencieusement.
- 🟠 **`AIGuildManager._ready()` émet `ai_guild_created`** (`ai_guild_manager.gd:92`) ; `GuildRanking._ready()` (#33, **avant** #34) connecte ce signal (`guild_ranking.gd:66`). L'ordre garantit que l'abonné existe avant l'émission → **OK par chance d'ordre**. Inverser les deux casserait l'enregistrement des guildes IA dans le classement sans erreur visible. **Aucun test ne couvre cet invariant d'ordre.**
- 🟠 **`AIGuildManager._initialize_guilds_for_current_phase()` lit `PhaseManager.get_current_phase()`** au `_ready` (#32 < #34) → OK, mais fallback fautif : `phase_manager.gd` n'a pas de souci, en revanche `ai_guild_manager.gd:78` écrit `PhaseManager.get_current_phase() if PhaseManager else PhaseManager.GamePhase.SERVEUR` — la branche `else` **déréférence `PhaseManager` quand il est falsy** (incohérent ; inoffensif car PhaseManager existe toujours, mais c'est un bug latent).
- 🟡 **`NotificationManager` est #42** mais des autoloads plus précoces appellent `NotificationManager.show_*` *au runtime* (pas au `_ready`), donc pas de problème d'init. Son `_setup_notification_container()` ajoute au root via `call_deferred` (`notification_manager.gd:73`) — robuste.
- 🟢 **`SaveManager._ready()`** diffère son câblage via `call_deferred("_setup_autosave")` (`save_manager.gd:27`) précisément pour ne pas dépendre de l'ordre → **bon pattern**, à généraliser.

> **Recommandation transverse** : les `_ready()` qui lisent un autre autoload devraient
> soit utiliser `call_deferred` (comme SaveManager), soit un signal `ready`/init explicite.
> Documenter dans `project.godot` (commentaire) la contrainte d'ordre : `GameTime` en
> premier, puis `GuildManager`, puis les systèmes consommateurs.

---

### 4.2 God objects 🟠

| Fichier | Lignes | Verdict |
|---|---|---|
| `scripts/main.gd` | **1078** | 🟠 God object UI. Mélange : thème, background, menus, fenêtres, raccourcis, **3 systèmes de popups modaux ad hoc** (loot l.470-566, drama l.613-709, prompt d'oisiveté l.951-1049 construits node par node en code), boucle de repos joueur (l.844-909), file d'attente d'événements. |
| `scripts/ui/windows/fenetre_monde.gd` | **1204** | 🟠 Le plus gros fichier du projet. Classement serveur/national/mondial + pool de recrutement + recrutement national (offres/agents/scouting). 3-4 responsabilités. |
| `scripts/ui/windows/fenetre_personnage.gd` | 971 | 🟡 Infos joueur + onglet progression de phase + historique PvE. |
| `scripts/ui/windows/fenetre_organisation_groupe.gd` | 827 | 🟡 Compo de groupe + drag&drop + aperçu de run. |
| `scripts/autoloads/guild_manager.gd` | 454 | 🟢 Acceptable en taille, **mais god-hub par couplage entrant** (voir 4.1). |

**`main.gd`** : la dette n'est pas la taille brute mais les **3 popups construits à la
main** (loot/drama/idle). Chacun fait ~80-100 lignes de `Label.new()`/`Button.new()` +
gestion de pause + file d'attente. Le projet possède déjà `BaseDialog`/`ConfirmDialog`
(`scripts/ui/dialogs/`) **non réutilisés ici**.
→ **Refactor** : extraire `LootConflictDialog`, `DramaDialog`, `IdlePromptOverlay` comme
scènes/composants dédiés héritant de `BaseDialog`. Gain estimé : −300 lignes dans `main.gd`,
suppression du triple état `_loot_dialog_active`/`_drama_popup_active`/`event_popup` au profit
d'un petit `ModalQueue`.

**`fenetre_monde.gd`** : séparer « affichage classements » et « recrutement » en deux
onglets/scripts (`fenetre_monde_classement.gd` + `fenetre_recrutement.gd`), la fenêtre n'étant
qu'un `TabContainer` hôte.

---

### 4.3 `singletons.gd` — résolveur dynamique 🟡

```gdscript
static func get_autoload(autoload_name: String):
    var loop = Engine.get_main_loop()
    if loop is SceneTree:
        return (loop as SceneTree).root.get_node_or_null("/root/" + autoload_name)
    return null
```

**Rôle légitime** : un `Resource` (SimulatedPlayer, Guild, Effect...) n'est pas dans
l'arbre, n'a pas `get_node()`, et ne peut donc pas atteindre un **autoload-nœud**
proprement. Le résolveur passe par `Engine.get_main_loop()` → c'est **justifié pour les
Resources**.

**Problèmes** :
- 🟡 **Double porte d'accès / confusion**. Dans `simulated_player.gd:549-552`, le code fait `Singletons.get_autoload("GuildManager")` *puis* `if not guild_manager: guild_manager = GuildManager` (le **fallback global fait exactement la même chose** — le nom d'autoload est résolvable en identifiant global même depuis une Resource). Résultat : deux façons d'obtenir le même objet, dans la même fonction. À choisir **une** convention.
- 🟡 **Coût/typage** : `get_autoload` retourne `Variant` (non typé), perte d'autocomplétion et de vérification statique, à l'opposé du « typage systématique » de CLAUDE.md.
- 🟡 **Usage hétérogène** : `guild.gd` l'utilise 5×, `simulated_player.gd` 8×, `ai_guild.gd`/`player_character.gd` l'utilisent **sans même importer le const** (l.0 — ils s'appuient donc sur autre chose, à vérifier ; possible bug de portée). Les **managers/systems** (dans l'arbre) ne devraient **jamais** l'utiliser : ils ont les globals.

**Convention proposée** :
- **Resources** → un seul helper. Garder `Singletons.get_autoload(...)` **uniquement** ici, et **supprimer les fallbacks globaux redondants**. Typer le retour des call sites localement (`var gm := Singletons.get_autoload("GuildManager") as Node`).
- **Nodes (managers/systems/UI)** → identifiants globaux d'autoload **exclusivement** (déjà majoritaire). Bannir `get_autoload` ici.
- Renommer le const importé en `AutoloadRef` partout pour signaler l'intention.

---

### 4.4 `SaveManager` — robustesse & couplage 🟠

**Points forts** ✅ :
- Versioning explicite (`CURRENT_SAVE_VERSION = 3`) + **registre de migrations séquentielles** `_build_migrations()` (l.153) propre et extensible.
- **Backup avant écrasement** (`_backup_existing_save` l.97) + **repli automatique sur backup** si la save principale est illisible (`load_game` l.111-121). Très bon filet de sécurité.
- Garde « save plus récente que le build » (l.167) → chargement best-effort au lieu de crash.
- Tolérance aux blocs manquants : tout `_apply_save_data` est gardé par `if data.has(...)`.
- Ordre de désérialisation **conscient des dépendances** (commentaires l.222, l.242 : médias/social *après* les membres).

**Faiblesses** 🟠 :
- 🟠 **Schéma de save éparpillé / couplage fort à tous les systèmes**. `save_game()` (l.56-78) liste en dur ~20 blocs ; ajouter un système = toucher 3 endroits (`save_game`, `_apply_save_data`, **et** `_DICT_SYSTEM_BLOCKS` l.15 pour la migration). Aucune source unique de vérité du schéma. **Fragilité** : oublier `_DICT_SYSTEM_BLOCKS` casse la migration des vieilles saves pour ce système, silencieusement.
  → **Refactor réaliste** : table déclarative `SAVE_REGISTRY := [{key, autoload, save_fn, load_fn, kind}]` itérée par `save_game`/`_apply_save_data`/migration. Un seul endroit à modifier.
- 🟠 **Sérialisation des membres entièrement manuelle** (`_serialize_player` l.344-397 : ~45 champs recopiés à la main). Tout champ ajouté à `SimulatedPlayer` et oublié ici **n'est pas sauvegardé** → bug silencieux. Le mix `set_meta`/propriétés (salary/is_national/region via meta, le reste en propriétés) **double** le risque d'oubli. Envisager un `to_save_dict()`/`from_save_dict()` **porté par `SimulatedPlayer`** (la Resource connaît ses champs), SaveManager ne faisant qu'orchestrer.
- 🟡 **Le graphe social transite par un chemin profond** : `GuildManager.behavior_system.social_dynamics` (`save_manager.gd:261`). Si `behavior_system` n'est pas encore créé (il l'est dans `GuildManager._ready` via `_init_behavior_system`), `_serialize_social` retourne `{}` silencieusement. Couplage à une structure interne de GuildManager.
- 🟡 **Pas de checksum / validation sémantique** post-chargement (ex. au moins 1 membre joueur). Une save syntaxiquement valide mais incohérente passe.

---

### 4.5 Signaux — câblage & signaux morts 🟠

**Câblage** : globalement **centralisé dans `main.gd`** pour le jeu→UI (`_connect_event_system`,
`_connect_national_systems`, `_connect_esport_systems`, `_connect_culture_systems`,
`_connect_player_systems`), ce qui est **bon** (un seul endroit pour comprendre les flux UI).
Les abonnements **système→système** sont, eux, dispersés dans chaque `_ready()`.

**Signal mort (émis sans écouteur / écouteur sans émetteur)** 🔴/🟠 :
- 🔴 **`member_left` n'existe pas sur `GuildManager`**. `notification_manager.gd:91-92` fait `if guild_manager.has_signal("member_left"): ... .connect(_on_member_left)` et définit `_on_member_left` (l.404) — mais **aucun `signal member_left` n'est déclaré** et **rien ne l'émet**. Le `has_signal` rend ça silencieux : **la notification de départ de membre ne se déclenche jamais**. Soit déclarer+émettre le signal (le départ existe via `remove_member`), soit supprimer le handler mort. *Fonctionnalité morte, pas un crash — mais trompeur.*
- 🟡 `guild_perk_unlocked`, `bank_changed`, `member_connected`/`member_disconnected` : émis ; vérifier la présence d'au moins un abonné UI (hors périmètre, à auditer côté UI).

**Risque de fuite de connexion** 🟡 :
- Sur ~86 `.connect()` dans managers/systems/autoloads, **la majorité n'a pas de garde `is_connected`**. C'est **acceptable** car les autoloads ne re-`_ready()` qu'au **hot-reload éditeur** (cf. CLAUDE.md « `_ready()` n'est pas rappelé lors d'un hot reload » — donc pas de double-connexion en prod). Les endroits qui *gardent* (`save_manager`, `phase_notifications` dans main, `poaching_handler`) le font pour des reconnexions différées. **Incohérence mineure**, pas un bug.
- 🟡 Les popups de `main.gd` connectent des lambdas à des boutons créés à la volée puis `queue_free()` le dialog : pas de fuite (le nœud meurt), mais pattern verbeux.

---

### 4.6 `class_name` vs autoload — SHADOWED_GLOBAL_IDENTIFIER 🟠

Plusieurs fichiers déclarent `const X = preload(...)` alors qu'un `class_name X` existe
déjà globalement → **le const masque le global** (warning `SHADOWED_GLOBAL_IDENTIFIER`,
et risque de confusion : deux `X` selon le fichier). Recensement :

| Identifiant masqué (`class_name` source) | Fichiers qui le re-`preload` en const |
|---|---|
| **`AIGuild`** (`resources/ai_guild.gd`) | `guild_manager.gd:4`, `guild_ranking.gd:6` |
| **`RandomEventResource`** (`resources/random_event.gd`) | `main.gd:5`, `event_manager.gd:6`, `event_popup.gd:4`, `events_data.gd:6` |
| **`EventChoiceResource`** (`resources/event_choice.gd`) | `main.gd:6`, `event_manager.gd:7`, `event_popup.gd:5`, `events_data.gd:7`, `random_event.gd:5` |
| **`LootTables`** (`data/loot_tables.gd`) | `dungeon_instance.gd:5` |
| **`DropZone`** (`components/drop_zone.gd`) | `fenetre_organisation_groupe.gd:7` |
| **`DraggableItem`** (`components/draggable_item.gd`) | `fenetre_organisation_groupe.gd:6` |
| **`EventPopupWindow`** (`windows/event_popup.gd`) | `main.gd:7` (alias local OK mais redondant) |

> Note : `WindowManagerScript`/`MenuBarScript`/`PlayerCharacterScript` etc. utilisent un
> **suffixe `Script`** → pas de shadowing (bonne convention déjà appliquée par endroits).

**Convention proposée (à généraliser)** :
1. Si un type a un `class_name`, **l'utiliser directement** (`AIGuild.new()`), **supprimer le const preload**. C'est la voie idiomatique Godot 4 — le `class_name` est déjà un preload global.
2. Si un alias local est vraiment souhaité (lisibilité/portée), **le suffixer `Script`** (`AIGuildScript`) pour ne jamais masquer le global.
3. Bannir `const X = preload(".../x.gd")` quand `x.gd` déclare `class_name X`.

Impact : **purement cosmétique/dette** (le code marche car le const pointe sur le même
fichier), mais ces warnings polluent la sortie et masquent de vrais warnings.

---

### 4.7 Découplage — signaux vs appels directs 🟠

Le projet privilégie les **appels directs cross-système** (`MediaManager.get_total_audience()`,
`GuildManager.guild.add_gold(...)`, `StaffManager.get_role_bonus(...)`). C'est **lisible**
mais crée un **couplage fort** : les systèmes National/Esport lisent/écrivent directement
`GuildManager.guild.gold` et `GuildManager.guild_members`.

- 🟠 **Écritures concurrentes sur `guild.gold`** depuis ≥5 systèmes (`media`, `sponsors`, `staff`, `tournament`, `transfer`, `guild_manager._pay_salaries`) tous sur `week_changed`, **sans ordre garanti entre eux** (ordre = ordre des autoloads). Un budget négatif transitoire est possible selon qui tick en premier. → Centraliser les mouvements d'or via une API `Guild.add_gold/spend_gold` (déjà existante) **et** un `EconomyManager` qui ordonne les flux hebdo, ou au minimum documenter l'ordre.
- 🟢 Le flux **jeu→UI** est bien découplé par signaux (events, dramas, sponsors, tournois, cohésion) — c'est le bon endroit pour les signaux et c'est bien fait.
- 🟡 `GuildCultureManager` (23 réfs à GuildManager) et `AdvisorManager` (lit 6 systèmes) sont des **agrégateurs en lecture** : couplage fort assumé et acceptable pour ces rôles, mais ils accèdent à des **structures internes** (`GuildManager.behavior_system.social_dynamics`) plutôt qu'à une API publique → fragile.

---

### 4.8 Frontières Resource / Manager 🟠

Plusieurs `Resource` contiennent de la **logique de simulation et atteignent des autoloads**,
ce qui brouille la frontière données/comportement :

- 🟠 **`SimulatedPlayer` (729 l., 61 fonctions)** appelle des autoloads : `ServerVersion`, `GuildManager`, `EffectSystem`, `GameTime` (`simulated_player.gd:538,549,592...`) et **émet un signal d'un autre objet** : `guild_manager.member_leveled_up.emit(...)` (l.558) — **une Resource émet un signal appartenant au GuildManager**. C'est une inversion de responsabilité : la progression de niveau devrait être *demandée* au GuildManager, pas exécutée + signalée depuis la Resource.
- 🟠 **`Guild` (Resource)** appelle `NotificationManager`/`EffectSystem`/`GameTime` via `Singletons` (`guild.gd:96,141,231`). Une donnée pure qui déclenche des notifications UI → couplage descendant indésirable.
- 🟡 `ai_guild.gd` contient `simulate_monthly_progress()` (logique de simulation lourde dans une Resource). Tolérable (l'IA est un agent), mais à terme un `AIGuild` *données* + simulation dans `AIGuildManager` serait plus net.

**Direction de refactor (incrémentale, pas de réécriture)** :
- Faire des Resources des **porteurs d'état + calculs purs** (`calculate_xp_for_level`, `get_burnout_risk`...). ✅ déjà le cas pour beaucoup.
- **Remonter les effets de bord** (émission de signaux d'autoloads, notifications, gain d'XP de guilde) **dans les managers**. Ex. `SimulatedPlayer.gain_experience` retourne le nombre de niveaux gagnés ; `GuildManager` applique le gain d'XP guilde et émet `member_leveled_up`.
- Cela élimine au passage le besoin de `Singletons` dans la plupart des Resources.

---

### 4.9 Code mort détecté 🟡

- `scripts/systems/fast_forward_manager.gd` (279 l.) + `scripts/ui/windows/fast_forward_dialog.gd` (573 l.) : **plus aucun appelant actif** — uniquement référencés par des lignes **commentées** de `main.gd` (l.26, 791, 814). ~850 lignes mortes. → Supprimer (ou réintégrer si la fonctionnalité est voulue).
- `notification_manager.gd:62` : `print("NotificationManager initialized")` non gardé (CLAUDE.md impose `GameLog`/`is_debug_build`). `fast_forward_manager.gd` truffé de `print()` bruts (mais mort).
- `_on_member_left` (notification_manager.gd:404) : handler mort (cf. 4.5).

---

### Top 5 refactors prioritaires

1. **🔴 Réparer/retirer le signal mort `member_left`** (`guild_manager.gd` + `notification_manager.gd:91`). Soit déclarer `signal member_left(member)` et l'émettre dans `remove_member()`, soit supprimer le handler. *Effort: 15 min. Impact: notification de départ aujourd'hui silencieusement cassée.*

2. **🟠 Rendre le schéma de save déclaratif** (`save_manager.gd`). Introduire un `SAVE_REGISTRY` itéré par `save_game`/`_apply_save_data`/migration, et **porter la (dé)sérialisation des champs membres dans `SimulatedPlayer.to_save_dict()/from_save_dict()`**. Supprime le risque n°1 de perte de save (champ oublié) et le triple point de modification. *Effort: 1-2 j.*

3. **🟠 Dégonfler `main.gd`** en extrayant les 3 popups modaux (`LootConflictDialog`, `DramaDialog`, `IdlePromptOverlay`) vers des composants héritant de `BaseDialog` déjà présent, derrière une petite file `ModalQueue`. −300 lignes, supprime 3 booléens d'état globaux. *Effort: 1 j.*

4. **🟠 Choisir UNE convention d'accès aux autoloads** et purger les redondances : `class_name`/global direct pour les Nodes, `Singletons.get_autoload` (typé localement) **uniquement** pour les Resources ; supprimer les `const X = preload(...)` qui masquent un `class_name` (§4.6) et les fallbacks doubles (§4.3). Élimine les warnings `SHADOWED_GLOBAL_IDENTIFIER`. *Effort: 0.5 j.*

5. **🟠 Documenter et sécuriser l'ordre d'init + ordonner l'économie hebdo.** (a) Commenter dans `project.godot` la contrainte (`GameTime` → `GuildManager` → consommateurs) et différer via `call_deferred` les `_ready()` qui lisent un autre autoload (sur le modèle `SaveManager`). (b) Centraliser/ordonner les mouvements d'or `week_changed` (salaires, sponsors, staff, tournois, transferts) pour éviter un solde négatif transitoire dépendant de l'ordre. *Effort: 0.5-1 j.*

*(Bonus rapide hors top 5 : supprimer ~850 lignes de code mort `fast_forward_*` — §4.9.)*
