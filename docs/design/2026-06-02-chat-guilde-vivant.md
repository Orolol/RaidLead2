# Design — Chat de guilde vivant (« Barrens chat » vanilla)

*Doc de design **v1.1** — 2 juin 2026. Statut : brouillon validé sur les grandes lignes, prêt à
implémenter par phases.*

> **Changelog v1.1** : décisions du dev intégrées (§11) ; ajout du système majeur de
> **Scènes scriptées à branches multi-acteurs** (§6) = le cœur du « vivant » (vraies saynètes,
> plusieurs personnes, plusieurs lignes, pauses, branches résolues par rolls pondérés sur les
> traits) ; cadence ambient **proportionnelle au nombre de joueurs en ligne** (§3.3).

## 0. Intention

Transformer le `ChatPanel` (aujourd'hui un simple log d'événements système) en un **chat de
guilde vivant** qui évoque WoW Vanilla : banter, memes, logistique de raid, dramas, **saynètes**
entre membres, réactions en personnage à ce qui se passe réellement dans la simulation.

Contrainte forte (jeu solo Steam) : **offline, gratuit par message, instantané, déterministe**
(rejouable avec `GameRandom.seed_rng`). → Pas de LLM au runtime dans le build de base.

**Approche retenue (décidée avec le dev) :** *Combo 1+2*
1. **Moteur runtime data-driven** (« ChatDirector ») — ce doc.
2. **Corpus généré par LLM au dev-time** (répliques **+ scènes à branches**) shippé en JSON.
3. *(Plus tard, optionnel)* backend LLM live opt-in pour 2-3 grands moments.

### Deux types de contenu (complémentaires)

- **Lignes** (§1-5) : one-liners réactifs/ambient, scorés individuellement. La *connective
  tissue* du chat, combinatoirement variée, le *fallback* quand aucune scène ne colle.
- **Scènes** (§6) : saynètes **multi-acteurs**, jouées **dans le temps avec pauses**, à
  **branches**. Le contenu « premium » qui donne la vie. Déclenchables en ambient **ou** en
  réaction (ex. un conflit de loot lance « le tribunal du ninja »).

Non-objectifs (v1) : multi-canaux (guilde/raid/whisper), commandes slash, recherche/filtre,
export logs, **saisie joueur / `/roll`** (décision §11.5 : plus tard). Items déjà listés en
`RoadmapComplet` (US 2.5 ChatPanel amélioré), hors scope de la « vie » du chat.

---

## 1. Principe directeur : pas de `if`, du **scoring d'utilité**

Le piège du chat scripté n'est pas « c'est scripté », c'est :
1. petits pools de lignes → répétition ;
2. réactions codées en dur (`if event == X: dire Y`) → spaghetti + lignes génériques.

On remplace les deux par un **moteur de sélection pondéré** (famille *Utility AI* /
*Infinite Axis Utility System*). Une réaction n'est plus du code : c'est une **donnée**
(une réplique/scène + ses tags + ses considérations). Ajouter du contenu = éditer un JSON.

> Même les **scènes à branches** (§6) respectent ça : le *graphe* est de la donnée, le moteur qui
> le joue est générique. « De vrais scripts à branches » **sans** `if` éparpillés dans le code.

### 1.1 Le modèle de score (décision §11.2 : `gates × Σbonus`)

Pour un appariement candidat `(locuteur s, réplique u)` dans un contexte `c` :

```
score(s, u, c) = base_weight(u) × (Σ bonus_i(s,u,c)) × (Π veto_j(s,u,c))
```

- **vetos** `∈ [0,1]`, surtout `{0,1}` : conditions dures (`requires_class`, `requires_trait`,
  `cooldown_actif`, `requires_relation`). Un seul `0` élimine le candidat — **remplace les
  `-9999` additifs** (plus propre, pas de nombre magique, pas de score négatif qui fuit).
- **bonus** `≥ 0` : contributions douces (affinité de trait, humeur, relation au sujet,
  affinité de vibe, équité de parole…). Additifs → lisibles, on voit la contribution de chacun.

> Modèle retenu : `gates × Σbonus` (intuitif à régler). L'IAUS produit-pur + *compensation
> factor* reste une option si on veut le textbook, mais on démarre simple.

### 1.2 Une **considération** = un axe + une courbe de réponse

Unité data-driven. Le moteur lit `axis` (via un registre de lecteurs d'axes), passe la valeur
dans `curve`, multiplie par `weight`, range dans le seau `bonus` ou `veto`. **Aucune logique
spécifique à la réplique dans le code.**

```jsonc
{ "axis": "speaker.has_trait", "param": "perfectionniste",
  "curve": "boolean", "kind": "bonus", "weight": 1.5 }
```

Courbes (valeur→[0,1]) : `boolean`, `linear`, `inverse`, `gaussian` (« proche de X »),
`threshold`, `step`. Paramétrables en JSON.

### 1.3 Le tirage : **softmax à température**

On ne prend **pas** le max (→ toujours la même ligne). Sur le top-N candidats :

```
P(k) = exp(score_k / T) / Σ_j exp(score_j / T)
```

- `T → 0` : quasi-greedy (la réplique la plus pile-poil). `T` grand : variété/chaos.
- **Température contextuelle (« selon le quand »)** : stimulus réactif fort → `T` bas (on reste
  sur le sujet) ; banter en temps mort → `T` haut (surprise).
- **Température par locuteur (« selon le qui »)** : trait `funny`/`drama_queen` → `T` perso plus
  haut (imprévisible) ; `perfectionniste`/`solitaire` → plus bas.

Tirage via `GameRandom` (déterministe). C'est l'intuition « vectorisation + tirage à
température » du dev, posée sur un scoring lisible.

---

## 2. La **vibe-space** : l'idée « embeddings », bakée au dev-time

Vectoriser le **contexte live** au runtime exigerait un modèle d'embeddings embarqué (sidecar
lourd) ou une API online → casse offline/gratuit/déterministe, et une cosinus 384-D est opaque à
debugger. On garde l'**intuition** sans le coût :

**Au dev-time** (génération du corpus), embeddings pour : dédupliquer (cosinus > 0.95),
clusteriser, **auditer la couverture**, et **projeter chaque réplique sur 3-4 axes nommés** = la
*vibe-space* :
- `serieux` (−1 déconne … +1 sérieux) · `toxicite` (−1 bienveillant … +1 salé) ·
  `sweat` (−1 casual … +1 hardcore).

On **bake ces scalaires dans le JSON** (`"vibe": [s, t, w]`).

**Au runtime**, plus aucun embedding : le **locuteur** a *aussi* des coords vibe (table statique
traits+humeur : `perfectionniste→+serieux`, `drama_queen→+toxicite +déconne`, `tryhard→+sweat`,
`casual→−sweat`, `mood bas→+toxicite`…). Considération **`affinite_vibe`** :

```
affinite_vibe = exp( −‖vibe_u − vibe_s‖² / (2σ²) )   ∈ (0,1]
```

→ « vectorisation + tirage » **collapsée en 3-4 dims cheap, déterministes et lisibles**. Les
embeddings ne servent qu'à *placer* les lignes au dev-time.

---

## 3. Architecture runtime

### 3.1 Composants

- **`ChatDirector`** (nouvel autoload) : le cerveau. S'abonne aux signaux, tient le blackboard,
  cadence l'ambient, score, tire, émet, **joue les scènes** (graphe + timers + branches).
- **`res://data/chat/`** : **tout le contenu** — `lines/*.json` (répliques), `scenes/*.json`
  (saynètes), `axes.json`/`vibe.json` (tables). Éditable sans toucher au code.
- **`ChatPanel`** (existant) : **vue passive**. Le Director émet
  `line_emitted(speaker_name, text, channel)` ; le panel rend. Lignes système factuelles
  conservées **grisées/terses** (décision §11.1 : *layered*, filtres plus tard) ; les réactions
  en personnage portent la couleur.
- **Lecteurs d'axes** : registre `axis_id → Callable(ctx) -> Variant`. Le **seul** endroit qui
  touche `SimulatedPlayer`/`GuildManager`/`SocialDynamics`. Isole le moteur du modèle de données.
- **`SceneRunner`** (sous-système du Director) : machine à états qui joue une scène active
  (casting → beats → branches → effets), une seule à la fois (cf. §6.5).

### 3.2 Le **blackboard de stimuli** (unifie réactif, ambient, scènes)

Chaque signal/ tick poste un **stimulus** dans une file ; *les handlers ne décident ni qui parle
ni quoi* :

```gdscript
class Stimulus:
    var kind: String          # "loot_epic","wipe","level_up","member_left","drama",
                              # "tension","burnout","ninja","ambient","reply"...
    var salience: float       # 0..1 priorité
    var subject = null         # membre au cœur de l'événement (pour relations/casting)
    var vars: Dictionary       # variables réelles injectables: {item, boss, wipes, zone...}
    var ttl_minutes: float     # décroît : stimulus périmé ne se déclenche plus
    var created_total_min: int # horodatage jeu
```

Chaque tick : prendre le stimulus le plus saillant non périmé → **tenter une scène** qui matche
(§6) ; sinon émettre **une ligne** (§3.4). Le blackboard donne gratuitement : mémoire (stimuli
qui décroissent → « ce ninja de tout à l'heure »), anti-rafale, priorisation.

### 3.3 Cadence — **vivant et proportionnel au nombre de joueurs** (décision §11.4)

`GameTime` va de **0.1× à 2400×**. Garde-fous :
- **Ambient cadencé en minutes de jeu**, intervalle **inversement proportionnel au nombre de
  membres en ligne** (et à leur « bavardise ») :
  ```
  interval_min ≈ clamp( base_interval / (sqrt(online_count) × talk_factor), min_gap, max_gap )
  ```
  où `talk_factor` monte avec la proportion de `social`/`funny` en ligne, baisse avec
  `solitaire`. Guilde vide (1-2 connectés) → sparse mais non muet ; 20 connectés → ça vit.
  Les **scènes** ont aussi une proba de déclenchement qui monte avec `online_count` (et elles
  exigent de toute façon un casting suffisant).
- **Plancher temps réel** : au plus ~1 émission / 1.5 s réelle → à 2400× le chat ne déborde pas.
  (Les **beats de scène** suivent leurs propres délais temps réel, cf. §6.3.)
- **Pause** : pas d'ambient quand `GameTime` est en pause (prompt d'oisiveté).
- **Fast-forward** : **chat supprimé** pendant `FastForwardManager` (décision §11.3) — pas de
  résumé. On reprend la vie normale à l'arrivée.

### 3.4 Pipeline (par tick, pour une **ligne**)

```
1. stim = blackboard.pop_most_salient()              # ou "ambient" si vide
2. si une scène matche stim (§6) et pas de scène active → lancer la scène, STOP
3. pool = pools_for(stim.kind)                        # filtre data-driven
4. locuteur(s) = sélection 2-phases (cf. ci-dessous)
5. pour chaque u du pool : score = base×Σbonus×Πveto
6. u* = softmax_sample(top_N, T(stim, locuteur))
7. texte = grammaire.expand(u*, stim.vars, locuteur)  # slots + variables réelles (§5)
8. line_emitted.emit(locuteur.nom, texte, channel)
9. si u*.provoke_reply → blackboard.push(reply_stimulus)   # threading léger (§6.6)
```

**Sélection du locuteur — deux phases** : (1) pondérer « qui a envie de parler » =
`talkativeness(trait) × f(mood) × en_ligne × équité_de_parole` → tirer 1 (parfois 2) ; (2) scorer
les répliques pour ce locuteur. Évite le O(membres×lignes).

---

## 4. Catalogue de considérations (axes réels du projet)

Branchés sur les vrais champs (`simulated_player.gd`) — briques réutilisées par lignes **et**
scènes (casting, branches) :

| Axe (`axis`) | Source | Usage typique |
|---|---|---|
| `speaker.class` | `personnage_classe` (`Mage`/`Guerrier`/`Prêtre`) | veto `requires_class: Mage` (eau, table, portail) |
| `speaker.role` | `get_role()` (Tank/Healer/DPS) | tank qui pull, heal qui manque d'eau |
| `speaker.has_trait` | `tags_comportement` / `tags_caches` | affinité de ton (tryhard, casual, drama_queen, perfectionniste, solitaire, serviable, ponctuel, retardataire, ninja_looter, greedy, rage_quitter) |
| `speaker.mood` | `mood` 0-100 | bas → +toxicité ; haut → +blague |
| `speaker.energy` | `energy` 0-100 | bas → « afk », « go dodo » |
| `speaker.stress`/`burnout` | `stress_level`, `burnout_level` | tendu → sec, sarcastique |
| `speaker.integration` | `integration` | recrue timide vs vétéran qui charrie |
| `speaker.days_in_guild` | `days_in_guild` | ancienneté, « les nouveaux… » |
| `speaker.circadian` | `circadian_type` | « team de nuit » tard le soir |
| `relation(speaker, subject)` | `relationships[id]` + `SocialDynamics` | ami félicite / rival charrie / ennemi clashe |
| `relation_to_role(role)` | idem, vs un rôle **déjà casté** | prank entre amis, clash entre rivaux (§6) |
| `context.event_magnitude` | `stim.salience` | épique vs gris, wipe #1 vs #7 |
| `context.time_of_day` | `GameTime.hour` | banter de nuit, raid du soir |
| `context.guild_morale` | `GuildCultureManager.guild_morale` | morale basse → +dramas/+sec |
| `context.phase` | `PhaseManager.current_phase` | leveling (LFG) vs esport (pression) |
| `affinite_vibe` | §2 | proximité vibe locuteur/réplique |
| `cooldown` / `equite_parole` | état Director | anti-répétition / voix à tous |

---

## 5. Grammaire de slots + injection de variables réelles

La **réactivité** vient de l'injection des variables du stimulus, pas de conditions. Réplique =
template à slots façon Tracery :

```jsonc
{
  "id": "loot_brag_rival", "pools": ["loot_epic"], "channel": "guild",
  "vibe": [-0.3, 0.7, 0.4],
  "text": "#sigh# encore #subject# qui rafle #item#, {forcément|comme par hasard|ofc}",
  "considerations": [
    { "axis": "relation", "param": "rival", "curve": "boolean", "kind": "veto" },
    { "axis": "speaker.mood", "curve": "inverse", "kind": "bonus", "weight": 0.8 }
  ],
  "cooldown_min": 180, "provoke_reply": "loot_defense"
}
```

- `#subject#`, `#item#`, `#boss#`, `#wipes#`, `#zone#` → `stim.vars` (vrais noms du jeu).
- `#symbol#` → sous-règles de grammaire (variété ; `#sigh#` = `{pff|bon|aïe}`).
- `{a|b|c}` → choix inline (tirage `GameRandom`).

Un corpus de **symboles partagés** (interjections, emotes `/`, argot vanilla) démultiplie la
variété sans réécrire les lignes.

---

## 6. Scènes scriptées à branches (multi-acteurs) — le cœur « vivant »

> Demande explicite du dev : des **interactions qui ramènent souvent plusieurs personnes**, se
> déroulent **sur plusieurs lignes avec des pauses**, comme de **vrais scripts** — et **à
> branches**, des rolls déterminant la suite selon des critères. Ex. : quelqu'un se fait
> **rickroll** ; selon ses traits il répond « haha très drôle » (timide), « ce n'est pas le bon
> lien » (sérieux), ou « MAIS BORDEL JE ME SUIS ENCORE FAIT AVOIR » (soupe-au-lait).

Une **scène** est un **graphe de dialogue data-driven** joué par le `SceneRunner`. Quatre briques :
**casting** (qui joue quel rôle), **beats** (lignes ordonnées + **pauses**), **branches** (rolls
pondérés), **effets** (impact réel sur la sim). Le moteur est générique : **ajouter une scène =
un JSON**. Le scoring du §1 est réutilisé pour le casting et la résolution de branches.

### 6.1 Modèle de données (exemple : le rickroll)

```jsonc
{
  "id": "rickroll",
  "trigger": { "pools": ["ambient", "social_prank"], "min_online": 3,
               "weight": 1.0, "cooldown_min": 1440 },

  "cast": {
    "prankster": {                                  // l'instigateur : plutôt un farceur
      "considerations": [
        { "axis": "speaker.has_trait", "param": "drama_queen", "curve": "boolean", "kind": "bonus", "weight": 1.0 },
        { "axis": "speaker.mood", "curve": "linear", "kind": "bonus", "weight": 0.5 }
      ]
    },
    "victim": {                                     // la cible : exclut le prankster
      "exclude": ["prankster"],
      "considerations": [
        { "axis": "speaker.integration", "curve": "inverse", "kind": "bonus", "weight": 0.8 },
        { "axis": "relation_to_role", "param": "prankster", "value": "ami", "curve": "boolean", "kind": "bonus", "weight": 0.6 }
      ]
    },
    "bystander": { "optional": true, "exclude": ["prankster", "victim"] }
  },

  "beats": [
    { "actor": "prankster", "delay": 0.0,
      "text": "@#victim# hey check ça, trouvé un addon de fou #url#" },

    { "actor": "victim", "delay": 3.5, "branch": {
        "axis_actor": "victim",                     // on score les options sur les axes de la victime
        "options": [
          { "id": "amuse", "text": "haha très drôle 🙄 #never_line#",
            "considerations": [
              { "axis": "speaker.has_trait", "param": "solitaire", "curve": "boolean", "kind": "bonus", "weight": 1.0 },
              { "axis": "speaker.mood", "curve": "linear", "kind": "bonus", "weight": 1.0 } ] },

          { "id": "pedant", "text": "ce n'est pas le bon lien... c'est un rickroll.",
            "considerations": [
              { "axis": "speaker.has_trait", "param": "perfectionniste", "curve": "boolean", "kind": "bonus", "weight": 1.5 } ] },

          { "id": "rage", "text": "MAIS BORDEL JE ME SUIS ENCORE FAIT AVOIR",
            "considerations": [
              { "axis": "speaker.mood", "curve": "inverse", "kind": "bonus", "weight": 1.0 },
              { "axis": "speaker.has_trait", "param": "rage_quitter", "curve": "boolean", "kind": "bonus", "weight": 1.5 } ],
            "effects": [ { "target": "victim", "mood": -5, "stress": +3 } ] }
        ] } },

    { "actor": "prankster", "delay": 2.0, "text": "{never gonna give you up 🎶|😂😂😂|gg ez}" },

    { "actor": "bystander", "delay": 1.5, "optional": true,
      "text": "#laugh# rip #victim#" }
  ]
}
```

### 6.2 Casting (réutilise le scoring)

```
pour chaque rôle (requis d'abord) :
    candidats = membres_en_ligne − déjà_castés − role.exclude_resolved
    score chaque candidat via role.considerations          # même moteur §1
    assigne via softmax (température)                       # variété de casting
    si aucun viable (tous veto 0) et rôle requis → SCÈNE AVORTÉE (essayer une autre)
```

Les rôles peuvent se référencer via `relation_to_role` (prank entre **amis**, clash entre
**rivaux**) → le graphe social pilote le casting. Rôles `optional` ignorés si pas castables.

### 6.3 Beats, timing & **pauses** (le « vivant »)

- Beats joués **séquentiellement** par un timer. `delay` = **secondes réelles** (jitter
  `GameRandom`) → les pauses *se sentent* quelle que soit la vitesse de jeu (une scène se déroule
  sur ~8-15 s réelles, comme une vraie conversation).
- *(Polish optionnel)* indicateur « #actor# est en train d'écrire… » entre deux beats.
- Une scène **ne se déclenche pas** en pause/fast-forward (cf. §3.3).

### 6.4 Branches (rolls pondérés = ta demande exacte)

Un beat peut porter un `branch`. On score les `options` via le moteur §1 sur les axes de
`axis_actor` (et ses relations aux autres rôles), puis **softmax-roll** → une option jouée. Le
rickroll : `victim` timide (`solitaire`) → « haha très drôle » ; `perfectionniste` → « pas le bon
lien » ; `mood` bas / `rage_quitter` → la rage (qui en plus **baisse son mood**). Branches
imbriquables (une option peut elle-même rediriger vers un sous-beat) — profondeur bornée.

### 6.5 Coexistence & verrou

- **Une seule scène active** à la fois. Pendant une scène, l'**ambient one-liner est suspendu**
  (lecture propre) ; les stimuli réactifs **à haute saillance** (drama, `member_left`) peuvent
  s'**intercaler** entre deux beats ou **préempter** (rare).
- Scènes **réactives** : un stimulus peut matcher une scène (ex. `loot_conflict_occurred` →
  scène « tribunal du ninja » avec `cast {accusé=subject, accusateur, défenseur}`). Quand une
  scène matche, elle est **préférée** à la simple ligne (contenu plus riche).

### 6.6 Threading émergent (couche légère, complément des scènes)

Pour les réactions courtes hors scène : une réplique peut déclarer `provoke_reply`. Le Director
poste un stimulus `reply` (TTL court) ; au tick suivant **un autre locuteur** (scoré par sa
**relation** au premier) répond. Profondeur bornée (`max_thread_depth = 2`). Donne des
mini-rebonds combinatoires là où écrire une scène complète serait excessif.

---

## 7. Anti-répétition & équité (sans code spécial)

Tout en considérations : **cooldown ligne/scène** (veto), **saturation thématique** (bonus
décroissant sur un thème récemment sur-employé), **pénalité locuteur récent**, **équité de
parole** (bonus croissant aux silencieux → tout le monde a une voix). Idem cooldown **par scène**
(`cooldown_min`) pour ne pas rejouer le rickroll trop souvent.

---

## 8. Génération du corpus (LLM, dev-time)

Pipeline outillé (Claude au dev-time, **0 dépendance runtime**) :

1. **Génération de lignes** : 2000+ répliques FR taggées `{pools, considerations, vibe,
   requires_*, provoke_reply}`.
2. **Génération de scènes** : 30-60 **saynètes à branches** multi-acteurs (cast +
   beats + branches conditionnées par traits + effets). Thèmes §8.1.
3. **Embeddings (dev-time)** : dédup (cosinus > 0.95), clustering, **audit de couverture**
   (combler les trous), projection → coords `vibe` (§2).
4. **Validation de schéma** (script `tests/`) : axes/params connus, courbes valides, pools/rôles
   référencés, `actor` de chaque beat ∈ `cast` → échoue en CI si un tag est cassé.
5. **Sortie** : `res://data/chat/**` versionné.

### 8.1 Thèmes & références vanilla à couvrir

- **Barrens chat** : Chuck Norris facts, « Mankrik's wife » (running gag), trolls bon enfant.
- **LFG/LFM** : « LFM UBRS need tank+heal, summons at stone », « anyone summon? », « inv plz ».
- **Mage/Démo utilitaire** : « MAGE TABLE up », « free water/food? », portails, summon.
- **Loot / DKP** : `/roll`, need vs greed, « DKP minus », « 50 DKP MINUS », loot council,
  **ninja looter**, « c'est MON Thunderfury ».
- **Raid logistique** : attunements (MC/Ony/BWL), resist gear, **world buffs** (« DON'T DIE »),
  « MORE DOTS », « get on vent/TS ».
- **Wipe / mort** : Leeroy Jenkins, « at least I have chicken », corpse run, « rez plz »,
  soulstone, spirit healer, « who pulled?? ».
- **Classes / clichés** : « ret pally lol », huntard & pet, « nerf rogues pls », « heal diff ».
- **Méta / serveur** : Tarren Mill vs Southshore, AFK in IF/Org, duels devant la banque, rank 14
  grind, file d'attente serveur, gold spam parodié, fishing Booty Bay.
- **Social interne** (branché sim) : félicitations level-up/loot, charrie de rival, soutien
  burnout, tension/clash sur morale basse, au-revoir sur départ.

**Scènes candidates** : rickroll · tribunal du ninja (loot conflict) · « qui a pull ?? » post-wipe
· défi en duel devant IF · panique world-buffs (« NE MOURREZ PAS ») · Leeroy moment · running gag
Mankrik's wife · bizutage de recrue · négo DKP · AFK-shaming · annonce de départ émouvante.

> Ton : nostalgique, fun, parfois salé mais **jamais haineux/discriminatoire** (garde-fou de
> génération). Le « toxique » reste du chambrage de guilde (`toxicite` modérée).

---

## 9. Points d'intégration (signaux réels)

Stimuli réactifs branchés sur l'existant (aucune décision dans les handlers) :

| Signal | `kind` | salience | `vars` |
|---|---|---|---|
| `dungeon_instance.loot_distributed` | `loot_epic`/`loot` | 0.4-0.9 | item, subject=member |
| `dungeon_instance.boss_failed` | `wipe` | 0.5-0.8 (↑ wipes) | boss, wipes |
| `dungeon_instance.boss_defeated` | `boss_kill` | 0.5 | boss |
| `dungeon_completed` | `raid_clear` | 0.6 | durée, or, wipes |
| `guild_manager.member_leveled_up` | `level_up` (1.0 si 60) | 0.3-1.0 | subject, lvl |
| `guild_manager.member_recruited` | `recruit` | 0.5 | subject |
| `guild_manager.member_left` | `member_left` | 0.8 | subject |
| `guild_manager.loot_conflict_occurred` | `ninja` (→ scène tribunal) | 0.9 | subject, item |
| `drama_manager.drama_occurred/resolved` | `drama` | 1.0 | drama |
| `guild_culture_manager.tension_detected` | `tension` | 0.7 | p1, p2 |
| `behavior_system.burnout_level_changed` | `burnout` | 0.6 | subject |
| `behavior_system.personal_event_triggered` | `perso` | 0.4 | subject, event |
| `game_time.hour_changed` / `week_changed` | (cadence ambient) | — | hour |

Le **personnage-joueur** peut être `subject`/`bystander` (les membres l'interpellent) → immersion.

---

## 10. Outillage debug & validation (répond à « chiant à debugger »)

- **Explicateur de score** (debug build, pattern `DebugMenuPanel`) : à chaque ligne émise/chaque
  casting/chaque branche, dump du top-5 avec **décomposition par considération** (« pourquoi la
  victime a ragequit : mood⁻¹ 0.8 × rage_quitter 1.0 = 0.8 ; vs amuse 0.3 »). Réglage = lecture
  de tableau, pas `print`.
- **Soak-test headless** (harnais `tests/`) : Director sur N jours simulés → transcript + stats
  (histogramme par ligne, distribution thèmes, taux répétition, % membres ayant parlé, **fréquence
  des scènes & branches empruntées**). Détecte « une ligne domine » / « les healers ne parlent
  jamais » / « la branche rage ne sort jamais » **sans lancer le jeu**.
- **Validation de schéma** en CI (§8.4).
- **Déterminisme** : tout tirage via `GameRandom` → seed fixe rejoue le même chat (testable).

---

## 11. Décisions (tranchées par le dev)

1. **Lignes système** : **layered** — système terse/grisé + réactions colorées. *Filtres plus
   tard.* ✅
2. **Modèle de score** : **`gates × Σbonus`** (Claude gère). ✅
3. **Fast-forward** : **chat supprimé** (pas de résumé). ✅
4. **Volume ambient** : **proportionnel au nombre de joueurs en ligne** (§3.3) et doit rester
   **vivant** ; défaut à calibrer en live (Phase A). ✅
5. **Saisie joueur / `/roll`** : **plus tard** (hors v1). ✅

---

## 12. Plan d'implémentation par phases

- **Phase A — Squelette & feeling** : `ChatDirector` autoload + blackboard + tick ambient
  (∝ online, game-speed-aware) + **mini-corpus main (~40 lignes banter)** + `ChatPanel` en vue.
  Valider *cadence* et *feeling* en live (MCP).
- **Phase B — Moteur de score** : considérations (`gates × Σbonus`), registre d'axes, sélection
  locuteur 2-phases, softmax/température, **explicateur de score** debug.
- **Phase C — Réactif** : stimuli branchés sur les vrais signaux (§9) + injection de variables.
- **Phase D — Scènes** : `SceneRunner` (casting + beats/timers/pauses + **branches** + effets) +
  2-3 scènes écrites main dont **le rickroll** ; threading léger (§6.6). *Le cœur « vivant ».*
- **Phase E — Robustesse** : anti-répétition/équité (§7) + **soak-test headless** + validation
  schéma CI.
- **Phase F — Gros corpus** : génération LLM lignes **+ scènes** + pipeline embeddings (dedup/
  cluster/couverture) + bake vibe-space (§2, §8).
- **Phase G — Polish & tuning** : réglage via debug, indicateur « est en train d'écrire… »,
  *stub* d'interface `ChatBackend` pour préparer le Palier 3 (LLM live opt-in) sans le construire.

Chaque phase est jouable/validable indépendamment (slice verticale dès Phase A).

---

## 13. Résumé en une phrase

Un **blackboard de stimuli** alimente un **moteur de scoring d'utilité** (vetos × bonus, dont une
**affinité de vibe** bakée au dev-time) qui **tire à température** *qui dit quoi* — et qui, pour
les grands moments, joue de **vraies scènes multi-acteurs à branches** (casting, beats avec
pauses, rolls pondérés sur les traits, effets sur la sim) — le tout **data-driven, offline,
déterministe et debuggable**, nourri par un **corpus vanilla (lignes + saynètes) généré au
dev-time par LLM**.
