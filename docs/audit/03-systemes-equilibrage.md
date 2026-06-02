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
