# Audit RaidLead — UI · Gameplay · Propreté du code

*Réalisé le 2 juin 2026 — Godot 4.6.2, branche `feat/milestones-4-5-ui-polish`.*

## Méthodologie

Audit mené en **7 volets parallèles** :

1. **Tour live du jeu** (MCP godot-mcp-pro) — lancement réel, navigation des fenêtres, captures d'écran, inspection runtime de l'état (`execute_game_script`). C'est ce volet qui a **confirmé des bugs invisibles à la lecture statique**.
2. **6 sous-agents d'analyse statique** spécialisés (lecture de ~33 000 lignes / 103 fichiers `.gd` + 16 scènes), un par axe :
   - §1 UI — code & scènes · §2 Gameplay — boucle & ergonomie · §3 Gameplay — systèmes & équilibrage
   - §4 Code — architecture & autoloads · §5 Code — propreté & qualité · §6 Code — tests, tooling & perf

Outils MCP croisés : `get_editor_errors` (**273 warnings**), `find_unused_resources` (**52 ressources non référencées**), `detect_circular_dependencies` (0 cycle de scènes), `get_project_statistics`.

Chaque section détaillée est conservée dans `docs/audit/0X-*.md` et **reproduite intégralement plus bas**. Sévérités : 🔴 critique (cassé / bloque le plaisir / bug latent) · 🟠 majeur · 🟡 mineur.

> ⚠️ Note d'environnement : le projet tourne désormais en **natif Windows** (renderer `mobile`), plus en WSL2/OpenGL3. Le `CLAUDE.md` (consignes WSL2, `--rendering-driver opengl3`, `GALLIUM_DRIVER`) est **obsolète** et devrait être mis à jour.

---

## Synthèse exécutive — ce qu'il faut corriger en priorité

RaidLead a une base **très riche** et des systèmes globalement bien câblés. Le problème dominant n'est pas le manque de contenu mais **la cohérence runtime** : l'UI affiche des choses vraies pendant que le moteur en pense d'autres, et la **boucle jouable du early-game (Phase 0) est de fait bloquée**.

### 🔴 Top bugs critiques (confirmés en jeu ou bugs latents certains)

| # | Problème | Preuve | Source |
|---|----------|--------|--------|
| C1 | **Le niveau du perso-joueur ne persiste pas.** Observé en live : chat et panneau de session annoncent « Joueur niveau 17 / +16 LVL », puis l'objet joueur lu en mémoire est `niveau=1, xp=0`. Le joueur est de fait **épinglé au niveau 1**. | `execute_game_script` : `player_character == membre "Joueur"` (objet unique), lu `niveau=1` après un level-up annoncé 17. `gain_experience` (simulated_player.gd:534) incrémente bien — donc reset/reconstruction en cours de partie à isoler (cycle repos/reconnexion). | Tour live + §2 |
| C2 | **Objectif Phase 0 inatteignable** → « finir un donjon héroïque » (niv. 60) alors que joueur + 10 membres démarrent **niv. 1**, montée dépendante de « mises à jour serveur » aléatoires, et **un seul membre disponible** à la fois pour monter un groupe (vérifié dans la fenêtre Organisation). Le « vrai jeu » ne se débloque jamais en partie normale. | Captures Organisation (1 dispo) + Personnage (Niv.1) ; `guild_initializer.gd:54`, `guild_manager.gd:310,331` | Tour live + §2 |
| C3 | **Stockage d'or qui détruit les revenus + spam de toasts.** `gold_storage` = 0 (niv 1-2) puis 1000 (niv 3) ; le farming/raid dépasse le cap et l'or est **jeté**, avec un toast « X or perdus » à chaque overflow. Vu en live : `guild.gold` figé à 1000 et **3 toasts empilés** en quelques secondes. | `guild_perks_data.gd:114`, `guild.gd:79`, `_notify_gold_overflow` ; capture des 3 toasts | Tour live + §3 |
| C4 | **Boucle énergie/épuisement trop serrée et intrusive.** À 60×, le joueur passe de 100 % à **épuisement total en ~9 h de jeu**, déclenchant une **modale bloquante** « Épuisement total ». Survenu **2 fois** pendant un court tour. | Drain `LEVELING 15/h` × malus fatigue (player_character.gd:27,160) ; captures | Tour live + §2 |
| C5 | **Perf de simulation O(M³)→O(M⁴) (social) + recalcul de classement en rafale.** `get_social_circle`/`get_online_friends` scannent tout le graphe par membre toutes les 5 min ; `_on_activity_completed` empile un `create_timer(2.0)` qui retrie **100 guildes** à chaque fin de donjon. Gel potentiel en sessions longues / haute vitesse. | `social_dynamics.gd`, `guild_ranking.gd:584` | §6 |
| C6 | **Ternaire à précédence piégeuse** : `guild_ranking.gd:414` — le test « est-ce notre guilde ? » est faux dans un cas (vrai bug fonctionnel, pas cosmétique). | `guild_ranking.gd:414` (INCOMPATIBLE_TERNARY) | §5 |
| C7 | **Signal mort `member_left`** : `notification_manager.gd:91` se connecte à un signal jamais déclaré/émis → la notif de départ de membre **ne se déclenche jamais** (échec silencieux via `has_signal`). | `notification_manager.gd:91-92`, `guild_manager.gd` | §4 |
| C8 | **Aucun test sur 6 systèmes « 100 % »** du roadmap : Staff, Tournament, Transfer, Legacy (0 assertion), Media/Sponsorship quasi rien, social et IA de débauchage non testés — c'est le code le plus coûteux **et** celui qui mute le plus l'état global. | `tests/` (21 suites / ~98 assertions) | §6 |

#### Bugs & incohérences additionnels (passe statique — détail en Partie B)

Ces points proviennent de la passe d'audit statique multi-agents (Partie B). Ils sont **complémentaires** des précédents et concernent surtout la **fiabilité de la boucle jouable centrale** (contrats runtime qui divergent).

| # | Problème | Preuve | Source |
|---|----------|--------|--------|
| C9 | **Les donjons risquent de ne jamais progresser** : `update_dungeons()` (activity_manager.gd:440) n'est **pas appelé** dans le flux temporel (`_on_minute_changed` → `_update_all_activities`), alors que la progression réelle vit dans `DungeonInstance.update()`. Un run lancé peut « promettre » un combat sans que le moteur ne tick. | activity_manager.gd:104,440 ; dungeon_instance.gd:110 | Partie B |
| C10 | **Le repos laisse l'ancienne activité produire des gains** : `disconnect_player()` ne coupe pas l'activité côté `ActivityManager`, qui continue d'appliquer XP/or/moral/intégration hors-ligne → feedback d'énergie/session peu fiable. | player_character.gd:203 ; activity_manager.gd:446 | Partie B |
| C11 | **Rôles UI ≠ rôles combat** : l'organisation lit `member.get_role()` (fenetre_organisation_groupe.gd:765) mais la compo donjon lit `member.personnage_role` (dungeon_instance.gd:274), parfois vide/désynchronisé → groupe « valide » en UI mais pénalisé comme sans tank/heal/DPS en combat. | divergence get_role() / personnage_role | Partie B |
| C12 | **Binding de signaux cassé dans EffectSystem** : `EffectInstance.expired` émet déjà l'instance (effect_instance.gd:14) **et** `EffectSystem` rebinde `target_id, effect_instance` (effect_system.gd:67) ; le `disconnect` teste un `Callable` non bindé (effect_system.gd:119) → appels à trop d'arguments / connexions jamais déconnectées. | effect_system.gd:67,119 | Partie B |
| C13 | **Fermer un événement peut bloquer tous les suivants** : `EventManager` bloque les tirages tant que `pending_event != null` (event_manager.gd:65), mais fermer la popup (event_popup.gd:248) reprend le temps **sans** résoudre l'événement → système d'events silencieusement inerte. | event_manager.gd:65 ; event_popup.gd:248 | Partie B |
| C14 | **Conflit de loot / abandon de donjon à propriétaires multiples** : `_abandon_dungeon()` déclenché en double (fenetre_donjon.gd:291 + parent fenetre_organisation_groupe.gd:749) ; conflit de loot pausé via `_loot_dialog_active` (main.gd:470) nettoyé par certains boutons seulement → conséquences appliquées 2× ou soft-lock. | main.gd:470 ; fenetre_donjon.gd:291 | Partie B |
| C15 | **Un événement aléatoire peut faire quitter le perso-joueur** : `random_member_leave` pioche dans toute la guilde (event_manager.gd:307) sans exclure le membre `is_player` (guild_manager.gd:348). | event_manager.gd:307 | Partie B |
| C16 | **Les raccourcis clavier contournent les verrous de phase** : Ctrl+N / Ctrl+E (main.gd:380) ouvrent National/Esport alors que les boutons de menu sont verrouillés (menu_bar.gd:64) → progression décrédibilisée. | main.gd:380 ; menu_bar.gd:64 | Partie B |

> **Recoupements de confirmation croisée** : la note Partie B « rapport de session = `personnage_niveau - 1` » (player_character.gd:317) **corrobore C1** (le « +16 LVL » affiché impliquait bien `niveau=17` à cet instant — puis reset à 1). Le « drift de signaux NotificationManager » (manque `member_left` **et** `pool_updated` vs `pool_refreshed`) **élargit C7**. La « validation Godot instable (signal 11) » de la Partie B recoupe l'**instabilité du build** observée pendant mon tour live.

### 🟠 Problèmes majeurs transverses

- **UI non réactive (fenêtres figées)** : la fenêtre Personnage et la liste Guilde affichent `Niveau 1` / « En attente d'un ordre » pendant que le chat annonce le niveau 17 → pas de rafraîchissement live. Aggravé par **3 timers de polling** redondants (`time_display.gd:54`, `fenetre_personnage.gd:66`, `player_control_panel.gd:31`) alors que des signaux existent. *(§1)*
- **État de pause désynchronisé** : `fast_forward_hours()` (game_time.gd:100) ignore `is_paused` ; après un repos, le temps repart mais le bouton reste « Reprendre » → label et état divergent. *(Tour live + §1)*
- **Incohérence des modales** : prompt d'oisiveté thémé vs **15 `AcceptDialog`/`ConfirmationDialog` natifs** (épuisement, events) ; **fuite de BBCode** (`[color=gray]…[/color]` affiché en texte) ; EventPopup au fond de donjon chargé → contraste faible ; popups qui **se chaînent et re-pausent** le jeu. *(Tour live + §1/§2)*
- **Échelle & cadence des IA** : **49 guildes en National, 99 en Esport** (ai_guild_manager.gd:13-17), chacune 12-25 membres ; et progression seulement si `week % 4 == 0` → IA **figées 3 semaines/4**, classement en marches d'escalier. *(§3)*
- **Forêt de jauges corrélées** : `energy/mood/fatigue/burnout/stress/integration/satisfaction/celebrity` + `guild_morale` — un wipe baisse le moral par 3 canaux (double comptage), lisibilité joueur faible. *(§3)*
- **God objects** : `main.gd` (~1080 l., 3 popups construits à la main au lieu de `BaseDialog`), `fenetre_monde.gd` (~1200 l.). *(§4)*
- **Dette de typage** : ~431 collections sans `[T]`, **~39 % des fonctions sans `-> Type`** — écart net au mandat « typage systématique » du CLAUDE.md. *(§5)*
- **Conseiller : mismatch de phase** — en Phase 0 Leveling, l'onglet « Cette semaine » affiche les objectifs **Phase 1 Serveur** et « Aucun contenu adapté au niveau moyen actuel » (le jeu admet qu'il n'y a rien à faire). *(Tour live + §3)*
- **Pas de CI ; 273 warnings non bloqués** ; harnais de tests couplé à l'état global et **`GameRandom.seed_rng` jamais appelé** par le runner → suites flaky. *(§6)*
- **Boucle PvE & repos non fiables (Partie B)** : tick de donjon non branché (C9), activité qui continue pendant le repos (C10), rôles UI/combat divergents (C11) — la boucle jouable centrale n'a **pas de source de vérité unique**. *(Partie B · P0)*
- **Contenu mal gaté (Partie B)** : tous les donjons/héroïques niv.60 listés dès la Phase 0 (`fenetre_organisation_groupe.gd:219`), activité « Fun » sélectionnable mais non composable, recrutement à causalité illisible (flags TODO `fenetre_monde.gd:776`). *(Partie B · P1)*
- **Layout non responsive (Partie B)** : `project.godot` force `viewport 1920` + `resizable=false` ; menu de 8 boutons fixes ; fenêtres restaurées **sans clamp** au viewport et fermées par `hide()` → état `WindowManager` désynchronisé. *(Partie B · P1)*
- **Comportement enum vs string (Partie B)** : `behavior_system.gd:450` compare `current_activity.type` (enum) à `"RAID"`/`"DUNGEON"` → fatigue/burnout/préférences mal pondérés. *(Partie B · P1)*
- **Production / assets (Partie B)** : PNG **1024 px utilisés comme icônes** (mémoire GPU gaspillée), bannières de donjon manquantes pour ~8 instances, services MCP (`MCPScreenshot/Input/Inspector`) en **autoloads runtime** à exclure de l'export release. *(Partie B · P2)*

### Points forts (à préserver)

NotificationManager (toasts qui marchent, animés, par type) · AdvisorManager (couverture + vue « Cette semaine ») · BalanceManager (rubber-band/catch-up bornés) · SaveManager (versioning + migration + backup + repli) · thème qui définit hover/pressed/disabled/focus · états vides bien gérés · loot bien étagé par niveau · 0 dépendance circulaire de scènes · icônes chargées dynamiquement via `asset_loader`.

---

## Quick wins consolidés (fort impact / faible effort)

1. **Plancher d'or early-game** : passer `gold_storage` niv 1-3 à ~5 000 et **router l'overflow vers la banque** plutôt que le détruire ; throttler le toast « or perdu ». *(C3)*
2. **Débloquer la Phase 0** : soit faire monter le joueur (corriger C1) et offrir des donjons à son niveau, soit redéfinir l'objectif Phase 0 en quelque chose d'atteignable dès le niv. 1-20. *(C1/C2)*
3. **Adoucir l'énergie** : baisser les drains / relever le seuil d'épuisement, et **remplacer la modale d'épuisement par un toast + repos auto** non bloquant. *(C4)*
4. **Bandeau d'objectif permanent** : afficher en haut l'objectif de phase courant + progression, au lieu de l'enfouir dans un sous-onglet. *(§2)*
5. **Tuer le polling UI** : supprimer les 3 timers, tout brancher sur `player_state_changed`/`minute_changed` ; corriger le label Pause. *(§1)*
6. **Throttle des pauses auto** : au-dessus d'une vitesse seuil, auto-résoudre les events en toast au lieu de pauser. *(§2/§6)*
7. **Nettoyage mécanique des warnings** : préfixe `_` sur ~110 params, suppression de 13 `const = preload` shadowant des `class_name`, `float()` sur les divisions entières → ~85 % des 273 warnings réglés par lots. *(§5)*
8. **Réparer `member_left`** (déclarer/émettre le signal) et le ternaire `guild_ranking.gd:414`. *(C6/C7)*
9. **Réduire le nombre d'IA** (ex. 12-16 max) et faire progresser chaque semaine. *(§3)*
10. **Pass audio/feel minimal** : SFX de level-up, loot épique, clear ; célébration des moments forts (aujourd'hui un simple `print`). *(§2)*
11. **Brancher le tick PvE** : appeler `ActivityManager.update_dungeons()` depuis le tick minute/heure + test « donjon vivant après `start_dungeon()` ». *(C9)*
12. **Couper l'activité au repos** : interrompre `current_activity` avant tout repos et ignorer les ticks d'activité si le joueur est offline. *(C10)*
13. **Source unique de rôle** : employer `get_role()` dans `DungeonInstance._check_group_composition()` (ou maintenir `personnage_role` partout, idéalement un enum). *(C11)*
14. **Événements robustes** : popup d'event réellement modale **ou** fermeture = choix explicite « Ignorer » appelant `resolve_event()` ; rendre `_abandon_dungeon()` idempotent (`if not is_active: return`). *(C13/C14)*
15. **Fenêtres saines** : fermeture par `close_requested` (au lieu de `hide()`), clamp des positions restaurées au viewport, et autoriser le resize en dev. *(Partie B · P1)*
16. **Hygiène de production** : variantes d'icônes 32/64/128/256 (au lieu des PNG 1024) + désactiver/exclure les autoloads MCP hors debug. *(Partie B · P2)*

---

## Constats du tour live (preuves runtime)

Ces points ont été **observés en exécutant le jeu**, pas seulement déduits du code :

- **C1 — niveau joueur volatil** : `player_character` est un objet unique (== membre « Joueur ») ; lu `niveau=1, xp=0` juste après que le chat ait annoncé « Joueur a atteint le niveau 17 » et la session « +16 LVL ». `gain_experience()` lève bien le niveau → quelque chose le réinitialise en cours de partie.
- **C3 — overflow d'or** : `guild.gold` figé à 1000 ; **3 toasts « Stockage d'or … X or perdus »** empilés ; session « Or: 82 » jeté.
- **C4 — épuisement** : modale « Épuisement total » apparue **2 fois** en quelques minutes de jeu à 60×.
- **Pause désync** : horloge qui avance (18:13 → 21:04) bouton sur « Reprendre ».
- **BBCode brut** affiché dans un panneau d'event (`[color=gray]…[/color]`, `[b]…[/b]`).
- **Modales empilées** : la fenêtre Personnage s'ouvre **sous** le prompt d'oisiveté au boot ; les EventPopup se superposent aux autres fenêtres et se chaînent.
- **Organisation** : un **seul** membre disponible (« Joueur Niv.1 ») pour composer un groupe.
- **Conseiller** : objectifs Phase 1 affichés en Phase 0 ; « Aucun contenu adapté au niveau moyen actuel » ; « Places libres : 0 » (guilde 10/10) mais « 15 candidats ».
- **Instabilité du build via MCP** : plusieurs arrêts inopinés du jeu lancé depuis l'éditeur pendant le tour (à surveiller — peut masquer un crash réel sur le chemin repos/épuisement).

Bons points visuels : fond de donjon soigné, toasts animés fonctionnels, tags de statut lisibles, menu bas avec verrous de phase visibles (National/Esport grisés), états vides corrects.

---

# Partie A — Sections détaillées (passe live + 6 sous-agents)

*Les six sections ci-dessous sont les rapports complets des sous-agents de la passe « live + statique » (fichier:ligne, tableaux, Top 5 par axe). Elles sont aussi disponibles séparément dans `docs/audit/`. La **Partie B** (audit statique multi-agents antérieur) suit en fin de document.*

## 1. UI — Code & Scènes

*Audit statique du code UI de RaidLead (Godot 4.6, GDScript). Périmètre : `scenes/*.tscn`, `scripts/ui/**`, `ui_theme.gd`, `ui_constants.gd`, `window_manager.gd`, `notification_manager.gd`. Toutes les références sont en `fichier:ligne`. Sévérités : 🔴 Critique · 🟠 Majeur · 🟡 Mineur.*

> **Note de cadrage** : le point #9 du brief (« 52 ressources inutilisées, l'UI n'affiche aucune icône ») est **factuellement faux à date**. Un autoload `scripts/autoloads/asset_loader.gd` charge et expose tous ces assets, et 9 fichiers UI les consomment réellement (portraits de classe, rôles, stats, slots, menus, bannières de donjon). Le sujet « icônes » est donc traité en §9 sous l'angle *couverture incomplète*, pas *absence totale*.

---

### 1.1 Réactivité — polling vs signaux

Le projet expose pourtant les bons signaux (`GameTime.minute_changed`, `PlayerCharacter.player_state_changed`, `GuildManager.member_*`, `PhaseManager.*`). Plusieurs endroits rafraîchissent quand même par `_process`/`Timer`.

| Fichier:ligne | Problème | Recommandation | Sévérité |
|---|---|---|---|
| `scripts/ui/components/time_display.gd:54` | `_process(_delta)` tourne **à chaque frame** uniquement pour réécrire la chaîne d'heure + l'indicateur `[PAUSE]`. Gaspillage permanent (la fenêtre est toujours visible). | S'abonner à `GameTime.minute_changed` (déjà émis, `game_time.gd:3`) pour le texte, et à un signal de pause (à ajouter dans `GameTime`, ou réutiliser `toggle_pause`) pour le `[PAUSE]`. Supprimer `_process`. | 🟠 |
| `scripts/ui/windows/fenetre_personnage.gd:64-77` | Timer 3 s (`update_timer`) qui appelle `update_character_info()` en polling. Or la fenêtre se connecte **déjà** à `player.player_state_changed` (l.394-396) qui couvre énergie/activité. Le timer fait double emploi. | Supprimer le `Timer` ; rafraîchir uniquement sur `player_state_changed` + à l'ouverture (`refresh_window`). Le `_notification(VISIBILITY_CHANGED)` (l.373) garde un refresh immédiat. | 🟠 |
| `scripts/ui/components/player_control_panel.gd:31-35` | Timer 5 s (`update_timer`, `autostart`) qui appelle `_update_display()`. Le panneau est **déjà** branché sur `player_state_changed` (l.183-185). Polling redondant qui tourne même hors-écran. | Retirer le `Timer` ; le signal suffit. Conserver un refresh à `set_player_character`. | 🟠 |
| `scripts/ui/windows/fenetre_personnage.gd:788` · `:802` | `get_tree().create_timer(5.0)` pour auto-free un Label de notif, et `AcceptDialog` recréé pour « requirements met ». Acceptable mais le 1er crée une notif maison alors que `NotificationManager` existe. | Router vers `NotificationManager.show_achievement(...)` plutôt qu'un Label temporisé. | 🟡 |
| `scripts/ui/windows/poaching_popup.gd:298,315,323,352,353,361,408,409,412` | 9 `create_timer(...)` chaînés pour simuler le tempo dramatique d'une négociation. Fonctionnel mais fragile (timers détachés, pas d'annulation si la popup ferme tôt). | Acceptable pour un effet narratif ; à terme remplacer par un `Tween`/`SceneTreeTimer` stocké et annulé dans `_exit_tree`. | 🟡 |
| `scripts/ui/components/notification_toast.gd:235` | `_process` met à jour la barre de décompte du toast. OK car le toast est éphémère, mais tourne par frame. | Tolérable. Option : piloter la barre par un `Tween` sur `value` (0→durée) plutôt qu'un `_process`. | 🟡 |
| `scripts/ui/components/tooltip.gd:24` | `_process` suit la souris en continu **dès que** le tooltip est visible. Acceptable pour un tooltip flottant. | OK ; vérifier que `hide_tooltip()` est bien appelé (sinon `_process` tourne dans le vide). | 🟡 |

---

### 1.2 Cohérence du thème — sources de couleur multiples

Le thème global (`UITheme.build()`) est correctement appliqué à la racine. Mais les couleurs **sémantiques** sont redéfinies dans **plusieurs** endroits, et les fenêtres contournent massivement le thème via des overrides inline.

**Sources de couleur sémantique concurrentes (succès/warning/error/info) :**

| Source | Fichier:ligne | Statut |
|---|---|---|
| Canonique | `scripts/ui/ui_constants.gd:21-25` (`COLOR_SUCCESS/WARNING/ERROR/INFO/ACHIEVEMENT`) | ✅ référence |
| Dérivée OK | `scripts/ui/components/chat_panel.gd:10-20` (dérive de `UIConstants`) | ✅ déjà corrigé |
| **Doublon** | `scripts/ui/components/badge.gd:37-47` (`BADGE_COLORS`) — recopie `Color(0.3,0.8,0.3)`, `Color(0.9,0.7,0.2)`, `Color(0.9,0.3,0.3)`, `Color(0.4,0.7,1.0)` | 🟠 à dériver de `UIConstants` |
| **Doublon** | `scripts/managers/notification_manager.gd:27-33` (`NOTIFICATION_COLORS`) — mêmes teintes avec alpha 0.95 | 🟠 à dériver de `UIConstants` |
| **Doublon** | `scripts/ui/dialogs/confirm_dialog.gd:41-47` (`ICON_COLORS`) — re-`Color(...)` warning/danger/info/success | 🟠 à dériver de `UIConstants` |

→ **5 définitions** de la palette sémantique au lieu d'une. Recommandation : `Badge`, `NotificationManager`, `ModalConfirmDialog` doivent lire `UIConstants.COLOR_*` (avec un `.a` appliqué si besoin), comme le fait déjà `chat_panel`.

**Overrides inline massifs (le thème global est court-circuité) :**

| Pattern | Volume | Recommandation | Sévérité |
|---|---|---|---|
| `add_theme_font_size_override("font_size", N)` avec N codé en dur | **175 occurrences / 24 fichiers** (ex. `fenetre_personnage.gd:83,166,171,176,...`) | Utiliser les constantes `UIConstants.FONT_SIZE_*` (l.47-51) et idéalement des variantes de thème (`Theme.set_type_variation`) « TitleLabel », « SubtitleLabel » au lieu de retailler chaque Label à la main. | 🟠 |
| `modulate = Color(...)` codé en dur sur Labels | **90 occurrences / 16 fichiers** (ex. `fenetre_monde.gd`, `fenetre_personnage.gd:198,206,261,...`) | Remplacer par `add_theme_color_override("font_color", UIConstants.COLOR_*)` (modulate teinte aussi les enfants/icônes, effet de bord). Centraliser les teintes « dim/highlight/success ». | 🟠 |
| `Color(0.7,0.7,0.7)` / `Color(0.8,0.8,1.0)` « texte secondaire » répétés | très fréquent (`fenetre_guilde.gd:172,261,440,467,479`, `fenetre_monde.gd`, etc.) | Une seule constante `UIConstants.COLOR_TEXT_DIM` existe déjà — l'employer partout. | 🟡 |
| `UIConstants.create_panel_stylebox` / `create_button_stylebox` (l.71-97) utilisent `CORNER_RADIUS=4` alors que `UITheme.RADIUS=5` | divergence de rayon entre helpers et thème | Aligner `UIConstants.CORNER_RADIUS` sur `UITheme.RADIUS` (ou supprimer les helpers, redondants avec le thème). | 🟡 |

---

### 1.3 Dialogs bruts vs composants maison

Le projet contient une **suite de dialogs maison aboutie** (`dialogs/base_dialog.gd`, `confirm_dialog.gd`→`ModalConfirmDialog`, `input_dialog.gd`, `progress_dialog.gd`) **+** un `components/confirm_dialog.gd` (`ConfirmDialog`). Pourtant **15 `AcceptDialog`/`ConfirmationDialog` natifs** sont instanciés à la main, non thémés au-delà du stylebox global.

| Fichier:ligne | Dialog brut | Remplacement conseillé |
|---|---|---|
| `scripts/ui/windows/fenetre_monde.gd:693` | `ConfirmationDialog` (contre-offre) | `ModalConfirmDialog.show_question(...)` |
| `scripts/ui/windows/fenetre_monde.gd:734,794,801` | `AcceptDialog` (résultats recrutement) | `NotificationManager.show_*` ou `BaseDialog.create_simple_dialog` |
| `scripts/ui/windows/fenetre_organisation_groupe.gd:622,638,652,667,715,822` | 6× `AcceptDialog` (erreurs/résultats) | erreurs → `NotificationManager.show_warning` ; rapport → `Fenetre_Loot` (déjà existante) |
| `scripts/ui/windows/fenetre_personnage.gd:798` | `AcceptDialog` (« requirements met ») | `ModalConfirmDialog`/`NotificationManager` |
| `scripts/ui/windows/fenetre_esport.gd:649` | `ConfirmationDialog` (négociation) | `ModalConfirmDialog` |
| `scripts/ui/components/player_control_panel.gd:322` | `AcceptDialog` (reconnexion) | `ModalConfirmDialog` |
| `scripts/main.gd:489,643,867` | `AcceptDialog` (conflit loot, repos, …) | le repos (l.867) est volontairement `PROCESS_MODE_ALWAYS` → garder ; loot (l.489) gagnerait à un `BaseDialog` thémé |
| `scripts/ui/windows/fenetre_loot.gd:1` | `extends AcceptDialog` | acceptable (titre + bouton Fermer standard), mais incohérent avec `BaseDialog` |

**Composants dialog quasi-orphelins** (seules les factories statiques existent, jamais appelées) :

| Composant | Usage réel |
|---|---|
| `dialogs/confirm_dialog.gd` (`ModalConfirmDialog`) | **0 appel** hors lui-même |
| `dialogs/input_dialog.gd` (`InputDialog`) | **0 appel** |
| `dialogs/progress_dialog.gd` (`ProgressDialog`) | **0 appel** (`fenetre_organisation_groupe.gd:608` note explicitement « sans ProgressDialog pour l'instant ») |
| `dialogs/base_dialog.gd` (`BaseDialog`) | utilisé uniquement comme parent des 3 ci-dessus |
| `components/confirm_dialog.gd` (`ConfirmDialog`) | **2 appels** (`fenetre_guilde.gd:663`, `fenetre_donjon.gd:294`) |

→ 🟠 **Soit** on adopte ces dialogs partout (cohérence + thème + raccourcis clavier Y/N gérés dans `ModalConfirmDialog._unhandled_key_input`), **soit** on supprime le mort. La situation actuelle (deux familles de dialogs maison + dialogs natifs) est le pire des trois mondes. Note : `ModalConfirmDialog` (dialogs/) et `ConfirmDialog` (components/) sont **deux** composants de confirmation qui font la même chose → en garder un seul.

---

### 1.4 Layout / anchors / resize

| Fichier:ligne | Problème | Recommandation | Sévérité |
|---|---|---|---|
| `scenes/Main.tscn:7` | Nœud racine nommé **`root2`** (héritage du chemin mort `/root/root2` mentionné dans l'audit précédent). Nom trompeur. | Renommer en `Main` (et vérifier qu'aucun `get_node` ne le cible). | 🟡 |
| `scenes/Main.tscn:26-29` | `menu_bar` est typé **`HBoxContainer`** dans la scène avec `custom_minimum_size (0,50)`, mais le **script** `menu_bar.gd` étend `Control`, force `PRESET_BOTTOM_WIDE` et `custom_minimum_size.y = 80`, puis crée son propre `PanelContainer`. Type de nœud incohérent avec le script + double source de hauteur (50 vs 80). | Aligner le type de nœud sur `Control` et retirer le `custom_minimum_size` de la scène (le script le pilote). | 🟠 |
| `scripts/managers/window_manager.gd:244-270` | `_apply_window_layout` **écrase tous les anchors** (met tout à 0) puis fixe `size = default_size (800×600)`. Les fenêtres construites avec `PRESET_CENTER`/`SIZE_EXPAND_FILL` perdent leur logique d'ancrage ; le resize utilisateur n'est pas borné au viewport. | Conserver les positions sauvegardées mais clam**er** taille+position au viewport courant (déjà fait pour le centrage `_center_window` l.291, pas pour les positions restaurées l.263-266). | 🟠 |
| `fenetre_guilde.gd:38-39`, `fenetre_personnage.gd:41`, `fenetre_monde.gd:24`, `fenetre_equipement.gd:22` | Tailles min **codées en dur** (`Vector2(800,600)`, `1000×700`, `900×600`, `760×540`). | Centraliser dans `UIConstants.WINDOW_DEFAULT_SIZE/MIN_SIZE` (déjà définis l.59-60, **non utilisés**). | 🟡 |
| `fenetre_guilde.gd:136`, `fenetre_personnage.gd:309,333,345,365`, `fenetre_monde.gd` | `ItemList`/panneaux avec `custom_minimum_size` fixes (300×500, 260×200, …) → cassent sur petites résolutions et ne profitent pas du `HSplitContainer`. | Préférer `size_flags = EXPAND_FILL` + min-size modeste ; laisser le split gérer la répartition. | 🟡 |
| `fenetre_guilde.gd:514-548` + `fenetre_personnage.gd:98-103` + `fenetre_monde.gd:53-58` + `fenetre_equipement.gd:205-209` | **4 réimplémentations** du drag de fenêtre par la barre de titre (et `fenetre_guilde` ajoute un resize maison l.538-548). Logique dupliquée et divergente. | Factoriser dans un seul `DraggableWindow`/`ResizableWindow` (le composant `components/resizable_window.gd` existe mais est **quasi-orphelin**, cf §1.5). | 🟠 |

---

### 1.5 Composants réutilisables — utilisés vs orphelins

| Composant | Fichier | Usages | Statut |
|---|---|---|---|
| `AdvancedTabs` | `components/advanced_tabs.gd` | `fenetre_personnage/monde/national/esport/social/conseils` (6) | ✅ bien utilisé |
| `Badge` | `components/badge.gd` | `fenetre_esport/national/social` | ✅ utilisé (mais couleurs en doublon, §1.2) |
| `StatDisplay` | `components/stat_display.gd` | `fenetre_guilde:288-325` (4 instances) | ⚠️ **sous-utilisé** : `fenetre_personnage` réaffiche énergie/moral/intégration en **Labels manuels** (l.248-262) au lieu de `StatDisplay` |
| `CustomProgressBar` | `components/custom_progress_bar.gd` | `player_control_panel:81`, `progress_dialog:83` | ⚠️ sous-utilisé : `fenetre_personnage` XP et requirements utilisent des `ProgressBar` bruts (l.220,568) |
| `DraggableItem` / `DropZone` | `components/` | `fenetre_organisation_groupe` (+ `advanced_tabs`) | ✅ utilisé (compo de raid) ; mais l'équipement utilise un **autre** système de DnD (`EquipDragCell`, DnD natif Godot) → 2 systèmes de drag&drop coexistent |
| `ResizableWindow` | `components/resizable_window.gd` | `fenetre_donjon.gd:40` (via `has_node`, optionnel) | 🟠 **quasi-orphelin** alors que 4 fenêtres réimplémentent drag/resize à la main (§1.4) |
| `Tooltip` (`components/tooltip.gd`) | classe maison | **0 instanciation** trouvée | 🟠 **orphelin** — les fenêtres utilisent `tooltip_text` natif (ce qui est OK), donc ce composant est mort |
| `FastForwardDialog` | `windows/fast_forward_dialog.gd` | preload **commenté** dans `main.gd:9` | 🟠 **mort** — à supprimer |
| Suite `dialogs/*` | cf §1.3 | 0–2 appels | 🟠 majoritairement mort |

→ Recommandation : **soit** brancher `StatDisplay`/`CustomProgressBar`/`ResizableWindow` partout (réduit la duplication §1.4 et §1.8), **soit** supprimer les composants morts (`Tooltip`, `FastForwardDialog`, dialogs orphelins). Du code mort en quantité dilue la « bibliothèque de composants » et trompe sur ce qui est réellement réutilisable.

---

### 1.6 Feedback utilisateur

| Fichier:ligne | Constat | Recommandation | Sévérité |
|---|---|---|---|
| `ui_theme.gd:82-115` | ✅ Le thème **définit bien** `hover`/`pressed`/`disabled`/`focus` pour Button/OptionButton/MenuButton. États OK globalement. | RAS (bon point). | — |
| `fenetre_guilde.gd:359-364` | Les **tags comportementaux** sont des `Button` `flat` non cliquables servant juste à afficher du texte + tooltip. Détourne le composant Button (effet hover trompeur : on dirait que c'est cliquable). | Utiliser `Badge.create_tag_badge` (existe, `badge.gd:355`) ou un Label stylé. | 🟡 |
| `player_control_panel.gd:289-315` | Feedback succès/erreur = Label temporaire animé maison. Incohérent avec `NotificationManager` (toasts) déjà disponible. | Router vers `NotificationManager.show_success/show_error`. | 🟡 |
| `menu_bar.gd:98-104` | `set_active_window` utilise `modulate` pour estomper les boutons inactifs → teinte aussi l'icône. Pas de vrai état « sélectionné » visuel cohérent avec le thème. | Utiliser `button_pressed` + un stylebox `toggled`/variation de thème plutôt que `modulate`. | 🟡 |
| `fenetre_personnage.gd:286-289`, `fenetre_monde`, `fenetre_personnage:881` | Boutons « Actualiser » manuels présents — symptôme que le rafraîchissement n'est pas assez piloté par signaux (cf §1.1). | Avec un refresh par signal, ces boutons deviennent superflus. | 🟡 |
| Listes vides | ✅ La plupart des listes gèrent l'état vide (« Aucun loot… », « Aucune réalisation… », etc. — 118 occ. de patterns `is_empty`/« Aucun »). | RAS (bon point général). | — |

---

### 1.7 Accessibilité / lisibilité

| Fichier:ligne | Constat | Recommandation | Sévérité |
|---|---|---|---|
| `ui_theme.gd:17-19` | Contraste texte : `TEXT (0.89)` sur `BG_PANEL (~0.15)` = bon. `TEXT_DIM (0.62)` sur panel = correct ; mais les `Color(0.6,0.6,0.6)`/`Color(0.7,0.7,0.7)` inline (§1.2) sur fond foncé frôlent le seuil WCAG. | Normaliser le « texte dim » via `UIConstants.COLOR_TEXT_DIM` (mesuré) au lieu de teintes ad hoc plus sombres. | 🟡 |
| Polices | Beaucoup de Labels à **`font_size 11–12`** (ex. `player_control_panel.gd:151` = 10, `fenetre_personnage.gd:260` = 11). En jeu de gestion dense, 10–11px est petit. | Plancher à 12 et piloter via `UIConstants.FONT_SIZE_SMALL`. | 🟡 |
| Tooltips | ✅ Bonne couverture sur la barre de menu (`menu_bar.gd:88` raccourcis), barres de titre (« Glissez pour déplacer »), boutons d'action. | RAS, mais ajouter des tooltips sur les **icônes de stat** (`StatDisplay`) et les badges de sévérité. | 🟡 |
| `fenetre_monde.gd:378-384` | Indicateurs de tendance par caractères `▲▼▬` sans libellé. OK visuellement, mais pas de tooltip. | Ajouter `tooltip_text` « En hausse / En baisse / Stable ». | 🟡 |
| Émojis comme icônes | 🎯⚡😊🤝⭐ utilisés un peu partout comme « icônes ». Rendu dépendant de la police système ; incohérent avec les vraies icônes pixel-art d'`AssetLoader`. | Pour les stats de membre, préférer `AssetLoader.get_stat_icon` (déjà branché dans `StatDisplay`). | 🟡 |

---

### 1.8 Duplication UI

| Duplication | Emplacements | Recommandation | Sévérité |
|---|---|---|---|
| `_add_detail_row(GridContainer/parent, label, value)` | **identique** dans `fenetre_guilde.gd:470`, `fenetre_monde.gd:740`, `fenetre_personnage.gd` (variantes) | Extraire un helper statique partagé (ex. `UIBuilder.detail_row`). | 🟠 |
| Header de fenêtre (titre draggable + bouton X) | réimplémenté dans `fenetre_personnage.gd:77-96`, `fenetre_monde.gd:60-79`, `fenetre_guilde.gd:66-96`, `fenetre_equipement.gd:34-50` | Composant `WindowHeader` réutilisable (titre + drag + close signal). | 🟠 |
| Drag/resize de fenêtre | cf §1.4 (4 copies) | `ResizableWindow` (déjà existant). | 🟠 |
| Construction de barres de stat (énergie/moral/intégration) | `fenetre_guilde` via `StatDisplay` **vs** `fenetre_personnage` via Labels manuels (l.248-262) | Unifier sur `StatDisplay`. | 🟡 |
| `_format_duration`/`_format_date`/`_format_duration_seconds` | `fenetre_personnage.gd:738-753`, `player_control_panel.gd:258`, `fenetre_loot.gd` | Centraliser dans un util de formatage (ou `GameTime`). | 🟡 |
| Helper `_mk_label(text, size)` | `fenetre_equipement.gd:114` (local) — utile ailleurs | Promouvoir en helper partagé. | 🟡 |

---

### 1.9 Icônes / `assets/generated/` — couverture réelle

**Correctif du brief** : les assets **sont** utilisés via `scripts/autoloads/asset_loader.gd` (cache + fallback). Consommateurs : `menu_bar`, `fenetre_guilde` (portraits + rôles), `fenetre_personnage`, `fenetre_organisation_groupe`, `fenetre_loot`, `fenetre_donjon` (bannières), `event_popup`, `stat_display`. L'UI **n'est donc pas** « tout texte ».

Cela dit, la **couverture est partielle et incohérente** :

| Fichier:ligne | Constat | Recommandation | Sévérité |
|---|---|---|---|
| `menu_bar.gd:89` + `asset_loader.gd:56-61` | `_menu_icons` ne mappe que **4** entrées (Personnage/Guilde/Monde/Organisation). Les boutons **National, Esport, Cohésion, Conseils** n'ont **pas** d'icône → barre de menu visuellement déséquilibrée (4 boutons avec icône, 4 sans). | Ajouter les 4 icônes manquantes dans `assets/generated/menu/` + le mapping, **ou** retirer toutes les icônes de la barre pour homogénéité. | 🟠 |
| `asset_loader.gd:117-118` | `get_menu_bar_bg()` charge `ui/menu_bar_bg.png` qui **n'existe pas** dans `assets/generated/` (le dossier `ui/` est absent du listing) → renvoie `null` silencieusement. | Générer l'asset ou retirer la méthode. | 🟡 |
| `asset_loader.gd:46-54` (`_activity_icons`), `_rarity_frames` (l.63-68) | Icônes d'activité et **frames de rareté** chargeables mais **jamais consommées** dans l'UI (aucun appel à `get_activity_icon`/`get_rarity_frame` hors AssetLoader). Le statut courant des membres affiche `[Donjon]`/`[Farming]` en **texte** (`fenetre_guilde.gd:195`). | Brancher `get_activity_icon` sur le statut des membres et `get_rarity_frame` autour des items de loot/équipement (gros gain de lisibilité). | 🟠 |
| Items de loot/équipement | `equip_drag_cell` et `fenetre_loot` affichent le nom coloré par rareté mais **sans cadre** ni icône de slot systématique. | Utiliser `get_slot_icon` + `get_rarity_frame` pour des cellules d'objet « MMO-like ». | 🟡 |

→ Bilan §9 : l'infrastructure d'icônes existe et fonctionne, mais **~40 % des hooks visuels** (activités, frames de rareté, 4 menus, fond de barre) ne sont pas câblés. Impact UX : interface partiellement illustrée, hétérogène.

---

### 1.10 Divers / robustesse

| Fichier:ligne | Constat | Sévérité |
|---|---|---|
| `notification_manager.gd:62` | `print("NotificationManager initialized")` non gardé par `OS.is_debug_build()` (contrairement à la convention `GameLog` du projet). | 🟡 |
| `fenetre_organisation_groupe.gd:724,727,730` · `fenetre_guilde.gd:657` | `print()` de debug résiduels dans des callbacks UI. | 🟡 |
| `notification_manager.gd:64-73` | `notification_container` ajouté à `get_tree().root` en `call_deferred` avec `z_index = 1000`, mais l'idle-prompt overlay (`main.gd:962`) est un `CanvasLayer layer=200` — un `CanvasLayer` passe **au-dessus** des `z_index` du même viewport : les toasts peuvent être masqués par l'overlay de pause. | 🟡 |
| `window_manager.gd:416-433` | Animation d'ouverture anime `size` de `Vector2.ZERO` → taille finale. Sur un `PanelContainer` à contenu `EXPAND_FILL`, ça peut provoquer un reflow visible (contenu qui « saute »). | 🟡 |
| `fenetre_personnage.gd:782` | `get_children()[0] as VBoxContainer` — accès positionnel fragile (casse si l'ordre des enfants change). | 🟡 |

---

### Top 5 quick wins UI

1. **Supprimer les 3 Timers de polling redondants** (`time_display.gd:54` → `minute_changed` ; `fenetre_personnage.gd:66` et `player_control_panel.gd:31` → déjà couverts par `player_state_changed`). Gain : moins de CPU permanent, code plus simple, et fin du décalage « jusqu'à 3-5 s » de l'UI. 🟠
2. **Unifier la palette sémantique** : faire dériver `Badge.BADGE_COLORS`, `NotificationManager.NOTIFICATION_COLORS` et `ModalConfirmDialog.ICON_COLORS` de `UIConstants.COLOR_*` (comme `chat_panel` le fait déjà). Passe de 5 sources à 1. 🟠
3. **Câbler les 4 icônes de menu manquantes** (National/Esport/Cohésion/Conseils) **et** brancher `get_activity_icon` sur le statut des membres : élimine l'aspect « moitié illustré ». 🟠
4. **Factoriser `WindowHeader` + `_add_detail_row`** (4 et 3 copies respectivement) : supprime ~150 lignes dupliquées et fiabilise le drag de fenêtre. 🟠
5. **Choisir une seule famille de dialogs** : adopter `ModalConfirmDialog`/`NotificationManager` pour les ~15 `AcceptDialog`/`ConfirmationDialog` bruts, et **supprimer** le mort (`FastForwardDialog`, `Tooltip`, `InputDialog`/`ProgressDialog` si non adoptés). Cohérence visuelle + raccourcis clavier gratuits. 🟠

---

*Décompte des trouvailles — 🔴 0 · 🟠 18 · 🟡 28 (hors bons points signalés ✅).*


---

## 2. Gameplay — Boucle & Ergonomie

> Audit statique (Read/Grep) de la boucle de jeu moment-à-moment et de l'ergonomie.
> Comparaison code implémenté vs intention des docs (`docs/GameLoop.md`, `docs/GameIdea.md`).
> Sévérités : 🔴 Critique (bloque le plaisir/la compréhension) · 🟠 Majeur · 🟡 Mineur.

### 2.0 Synthèse du diagnostic

Le jeu a une boucle de gestion riche **techniquement complète** (4 phases, behavior system, social, stress, équipement). Mais l'ergonomie moment-à-moment souffre d'un **déficit de fil conducteur** : le joueur arrive sur une fenêtre Personnage sans savoir quoi faire, sans objectif mis en avant, sans onboarding. La boucle « pause-si-oisif → choix d'activité » est bien pensée mais ne concerne **que le personnage-joueur** (1 entité sur ~11), alors que le cœur du jeu — gérer la guilde — n'a aucun prompt équivalent. Le résultat probable : le joueur regarde le temps passer sans comprendre quel levier actionner.

---

### 2.1 Le « que faire maintenant ? » — fil conducteur & onboarding

**🔴 Aucun onboarding, aucun objectif mis en avant à l'écran.**
- Au lancement, `main.gd:222` ouvre la fenêtre **Personnage** par défaut. Or l'objectif de Phase 0 (« compléter 1 donjon héroïque ») n'est visible que si le joueur clique l'onglet *Progression* de cette fenêtre (`fenetre_personnage.gd:113`). Rien à l'écran principal ne dit « voici ton but ».
- Pire : l'objectif Phase 0 est **inatteignable au niveau 1**. Le joueur démarre niveau 1 (`guild_manager.gd:331`, `player_character.gd:48`) avec 10 membres tous **niveau 1** (`guild_initializer.gd:54`). Or un donjon héroïque est niveau 60. Le chemin réel (leveling de toute la guilde de 1→60 via mises à jour serveur aléatoires à 40%/version, `guild_manager.gd:310`) n'est **expliqué nulle part**. Le joueur n'a aucun moyen de deviner qu'il doit attendre des « versions serveur » pour monter en niveau.
- `AdvisorManager` existe et produit des conseils contextuels par phase (`advisor_manager.gd:58`), mais il est **enfoui dans une fenêtre (Ctrl+A)** que rien n'incite à ouvrir, et il ne pousse qu'**une** alerte/semaine en notification (`advisor_manager.gd:32`). Ce n'est pas un fil conducteur, c'est une consultation passive.

> **Intention trahie** : `GameLoop.md:204-208` promet « Tutoriels intégrés », « Feedback clair sur les raisons d'échec », « Objectifs atteignables, progression visible et régulière ». Aucun des trois n'est présent dans la boucle principale.

**Solutions de game design :**
1. **Bandeau d'objectif permanent** (style FM « prochaine échéance ») : une barre fine en haut ou sous le menu affichant en continu l'objectif de phase courant + sa jauge (lire `PhaseManager.get_requirements_progress()`). Cliquable → ouvre la fenêtre détaillée.
2. **Panneau « Que faire ? » au boot** : un premier conseil `AdvisorManager` poussé d'emblée, pas seulement au `week_changed`. Au démarrage Phase 0 : « Vos membres sont niveau 1. Lancez des donjons de bas niveau et attendez les mises à jour serveur pour progresser vers le héroïque. »
3. **Onboarding scripté minimal** (3-4 étapes pointant menu Organisation → composer → lancer → loot), désactivable. C'est l'investissement à plus fort ROI sur le plaisir.

---

### 2.2 Boucle moment-à-moment — pause-si-oisif, choix, reprise

**🟠 La boucle « pause-si-oisif » ne couvre que le personnage-joueur, pas la guilde.**
- `main.gd:918-949` met le temps en pause quand **le joueur** n'a pas d'activité et affiche un overlay de choix (`_show_activity_prompt`). Excellent pour le perso. Mais le vrai gameplay — proposer donjons/raids à la guilde, recruter, gérer le moral — n'a **aucun équivalent**. Rien ne pause ni n'alerte quand la guilde est inactive, quand un raid est dispo, ou quand un membre menace de partir. Le joueur peut laisser filer le temps sans rien décider, ce qui contredit le modèle « Football Manager » revendiqué.

**🟡 Le prompt d'oisiveté propose Donjon/Raid mais le perso-joueur niveau 1 ne peut rien lancer d'utile.**
- `main.gd:1031` ajoute un bouton « Donjon/Raid » au prompt. Bonne intention, mais en early-game (tout niveau 1) ça ouvre une fenêtre d'organisation où les seuls contenus listés commencent bas — cohérent — sauf que le joueur ne sait toujours pas que c'est *la* voie de progression.

**🟡 Reprise auto après repos : correcte mais opaque.**
- `player_character.gd:123` `resume_last_activity()` reprend la dernière activité — bien. Mais si `last_activity_choice` est vide (premier repos), on retombe sur le prompt (`main.gd:902`), ce qui est logique mais non signalé.

**🟢 Points positifs :** le temps reprend correctement (`choose_activity` → `player_state_changed` → `_exit_idle_prompt` → `GameTime.resume()`, chaîne vérifiée `main.gd:951-1056`) ; le repos est instantané via `fast_forward_hours` plutôt qu'un hack temps-réel ; le verrou `is_in_forced_rest` évite la double-exécution.

**Solutions :**
1. **Étendre la pause-si-oisif à la guilde** : si aucun contenu de groupe n'est en cours et qu'un quorum de membres est en ligne, pousser une notification actionnable « 6 membres en ligne — organiser un donjon ? » (bouton direct).
2. **Pré-remplir `last_activity_choice`** à « LEVELING » par défaut au boot Phase 0 pour éviter le prompt initial à froid, et afficher dans le prompt pourquoi il s'ouvre (« Aucune activité en cours »).

---

### 2.3 Lisibilité du feedback (énergie, moral, loot, progression)

**🟠 Le feedback se disperse entre 4 canaux non hiérarchisés.** ChatPanel (`main.gd:90`), NotificationManager toasts, popups modaux (loot/drama), et jauges dans le panneau de contrôle. Rien n'indique au joueur lesquels surveiller. Le loot va dans le chat *et* en notification *et* parfois en popup conflit — redondant sans être complet (un loot auto-équipé n'apparaît qu'en chat).

**🟠 Les conséquences des stats restent invisibles.** L'énergie/le moral/le stress des membres pilotent la réussite PvE (`dungeon_instance.gd:234-238`, `:392`) et la présence, mais le joueur ne voit nulle part *pourquoi* un membre performe mal. L'aperçu de run (`fenetre_organisation_groupe.gd:472`) est un bon début (énergie/stress moyens, alertes burnout) mais il est **le seul endroit** où ces facteurs sont rendus lisibles, et seulement au moment de composer.

**🟡 Pas de feedback sur le « non-événement ».** Quand rien ne se passe (nuit, membres déconnectés), l'écran est muet. Le joueur ne sait pas s'il doit accélérer le temps ou agir.

**🟡 Level-up du perso joué uniquement via `print()`** (`player_character.gd:348`) — aucun toast ni juiciness pour un moment pourtant gratifiant.

**Solutions :**
1. **Hiérarchiser** : toasts = événements actionnables/critiques uniquement ; chat = journal détaillé ; popups = décisions bloquantes. Documenter cette règle et l'appliquer (ex. retirer la double-notif loot).
2. **Tooltips explicatifs sur les jauges membres** (« Énergie 18 % → −30 % de réussite en donjon »).
3. **Toast de level-up** pour le perso joué + petit feedback visuel.

---

### 2.4 Flow PvE — composition → run → loot

**🟢 Le flow est globalement bon** : Organisation (drag&drop des membres dans les slots de rôle, auto-assign, aperçu de score) → fenêtre Donjon animée (chemin, marqueurs de boss, wipes) → fenêtre Loot (rapport, performance, butin). C'est la partie la plus aboutie.

**🟠 Trop de fenêtres empilées et de modaux pour un seul run.**
- Lancer un donjon ferme l'organisation (`fenetre_organisation_groupe.gd:665`), ouvre `Fenetre_Donjon` (`:732`), qui à la fin ouvre `Fenetre_Loot` (`fenetre_donjon.gd:256`), un `AcceptDialog`. Un conflit de loot en cours de run ajoute encore un `AcceptDialog` modal qui **pause le jeu** (`main.gd:481`). Beaucoup de clics « Fermer ».
- L'`AcceptDialog` brut de loot/conflit/drama (`main.gd:489`, `:643`) **n'hérite pas du thème** et casse la cohérence visuelle obtenue ailleurs.

**🟠 Le joueur subit le run plus qu'il ne le pilote.** Une fois lancé, le combat se résout seul (`dungeon_instance.gd:186`). Le seul levier est « Abandonner ». Pas de décision tactique en cours (changer un membre, utiliser une ressource, retry/stop sur wipe). `GameIdea.md:156` prévoyait « événements aléatoires basés sur les tags des joueurs » pendant l'instance — absent.

**🟡 L'attribution de loot manuelle promise est largement automatisée.** `GameIdea.md:176` : « le vrai-joueur choisit quel membre reçoit ». En pratique, seul un sous-ensemble (rare+ avec ≥2 éligibles) déclenche un choix (`dungeon_instance.gd:315-329`) ; le reste est auto-attribué au moins équipé (`_pick_loot_winner`). C'est défendable pour le confort, mais c'est un retrait d'agance non documenté côté joueur.

**Solutions :**
1. **Fusionner Donjon + Loot** en une seule fenêtre thémée (le rapport remplace la vue de progression à la fin), supprimer un niveau de modal.
2. **Convertir les popups loot/conflit/drama** en overlay thémé réutilisable (le modèle `_show_activity_prompt` existe déjà — en faire un composant).
3. **Ajouter 1-2 micro-décisions par run** (events de tags : « le ninja-looter réclame l'objet, l'imposer ? ») pour transformer le run subi en run piloté.

---

### 2.5 Contrôle du temps

**🟢 Bons fondamentaux** : pause via Espace (`main.gd:392`) et bouton, presets de vitesse 1x→Max façon FM (`time_display.gd:15-21,100`), indicateur `[PAUSE]` (`time_display.gd:58`).

**🟠 Pause automatique en cascade à haute vitesse (confirmé par la roadmap).** Chaque événement/drama/conflit force une pause (`main.gd:485`, `:639`). À vitesse Max, les événements s'enchaînent et le jeu re-pause en continu → le joueur passe son temps à fermer des popups. De plus la **file d'attente** d'événements (`_pending_event_queue`) garantit qu'ils s'affichent tous séquentiellement, sans regroupement ni « tout résoudre ».

**🟡 Slider + presets redondants et désynchronisables.** Le slider continu (`time_display.gd:39`) et les boutons-presets coexistent ; un réglage au slider n'aligne aucun preset, ce qui brouille la lecture.

**🟡 Pas de « pause intelligente » configurable.** Aucun moyen pour le joueur de choisir quels événements pausent (alors que c'est un standard du genre).

**Solutions :**
1. **Throttle/regroupement d'événements** : à haute vitesse, agréger les événements non critiques en un digest hebdomadaire plutôt que de pauser à chaque fois ; ne pauser de force que pour les décisions vraiment bloquantes.
2. **Préférences de pause auto** (cases à cocher : drama / conflit loot / débauchage…), comme FM.
3. **Choisir un seul paradigme de vitesse** (presets) et faire du slider un réglage fin secondaire, ou retirer le slider.

---

### 2.6 Profondeur vs lisibilité

**🔴 Énorme profondeur simulée, quasi invisible et non actionnable.** Le `BehaviorSystem` (préférences dynamiques, circadien, fatigue/burnout, `dungeon_instance.gd:261`), `SocialDynamics` (amitiés/rivalités/cliques), le stress, la mémoire émotionnelle… tournent en coulisse. Le joueur n'a **aucune surface de lecture en temps réel** : pas de vue « ce soir, qui est en ligne, dans quel état, qui se brouille avec qui ». La fenêtre Cohésion (Ctrl+K) existe mais c'est, là encore, une consultation passive enfouie. Une simulation invisible est, du point de vue du joueur, soit du bruit aléatoire, soit une frustration (« pourquoi a-t-il raté ? »).

**🟠 Le débauchage, les salaires impayés, les dramas ont des conséquences fortes mais des signaux faibles.** Ex. salaires impayés → −15 moral à tous les salariés + −3 réputation (`guild_manager.gd:113-122`), signalé par un simple toast. Conséquence lourde, alerte fugace.

**Solutions :**
1. **Tableau de bord « État de la guilde » à plat** (1 ligne/membre : statut connexion, énergie, moral, stress, relation-clé) accessible en 1 clic, mis à jour live — la vraie « salle de contrôle » du gestionnaire.
2. **Rendre les systèmes cachés *lisibles a posteriori*** : quand un run échoue, un mini-explicatif (« fatigue −X, composition −Y, manque de familiarité −Z ») transforme l'opacité en apprentissage (réutilise les facteurs déjà calculés `dungeon_instance.gd:212-272`).

---

### 2.7 Intuitivité de la navigation

**🟠 8 fenêtres mutuellement exclusives, pas de hiérarchie.** Le menu (`menu_bar.gd:31-47`) aligne Personnage/Guilde/Monde/Organisation/National/Esport/Cohésion/Conseils à plat. En Phase 0, National/Esport sont grisés (`menu_bar.gd:57`), mais 6 boutons restent et rien ne hiérarchise « ce que tu utilises tout le temps » (Organisation, Guilde) vs « consultation ».

**🟡 Raccourcis peu découvrables.** Ctrl+P/G/M/O/N/E/K/A ne sont exposés qu'en tooltip (`menu_bar.gd:79`) ; le mapping est arbitraire (Cohésion=K, Conseils=A) et non mnémotechnique. Pas d'écran d'aide listant les raccourcis.

**🟡 `Échap` ferme la fenêtre active** (`main.gd:396`) — utile, mais peut surprendre quand on s'attend à fermer un popup d'abord.

**Solutions :**
1. **Regrouper le menu** : actions fréquentes à gauche (Guilde, Organisation), consultation à droite (Monde, Conseils, Cohésion), modules de phase verrouillés à part.
2. **Overlay d'aide raccourcis** (touche `?` / F1 en build release) — le `HelpOverlay` est déjà planifié dans la roadmap (Phase 3 UI).

---

### 2.8 Game feel (juiciness)

**🟠 Absence quasi totale de game feel.**
- **Aucun son** : pas d'AudioStreamPlayer dans la boucle (recruter, looter, level-up, victoire, wipe = silence). C'est le manque le plus criant pour le plaisir moment-à-moment.
- **Animations minimales** : quelques tweens d'alpha (`player_control_panel.gd:300`), barre de progression animée, marqueurs de boss qui changent de couleur. Pas de feedback d'impact (un boss vaincu, un loot épique, un level-up devraient « claquer »).
- **Pas de célébration** des moments forts (donjon héroïque = transition de phase, world first…) au-delà d'un toast achievement.

**Solutions :**
1. **Pass audio minimal** : 6-8 SFX (clic, succès, échec, loot par rareté, level-up, alerte) + une ambiance discrète. ROI plaisir maximal pour un coût faible.
2. **Juicy sur 3 moments clés** : loot épique (flash + son), level-up (toast + particules), clear de boss (punch sur le marqueur). Le système de particules MCP est disponible.

---

### 2.9 Courbe early-game (Phase 0)

**🔴 Early-game vide et lent, sans cap clair.**
- **Concentration en soirée confirmée par le code** : les membres ne se connectent que `is_evening()` (19h→2h) ou week-end après-midi (`simulated_player.gd:194-197`, plannings `guild_initializer.gd:61-69`). Le jeu démarre à **18h** (`game_time.gd:21`) : il y a donc une heure morte, puis une fenêtre d'activité le soir, puis une nuit déserte. À vitesse normale, de longues plages sans personne en ligne.
- **Progression de niveau hors du contrôle du joueur** : monter 1→60 dépend des mises à jour serveur (40% de chance/version/membre, `guild_manager.gd:310`). Le joueur **subit** le rythme, ce qui contredit `GameLoop.md:208` (« progression visible et régulière »).
- **Tension de design** : le pitch est « guilde d'**élite** de **haut niveau** » (`GameIdea.md:7`, CLAUDE.md) mais on démarre une guilde de **bleveling niveau 1**. L'early-game ne ressemble pas à la fantaisie vendue, et le pont entre les deux n'est ni expliqué ni rythmé.

**Solutions :**
1. **Densifier l'early-game** : autoriser des créneaux après-midi/matin en semaine pour quelques membres, ou démarrer le jeu un vendredi/week-end soir pour une première session peuplée. Réduire la nuit morte (déconnexions plus douces).
2. **Donner un levier de progression actif** : permettre au joueur d'**organiser des sessions de leveling de groupe** qui accélèrent le niveau des membres (au lieu d'attendre les versions serveur), avec un objectif intermédiaire lisible (« amener 5 membres niveau 20 »).
3. **Objectifs en escalier** affichés (niveau 20 → 40 → 60 → 1er héroïque) pour rendre la longue montée vers le héroïque concrète et gratifiante.

---

### Top 5 quick wins gameplay

1. **Bandeau d'objectif permanent** sous le menu (objectif de phase + jauge, lu depuis `PhaseManager.get_requirements_progress()`, cliquable). Tue le « je ne sais pas quoi faire » pour un coût UI minime. *(cf. 2.1)*
2. **Pass audio minimal (6-8 SFX + ambiance)** sur clic/succès/échec/loot/level-up/alerte. Plus gros gain de plaisir par heure investie. *(cf. 2.8)*
3. **Throttle des pauses auto + préférences de pause** à haute vitesse (agréger les événements mineurs, ne pauser que le bloquant). Supprime la friction n°1 du contrôle du temps. *(cf. 2.5)*
4. **Premier conseil `AdvisorManager` poussé au boot** + reformulé pour expliquer le chemin de progression Phase 0 (niveaux → héroïque). Rend l'opacité de l'early-game actionnable sans gros dev. *(cf. 2.1, 2.9)*
5. **Thémer les popups loot/conflit/drama** en réutilisant le pattern d'overlay de `_show_activity_prompt` (composant unique), et fusionner Donjon+Loot en une fenêtre. Cohérence visuelle + moins de clics « Fermer ». *(cf. 2.4)*


---

## 3. Gameplay — Systèmes & Équilibrage

*Audit statique (Read/Grep) de RaidLead, branche `feat/milestones-4-5-ui-polish`. Aucune exécution du jeu. Sévérité : 🔴 Critique (système cassé / progression bloquée), 🟠 Majeur (déséquilibre ou feature inerte), 🟡 Mineur (tuning).*

---

### 3.0 Résumé exécutif

- **Globalement, l'ossature « tourne »** : tous les managers de phase (National, Esport, Cohésion, Conseiller, Équilibrage) sont bien câblés à `GameTime.week_changed`/`day_changed` et alimentés chaque semaine. C'est l'amélioration la plus visible des derniers commits — il y a peu de systèmes totalement morts, contrairement à ce que laissait craindre la liste de signaux inutilisés.
- **Le vrai risque est un déséquilibre économique de fin de partie** : une fois le PvE rodé (raids à 1500-3500 or, héroïques x2, sponsors + streaming + tournois cumulés), les rentrées dépassent largement les sinks (salaires, bootcamps, team-building). À l'inverse, en early-game la trésorerie est **plafonnée à 0 puis 1000 or** (niveaux 1-2), créant une perte d'or silencieuse.
- **Empilement de jauges corrélées** : `energy`, `mood`, `fatigue_accumulated`, `burnout_level`, `stress_level`, `integration`, `satisfaction`/`loyalty`, `celebrity_level`, `guild_morale`. Six d'entre elles bougent dans le même sens lors d'un événement (un wipe baisse mood, monte stress+fatigue, alimente burnout, qui re-baisse mood…). Lisibilité joueur faible, double comptage probable.
- **Bug d'échelle des guildes IA confirmé** : 49 guildes IA en National et **99 en Esport** sont instanciées avec chacune 12-25 membres simulés en `Dictionary` + une simulation mensuelle complète. C'est lourd et l'UI n'affiche qu'un top. Plus grave : la simulation mensuelle ne s'exécute que si `week % 4 == 0`, donc les IA ne progressent **qu'une fois par mois** quel que soit le rythme.
- **Conditions de progression lisibles mais avec angles morts** : Phase 0→1 (1 héroïque) est claire ; Phases 1→2 et 2→3 demandent « rang 1 sur N semaines », or `days_at_rank_1` est partagé entre serveur et national et **remis à zéro dès qu'on perd la 1ʳᵉ place une seule journée** — un sous-classement transitoire annule des semaines de progression sans que le joueur le voie.
- **Plusieurs signaux réellement morts** = features partiellement câblées : `streamer_stopped`, `sponsor_offer_available`, `counter_offer_result`, `relationship_formed`/`relationship_broken`/`social_conflict`/`clique_formed` (jamais écoutés). Le streaming ne « s'arrête » jamais proprement, et les events sociaux ne déclenchent aucune notification ni UI réactive.
- **BalanceManager** est propre et bien câblé (recrutement joueur, rubber-band IA, catch-up, stipend), mais sa **façade `tunable()` ne couvre qu'une fraction des nombres magiques** : difficultés de donjon, seuils de burnout, taux de drama, croissance célébrité, revenus sponsors restent en `const` dispersées.
- **PvE cohérent par niveau** sur le loot (iLvl bien étagé 1→85) mais le **calcul de difficulté de donjon multiplie 4 facteurs non bornés entre eux** (`niveau × équipement × skill`), ce qui rend le résultat très sensible et difficile à équilibrer ; la composition de raid 40 est ramenée à un noyau de 15, ce qui est un choix sain mais sous-documenté.
- **Conseiller (AdvisorManager)** est le meilleur système du lot : il couvre finances, burnout, moral, tensions, roster, équipement et progression de phase, avec une vue « Cette semaine » actionnable. Petit angle mort : il n'alerte pas sur le **débordement de trésorerie** ni sur l'**inactivité des leviers National/Esport** (sponsors signables, tournois disponibles non joués).

**Compte par sévérité : 🔴 2 · 🟠 9 · 🟡 8**

---

### 3.1 Tableau de synthèse

| Système | Branché à la boucle ? | Visible joueur ? | Problème | Reco |
|---|---|---|---|---|
| PhaseManager (progression) | ✅ `day`/`week` | ✅ Fenetre_Personnage | `days_at_rank_1` partagé serveur/national + reset total dès J1 hors top 1 (🟠) | Compteur par scope + tolérance (ex. « rang 1 sur 14 des 18 derniers jours ») |
| Économie / or | ✅ PvE + salaires | ⚠️ partiel | Gains tardifs >> sinks ; plafond 0/1000 or en early-game = or perdu (🔴 early, 🟠 late) | Relever le plancher de stockage ; ajouter sinks récurrents (réparation, entretien) |
| Recrutement (RecruitmentPool) | ✅ `day`/`hour` | ✅ Fenetre_Monde | OK ; pool national 50-100 lourd, `_simulate_competition` 5%/h non scalé phase (🟡) | RAS critique ; brider la fréquence en grands pools |
| AIGuild (progression mensuelle) | ⚠️ `week%4` only | ⚠️ top seulement | IA ne progressent qu'1×/mois ; 99 guildes en Esport = coût + bruit (🟠) | Découpler la cadence ; réduire le nb d'IA réellement simulées (top 20 actif + reste figé) |
| AIGuild (débauchage) | ✅ mensuel + 5%/j | ✅ PoachingPopup | Crédible. `counter_offer_result` jamais émis (🟡) | Émettre le signal ou le supprimer |
| GuildRanking | ✅ `week` + events | ✅ Fenetre_Monde | OK. Score National/Esport ne change la 1ʳᵉ place qu'à la marge (multiplicateurs ±20%) (🟡) | Vérifier que le joueur peut réellement détrôner le top |
| MediaManager (streaming) | ✅ `week` (≥National) | ✅ Fenetre_National | `streamer_stopped` jamais émis : un streamer le reste à vie (🟠) | Émettre l'arrêt quand audience→0 / célébrité chute |
| SponsorshipManager | ✅ `week` (≥National) | ✅ Fenetre_National | `sponsor_offer_available` jamais émis : aucune notif d'offre (🟡) | Émettre au refresh du pool |
| DramaManager | ✅ `week` + media | ✅ Popup National | OK, bien intégré (reput, sponsors, moral) | RAS |
| StaffManager (Esport) | ✅ `week` | ✅ Fenetre_Esport | OK. Bien-être hebdo orchestré | RAS |
| TournamentManager | ✅ `week` (≥Esport) | ✅ Fenetre_Esport | OK. Reput internationale décroît 0.15/sem = pression saine | RAS |
| TransferManager | ✅ `week` | ✅ Fenetre_Esport | OK. Fenêtres + adaptation culturelle fonctionnelles | RAS |
| LegacyManager | ✅ via signaux | ✅ Fenetre_Esport | OK. `_check_titles` re-déclenche `_unlock_title` (déjà gardé) (🟡) | RAS |
| BehaviorSystem (présence dynamique) | ✅ `minute`/`hour`/`day` | ⚠️ indirect | Câblé. `should_connect_dynamic`/`should_disconnect_dynamic` (publics) **jamais appelés** — code mort doublé par `_connection_state_modifier` (🟠) | Supprimer les 2 fonctions mortes ou les utiliser |
| SocialDynamics | ✅ via GuildCulture | ✅ Fenetre_Social | Alimenté chaque semaine. Signaux `relationship_*`/`clique_formed`/`social_conflict` jamais écoutés (🟠) | Brancher des notifs/feedback UI ou retirer les signaux |
| GuildCultureManager (moral) | ✅ `week` | ✅ Fenetre_Social | OK. Contagion + traditions + team-building branchés | RAS |
| AdvisorManager | ✅ `week` | ✅ Fenetre_Conseils | Très bon. Manque alerte débordement or + leviers inactifs (🟡) | Ajouter 2 analyses |
| BalanceManager | ✅ `week` | ✅ Fenetre_Conseils | Bien câblé. Façade `tunable()` partielle (🟡) | Migrer les const de combat/burnout/médias |
| Jauges joueur (6+) | ✅ partout | ⚠️ surcharge | Trop de jauges corrélées, double comptage potentiel (🟠) | Regrouper en 2-3 axes lisibles (Forme / Moral / Lien) |

---

### 3.2 Systèmes morts / orphelins

Grep croisé `signal … / .emit( / .connect(` sur `scripts/` :

- 🟠 **`MediaManager.streamer_stopped`** (`media_manager.gd:7`) — **jamais émis**. `_update_streamers` fait croître/décroître l'audience mais ne repasse jamais `is_streamer = false`, même audience à 0. Un membre devenu streamer le reste indéfiniment → la base de streamers ne fait que croître, gonflant artificiellement audience et revenus. Conséquence d'équilibrage : revenu de streaming jamais « perdu ».
- 🟡 **`SponsorshipManager.sponsor_offer_available`** (`sponsorship_manager.gd:7`) — jamais émis. `_refresh_pool` régénère 8 offres sans notifier. Le joueur doit ouvrir la fenêtre pour découvrir qu'un sponsor est signable.
- 🟡 **`PoachingHandler.counter_offer_result`** (`poaching_handler.gd:8`) — déclaré, jamais émis. La contre-offre (`_on_counter_offer_made`) modifie le moral mais ne renvoie aucun résultat ; `AIGuildManager.simulate_counter_offer_response` existe mais n'est **jamais appelé** depuis le handler → la contre-offre du joueur n'a en fait aucune chance d'échouer/réussir simulée.
- 🟠 **`SocialDynamics`** : `relationship_formed`, `relationship_changed`, `relationship_broken`, `clique_formed`, `social_conflict` — **tous émis mais aucun listener** (seul `GuildCultureManager` lit l'état via getters, pas via signaux). Les relations se forment « en silence » : ni notification, ni rafraîchissement live de Fenetre_Social (qui n'écoute que les signaux de `GuildCultureManager`). Feature riche, ressenti nul.
- 🟠 **`BehaviorSystem.should_connect_dynamic` / `should_disconnect_dynamic`** (`behavior_system.gd:85,147`) — fonctions publiques complètes (modèle fatigue/burnout/humeur/amis) **jamais appelées**. La présence réelle passe par `_check_scheduled_connections` + `_connection_state_modifier` (lignes 538-571), qui ré-implémente la même logique. Code mort en double, source de confusion.
- 🟡 **`BehaviorSystem.relationship_formed`** (`behavior_system.gd:7`) — déclaré sur le BehaviorSystem mais jamais émis (l'émission réelle est dans `SocialDynamics`). Doublon de signal.
- 🟡 **`apply_circadian_modifier`** (`behavior_system.gd:271`) — calcule un modificateur circadien matin/soir mais n'est appelé par aucun chemin de performance/activité repéré. Le « type circadien » n'a donc d'effet que sur l'**heure** de connexion, pas sur la performance annoncée.

**À noter (pas mort) :** `poaching_attempt`, `drama_response_needed`, `tension_detected`, `team_building_done`, `tradition_established`, `transfer_window_opened`, `title_unlocked`, `legacy_earned`, `morale_changed`, `progression_updated`, `guild_position_changed`, `new_server_first`, `staff_pool_refreshed`, `difficulty_changed`, `catchup_applied`, `burnout_level_changed`, `personal_event_triggered`, `behavior_changed` sont **bien écoutés** (main.gd / fenêtres / NotificationManager). Le tissu d'événements de phase est correct.

---

### 3.3 Faisabilité des conditions de progression

**Phase 0 → 1 (`phase_manager.gd:33`)** : `heroic_dungeons_completed >= 1`. Lisible et atteignable (un héroïque niv. 60). ✅ — sous réserve que `DungeonInstance` appelle bien `complete_heroic_dungeon` (corrigé selon la roadmap).

**Phase 1 → 2 (`phase_manager.gd:47-53`)** : `server_rank_position == 1` **pendant 14 jours**, `active_members_min >= 15`, `integration >= 70`, `content_cleared_percent >= 80`.
- 🟠 **Deadlock potentiel sur la durée** : `days_at_rank_1` (`phase_manager.gd:427`) est incrémenté si position == 1, **sinon remis à 0**. Une seule journée de recul (un server first IA, une simulation mensuelle défavorable) annule 13 jours acquis. Le joueur ne voit pas pourquoi sa progression « régresse ». → tolérance glissante recommandée.
- 🟡 **`active_members_min` lit `get_online_members().size()`** (`phase_manager.gd:308`) = membres **connectés à l'instant**, pas membres de la guilde. En early-game peu peuplé (connexions concentrées le soir, cf. roadmap), ce seuil de 15 *connectés simultanément* peut n'être atteint qu'à certaines heures, rendant la vérification hebdomadaire instable.

**Phase 2 → 3 (`phase_manager.gd:62-69`)** : `national_rank_position == 1` **30 jours**, `max_dramas_per_year <= 2`, `active_sponsors >= 1`, `world_first_count >= 3`, `media_reputation >= 75`.
- 🟠 **`days_at_rank_1` est le MÊME compteur** que pour le serveur (`_update_rank_duration` ne distingue pas la phase). Si le joueur était rang 1 serveur puis passe national, le compteur peut être incohérent au changement de phase.
- 🟡 **`world_first_count`** = nb de `server_firsts` au nom de la guilde joueur (`_count_player_world_firsts`). En national, atteindre 3 dépend de battre 99 IA au premier clear — faisable mais opaque (le joueur ne sait pas combien il en a).

**Phase 3 (finale, `phase_manager.gd:78-84`)** : objectifs de maîtrise (`world_championship_wins>=1`, `professional_staff_count>=3`, `international_reputation>=90`, `team_stability>=80`). Pas de phase suivante, donc `check_phase_progression` sort tôt — mais `get_requirements_progress()` (l.447) permet à l'UI/Advisor de les afficher. ✅ Bonne mécanique.

---

### 3.4 Équilibrage économique

**Sources d'or** : clear PvE (donjons 50→275, héroïques x2, raids **1500→3500**, `dungeon_instance.gd:432`), sponsors (60→400/sem × 3 actifs, `sponsorship_manager.gd:19`), part streaming 30% (`media_manager.gd:51`), tournois (1500→12000, `tournament_manager.gd`), catch-up + stipend (`balance_manager.gd:169-184`).

**Sinks d'or** : salaires nationaux (`get_meta("salary")`, 10-100/sem), salaires staff (200-380/sem × 6, `staff_manager.gd:63`), commission d'agent (one-shot), bootcamp (2000), team-building (300-1200), traditions (500-1500 one-shot), prime de transfert (4 sem salaire + commission).

- 🔴 **Plancher de trésorerie cassé en early-game** : `gold_storage` vaut **0 aux niveaux 1-2** (`guild_perks_data.gd:114`), 1000 au niveau 3, 9000 au niveau 5. À 0, `add_gold` ne plafonne pas (l.88-90, branche « non plafonnée »), donc OK ; **mais dès le niveau 3 le cap de 1000 or** est trivial à atteindre (un seul raid en rapporte 1500-3500) → `_notify_gold_overflow` détruit l'excédent. Le joueur perd massivement de l'or juste après avoir débloqué les raids, avant le palier de stockage suivant. Incohérence : on débloque les gains avant le stockage.
- 🟠 **Accumulation non bornée en fin de partie** : au niveau 10, `gold_storage = 200000`. Avec 3 sponsors haut de gamme (~1000/sem), streaming, et tournois, les rentrées hebdo dépassent largement la masse salariale (même 6 staff + 10 salariés ≈ 3000-4000/sem). Aucun sink récurrent proportionnel aux revenus → le joueur tend vers le cap et y reste. Le `gold_overflow` devient un « bruit » permanent plutôt qu'un signal utile.
- 🟡 **Pas de coût d'entretien récurrent** : seuls les salaires sont récurrents. Pas de réparation d'équipement, pas de loyer/infrastructure, pas de coût de raid (consommables). La boucle « farmer pour payer » disparaît une fois les salaires couverts.
- 🟡 **Nombres magiques dispersés** : `BOOTCAMP_COST=2000`, `TRANSFER_FEE_WEEKS=4`, revenus sponsors en `const` de template, gold_reward par donjon en data. Seul `pve.gold_reward_mult` passe par `BalanceManager` ; les sinks ne sont pas tunables.

**Verdict** : le joueur ne peut quasiment pas faire faillite (catch-up + stipend en difficulté Détendu, gains PvE garantis), et finit riche sans levier de dépense. L'or n'est une contrainte que dans une fenêtre étroite (transition vers les salaires nationaux).

---

### 3.5 Équilibrage PvE (donjons, loot, auto-équipement)

- ✅ **Loot bien étagé** (`loot_tables.gd:175`) : iLvl 1-15 (niv 1-20) → 50-65 (niv 51-60) → +10-15 héroïque. Cohérent. Raretés 60/30/8/2 (héroïque 40/35/20/5). Budget de stats par slot × rareté propre.
- 🟠 **Calcul de difficulté multiplicatif fragile** (`dungeon_data.gd:331-367`) : `score = penalité_niveau × (avg_equipment / (level_reco×3)) × (avg_skill / 50)`. Trois ratios non bornés se multiplient. Un groupe sur-équipé **et** sur-skillé voit son score exploser (clampé à 2.0), un groupe sous-équipé s'effondre (0.9^Δniveau). La courbe est très raide et difficile à régler — un petit écart d'iLvl change radicalement l'issue. → préférer une somme pondérée bornée.
- 🟡 **`expected_equipment = level_recommended × 3`** (l.361) est un nombre magique non documenté et non aligné sur la courbe d'iLvl réelle de `loot_tables` (qui à niv 55 donne ~57 iLvl, pas 165). Un groupe « correctement » équipé selon le loot du jeu sera donc systématiquement **sous** la cible → malus permanent. Possible biais de difficulté à la hausse.
- 🟡 **Composition raid 40 → noyau de 15** (`dungeon_data.gd:322`) : choix de design sain (jouable avec un roster de guilde) mais le malus de sous-effectif « lore » repose sur la difficulté de contenu, pas explicité au joueur.
- 🟡 **`get_boss_loot_chance`** : 30% / 80% boss final (+20% héroïque). Raisonnable, mais combiné à 3-6 items par table, un raid de 10 boss peut générer beaucoup de loot → alimente le débordement de banque (cap 60) et d'or.

---

### 3.6 IA concurrentes

- 🟠 **Bug d'échelle confirmé** : `GUILD_COUNT_BY_PHASE` = 9 / **49** / **99** (`ai_guild_manager.gd:13-17`). En Esport, 99 `AIGuild` chacune avec 12-25 membres `Dictionary` + `simulate_monthly_progress` (PvE, recrutement, turnover, réputation) + débauchage croisé. Coût mémoire/CPU réel, alors que l'UI ne montre qu'un top. La roadmap le notait comme « observation mineure » ; c'est en réalité un **problème de perf + de bruit** (server firsts répartis sur 99 guildes → le joueur en décroche peu).
- 🟠 **Progression IA seulement mensuelle** : `_run_monthly_simulation` ne s'exécute que si `week % 4 == 0` (`ai_guild_manager.gd:301`). Entre deux, les IA sont **figées** (réputation, clears, niveau). À haute vitesse de jeu, le joueur progresse en continu tandis que les IA avancent par paliers d'un mois → classement en marches d'escalier peu crédible.
- ✅ **Rubber-band** (`ai_guild.gd:236` via `get_ai_progression_mult`) : +5%/sem de dominance au-delà de 2 semaines, max +25%. Sain et borné.
- ✅ **Débauchage** crédible : ciblage des membres peu intégrés/insatisfaits, offres par stratégie, probabilité bornée 0.05-0.85, risque célébrité ajouté. Bonne profondeur.
- 🟡 **Réputation IA dérive vers 50** (`ai_guild.gd:379`) : toutes les IA convergent vers la moyenne, écrasant la diversité des stratégies à long terme.

---

### 3.7 Systèmes redondants — la forêt de jauges

Sur `SimulatedPlayer` (+ guilde) coexistent : `energy` (0-100), `mood` (0-100), `fatigue_accumulated` (0-100), `burnout_level` (0-3, dérivé de fatigue), `stress_level` (0-100, « distinct de fatigue » dixit le commentaire l.77), `integration` (0-100), `satisfaction`/`loyalty`, `celebrity_level`, et au niveau guilde `guild_morale` (0-100).

- 🟠 **Corrélation et double comptage** : un wipe ou un bootcamp ajoute `stress` (`tournament_manager`), un raid ajoute `fatigue` (`behavior_system._update_fatigue_levels`), `burnout` est dérivé de `fatigue` et **re-soustrait du mood** (`update_burnout_level` l.368-377), tandis que `stress` alimente aussi `get_burnout_risk()`. Mood baisse donc via 3 canaux pour un même événement. `team_stability` (`phase_manager._compute_team_stability`) combine mood+integration−stress−burnout : il agrège des jauges déjà corrélées.
- 🟠 **Lisibilité joueur** : difficile de savoir quel levier actionner. `fatigue` et `stress` sont conceptuellement le même axe (« usure ») avec des sources différentes ; `mood` et `guild_morale` se chevauchent (morale = moyenne des mood + santé sociale).
- **Reco** : fusionner en **3 axes lisibles** — *Forme* (energy+fatigue+burnout), *Moral* (mood+stress, individuel), *Lien* (integration+relations sociales). Garder `celebrity_level` à part (axe National). Cela réduirait aussi le double comptage dans `team_stability`.

---

### 3.8 BalanceManager

- ✅ **Câblage** : presets RELAXED/NORMAL/HARD bien définis ; `get_recruit_chance_mult` lu par `recruitment_pool.attempt_recruitment:280` ; `get_ai_progression_mult` lu par `ai_guild._simulate_pve_progression:239` ; catch-up + stipend appliqués chaque semaine. `compute_standing` (rang + trésorerie + moral) est une bonne heuristique de « galère/domination ».
- 🟡 **Façade `tunable()` incomplète** : le dictionnaire `BALANCE` couvre recrutement, salaires impayés, scout, quelques malus PvE et les poids de ranking. Mais **les leviers les plus impactants restent hors façade** : difficultés de donjon, seuils de burnout (50/70/90), taux de drama (0.10-0.15), croissance de célébrité, revenus/durées sponsors, coûts bootcamp/transfert/team-building. La promesse « équilibrer sans éditer 15 scripts » n'est tenue qu'à moitié.
- 🟡 **`ranking.weight.*` est un miroir mort** de `GuildRanking.SCORE_WEIGHTS` : les deux dictionnaires coexistent sans que `GuildRanking` lise la façade. Risque de désynchronisation.

---

### 3.9 Conseiller (AdvisorManager)

- ✅ **Excellente couverture** : finances (salaires vs or), burnout/stress, moral, tensions/inimitiés, places de roster, équipement sous-niveau, progression de phase (avec labels FR lisibles par requirement). La vue `get_weekly_summary()` (membres à risque, objectifs triés par % accessible, contenu conseillé, recrutement) est exactement le bon niveau d'aide pour un jeu de gestion.
- 🟡 **Angles morts** :
  - Pas d'alerte sur le **débordement de trésorerie** (or perdu au cap) — pourtant détecté par `Guild._notify_gold_overflow`.
  - Pas d'incitation à **utiliser les leviers National/Esport inactifs** : sponsors signables non signés, tournois disponibles non joués, fenêtre de transfert ouverte. Le joueur peut stagner sans savoir qu'une opportunité dort.
  - `_analyze_equipment` utilise un seuil dur `iLvl < 120` au niveau 60, qui ne correspond pas à la courbe de `loot_tables` (un niv 60 plafonne vers ~85 hors raid). Le conseil peut s'afficher en permanence.

---

### 3.10 Top 5 quick wins systèmes

1. **🔴 Réparer le plancher de stockage d'or early-game** (`guild_perks_data.gd`) : relever `gold_storage` aux niveaux 1-3 (ex. 3000/5000) ou retarder l'accès aux raids, pour ne plus détruire l'or juste après les avoir débloqués. Une ligne de data, impact immédiat sur la frustration.

2. **🟠 Corriger la durée de rang 1** (`phase_manager.gd:427`) : remplacer le reset brutal de `days_at_rank_1` par une fenêtre glissante (« 14 des 18 derniers jours au rang 1 ») et **séparer les compteurs serveur / national**. Débloque une progression aujourd'hui fragile, sans nouveau système.

3. **🟠 Émettre `streamer_stopped`** (`media_manager.gd`) : repasser `is_streamer=false` quand l'audience tombe à 0 ou que la célébrité passe sous le seuil, et émettre le signal. Stoppe la croissance non bornée des revenus de streaming et redonne du sens à la gestion média.

4. **🟠 Découpler la cadence des IA et réduire le nombre simulé** (`ai_guild_manager.gd`) : simuler la progression IA **chaque semaine** (pas tous les 4) et ne faire tourner la simulation lourde que sur un « top actif » (~20 guildes), les autres restant des entrées de classement figées. Gain de perf + classement crédible.

5. **🟠 Ajouter deux analyses au Conseiller** (`advisor_manager.gd`) : (a) alerte de débordement de trésorerie avec suggestion de sink (team-building, tradition, staff) ; (b) opportunité « levier inactif » (sponsor signable / tournoi disponible / fenêtre de transfert ouverte). Réutilise l'infrastructure existante, comble le trou d'engagement fin de partie.

*Bonus tuning 🟡 : remplacer le calcul de difficulté de donjon multiplicatif par une somme pondérée bornée, et aligner `expected_equipment` (`dungeon_data.gd:361`) sur la vraie courbe d'iLvl de `loot_tables`.*


---

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


---

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


---

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


---


---

# Partie B — Audit complémentaire (passe statique multi-agents)

*Cette passe a été réalisée séparément (analyse statique pure, 4 sous-agents, sans accès MCP au jeu ce jour-là — d'où le texte sans accents conservé tel quel). Elle **recoupe parfois la Partie A** : ces recoupements valent **confirmation croisée**. Ses apports **uniques** les plus précieux (intégrés dans la synthèse exécutive sous les codes C9–C16 et les « majeurs Partie B ») : tick des donjons non branché, fuite d'activité au repos, `EffectSystem`, blocage des événements, divergence des rôles UI/combat, assets 1024 px en icônes, autoloads MCP en runtime, layout non responsive. Le backlog priorisé et la conclusion ci-dessous restent d'actualité.*



Date : 2 juin 2026  
Perimetre : UI, ergonomie de gameplay, proprete du code, scenes, assets, performances et outillage.  
Methode : audit principal + 4 sous-agents specialises.

## Resume executif

RaidLead a une base solide et deja tres riche : simulation de guilde, activites, PvE, recrutement, phases, IA, sauvegarde, UI multi-fenetres et tests maison. Le probleme principal n'est pas le manque de systemes, mais la coherence entre eux. Plusieurs fonctionnalites existent cote donnees, UI ou simulation, mais leur contrat runtime diverge, ce qui peut donner au joueur des informations vraies dans l'interface mais fausses dans le moteur.

Les priorites les plus importantes sont :

1. Stabiliser la boucle jouable centrale : activite du joueur, organisation de groupe, progression de donjon, rapport de run, loot et consequences.
2. Corriger les incoherences UI qui contournent l'etat reel : raccourcis ignores par les verrous de phase, fermeture des fenetres par simple `hide()`, layouts fixes, panneaux sans scroll.
3. Remettre d'equerre les contrats techniques : signaux, typage, source de verite des roles, tick des donjons, effets actifs, notifications.
4. Reduire la dette de production : autoloads MCP en runtime, assets 1024 utilises comme icones, gros ecrans UI construits en code, outils de validation instables.

## Methode et limites

Sous-agents utilises :

- Agent UI : audit des scenes et scripts UI, ergonomie, responsive, accessibilite.
- Agent gameplay : audit boucle de jeu, progression, feedback, equilibrage et etats incoherents.
- Agent code : audit architecture, typage, signaux, tests, dette structurelle.
- Agent scenes/perf/assets : audit scenes, imports, assets, complexite et configuration projet.

Exploration locale effectuee :

- Lecture de `project.godot`, `scripts/**`, `scenes/**`, `tests/**`, `docs/**`.
- Recherche statique de tailles fixes, signaux, `load/preload`, TODO, patterns UI, variables non typees.
- Tentative de validation via Godot 4.6.2 :
  - `CheckScripts.tscn` a crashe le binaire Godot avec signal 11 apres environ 133 s.
  - `TestRunner.tscn` a egalement crashe le binaire quand lance en parallele lors de la premiere tentative.
- Tentative MCP Godot :
  - L'editeur Godot a ete demarre avec `--rendering-driver opengl3`.
  - Le port `127.0.0.1:6505` a bien montre une connexion TCP.
  - Les commandes MCP ont toutefois continue a repondre : "Godot editor is not connected".
  - L'audit final s'appuie donc surtout sur l'analyse statique et les sous-agents.

Point positif : l'audit scenes/assets n'a pas trouve de references `res://` cassees dans `project.godot`, `.tscn` ou `.gd`, ni de `.png` sans `.import`, ni de `.import` pointant vers une source absente.

## P0 - Bloquants ou incoherences fortes

### Les donjons actifs risquent de ne jamais progresser

Constat :

- `scripts/systems/activity_manager.gd:35` connecte `GameTime.minute_changed`.
- `_on_minute_changed` appelle `_update_all_activities()` autour de `scripts/systems/activity_manager.gd:104`.
- `update_dungeons()` existe autour de `scripts/systems/activity_manager.gd:440`, mais n'est pas appele dans le flux temporel principal.
- `DungeonInstance.update()` porte pourtant la progression reelle autour de `scripts/systems/dungeon_instance.gd:110`.

Impact :

- Un donjon peut etre lance, mais ne pas avancer naturellement avec le temps de jeu.
- La fenetre de donjon peut donner une promesse de run vivant alors que le moteur ne tick pas.

Quick win :

- Appeler `update_dungeons()` depuis le tick minute ou heure de `ActivityManager`.
- Ajouter un test qui lance un donjon, avance le temps, puis verifie que `current_boss_index`, `current_position` ou l'etat de run evolue.

Chantier :

- Creer un vrai controleur PvE qui possede le cycle `start -> tick -> boss -> loot -> report -> history`.

### Le repos du joueur peut laisser l'ancienne activite produire des gains

Constat :

- Le repos est orchestre dans `scripts/main.gd:848`.
- `PlayerCharacter.disconnect_player()` autour de `scripts/resources/player_character.gd:203` ne retire pas explicitement l'activite active cote `ActivityManager`.
- `ActivityManager` peut continuer a appliquer XP, or, moral ou integration autour de `scripts/systems/activity_manager.gd:446`.

Impact :

- Le joueur "se repose" mais peut continuer a progresser en arriere-plan.
- Le feedback d'energie et de session devient peu fiable.

Quick win :

- Interrompre explicitement l'activite courante avant tout repos.
- Dans `ActivityManager`, ignorer tout tick si le joueur est offline ou si `player.current_activity == null`.

Chantier :

- Unifier online/offline/repos/activite sous une seule source de verite, avec transitions explicites.

### Les roles UI et les roles combat divergent

Constat :

- L'organisation utilise `member.get_role()` dans `scripts/ui/windows/fenetre_organisation_groupe.gd:765`.
- Le calcul de composition donjon lit `member.personnage_role` dans `scripts/systems/dungeon_instance.gd:274`.
- Certaines recrues ou le joueur peuvent avoir `personnage_role` vide ou non synchronise.

Impact :

- L'UI peut afficher un groupe valide.
- Le combat peut le penaliser comme groupe sans tank, heal ou DPS.

Quick win :

- Utiliser `get_role()` dans `DungeonInstance._check_group_composition()`.
- Ou initialiser et maintenir `personnage_role` partout a la creation et au chargement.

Chantier :

- Remplacer les strings de role par un enum ou une constante canonique.

### Binding de signaux probablement casse dans EffectSystem

Constat :

- `EffectInstance.expired` emet deja l'instance dans `scripts/resources/effect_instance.gd:14`.
- `EffectSystem` bind aussi `target_id, effect_instance` dans `scripts/systems/effect_system.gd:67`.
- Les arguments bindes Godot sont ajoutes apres ceux du signal.
- Le disconnect teste ensuite un Callable non binde autour de `scripts/systems/effect_system.gd:119`.

Impact :

- Risque d'appel avec trop d'arguments.
- Risque de signaux non deconnectes.
- Les effets temporaires peuvent devenir une source d'erreurs runtime difficiles a tracer.

Quick win :

- Stocker les `Callable` bindes dans une table.
- Ou utiliser des lambdas a signature exacte :
  - `func(inst): _on_effect_expired(target_id, inst)`
  - `func(inst, count): _on_effect_stack_changed(target, inst, count)`

Chantier :

- Ajouter des tests d'application, stack, expiration et suppression d'effet.

### Fermer un evenement peut bloquer tous les futurs evenements

Constat :

- `EventManager` bloque les nouveaux tirages si `pending_event` est non nul dans `scripts/autoloads/event_manager.gd:65`.
- Fermer la popup via `scripts/ui/windows/event_popup.gd:248` reprend le temps et ferme l'UI, mais ne resout pas l'evenement.

Impact :

- Un joueur qui ferme ou quitte une popup peut bloquer la file d'evenements.
- Le systeme d'evenements devient silencieusement inerte.

Quick win :

- Rendre la popup vraiment modale et impossible a fermer sans choix.
- Ou transformer la fermeture en choix explicite "Ignorer", qui appelle `EventManager.resolve_event()`.

Chantier :

- Ajouter une file d'evenements robuste : pending, ignored, resolved, expired.

### Conflit de loot et abandon de donjon ont des proprietaires multiples

Constat :

- Le conflit de loot pause le jeu et active `_loot_dialog_active` dans `scripts/main.gd:470`.
- Seuls certains boutons nettoient l'etat.
- L'abandon de donjon emet `abandon_requested` puis appelle aussi `_abandon_dungeon()` dans `scripts/ui/windows/fenetre_donjon.gd:291`.
- Le parent reagit aussi a `abandon_requested` dans `scripts/ui/windows/fenetre_organisation_groupe.gd:749`.

Impact :

- Fermeture de popup = risque de jeu bloque.
- Abandon = consequences potentiellement appliquees deux fois.

Quick win :

- Un seul proprietaire de l'abandon.
- Rendre `_abandon_dungeon()` idempotent avec `if not is_active: return`.
- Desactiver la fermeture des popups critiques ou fournir une resolution par defaut.

Chantier :

- Centraliser les decisions modales de run dans un `RunDecisionController`.

## P1 - UI et ergonomie

### Les raccourcis clavier contournent les verrous de phase

Constat :

- Les boutons `National` et `Esport` sont verrouilles via `scripts/ui/components/menu_bar.gd:64`.
- Les raccourcis dans `scripts/main.gd:380` appellent directement les handlers.

Impact :

- Le joueur peut ouvrir des fenetres supposees verrouillees.
- Le systeme de progression perd de sa credibilite.

Quick win :

- Centraliser l'ouverture dans une methode `try_show_window(window_name)`.
- Cette methode verifie les locks de phase, puis appelle `WindowManager.show_window()`.

Chantier :

- Faire du menu une source unique de navigation, avec etats `locked`, `available`, `active`.

### Fermeture incoherente des fenetres

Constat :

- Plusieurs boutons `X` appellent simplement `hide()`.
- Exemples :
  - `scripts/ui/windows/fenetre_personnage.gd:370`
  - `scripts/ui/windows/fenetre_monde.gd:1203`
  - `scripts/ui/windows/fenetre_guilde.gd:482`
- `WindowManager` garde alors la fenetre comme ouverte/active.

Impact :

- Bouton de menu actif incorrect.
- Layout sauvegarde et z-order moins fiables.
- L'utilisateur ne sait pas si la fenetre est fermee ou masquee.

Quick win :

- Emettre `close_requested` partout.
- Laisser `WindowManager.close_window()` gerer fermeture, sauvegarde et etat actif.

Chantier :

- Introduire une base commune de fenetre ou un composant `ManagedWindow`.

### Layout non responsive

Constat :

- `project.godot:54` force `viewport_width=1920`.
- `project.godot:56` force `window/size/resizable=false`.
- La barre de menu a 8 boutons de 150 px plus separations de 20 px dans `scripts/ui/components/menu_bar.gd:28` et `:87`.

Impact :

- Le jeu est fragile en 1366x768, 1600x900, Steam Deck, fenetre reduite ou capture.
- L'UI peut deborder ou compresser les contenus.

Quick win :

- Autoriser le resize en dev.
- Tester 1366x768, 1600x900, 1920x1080.
- Reduire les boutons de menu ou passer en deux lignes si necessaire.

Chantier :

- Definir des tailles min/max par fenetre et un menu adaptatif avec overflow.

### Positions de fenetres restaurees sans clamp

Constat :

- `WindowManager` restaure position et taille autour de `scripts/managers/window_manager.gd:263`.
- Les positions sauvegardees ne sont pas revalidees contre la taille actuelle du viewport.
- Les drags de certaines fenetres ne clampent pas non plus, par exemple `scripts/ui/windows/fenetre_monde.gd:53`.

Impact :

- Une fenetre peut revenir hors ecran.
- Une resolution plus petite peut rendre une vue inutilisable.

Quick win :

- Ajouter `_keep_window_on_screen(window)` apres restore, drag et resize.

Chantier :

- Sauvegarder les layouts par resolution ou normaliser en pourcentage.

### Scroll et wrapping incomplets

Constat :

- Le panneau detail recrutement manque de scroll/wrap sur certaines zones autour de `scripts/ui/windows/fenetre_monde.gd:263`, `:515`, `:740`.
- `Fenetre_Guilde` utilise plusieurs tailles fixes autour de `scripts/ui/windows/fenetre_guilde.gd:135`.

Impact :

- Textes longs tronques ou compresses.
- Les candidats/membres avec beaucoup de tags ou infos deviennent difficiles a lire.

Quick win :

- Ajouter `ScrollContainer` aux panneaux detail.
- Mettre `autowrap_mode` sur les descriptions.
- Mettre `clip_text` ou taille min sur les valeurs longues.

Chantier :

- Extraire un composant `DetailPanel` reutilisable.

### Fenetre Donjon construite de facon incoherente

Constat :

- `scenes/Fenetre_Donjon.tscn:20` contient un `ResizableWindow`.
- Le vrai `VBoxContainer` de contenu est un frere, pas un enfant, autour de `scenes/Fenetre_Donjon.tscn:23`.
- `scripts/ui/components/resizable_window.gd:20` cree pourtant sa propre structure de titre/contenu.

Impact :

- Le composant reusable ne sert pas correctement.
- Risque de confusion pour resize, focus, fermeture et theming.

Quick win :

- Supprimer le noeud s'il est decoratif/inutile.
- Ou mettre tout le contenu dans `ResizableWindow.content_container`.

Chantier :

- Standardiser toutes les fenetres sur la meme structure de scene.

### Accessibilite et interactions alternatives

Constat :

- Beaucoup d'etats reposent sur couleur, emoji ou icone seule.
- L'organisation de groupe depend fortement du drag and drop autour de `scripts/ui/windows/fenetre_organisation_groupe.gd:302`.

Impact :

- Interaction plus difficile au clavier, trackpad ou pour joueurs daltoniens.
- Les roles/risques peuvent manquer de libelles explicites.

Quick win :

- Tooltips sur roles, slots et boutons.
- Libelles textuels en plus de la couleur.
- Double-clic ou bouton "Assigner" en alternative au drag and drop.

Chantier :

- Navigation clavier complete sur menu, listes, slots et popups.

## P1 - Gameplay et lisibilite de la boucle

### L'activite Fun est selectionnable mais pas composable

Constat :

- `_populate_fun_list()` ajoute des activites dans `scripts/ui/windows/fenetre_organisation_groupe.gd:239`.
- `_update_group_composition()` affiche seulement "Participants illimite" autour de `scripts/ui/windows/fenetre_organisation_groupe.gd:281`.
- `_launch_fun_activity()` lit ensuite les slots autour de `scripts/ui/windows/fenetre_organisation_groupe.gd:614`, mais aucun slot n'existe.

Impact :

- Le joueur peut selectionner une activite qui ne peut pas etre lancee correctement.

Quick win :

- Cacher Fun de cette fenetre.
- Ou ajouter une vraie selection multi-participants.

Chantier :

- Donner a Fun une boucle utile : moral, cohesion, fatigue, relations, cout ou opportunite.

### Le contenu endgame est presente trop tot

Constat :

- Tous les donjons et heroiques sont listes dans `scripts/ui/windows/fenetre_organisation_groupe.gd:219`.
- Les heroiques sont niveau 60 dans `scripts/data/dungeon_data.gd:369`.
- La premiere phase demande pourtant deja un donjon heroique dans `scripts/systems/phase_manager.gd:28`.

Impact :

- La progression donne l'impression de sauter directement vers le endgame.
- Le joueur ne comprend pas le prochain objectif naturel.

Quick win :

- Filtrer ou verrouiller les instances par phase, niveau moyen, serveur version et progression.
- Afficher "verrouille" et la raison.

Chantier :

- Refaire les paliers :
  - leveling solo/guilde
  - premiers donjons normaux
  - preparation niveau 60
  - heroiques
  - raids

### Le recrutement manque de causalite lisible

Constat :

- La chance depend de nombreux modificateurs dans `scripts/autoloads/recruitment_pool.gd:241`.
- L'UI utilise encore des flags hardcodes/TODO dans `scripts/ui/windows/fenetre_monde.gd:776`.

Impact :

- Le joueur ne comprend pas pourquoi une recrue accepte ou refuse.
- Les choix de reputation, taille de guilde, attentes et succes recents sont peu actionnables.

Quick win :

- Afficher une estimation par bande : faible, moyenne, elevee.
- Montrer les 2 ou 3 principaux modificateurs.

Chantier :

- Transformer le recrutement en mini-negociation : promesse de role, salaire, raid spot, culture, scouting.

### Certains effets comportementaux comparent enum et strings

Constat :

- Dans `scripts/systems/behavior_system.gd:450`, `member.current_activity.type` est compare a `"RAID"`, `"DUNGEON"`, etc.
- `Activity.type` est un enum dans `scripts/resources/activity.gd`.

Impact :

- Fatigue, burnout et preferences peuvent etre mal ponderes.
- Le joueur voit des consequences comportementales moins fiables.

Quick win :

- Comparer a `Activity.ActivityType.RAID`, `DUNGEON`, etc.

Chantier :

- Centraliser les couts comportementaux des activites dans `Activity` ou `BalanceManager`.

### Un evenement peut faire quitter le personnage joueur

Constat :

- `random_member_leave` choisit dans toute la guilde autour de `scripts/autoloads/event_manager.gd:307`.
- Le joueur est un membre special cree par `GuildManager` autour de `scripts/autoloads/guild_manager.gd:348`.

Impact :

- Un evenement aleatoire peut retirer le personnage joueur.

Quick win :

- Exclure `is_player` et tout membre protege.

Chantier :

- Introduire des tags de protection : joueur, fondateur, story-critical.

### Rapport de session du joueur surestime les gains de niveau

Constat :

- `levels_gained = personnage_niveau - 1` autour de `scripts/resources/player_character.gd:317`.
- Ce n'est pas un gain de session, mais l'ecart depuis le niveau 1.

Impact :

- Le rapport de session trompe le joueur.

Quick win :

- Stocker `session_start_level`.
- Calculer `levels_gained = personnage_niveau - session_start_level`.

Chantier :

- Produire un vrai rapport de session : activites, XP, or, fatigue, loot, objectifs avances.

## P1 - Code, architecture et signaux

### Drift de signaux dans NotificationManager

Constat :

- `NotificationManager` cherche `member_left` et `pool_updated` autour de `scripts/managers/notification_manager.gd:89`.
- `GuildManager` declare `member_recruited`, mais pas `member_left`, autour de `scripts/autoloads/guild_manager.gd:7`.
- `RecruitmentPool` expose `pool_refreshed`, pas `pool_updated`, autour de `scripts/autoloads/recruitment_pool.gd:3`.

Impact :

- Notifications manquantes silencieusement.
- Le joueur perd des feedbacks essentiels.

Quick win :

- Aligner noms de signaux et abonnements.
- Ajouter une verification de connectivite des signaux au demarrage debug.

Chantier :

- Introduire un event bus typable ou un inventaire de signaux documente.

### Trop d'autoloads et dependances globales

Constat :

- `project.godot` charge environ 25 autoloads.
- `SaveManager` connait de nombreux systemes un par un autour de `scripts/autoloads/save_manager.gd:56`.
- `GuildManager` instancie `PoachingHandler` et `BehaviorSystem` autour de `scripts/autoloads/guild_manager.gd:373`.

Impact :

- Ordre d'initialisation fragile.
- Tests plus difficiles.
- Sauvegarde fortement couplee au modele global.

Quick win :

- Identifier les autoloads strictement necessaires.
- Ajouter des facades publiques plutot que des acces directs a tout.

Chantier :

- Garder en autoload seulement temps, save, event bus/facade et services transverses.
- Regrouper les managers metier sous un `GameSystems`.

### Typage insuffisant pour la regle du repo

Constat statique du sous-agent code :

- Environ 1 903 `var x =`.
- Environ 758 fonctions sans `->`.
- Environ 690 `Array`/`Dictionary` non parametres.
- Exemples :
  - `scripts/main.gd:22`
  - `scripts/managers/window_manager.gd:16`
  - `scripts/systems/activity_manager.gd:44`

Impact :

- Le code ne respecte pas encore la consigne "GDScript typage systematique".
- Les erreurs de contrat role/activite/signaux sont plus faciles a rater.

Quick win :

- Commencer par autoloads et systems, pas par toute l'UI.
- Typer les signatures publiques d'abord.

Chantier :

- Activer une discipline de migration par module :
  - `ActivityManager`
  - `DungeonInstance`
  - `GuildManager`
  - `RecruitmentPool`
  - `WindowManager`

### Fenetres UI trop grosses et trop metier

Constat :

- `scripts/ui/windows/fenetre_monde.gd` depasse 1 100 lignes.
- `scripts/main.gd` approche 1 000 lignes.
- `scripts/ui/windows/fenetre_personnage.gd` approche 1 000 lignes.
- `Fenetre_Monde` gere a la fois presentation, progression, classement et recrutement.

Impact :

- Maintenance lente.
- Tests UI difficiles.
- Les changements d'equilibrage peuvent modifier des fichiers UI.

Quick win :

- Extraire des helpers de presentation :
  - `RecruitmentPresenter`
  - `RankingPresenter`
  - `MemberDetailPresenter`

Chantier :

- Decouper les gros ecrans en composants Godot reutilisables.

### UI construite massivement en code

Constat :

- Les scenes `.tscn` sont legeres.
- De nombreux noeuds sont crees par script :
  - `fenetre_monde.gd` et `fenetre_personnage.gd` ont chacun de nombreuses occurrences `add_child`.
- `WindowManager.show_window()` cache les autres fenetres puis force un refresh autour de `scripts/managers/window_manager.gd:106` et `:118`.

Impact :

- Les scenes sont peu inspectables via l'editeur.
- Les refresh peuvent reconstruire beaucoup de noeuds.
- Les etats d'interaction peuvent etre perdus.

Quick win :

- Ajouter des flags `dirty`.
- Rafraichir seulement si les donnees ont change.
- Ne pas rebuild pendant une interaction utilisateur.

Chantier :

- Migrer les blocs UI stables vers scenes/composants.

## P2 - Assets, performances et production

### Assets 1024 utilises comme icones

Constat :

- Les assets generes sont de gros PNG, souvent autour de 300 a 600 Ko.
- Exemple : `assets/generated/classes/mage.png.import` conserve une source 1024.
- Ces images sont utilisees comme icones de menu, portraits miniatures et icones de stats :
  - `scripts/ui/components/menu_bar.gd:89`
  - `scripts/ui/windows/fenetre_guilde.gd:198`
  - `scripts/ui/components/stat_display.gd:106`

Impact :

- Memoire GPU inutile.
- Chargements plus lourds.
- Risque de rendu flou ou cout de downscale permanent.

Quick win :

- Generer ou importer des variantes :
  - 32 px pour petites icones.
  - 64 px pour roles/classes.
  - 128 px pour portraits.
  - 256 px pour banniere/illustration.

Chantier :

- Ajouter un manifest d'assets avec taille cible et usage.
- Ajouter un test CI qui refuse les icones UI en 1024.

### Banniere de donjon incomplete

Constat :

- `AssetLoader` construit dynamiquement `assets/generated/dungeons/<id>.png` autour de `scripts/autoloads/asset_loader.gd:120`.
- `DungeonData` contient plus de cles que les 6 images existantes.
- Manquants signales : `gnomeregan`, `uldaman`, `zul_farrak`, `stratholme`, `scholomance`, `onyxias_lair`, `blackwing_lair`, `zul_gurub`.

Impact :

- Certaines instances auront un rendu absent ou fallback silencieux.

Quick win :

- Ajouter placeholder explicite + warning debug.

Chantier :

- Registre contenu qui valide `DungeonData` vers assets.

### Services MCP actifs comme autoloads runtime

Constat :

- `project.godot` inclut :
  - `MCPScreenshot`
  - `MCPInputService`
  - `MCPGameInspector`
- Ces services font du polling `_process()` et de l'IPC fichier :
  - `addons/godot_mcp/mcp_screenshot_service.gd:13`
  - `addons/godot_mcp/mcp_input_service.gd:16`
  - `addons/godot_mcp/mcp_game_inspector_service.gd:59`

Impact :

- Outils dev charges dans le runtime si non exclus.
- Potentiel bruit performance et surface d'export inutile.

Quick win :

- Les desactiver hors debug ou export release.

Chantier :

- Presets export dev/prod separes.

### TimeDisplay met a jour l'heure chaque frame

Constat :

- `scripts/ui/components/time_display.gd:54` met a jour via `_process`.
- `GameTime` emet deja des signaux temporels autour de `scripts/autoloads/game_time.gd:54`.

Impact :

- Polling UI permanent inutile.

Quick win :

- Mettre a jour a la minute ou via `minute_changed`.

Chantier :

- Revoir tous les timers/pollings UI et basculer vers signaux.

### Donnees metier surtout en scripts/dictionnaires

Constat :

- Peu ou pas de `.tres/.res` metier.
- Beaucoup de data vivent dans des scripts statiques ou dictionnaires.

Impact :

- Validation editeur limitee.
- Diff plus verbeux.
- Moins facile de faire des outils contenu.

Quick win :

- Documenter quelles donnees restent en script et pourquoi.

Chantier :

- Migrer progressivement donjons, perks, events ou loot tables vers Resources Godot.

## P2 - Outillage et tests

### Validation Godot instable sur cette machine

Constat :

- `CheckScripts.tscn` et `TestRunner.tscn` ont crashe Godot 4.6.2 avec signal 11 lors de cet audit.
- Les tentatives ont respecte `--rendering-driver opengl3`.
- La relance solo avec `GALLIUM_DRIVER=d3d12` a aussi crashe apres environ 133 s.

Impact :

- Impossible de certifier la compilation depuis cette passe.
- Les prochains chantiers doivent d'abord retrouver une validation fiable.

Quick win :

- Reproduire dans une session propre sans autres Godot ouverts.
- Lancer `CheckScripts.tscn` puis `TestRunner.tscn` separement.
- Ajouter un timeout court et logs de derniere scene/script charge.

Chantier :

- Stabiliser une commande CI Windows et/ou WSL reproductible.

### MCP installe mais non utilisable via commandes Codex pendant l'audit

Constat :

- Le plugin est active dans `project.godot`.
- L'editeur lance a bien etabli une connexion TCP sur `127.0.0.1:6505`.
- Les commandes MCP ont tout de meme repondu "Godot editor is not connected".

Impact :

- Pas de capture runtime ni d'analyse scene MCP fiable pendant cette passe.

Quick win :

- Verifier que `.mcp.json` pointe vers la meme installation que l'addon projet.
- Fermer les anciens Godot ouverts avant lancement MCP.
- Redemarrer le serveur MCP puis l'editeur.

Chantier :

- Ajouter une procedure `docs/MCP_Godot_Debug.md` avec checklist connexion.

### Couverture de tests a etendre

Priorites de tests :

- Donjon vivant apres `start_dungeon()`.
- Repos joueur qui interrompt l'activite.
- Roles UI vs roles combat.
- `EffectSystem` expiration/stack/disconnect.
- Event popup fermee/ignoree/resolue.
- Abandon de donjon idempotent.
- Signal `NotificationManager` connecte aux vrais signaux.
- Smoke UI sur les fenetres principales : Personnage, Guilde, Monde, Organisation, Donjon.

## Backlog priorise

### Semaine 1 - Stabilisation

1. Fixer tick des donjons dans `ActivityManager`.
2. Fixer interruption d'activite pendant repos joueur.
3. Unifier `get_role()` et `personnage_role` dans combat.
4. Corriger `EffectSystem` signal binding.
5. Corriger fermeture evenements/conflits loot.
6. Aligner signaux `NotificationManager`.
7. Relancer `CheckScripts.tscn` et `TestRunner.tscn` en session propre.

### Semaine 2 - UX jouable

1. Centraliser `try_show_window()` avec locks de phase.
2. Remplacer les `hide()` de fermeture par `close_requested`.
3. Ajouter clamp fenetres.
4. Ajouter scroll/wrap aux panneaux detail Monde/Guilde.
5. Corriger ou retirer Fun dans Organisation.
6. Filtrer les instances par phase/niveau.
7. Ajouter feedback de chance de recrutement.

### Mois 1 - Boucle principale

1. Construire un rapport de run causal.
2. Faire du PvE une source de verite unique.
3. Ajouter un bandeau d'objectif permanent.
4. Exposer fatigue/stress/relations dans la fiche membre.
5. Ajouter alternatives clic/clavier au drag and drop.
6. Extraire presenters pour Monde/Guilde/Personnage.

### Mois 2 - Production

1. Variantes d'assets 32/64/128/256.
2. Validation data vers assets.
3. MCP dev-only en runtime.
4. Presets export dev/prod.
5. Migration progressive des donnees en Resources.
6. Typage systematique des systems/autoloads.

## Top quick wins

1. Appeler `ActivityManager.update_dungeons()` depuis le tick temporel.
2. Remplacer `DungeonInstance` `personnage_role` par `get_role()`.
3. Interrompre les activites au repos.
4. Corriger le binding des signaux dans `EffectSystem`.
5. Transformer fermeture evenement en choix "Ignorer".
6. Centraliser l'ouverture des fenetres pour respecter les locks.
7. Remplacer les `hide()` des boutons `X` par `close_requested`.
8. Clamp des fenetres restaurees.
9. Scroll + autowrap sur les details recrutement/membre.
10. Desactiver ou exclure les autoloads MCP hors debug.
11. Reduire les assets d'icones 1024 en variantes cible.
12. Ajouter les tests de regression P0.

## Conclusion

La meilleure prochaine passe ne devrait pas ajouter de nouveaux systemes. Elle devrait rendre les systemes existants fiables, lisibles et relies a une seule boucle de jeu. Le jeu a deja beaucoup de matiere. Maintenant il faut que chaque bouton raconte une verite : ce que l'UI annonce doit etre exactement ce que le moteur calcule, et chaque consequence doit revenir au joueur sous forme de feedback clair.

