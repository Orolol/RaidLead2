# Spec — Chantier 1 : Refonte visuelle « MMO pixel-art » (skin WoW-early)

*Spec **v1** — 3 juin 2026. Statut : brouillon prêt à arbitrage / phasage.*
*Pendant de [Chantier 2 — UI au service du gameplay](2026-06-03-ui-architecture-gameplay.md).*

> **Décisions verrouillées** (arbitrées avec le dev, 3 juin 2026)
> 1. **Source des assets de chrome** : kits tiers **licenciés / CC0** (pas de rip WoW — illégal pour Steam).
> 2. **Style du chrome** : **pixel-art unifié**, cohérent avec les icônes `umempart` existantes. Pas de peinture AAA : un MMO fantasy **lu à travers le pixel-art**.
> 3. **Non-goals de ce chantier** : pas de support multi-résolution / slider d'échelle UI, pas de docking. (Couverts ou écartés côté Chantier 2.)

---

## 0. Intention

L'UI actuelle est **fonctionnelle mais générique** : un thème « app moderne sombre » entièrement
en `StyleBoxFlat` plat, coins arrondis 5px, accent bleu, **zéro texture**, **police système par
défaut**. Ça ne dit pas « MMO », ça dit « dashboard ».

Objectif : donner à RaidLead une **identité visuelle de MMO fantasy** inspirée de WoW vanilla
(pierre sombre, or/bronze, parchemin, cadres ornementés, raretés colorées), **rendue en pixel-art**
pour rester cohérent avec le contenu déjà généré (portraits de classes, icônes) et tenir un budget
de prod réaliste pour un solo/indie.

Ce chantier est **purement présentationnel** : il ne change ni la logique de jeu, ni (en principe)
l'arborescence des fenêtres. Il remplace la **couche de thème** et **ajoute des assets**.
Le découpage des écrans est traité dans le Chantier 2.

### Pourquoi « pixel-art » et pas « peint AAA »
- On a déjà un **pipeline pixel-art** (ComfyUI + LoRA `umempart`) et ~40 assets de contenu pixel.
- Un chrome peint façon WoW retail jurerait avec des portraits pixel ; l'inverse (tout pixel) est
  **cohérent**, **sourçable en CC0**, et **lisible** à 1920×1080.
- Référence mentale : l'UI fantasy de jeux pixel (RPG Maker fantasy kits, *Hammerwatch*, *CrossCode*
  menus, *Moonlighter* HUD) — ornementé mais net, pas baveux.

---

## 1. État des lieux (ce qu'on remplace)

| Aspect | Aujourd'hui | Fichier(s) |
|---|---|---|
| Thème | Construit **100 % en code** (`UITheme.build()`), appliqué à `root.theme` | `scripts/ui/ui_theme.gd` |
| Styleboxes | **`StyleBoxFlat` uniquement**, aucune texture, `radius=5` global | idem |
| Palette | Bleu nuit + accent `#4da3f5`, dérivée canonique dans `UIConstants` | `scripts/ui/ui_constants.gd` |
| Police | **Aucune police custom** → fonte Godot par défaut, antialiasée | `project.godot` (aucune entrée font) |
| Filtrage textures | Défaut projet (linéaire) — incompatible pixel-perfect | `project.godot` |
| Assets | Pixel-art **contenu seulement** (portraits, icônes, donjons, fonds) dans `assets/generated/` | `assets/generated/**` |
| Chrome texturé | **Néant.** `AssetLoader.get_menu_bar_bg()` pointe vers `ui/menu_bar_bg.png` **qui n'existe pas** | `scripts/autoloads/asset_loader.gd:117` |
| Icônes menu | Seulement **4 sur 8** (`personnage/guilde/monde/organisation`) ; manquent national/esport/cohésion/conseils | `assets/generated/menu/` |
| Fond | `bg_main.png` existe, affiché assombri (`modulate 0.6`) | `scripts/main.gd:69` |
| Résolution | **1920×1080 figé, `resizable=false`**, renderer `mobile` | `project.godot` |

**Conséquence pour le re-skin** : tout passe par `UITheme` (point d'entrée unique) — c'est une
**bonne nouvelle**. Re-skiner = réécrire le builder de thème pour produire des
`StyleBoxTexture` (9-slice) au lieu de `StyleBoxFlat`, + charger une police pixel, + poser les
assets. Aucune fenêtre n'inline ses styles (vérifié : `UIConstants` est la source unique de
couleurs), donc le re-skin se propage automatiquement.

---

## 2. Direction artistique cible

### 2.1 Langage visuel
- **Matières** : pierre sombre gravée (panneaux), bois/métal patiné (cadres), parchemin
  (zones de texte/lecture), **or/bronze** (accents, bordures actives, titres).
- **Cadres ornementés 9-slice** : coins à ferrures/rivets, arêtes biseautées, **pas** de coins
  arrondis lisses. Le `radius=5` actuel disparaît au profit de coins pixel nets.
- **Raretés** (déjà la convention WoW, à conserver/renforcer) : commun blanc, rare bleu,
  épique violet, + **gris poubelle**, **vert**, **orange légendaire** pour extension future.
- **États clairement signés** : hover = liseré or + légère surbrillance ; pressed = enfoncé
  (ombre interne) ; disabled = désaturé/grisé ; focus = liseré or pointillé.

### 2.2 Palette pixel-art proposée (remplace l'actuelle)
Cible : MMO fantasy sombre, dorée. Valeurs indicatives à figer sur la palette du kit retenu
(une palette restreinte ~16-24 teintes améliore la cohérence pixel-art).

| Rôle | Couleur cible (hex indicatif) | Remplace |
|---|---|---|
| Fond profond (hors-panneau) | `#14110c` brun-noir | `BG_DEEP #1a1c25` |
| Panneau (pierre) | `#241d16` / `#2c2418` | `BG_PANEL #252834` |
| Surface surélevée (bouton) | `#3a2f20` | `BG_RAISED #303238` |
| Bordure (ferrure) | `#5a4528` bronze | `BORDER #474d61` |
| **Accent (or)** | `#e0b34d` | `ACCENT #4da3f5` (bleu → or) |
| Texte | `#efe6d2` parchemin clair | `TEXT #e3e8f0` |
| Texte atténué | `#a9997a` | `TEXT_DIM #9fa5b6` |
| Succès | `#6fbf4d` | `#4ccc4c` (ok) |
| Alerte | `#d8a32e` | `#e6b300` (ok) |
| Erreur/danger | `#c2462e` rouge brique | `#e64d4d` |

> **Sémantiques & raretés** restent dans `UIConstants` (source canonique). Seules les couleurs
> **structurelles** (`BG_*`, `ACCENT`, `TEXT*`, `BORDER*`) migrent dans `UITheme`. Le re-skin
> doit garder cette séparation : `UIConstants` continue de dériver ses couleurs de `UITheme`.

### 2.3 Garde-fous de lisibilité
- Contraste texte/fond AA minimum (le parchemin `#efe6d2` sur pierre `#241d16` passe largement).
- Or réservé aux **accents** (titres, valeurs clés, état actif) — pas de pavé de texte en or.
- Densité d'ornement **décroissante** vers l'intérieur : cadre riche en bordure de fenêtre,
  sobre dans les listes/tableaux (sinon bruit visuel et illisibilité des données).

---

## 3. Architecture technique du re-skin

Cinq briques techniques, dans l'ordre de dépendance.

### 3.1 Pixel-perfect : filtrage & rendu
- **Project setting** : `rendering/textures/canvas_textures/default_texture_filter = Nearest`
  (sinon le pixel-art bave). Aujourd'hui non réglé → tout le chrome serait flou.
- Chaque texture UI importée en **NEAREST, mipmaps OFF, `fix_alpha_border` ON**.
- 1920×1080 figé (non-goal multi-res) **simplifie** : pas de scaling fractionnaire imprévu sur
  les 9-slice. Concevoir le chrome à **échelle 1:1 écran** (1 px source = 1 px écran), ou à un
  facteur entier assumé (ex. assets ×2 affichés ×1) pour un grain plus fin. **À figer en Phase A.**

### 3.2 Police pixel-art (transformation la plus rentable)
La police par défaut à elle seule « casse » l'identité. À remplacer par une fonte pixel.

- **Contrainte bloquante — accents français.** Le jeu est **en français** (`à é è ç ê î ô û …`).
  **Beaucoup de fontes pixel ne couvrent pas le Latin étendu.** Tout candidat doit être validé
  glyphe par glyphe sur un échantillon FR avant adoption.
- **Candidats à couverture large (à vérifier au cas par cas)** : *Pixel Operator* (licence
  permissive, couverture Unicode large, recommandé comme base sûre), *monogram* (CC0), *m5x7 /
  m6x11* (gratuit). Éviter *Press Start 2P* (pas d'accents complets, très large).
- **Deux rôles** : une fonte **titre/affichage** (display, tailles 20/24) et une fonte **corps**
  (lisible 12/14, c'est le point dur en pixel — privilégier une fonte conçue pour le petit texte
  type Pixel Operator). Possibilité d'une seule fonte si elle tient les deux.
- **Import** : `FontFile`, antialiasing OFF, hinting désactivé, tailles = **multiples du grain**
  (ex. 8/16 plutôt que 14) pour rester net. `Theme.default_font` + `default_font_size`.

### 3.3 Chrome 9-slice : `StyleBoxFlat` → `StyleBoxTexture`
Cœur du chantier. Réécrire `UITheme` pour produire des `StyleBoxTexture` :
- `texture` = PNG 9-slice ; `texture_margin_{left,right,top,bottom}` = épaisseur des coins/bords ;
  `axis_stretch_horizontal/vertical = TILE` (ou `TILE_FIT`) pour des bords qui se **répètent**
  proprement en pixel (pas d'étirement baveux des arêtes).
- Conserver l'API helper actuelle : remplacer `_flat(...)` par un `_tex(asset, margins, ...)` qui
  fabrique le `StyleBoxTexture`. Garder un **fallback `_flat`** quand un asset manque (dev
  incrémental : une fenêtre non encore skinnée reste fonctionnelle).
- Couvrir **tous** les types déjà stylés par `UITheme.build()` (cf. §4) : `PanelContainer`,
  `Panel`, `Button`/`OptionButton`/`MenuButton`, `LineEdit`, `ItemList`, `TabContainer`,
  `ProgressBar`, `PopupMenu`, `Window`/dialogs, `TooltipPanel`, séparateurs.

### 3.4 Stratégie de ressource de thème
Deux options :
- **(A) 100 % code** (statu quo étendu) : `UITheme.build()` charge les textures via `load()` et
  assemble les styleboxes. *Avantage* : un seul point de vérité, diff git lisible, pas de `.tres`
  binaire. *Inconvénient* : pas d'aperçu live dans l'éditeur.
- **(B) `.theme` ressource** éditable dans l'inspecteur Godot + overrides dynamiques en code.
  *Avantage* : tweak visuel sans recompiler, aperçu éditeur. *Inconvénient* : double source,
  merges pénibles.
- **Reco : rester en (A)** (cohérent avec la culture « style-as-code » du repo, déjà en place),
  en isolant les **constantes d'assets** (chemins, marges 9-slice) en tête de fichier pour les
  régler facilement. Réévaluer (B) seulement si l'itération visuelle devient un goulet.

### 3.5 Organisation des fichiers
```
assets/
  generated/        # CONTENU pixel-art existant (portraits, icônes) — inchangé
  ui/               # NOUVEAU — chrome licencié/CC0 (9-slice, boutons, cadres)
    panels/         # window_frame, panel, header, parchment, tooltip
    buttons/        # btn_normal/hover/pressed/disabled (9-slice)
    tabs/ inputs/ bars/ icons/ frames/ cursors/
  fonts/            # NOUVEAU — fontes pixel (.ttf + .import NEAREST)
docs/licenses/
  ASSET_MANIFEST.md # NOUVEAU — registre asset → source → licence → preuve
```
`AssetLoader` gagne des accesseurs chrome (`get_ui_panel("window_frame")`, etc.) **avec cache et
fallback `null`** déjà en place — étendre les lookup tables, pas l'architecture.

---

## 4. Inventaire exhaustif des assets nécessaires

« Tout prévoir » = la checklist de prod. Chaque ligne = un asset (ou jeu d'états) à sourcer/produire.
**9s** = nine-slice requis ; **états** = variantes visuelles.

### 4.1 Chrome de fenêtre & conteneurs
| Asset | 9s | États | Notes |
|---|---|---|---|
| Cadre de fenêtre (window frame) | ✔ | 1 | Bordure ornementée des fenêtres principales |
| Barre de titre / header | ✔ | actif/inactif | Zone draggable + titre or |
| Panneau interne (`PanelContainer`) | ✔ | 1 | Surface pierre, ornement sobre |
| Panneau « parchemin » (zones lecture) | ✔ | 1 | Pour blocs de texte (descriptions, conseils) |
| Tooltip | ✔ | 1 | Liseré or fin |
| Popup/menu contextuel (`PopupMenu`) | ✔ | + hover item | |
| Bouton fermer (X) | — | normal/hover/pressed | Coin de fenêtre |
| Poignée de drag / grip | — | 1 | Optionnel, signale le déplaçable |
| Séparateur ornemental (H/V) | ✔ (H) | 1 | Remplace `StyleBoxLine` |

### 4.2 Contrôles
| Asset | 9s | États | Notes |
|---|---|---|---|
| Bouton standard | ✔ | normal/hover/pressed/disabled/focus | **Le plus visible** — soigner |
| `OptionButton`/`MenuButton` + flèche | ✔ | idem + flèche déroulante | |
| Onglet (`TabContainer`/AdvancedTabs) | ✔ | selected/unselected/hover | |
| `LineEdit` (champ texte) | ✔ | normal/focus | + caret or |
| `SpinBox` (+ boutons ±) | ✔ | normal/focus/hover boutons | Utilisé en négociation recrutement |
| `CheckBox` / `Radio` | — | on/off/hover/disabled | Si présents dans options/filtres |
| `Slider` (track + grabber) | ✔ track | grabber normal/hover | Vitesse temps, échelle |
| Scrollbar (track + grabber) | ✔ | normal/hover | Listes/longues fenêtres |

### 4.3 Barres & jauges (fort impact « jeu »)
| Asset | 9s | États | Notes |
|---|---|---|---|
| `ProgressBar` fond + remplissage | ✔ | 1 | Base XP/progression |
| Jauges colorées (énergie/humeur/stress) | ✔ | seuils good/med/bad | `CustomProgressBar` segmenté existe déjà — lui donner une skin |
| Barre de ressource (HUD) | ✔ | 1 | **Dépend du Chantier 2** (top bar) |

### 4.4 Iconographie
| Lot | Quantité | Existe ? | À produire |
|---|---|---|---|
| Icônes menu/navigation | 8 (après regroupement Chantier 2, peut tomber à ~5) | **4/8** | national, esport, cohésion, conseils — **ou** nouveau set selon hubs Chantier 2 |
| Icônes ressources (or, réputation, moral, masse salariale) | ~5 | **0** | **Manquant** — nécessaire au HUD Chantier 2 |
| Icônes stats | 6 (énergie, humeur, intégration, skill, xp, ilvl) | ✔ | Re-harmoniser au nouveau style si besoin |
| Icônes rôles (tank/heal/dps) | 3 | ✔ | OK |
| Icônes activités | 7 | ✔ | OK |
| Icônes d'état (online/offline/burnout/drama/alerte) | ~6 | partiel | offline ✔ ; ajouter burnout, alerte, drama, salaire impayé |
| Icônes d'événement | 4 (celebration/crisis/dispute/integration) | 3-4 | compléter |

### 4.5 Cadres de contenu
| Asset | 9s | États | Notes |
|---|---|---|---|
| Cadres de rareté d'item | — | common/uncommon/rare/epic (+ legendary) | **4 existent** — vérifier qu'ils tiennent le nouveau style ; ajouter légendaire |
| Cadre de portrait de classe | ✔ | + liseré online/offline | Encadre les portraits existants |
| Slot d'équipement vide | — | normal/hover/drop-valid/drop-invalid | `EquipDragCell` existe — lui donner une skin |
| Vignette de membre (ligne de roster) | ✔ | normal/sélection/hover | Forte densité — rester sobre |

### 4.6 Ambiance (optionnel / Phase E)
| Asset | Notes |
|---|---|
| Fond principal | `bg_main.png` existe ; éventuellement décliner par phase (Leveling→Esport) |
| Curseur fantasy | Curseur custom (flèche + main) — petit luxe d'identité |
| Textures de coin / overlays de vignette | Assombrissement des bords d'écran, grain léger |
| Écran-titre / chargement | Hors-scope strict mais à prévoir dans le set |

> **Total estimé** : ~35-50 assets de chrome + ~15 icônes à compléter. Un **kit pixel UI fantasy
> cohérent** (un seul auteur/palette) couvre 70-80 % en une passe ; le reste = icônes spécifiques
> (ressources, états) à générer maison (ComfyUI) **dans la palette du kit**.

---

## 5. Sourcing & conformité licence (enjeu Steam)

### 5.1 Stratégie
1. **Choisir UN kit pixel-UI fantasy de référence** (cohérence palette/grain) comme socle du
   chrome. Critère : licence claire (CC0 idéalement, ou licence commerciale one-off), couverture
   large (panneaux + boutons + onglets + barres), grain compatible avec `umempart`.
2. **Compléter les icônes manquantes** (ressources, états, menu) en **génération maison** calée
   sur la palette du kit (le pipeline ComfyUI existe déjà). Ces assets-là, on les **possède**.
3. **Police** : fonte à licence permissive (OFL/CC0) avec accents FR validés.

### 5.2 Sources connues fiables (à vérifier au cas par cas)
- **Kenney** (`kenney.nl`) : packs UI **CC0** (dont variantes pixel/RPG) — base la plus sûre
  légalement. Style parfois générique → à compléter pour le cachet « fantasy sombre ».
- **itch.io** : nombreux *pixel fantasy UI kits* — **licences très variables** (CC0, « free for
  commercial with credit », « no resale »…). **Lire la licence de CHAQUE pack.**
- **CraftPix / GameDev Market / itch payants** : kits commerciaux propres, licence one-off
  généralement compatible Steam. Vérifier la clause de redistribution.
- ❌ **Rip WoW / assets Blizzard** : exclu (propriété Blizzard, illégal en distribution).

> Je n'invente pas d'URL/pack précis ici : la sélection finale doit passer par une **revue
> licence**. Kenney CC0 est le seul que j'affirme sans réserve.

### 5.3 Garde-fou conformité — `docs/licenses/ASSET_MANIFEST.md`
Registre **obligatoire**, une ligne par asset (ou par pack) :
`fichier | source (URL) | auteur | licence | date | attribution requise (o/n) | preuve (capture/lien)`.
- Critère d'acceptation du chantier : **100 % des assets shippés tracés** dans le manifeste, tous
  CC0 ou licence commerciale prouvée. Aucun asset « origine inconnue ».
- Si une licence exige l'attribution → écran **Crédits** (à prévoir, même minimal).

---

## 6. Plan d'intégration Godot (technique)

1. **Preset d'import** pixel UI : créer un preset Godot (NEAREST, mipmaps off, fix_alpha_border)
   et l'appliquer à `assets/ui/**` et `assets/fonts/**`.
2. **Project settings** : `default_texture_filter = Nearest`. Vérifier l'antialiasing de fonte
   global (`gui/theme/...`) désactivé pour le pixel.
3. **`UITheme` v2** : introduire `_tex(...)`, table de constantes d'assets en tête, conserver
   `_flat(...)` en fallback. Migrer type par type (§4) — **chaque type migré est testable seul**.
4. **`AssetLoader`** : ajouter les lookups chrome + `get_ui_panel/get_ui_button/...` (cache +
   fallback déjà génériques). Corriger/retirer le `get_menu_bar_bg()` cassé.
5. **Fond `main.gd`** : revoir le `modulate 0.6` (peut-être inutile/contre-productif avec un
   chrome opaque ornementé).
6. **Vérification non-régression** : screenshots MCP avant/après par fenêtre (`get_game_screenshot`)
   + `compare_screenshots` ; `CheckScripts` + `TestRunner` doivent rester verts (le thème ne touche
   pas la logique mais `UITheme` est chargé au boot).

---

## 7. Phasage (incrémental, toujours shippable)

> Chaque phase laisse le jeu **jouable et cohérent** (fallback `_flat` pour le non-encore-skinné).

- **Phase A — Fondations (impact immédiat, peu d'assets)**
  Police pixel (FR validé) + palette `UITheme` v2 + `default_texture_filter=Nearest` + presets
  d'import + arbo `assets/ui` + `ASSET_MANIFEST.md` + choix de l'échelle (1:1 vs ×2).
  *À elle seule, la police change radicalement le ressenti.*
- **Phase B — Chrome cœur (le 80/20)**
  9-slice : cadre de fenêtre, header, `PanelContainer`, **boutons** (5 états), onglets.
  `UITheme` bascule en `StyleBoxTexture` pour ces types. *C'est ici que « ça devient un MMO ».*
- **Phase C — Contrôles & données**
  `LineEdit`, `SpinBox`, `OptionButton`, `ItemList`/sélection, `ProgressBar`/jauges, scrollbars,
  séparateurs ornementaux, tooltip, popups.
- **Phase D — Iconographie**
  Compléter icônes menu (selon hubs du Chantier 2), **icônes ressources** (or/réput/moral), états
  (burnout/alerte/drama), cadres de portrait & rareté harmonisés.
- **Phase E — Polish & ambiance**
  Curseur custom, overlays de bord, fond par phase, micro-transitions, hooks SFX UI (clic/hover —
  optionnel), écran crédits si attribution requise.

**Dépendance forte avec le Chantier 2** : les **Phases A-C** (fonte, palette, chrome générique)
sont **indépendantes** de la structure des écrans → faisables en premier sans rework. Les
**Phases D-E** (icônes de menu, barre de ressource, cadres contextuels) **dépendent** des hubs et
du HUD définis au Chantier 2 → les caler **après** la refonte de navigation pour ne pas produire
des icônes/skins pour des fenêtres qui vont fusionner.

---

## 8. Risques & garde-fous

| Risque | Mitigation |
|---|---|
| **Accents FR absents** d'une fonte pixel | Validation glyphe en Phase A ; shortlist Pixel Operator/monogram |
| 9-slice **étiré/baveux** sur bords | `axis_stretch = TILE`, marges correctes, NEAREST, échelle entière |
| Lisibilité des **données denses** (roster, tableaux) noyées sous l'ornement | Densité d'ornement décroissante (§2.3) ; chrome sobre dans listes |
| Renderer `mobile` + shaders | Le re-skin n'exige **aucun shader** (9-slice + textures) ; rester là-dessus |
| Régression visuelle silencieuse | Screenshots MCP avant/après par fenêtre + `compare_screenshots` |
| Licence d'asset non conforme (Steam) | `ASSET_MANIFEST.md` obligatoire, revue licence par pack |
| Effort « par fenêtre » gaspillé si la structure change | Faire Phases A-C avant, D-E après le Chantier 2 |
| Incohérence kit tiers vs `umempart` | Choisir un kit à palette restreinte + re-générer les icônes maison dans CETTE palette |

---

## 9. Critères d'acceptation

- [ ] Police pixel appliquée partout, **accents FR corrects** (échantillon `àéèçêîôûœ` validé).
- [ ] `UITheme` produit des `StyleBoxTexture` pour tous les types listés §4.1-4.3 (fallback `_flat`
      seulement pour assets manquants assumés).
- [ ] Aucune fenêtre n'affiche de coins arrondis « app » résiduels ; identité MMO cohérente
      (vérif. screenshots des 8 fenêtres actuelles + HUD).
- [ ] `default_texture_filter=Nearest`, aucun flou pixel.
- [ ] `CheckScripts` + `TestRunner` verts ; boot live OK (MCP).
- [ ] `ASSET_MANIFEST.md` complet, 100 % CC0/commercial prouvé ; crédits si requis.
- [ ] Icônes menu complètes pour le set de navigation final (post-Chantier 2).

---

## 10. Estimation & séquencement

- **Phases A-B** : ~3-4 j (le gros du ressenti). **Phase C** : ~2-3 j. **Phases D-E** : ~3-4 j
  (dont sourcing/génération d'icônes), **après** Chantier 2.
- **Ordre recommandé global** : Chantier 2 (structure) **et** Phases A-C du Chantier 1 peuvent
  avancer en parallèle (orthogonaux) ; Phases D-E du Chantier 1 **après** la structure figée.

---

*Fin de spec — Chantier 1.*
