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
