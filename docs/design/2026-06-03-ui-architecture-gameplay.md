# Spec — Chantier 2 : UI au service du gameplay (HUD persistant + refonte navigation)

*Spec **v1** — 3 juin 2026. Statut : brouillon prêt à arbitrage / phasage.*
*Pendant de [Chantier 1 — Refonte visuelle MMO](2026-06-03-ui-refonte-visuelle-mmo.md).*

> **Statut implementation — 4 juin 2026**
> - HUD persistant implemente : `ResourceBar`, `ObjectiveTracker`, `AlertRail`.
> - Navigation principale remplacee par 5 hubs : Guilde, Competition, Business, Recrutement, Conseil.
> - `MemberInspector` et selection partagee ajoutes via `GuildManager.member_selected`.
> - Deep-links HUD/rail/raccourcis vers hub + section branches.
> - Dernier reste technique : extraire totalement les anciennes fenetres lourdes en sous-composants natifs.

> **Décisions verrouillées** (arbitrées avec le dev, 3 juin 2026)
> - **En scope** : (1) **HUD permanent persistant** — l'état vital toujours visible sans ouvrir de
>   fenêtre ; (2) **refonte navigation / regroupement** — collapser 8+ fenêtres en quelques hubs
>   organisés par boucle de jeu.
> - **Non-goals** : pas de panneaux ancrables / multi-fenêtres (on **reste en mono-fenêtre**) ;
>   pas de support multi-résolution / slider d'échelle (reste figé 1920×1080).
> - **Indépendant du skin** (Chantier 1) : ici on parle **structure & flux d'info**, pas pixels.

---

## 0. Intention

Aujourd'hui, **tout** ce qui compte est **enfoui dans des fenêtres** qu'il faut ouvrir une par une
(mode mono-fenêtre). Pour savoir « combien d'or j'ai / quel est mon objectif / qui est en burnout /
ai-je un drama à traiter », le joueur doit **ouvrir Conseils, puis Personnage, puis Cohésion…**.
C'est un **dashboard de systèmes**, pas une **UI de jeu**.

Une UI « au service du gameplay » suit la règle : **l'état vital et les alertes actionnables sont
toujours visibles** ; les fenêtres servent au **drill-down**, pas à la surveillance. Et la
navigation doit être organisée par **boucle de jeu** (ce que le joueur *fait*), pas par **système
technique** (ce que le code *contient*).

Deux livrables :
1. Une **couche HUD persistante** (barre de ressources + tracker d'objectif + rail d'alertes).
2. Une **refonte de la navigation** (8+ boutons → ~4-5 hubs cohérents, fenêtres rétrogradées en
   sections).

---

## 1. État des lieux

### 1.1 Navigation actuelle (mono-fenêtre)
8 boutons en barre basse → `WindowManager.show_window()` (une seule fenêtre visible), + raccourcis
Ctrl. Source : `scripts/ui/components/menu_bar.gd`, `scripts/main.gd:141-183`.

| Bouton | Fenêtre | Raccourci | Verrou | Contenu (onglets) |
|---|---|---|---|---|
| Personnage | `Fenetre_Personnage` (978 l.) | Ctrl+P | — | Identité / Progression de phase / Réputation |
| Guilde | `Fenetre_Guilde` (733 l.) | Ctrl+G | — | Membres / Perks / Historique loot |
| Monde | `Fenetre_Monde` (767 l.) | Ctrl+M | — | Classement / **Recrutement** |
| Organisation | `Fenetre_OrganisationGroupe` (802 l.) | Ctrl+O | — | Compo de groupe PvE + aperçu run |
| National | `Fenetre_National` (493 l.) | Ctrl+N | Phase ≥2 | Célébrité / Médias / Sponsors / Dramas |
| Esport | `Fenetre_Esport` (723 l.) | Ctrl+E | Phase ≥3 | Staff / Tournois / Bien-être / Transferts / Legacy |
| Cohésion | `Fenetre_Social` (469 l.) | Ctrl+K | — | Moral / Relations / Cliques / Team-building / Traditions / Conflits |
| Conseils | `Fenetre_Conseils` (542 l.) | Ctrl+A | — | Cette semaine / Conseils / Stats / Équilibrage |
| *(+ Équipement/Banque)* | `Fenetre_Equipement` | clic-droit membre | — | Slots + banque (drag&drop) |

### 1.2 HUD actuel (ad hoc, monté à la main dans `main.gd`)
| Élément | Position | Ce qu'il montre | Limite |
|---|---|---|---|
| `TimeDisplay` | top-center | Date/heure + vitesse + pause | OK mais isolé |
| `ChatPanel` | bottom-right | Log/chat vivant | OK |
| `PlayerControlPanel` | top-left | Activité joueur, énergie, repos | Centré sur le **perso joueur**, pas la guilde |
| `NotificationToast` | top-center | Toasts éphémères | **Éphémère** : une alerte qui demande une action disparaît |

**Ce qui manque cruellement en permanence** : **or**, **réputation**, **moral de guilde**,
**objectif de phase + progression**, **membres en ligne / total**, **alertes actionnables**
(drama en attente, salaire impayé, recrue qui expire, burnout). Tout ça existe **en données** mais
n'est lisible qu'en ouvrant une fenêtre.

### 1.3 Problèmes structurels
- **Surveillance = navigation** : impossible de « jeter un œil », il faut ouvrir/fermer.
- **Regroupement par système** : « National » et « Esport » sont des *phases*, « Cohésion » et
  « Guilde » se recouvrent (membres/relations/moral éparpillés sur 3 fenêtres).
- **Alertes volatiles** : les choses urgentes passent en toast et s'évaporent.
- **Fenêtres monolithes** : 500-980 lignes, multi-onglets ; le joueur s'y perd.
- **Découverte** : 8 boutons + verrous de phase, sans hiérarchie ni « par où commencer ».

---

## 2. Principes directeurs

1. **Glanceable d'abord.** L'état vital (ressources, temps, objectif, alertes) est **toujours
   affiché**. Ouvrir une fenêtre ne sert qu'au **détail** et à l'**action**.
2. **Hiérarchie d'information** : *HUD (coup d'œil)* → *Hub (résumé d'une boucle)* → *Section
   (détail/action)*. Trois niveaux, pas huit fenêtres plates.
3. **Regrouper par boucle de jeu**, pas par système technique. Le joueur pense « gérer ma guilde /
   performer / développer ma carrière / demander conseil », pas « MediaManager / StaffManager ».
4. **Divulgation progressive** : la complexité (National, Esport) apparaît **dans** son hub quand
   la phase la débloque, au lieu d'un bouton grisé permanent.
5. **Une surface d'action primaire par boucle** : depuis le HUD, l'action la plus fréquente d'une
   boucle est à **un clic** (ex. « assigner activité », « lancer un run », « traiter le drama »).
6. **Alertes actionnables persistantes** : ce qui exige une décision **reste** jusqu'à résolution
   (rail d'alertes), distinct des toasts informatifs éphémères.

---

## 3. Audit de l'information (ce qui va où)

Cartographie de chaque info/action vers son **niveau** cible. C'est ce qui pilote la refonte.

| Donnée / action | Source (signal/méthode) | Niveau cible |
|---|---|---|
| Or | `Guild.gold` (⚠ **pas de signal** `gold_changed`) | **HUD** (top bar) |
| Réputation | `Guild.reputation_changed(old,new,reason)` | **HUD** |
| Moral de guilde | `GuildCultureManager.get_guild_morale()` + `morale_changed(new,old)` | **HUD** |
| Date / heure / vitesse | `GameTime` (`TimeDisplay`) | **HUD** (fusion top bar) |
| Membres en ligne / total | `GuildManager.member_connected/disconnected` + roster | **HUD** |
| Objectif de phase + progression | `PhaseManager.get_requirements_progress(phase)` + `progression_updated`, `phase_changed` | **HUD** (tracker) |
| Masse salariale / solvabilité | GuildManager (paie hebdo) | **HUD** (icône) + Hub Business |
| Drama en attente | `DramaManager` (popup) | **Rail d'alertes** |
| Salaire impayé / trésorerie pleine | `Guild` (overflow), paie | **Rail d'alertes** |
| Recrue qui expire / cooldown refus | `RecruitmentPool` | **Rail d'alertes** + Hub Guilde |
| Burnout / stress élevé | `SimulatedPlayer.get_burnout_risk()` | **Rail d'alertes** + Hub Guilde |
| Tension/conflit social | `SocialDynamics` / Cohésion | **Rail d'alertes** + Hub Guilde |
| Synthèse hebdo (« Cette semaine ») | `AdvisorManager.get_weekly_summary()` | **Rail/Conseil** |
| Roster détaillé, tags, équipement | GuildManager / Equipment | **Section** (Hub Guilde) |
| Relations / cliques / traditions | GuildCultureManager / SocialDynamics | **Section** (Hub Guilde) |
| Compo de groupe + run PvE | ActivityManager / DungeonInstance | **Section** (Hub Compétition) |
| Classement serveur/national/mondial | `GuildRanking.ranking_updated(rankings)` | **Section** (Hub Compétition) |
| Médias / sponsors / célébrité | Media/Sponsorship/Drama Managers | **Section** (Hub Business, phase ≥2) |
| Staff / tournois / transferts / legacy | Staff/Tournament/Transfer/Legacy Managers | **Section** (Hub Business, phase ≥3) |
| Stats détaillées / équilibrage | AdvisorManager / BalanceManager | **Section** (Hub Conseil) |

> ⚠ **À brancher / vérifier en implémentation** : `Guild` n'expose **pas** de signal de changement
> d'or (seulement `add_gold/spend_gold` + une notif d'overflow). La barre de ressource exige
> d'**ajouter `signal gold_changed(old, new)`** (émis dans `add_gold`/`spend_gold`) sinon le HUD
> devra poller (à éviter — le repo a justement supprimé les pollings UI). Les autres sources
> ci-dessus sont des signaux/méthodes **réels** repérés dans le code, mais le wiring exact reste à
> confirmer fenêtre par fenêtre.

---

## 4. Couche HUD persistante (livrable 1)

Layout cible (mono-fenêtre conservé : les hubs s'ouvrent dans la zone centrale `window_manager`).

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ [TOP BAR]  ⏿Or 12.4k  ★Réput 340  ♥Moral 72  👥 8/14 en ligne   ⏱ J128 21:40 ▸▸ ⏸ │  ← toujours visible
├───────────────┬─────────────────────────────────────────────┬─────────────────┤
│ [JOUEUR]      │                                             │ [RAIL D'ALERTES]│
│ Activité 🎯   │            ZONE CENTRALE                     │ ⚠ Drama: Kael   │  ← alertes
│ Énergie ▓▓▓░  │       (hub / fenêtre ouverte)               │ 💀 Burnout: Lia │    persistantes
│ [Ordres…]     │                                             │ ⏳ Recrue -2j   │    actionnables
│               │   ┌─ Objectif de phase (tracker) ─┐         │ 💰 Salaire dû   │
│               │   │ Phase 0 ▸ 1 donjon héroïque 0/1│         │                 │
│               │   └───────────────────────────────┘         │                 │
├───────────────┴─────────────────────────────────────────────┴─────────────────┤
│ [CHAT vivant]                                  [NAV]  Guilde│Compét.│Business│Conseil │ ← nav regroupée
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4.1 Top bar — barre de ressources/statut (NOUVEAU `ResourceBar`)
- Contenu : **or, réputation, moral, en ligne/total**, + **date/heure/vitesse** (fusionne
  `TimeDisplay`). Icônes (cf. Chantier 1 §4.4, **à produire**).
- Réactif **par signaux** (`reputation_changed`, `morale_changed`, `member_connected/disconnected`,
  `gold_changed` **à ajouter**), **zéro polling**.
- Survol → tooltip de détail (ex. réput : gains/pertes récents ; moral : facteurs).
- Clic sur une ressource → ouvre le hub/section pertinent (or → Business, moral → Guilde/Cohésion).

### 4.2 Tracker d'objectif de phase (NOUVEAU `ObjectiveTracker`)
- Mini-bandeau toujours visible : **phase courante + objectif(s) + progression live**, alimenté par
  `PhaseManager.get_requirements_progress()` + `progression_updated`.
- Repliable/dépliable. Clic → section Progression du Hub Compétition.
- **Corrige une plainte playtest connue** : « carte Phase actuelle non rafraîchie » → ici, réactif.

### 4.3 Rail d'alertes actionnables (NOUVEAU `AlertRail` + `AlertCard`)
- Colonne droite : **cartes d'alerte persistantes** qui **restent jusqu'à résolution**.
- Sources : `DramaManager` (drama à trancher), paie/`Guild` (salaire impayé, trésorerie pleine),
  `RecruitmentPool` (recrue qui expire), burnout/stress (`get_burnout_risk`), tensions sociales,
  et l'alerte la plus critique d'`AdvisorManager.get_weekly_summary()`.
- Chaque carte = icône + libellé court + **action directe** (« Traiter », « Payer », « Voir »).
  Clic → ouvre la section concernée **avec le contexte présélectionné**.
- **Distinct des toasts** : `NotificationToast` reste pour l'informatif éphémère (« +loot »,
  « level up ») ; le rail pour ce qui **demande une décision**.
- Priorisation/sévérité réutilise la logique déjà existante d'`AdvisorManager` (pastilles de
  sévérité). Anti-spam : dédup par sujet.

### 4.4 Panneau joueur (évolution de `PlayerControlPanel`)
- Reste top-left mais resserré : activité courante (🎯/⏸️/😴), énergie, **ordres rapides**
  (Leveling/Farming/Détente/Repos/**Donjon-Raid**). Déjà largement en place — surtout
  l'intégrer visuellement au HUD plutôt que flottant.

### 4.5 Inspecteur contextuel (NOUVEAU `MemberInspector`, Phase 4)
- Sélectionner un membre (roster, compo, rail) ouvre un **inspecteur** latéral : portrait, classe,
  rôle, stats vitales, tags révélés, équipement résumé, relations clés, **actions** (équiper,
  scouter, gérer). Remplace le va-et-vient entre Guilde/Équipement/Cohésion pour un même membre.

---

## 5. Refonte de la navigation (livrable 2)

### 5.1 Regroupement : 8+ fenêtres → 4 hubs (+ recrutement)
Chaque **hub** = une fenêtre-coquille (`HubWindow`) avec des **sections** (réutilise `AdvancedTabs`).
Les anciennes fenêtres deviennent des **sections**.

| Hub | Raccourci | Sections (ex-fenêtres/onglets) | Boucle de jeu servie |
|---|---|---|---|
| **🛡 Guilde** | Ctrl+G | Roster & membres · Équipement/Banque · Cohésion (moral/relations/cliques/traditions/conflits) · *(Recrutement → voir ci-dessous)* | « Gérer ma guilde » (interne) |
| **⚔ Compétition** | Ctrl+C | Organisation de groupe (PvE) · Classements (serveur/national/mondial) · Progression de phase | « Performer » (PvE & ranking) |
| **🌟 Carrière/Business** | Ctrl+B | National (célébrité/médias/sponsors/dramas) · Esport (staff/tournois/transferts/legacy) — **sections apparaissent selon la phase** | « Développer ma carrière » (méta, phase ≥2/≥3) |
| **📋 Conseil** | Ctrl+A | Cette semaine · Conseils · Statistiques · Équilibrage | « Comprendre / décider » (dashboard) |
| **🧭 Recrutement** | Ctrl+R | Pool de recrues + négociation/scouting | Boucle de recrutement (haute fréquence → mérite l'accès direct) |

- **Personnage** (identité/réputation/progression) : la **progression** va dans Compétition
  (tracker HUD + section) ; l'**identité/réputation joueur** devient une petite section de Guilde
  ou un panneau accessible depuis l'avatar de la top bar. La fenêtre monolithe disparaît.
- **Recrutement** était un onglet de « Monde » : on le **promeut** en accès direct (c'est une des
  boucles les plus fréquentes), tout en gardant les **classements** dans Compétition.
- **Divulgation progressive** : le hub **Business** est visible dès qu'**au moins une** de ses
  sections est débloquée ; sinon masqué (plutôt qu'un bouton grisé permanent).

> Le nombre exact de hubs (4 vs 5) et le rattachement de « Recrutement » (hub à part vs section de
> Guilde) sont les **deux arbitrages ouverts** de cette spec. Reco : **5 entrées** (Guilde,
> Compétition, Business, Conseil, Recrutement) — c'est la boucle la plus directe.

### 5.2 Raccourcis remappés
- Anciens Ctrl+P/M/O/N/E/K deviennent : **Ctrl+G** Guilde, **Ctrl+C** Compétition, **Ctrl+B**
  Business, **Ctrl+A** Conseil, **Ctrl+R** Recrutement. À l'**intérieur** d'un hub, **Tab / 1-9**
  changent de section. (Garder `Espace` pause, `Échap` ferme.)
- Mettre à jour `menu_bar.gd` (signaux par bouton) et `main.gd` (`_register_windows`,
  `_connect_menu_signals`, table de raccourcis `:241-281`).

### 5.3 Impact technique
- **`HubWindow`** : coquille générique (header + `AdvancedTabs` + zone section). Les fenêtres
  actuelles sont déjà des `PanelContainer` autonomes → **réembarquables comme sections** avec peu
  de friction (elles ne font pas d'hypothèse de plein écran).
- **`WindowManager`** : reste mono-fenêtre ; on enregistre désormais ~5 hubs au lieu de 8 fenêtres.
  La mémorisation de position reste valable.
- **Verrous de phase** : déplacés du bouton (grisé) vers la **présence/absence de section** dans le
  hub Business (réagit à `phase_changed`/`phase_unlocked`).

---

## 6. Flux par boucle (preuve « UI au service du gameplay »)

Pour chaque boucle clé : friction actuelle → flux cible. C'est le test de réussite du chantier.

### 6.1 Boucle quotidienne (check & pilotage)
- **Avant** : ouvrir Conseils (alertes) → fermer → Personnage (objectif) → fermer → Cohésion
  (moral) → fermer → donner un ordre au joueur. ~5 ouvertures.
- **Après** : tout en HUD (or/moral/objectif/alertes visibles) ; agir depuis le **rail** et le
  **panneau joueur** sans rien ouvrir. **0 ouverture** pour surveiller, 1 clic pour agir.

### 6.2 Boucle de crise (drama / burnout / salaire)
- **Avant** : un toast passe, on le rate ; on découvre le problème plus tard en ouvrant la fenêtre.
- **Après** : **carte d'alerte persistante** dans le rail jusqu'à résolution → « Traiter » ouvre la
  section avec le membre/contexte présélectionné.

### 6.3 Boucle PvE (composer → lancer → loot)
- **Avant** : Organisation (compo + aperçu) → run → Loot. Correct, mais isolé du reste.
- **Après** : depuis le HUD ou le hub Compétition, **« Lancer un run »** présélectionne le contenu
  conseillé (lié à l'objectif de phase du tracker) ; l'aperçu de run (énergie/stress/score, déjà
  existant) reste ; loot inchangé.

### 6.4 Boucle de recrutement
- **Avant** : Monde → onglet Recrutement, noyé sous le classement.
- **Après** : **Hub Recrutement direct** (Ctrl+R) ; alerte « recrue qui expire » dans le rail
  pousse vers la bonne fiche.

### 6.5 Boucle de progression de phase
- **Avant** : objectif à aller chercher dans Personnage (et non rafraîchi au load — bug playtest).
- **Après** : **tracker HUD permanent**, réactif ; clic → section Progression (Compétition).

---

## 7. Composants & specs d'écran

### 7.1 Nouveaux composants
| Composant | Rôle | Réutilise |
|---|---|---|
| `ResourceBar` | Top bar ressources/temps, réactive par signaux | `StatDisplay`, `Badge` |
| `ObjectiveTracker` | Objectif de phase + progression live, repliable | `CustomProgressBar`, `PhaseManager` |
| `AlertRail` + `AlertCard` | Alertes actionnables persistantes priorisées | `Badge` (sévérité), `AdvisorManager` |
| `HubWindow` | Coquille hub (header + sections) | `AdvancedTabs`, `WindowManager` |
| `MemberInspector` | Inspecteur contextuel d'un membre (Phase 4) | `StatDisplay`, `Badge`, Equipment |

### 7.2 Réutilisé tel quel
`AdvancedTabs` (sections de hub), `ChatPanel`, `NotificationToast` (informatif éphémère),
`PlayerControlPanel` (resserré), `Tooltip`, `CustomProgressBar`, `StatDisplay`, `Badge`,
les fenêtres existantes (rétrogradées en sections).

### 7.3 Modèle de sélection
Un **état de sélection partagé** (membre courant) alimente l'inspecteur et les actions du rail.
À porter par un petit autoload léger ou un signal sur `GuildManager` (à trancher en impl).

---

## 8. Phasage (additif, jamais cassant)

> Principe : on **ajoute** la couche HUD avant de **réorganiser** la navigation. Chaque phase est
> indépendamment livrable et améliore l'UX sans rien casser.

- **Phase 1 — Top bar + tracker d'objectif (NOUVEAU, additif)**
  `ResourceBar` (or/réput/moral/online/temps) + `ObjectiveTracker`. Ajoute `gold_changed` sur
  `Guild`. Aucune fenêtre touchée. **Gros gain immédiat de lisibilité.**
- **Phase 2 — Rail d'alertes**
  `AlertRail`/`AlertCard` branché sur drama/salaire/recrue/burnout/tension + `AdvisorManager`.
  Toasts informatifs conservés. Actions « ouvre la fenêtre concernée » (avant regroupement).
- **Phase 3 — Refonte navigation (regroupement)**
  `HubWindow` ; collapse 8 fenêtres → ~5 hubs ; remap raccourcis ; verrous de phase → sections ;
  promotion de Recrutement. Les actions du rail/HUD pointent désormais vers **sections**.
- **Phase 4 — Inspecteur contextuel & sélection**
  `MemberInspector` + état de sélection partagé ; réduit le va-et-vient inter-sections.
- **Phase 5 — Polish des flux**
  Présélection de contenu PvE depuis l'objectif, actions à 1 clic, deep-links rail→section
  contextualisés, raffinage densité/placement.

**Dépendances avec le Chantier 1** : les Phases 1-2 (HUD) ont besoin d'**icônes de ressources**
(Chantier 1 §4.4, à produire). Faisable avec placeholders puis skinné. La Phase 3 (regroupement)
**fige le set d'icônes de menu** → caler la **Phase D du Chantier 1** *après* la Phase 3 d'ici.

---

## 9. Risques & garde-fous

| Risque | Mitigation |
|---|---|
| HUD qui **mange** l'espace (déjà 1920×1080 figé, fenêtres 800×600 centrées) | Top bar fine + rail repliable ; zone centrale préservée ; tester l'encombrement par screenshot |
| `gold` sans signal → tentation de **polling** | Ajouter `gold_changed` (le repo a banni le polling UI — respecter) |
| **Rétrograder** les fenêtres en sections casse des hypothèses internes | Elles sont déjà des `PanelContainer` autonomes ; migrer une à une, `CheckScripts`+`TestRunner` à chaque |
| Rail d'alertes **bruyant** (spam) | Dédup par sujet + sévérité + persistance jusqu'à résolution (pas de re-trigger) |
| Surcharge de la top bar | Limiter à 4-5 ressources + temps ; le reste en tooltip/hub |
| Confusion pendant la transition nav | Phaser : HUD d'abord (additif), regroupement ensuite ; garder libellés explicites |
| Mémorisation de positions de fenêtres devenue obsolète | Réinitialiser le layout au passage en hubs (Phase 3) |

---

## 10. Critères d'acceptation

- [ ] Or, réputation, moral, en ligne/total, temps : **visibles en permanence**, réactifs par
      signaux (zéro polling). `gold_changed` ajouté et émis.
- [ ] Objectif de phase + progression **toujours visibles** et **rafraîchis au load** (corrige le
      bug playtest connu).
- [ ] Une alerte actionnable (drama/salaire/recrue/burnout) **persiste** jusqu'à résolution et
      offre une action directe contextualisée.
- [ ] Navigation : **≤ 5 entrées** de premier niveau ; chaque ancienne fenêtre accessible comme
      section ; verrous de phase gérés par présence de section.
- [ ] Les 5 boucles (§6) démontrées : **0 ouverture** pour surveiller l'état vital ; action
      fréquente à ≤ 1 clic.
- [ ] `CheckScripts` + `TestRunner` verts ; boot live OK (MCP, screenshots par hub).

---

## 11. Estimation & séquencement

- **Phase 1** : ~2 j · **Phase 2** : ~2 j · **Phase 3** : ~3-4 j (le gros) · **Phase 4** : ~2-3 j ·
  **Phase 5** : ~2 j.
- **Ordre global recommandé** (avec Chantier 1) :
  1. **Chantier 2 Phases 1-2** (HUD additif) — gain UX immédiat, indépendant du skin.
  2. **Chantier 1 Phases A-C** (fonte/palette/chrome) — en parallèle, orthogonal.
  3. **Chantier 2 Phase 3** (regroupement) — fige la structure.
  4. **Chantier 1 Phases D-E** (icônes de menu/ressources, ambiance) — après structure figée.
  5. **Chantier 2 Phases 4-5** (inspecteur, polish des flux).

---

*Fin de spec — Chantier 2.*
