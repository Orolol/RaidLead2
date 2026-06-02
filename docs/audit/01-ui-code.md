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
