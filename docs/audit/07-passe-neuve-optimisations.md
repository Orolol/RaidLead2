# Passe neuve d'optimisation - 2026-06-02

Audit après les changements récents. Objectif : ne pas recycler les anciens constats, mais regarder ce que les refactors ont corrigé, ce qui reste fragile, et les nouvelles optimisations possibles côté UI, gameplay, performance et propreté de code.

## Méthode et limites

Ce qui a été fait :

- inspection statique de `scripts/**`, `scenes/**`, `project.godot`, `tests/**` ;
- vérification des nouveaux composants extraits : `SystemNotifier`, `DebugMenuPanel`, `RecruitmentPanel` ;
- tentative de validation Godot et de lecture MCP.

Limites importantes :

- Le MCP `godot-mcp-pro` répond, mais l'éditeur n'est pas connecté : `Connection error: Godot editor is not connected`.
- La validation Godot n'a pas pu être menée : Godot 4.6.2 a crashé en natif pendant `CheckScripts.tscn`, puis le lancement 4.5 a produit l'erreur Windows montrée dans le thread.
- Le screenshot indique `Godot_v4.5-stable_win64.exe`, alors que le projet cible maintenant Godot 4.6.2. Ne pas valider ce projet avec 4.5.

Donc ce rapport est une passe statique approfondie, sans screenshot ni playtest fiable.

## Ce qui a clairement progressé

- `scripts/systems/system_notifier.gd` retire une bonne partie du bruit de notifications de `scripts/main.gd`.
- `scripts/ui/components/debug_menu.gd` isole le menu debug, ce qui rend `main.gd` plus lisible.
- `scripts/ui/windows/recruitment_panel.gd` sort le recrutement de `fenetre_monde.gd`, bonne direction pour une UI plus maintenable.
- `scripts/main.gd:607` et `scripts/main.gd:622` ajoutent un rewire après chargement de sauvegarde. C'est une vraie correction de risque après remplacement du `PlayerCharacter`.
- `scripts/autoloads/guild_manager.gd:14` et `scripts/autoloads/guild_manager.gd:269` ajoutent enfin `member_left`, avec test à `tests/run_tests.gd:681`.
- `scripts/systems/dungeon_instance.gd:277` utilise `member.get_role()` pour la composition de combat, mieux que `personnage_role`.
- `scripts/ui/windows/fenetre_monde.gd:765` délègue maintenant la fermeture au `WindowManager`.

Ces changements vont dans le bon sens. Les optimisations ci-dessous ciblent surtout les raccords encore fragiles.

## Priorités hautes

### P0 - Fermer un event peut encore casser l'EventManager

Références :

- `scripts/ui/windows/event_popup.gd:245`
- `scripts/ui/windows/event_popup.gd:263`
- `scripts/autoloads/event_manager.gd:221`
- `scripts/autoloads/event_manager.gd:238`
- `scripts/autoloads/event_manager.gd:241`
- `scripts/autoloads/event_manager.gd:265`
- `scripts/autoloads/event_manager.gd:271`

`EventPopup._on_close_requested()` appelle `event_manager.dismiss_event()`. `dismiss_event()` appelle `resolve_event(pending_event, null)`, mais `resolve_event()` lit ensuite `choice.text` puis `choice.apply_consequences()`.

Impact probable : fermer la popup d'événement via X/Escape peut provoquer une erreur runtime au lieu de simplement dismiss l'événement. C'est d'autant plus critique que les events mettent le jeu en pause.

Recommandation :

- séparer `dismiss_event()` de `resolve_event()` ;
- ou accepter `choice == null` dans `resolve_event()` avec un chemin explicite sans conséquences ;
- ajouter un test qui ouvre un event puis appelle `dismiss_event()`.

### P1 - Les donjons tournent maintenant à chaque frame depuis `main`

Références :

- `scripts/main.gd:214`
- `scripts/main.gd:218`
- `scripts/systems/activity_manager.gd:440`
- `scripts/systems/dungeon_instance.gd:144`
- `scripts/systems/dungeon_instance.gd:153`
- `scripts/systems/dungeon_instance.gd:415`
- `scripts/systems/dungeon_instance.gd:422`

Le correctif récent relance bien la progression des donjons, mais le choix actuel fait poller `ActivityManager.update_dungeons(delta)` depuis `main._process()` à chaque frame, même quand aucun donjon n'est actif. En plus, les donjons avancent avec `delta * GameTime.time_speed`, alors que les autres activités sont pilotées par `GameTime.minute_changed`.

Risques :

- coût permanent inutile ;
- progression frame-rate dependent ;
- émissions `progress_updated` très fréquentes à haute vitesse ;
- logique temporelle divisée entre "tick de simulation" et "frame de rendu".

Recommandation :

- déplacer le ticking dans `ActivityManager` ;
- activer le process seulement si `active_dungeons.size() > 0` ;
- ou mieux : avancer les donjons sur un tick de simulation borné, cohérent avec `GameTime`.

### P1 - NotificationManager écoute encore un ancien signal de recrutement

Références :

- `scripts/autoloads/recruitment_pool.gd:3`
- `scripts/autoloads/recruitment_pool.gd:53`
- `scripts/autoloads/recruitment_pool.gd:176`
- `scripts/autoloads/recruitment_pool.gd:334`
- `scripts/managers/notification_manager.gd:114`
- `scripts/managers/notification_manager.gd:115`
- `scripts/managers/notification_manager.gd:473`

`RecruitmentPool` émet `pool_refreshed`, mais `NotificationManager` cherche `pool_updated`. Résultat : les notifications liées au renouvellement du pool ne partent jamais.

Recommandation :

- remplacer `pool_updated` par `pool_refreshed` ;
- adapter la signature de `_on_recruitment_pool_updated`, car `pool_refreshed` n'envoie aucun argument ;
- ajouter un test de connexion ou un smoke test NotificationManager.

### P1 - Les raccourcis clavier contournent les verrous de phase

Références :

- `scripts/ui/components/menu_bar.gd:57`
- `scripts/ui/components/menu_bar.gd:67`
- `scripts/ui/components/menu_bar.gd:118`
- `scripts/ui/components/menu_bar.gd:127`
- `scripts/ui/components/menu_bar.gd:132`
- `scripts/main.gd:220`
- `scripts/main.gd:226`
- `scripts/main.gd:235`

Le menu grise bien certains boutons selon la phase, mais `main._input()` appelle directement les handlers privés du menu. Les boutons désactivés ne protègent pas forcément les raccourcis ou appels directs.

Recommandation :

- exposer une méthode publique `request_open(window_name)` dans `MenuBar` ou `WindowManager` ;
- vérifier `_is_window_locked(window_name)` avant d'émettre le signal ;
- ne plus appeler `_on_*_pressed()` depuis `main`.

### P1 - Le rewire post-save laisse une connexion UI vers l'ancien PlayerCharacter

Références :

- `scripts/main.gd:622`
- `scripts/main.gd:635`
- `scripts/main.gd:642`
- `scripts/ui/components/player_control_panel.gd:171`
- `scripts/ui/components/player_control_panel.gd:177`
- `scripts/ui/components/player_control_panel.gd:178`

`main._rewire_player_after_load()` déconnecte ses propres callbacks de l'ancien joueur, puis appelle `player_control_panel.set_player_character(new_pc)`. Mais `PlayerControlPanel.set_player_character()` ne déconnecte pas `_update_display` de l'ancien `player_character` avant de remplacer la référence.

Impact : après un load, l'ancien resource peut encore déclencher `_update_display()` sur le panneau. C'est un risque de fuite de signal et d'affichage incohérent.

Recommandation :

- dans `set_player_character(player)`, si l'ancien joueur est différent et connecté, déconnecter `old.player_state_changed` ;
- ajouter un test léger : assigner joueur A, puis B, vérifier que A n'a plus `_update_display` connecté.

## UI et ergonomie

### P1 - Le panneau de détails du recrutement peut déborder

Références :

- `scripts/ui/windows/recruitment_panel.gd:83`
- `scripts/ui/windows/recruitment_panel.gd:85`
- `scripts/ui/windows/recruitment_panel.gd:237`
- `scripts/ui/windows/recruitment_panel.gd:239`
- `scripts/ui/windows/recruitment_panel.gd:271`
- `scripts/ui/windows/recruitment_panel.gd:293`

Le panneau droit est un `VBoxContainer` direct, sans `ScrollContainer`. Les détails peuvent devenir longs : tags révélés, motivation BBCode, planning, salaire, agent, scout, boutons. Le `RichTextLabel.fit_content = true` aggrave le risque d'extension verticale.

Recommandation :

- mettre `recruit_details` dans un `ScrollContainer` ;
- fixer des tailles minimales/maximales propres ;
- garder les boutons d'action dans une zone stable en bas si possible.

### P1 - La sélection d'une recrue repose sur un index recalculé

Références :

- `scripts/ui/windows/recruitment_panel.gd:119`
- `scripts/ui/windows/recruitment_panel.gd:149`
- `scripts/ui/windows/recruitment_panel.gd:159`
- `scripts/ui/windows/recruitment_panel.gd:181`
- `scripts/ui/windows/recruitment_panel.gd:104`

La liste est reconstruite avec un filtre, puis `_on_recruit_selected(index)` refait un `get_available_players(filters)` et reprend `filtered_players[index]`. Si le pool change entre l'affichage et le clic, l'index peut pointer vers un autre joueur.

Recommandation :

- maintenir `_visible_recruits: Array[SimulatedPlayer]` ;
- ou utiliser `ItemList.set_item_metadata(index, player)` puis `get_item_metadata(index)`.

### P2 - Certaines fenêtres ferment encore en `hide()` local

Références :

- `scripts/ui/windows/fenetre_conseils.gd:69`
- `scripts/ui/windows/fenetre_national.gd:73`
- `scripts/ui/windows/fenetre_esport.gd:80`
- `scripts/ui/windows/fenetre_social.gd:72`
- `scripts/ui/windows/fenetre_organisation_groupe.gd:730`
- `scripts/ui/windows/fenetre_organisation_groupe.gd:731`
- `scripts/ui/components/resizable_window.gd:111`
- `scripts/ui/components/resizable_window.gd:113`

`Fenetre_Monde` et `Fenetre_Personnage` ont été corrigées, mais plusieurs fenêtres ferment encore elles-mêmes. Cela peut désynchroniser `WindowManager.open_windows`.

Recommandation :

- standardiser : chaque fenêtre émet `close_requested`, le `WindowManager` décide ;
- éviter `hide()` dans les callbacks de fermeture des fenêtres managées ;
- ajouter un test `WindowManager.is_window_open()` après fermeture.

### P2 - Rôle affiché en donjon différent du rôle utilisé au combat

Références :

- `scripts/systems/dungeon_instance.gd:277`
- `scripts/ui/windows/fenetre_donjon.gd:174`

La simulation utilise maintenant `member.get_role()`, mais l'UI de donjon affiche encore `member.personnage_role`. Un joueur peut voir un rôle vide/désynchronisé alors que la simulation utilise un fallback correct.

Recommandation : afficher `member.get_role()` dans `Fenetre_Donjon`.

### P2 - Le label de position dans Monde est retrouvé par parcours fragile

Références :

- `scripts/ui/windows/fenetre_monde.gd:126`
- `scripts/ui/windows/fenetre_monde.gd:130`
- `scripts/ui/windows/fenetre_monde.gd:364`
- `scripts/ui/windows/fenetre_monde.gd:369`

`_update_our_position_info()` retrouve le label via les données d'onglet et les enfants. Le label est pourtant créé localement. C'est fragile dès que la structure de l'onglet change.

Recommandation : stocker `var our_position_label: Label` comme membre de la fenêtre.

## Gameplay et boucle de jeu

### P1 - Repos : le fast-forward reste synchrone et coûteux

Références :

- `scripts/main.gd:657`
- `scripts/main.gd:677`
- `scripts/main.gd:697`
- `scripts/autoloads/game_time.gd:100`
- `scripts/autoloads/game_time.gd:101`
- `scripts/autoloads/game_time.gd:103`

Le repos est devenu plus fluide côté UX, mais `GameTime.fast_forward_hours(hours)` émet toujours minute par minute (`60 * hours`). Un repos de 8h déclenche 480 minutes et tous les abonnés de `minute_changed`, en un seul appel.

Recommandation :

- pour le repos, appliquer directement les effets recherchés au lieu de simuler toutes les minutes ;
- ou introduire un mode fast-forward budgété par frame ;
- au minimum, mesurer le coût à haute vitesse avec 30 membres.

### P2 - Recrutement standard encore alimenté par des données hardcodées

Références :

- `scripts/ui/windows/recruitment_panel.gd:441`
- `scripts/ui/windows/recruitment_panel.gd:453`
- `scripts/ui/windows/recruitment_panel.gd:454`
- `scripts/ui/windows/recruitment_panel.gd:459`

Le panneau de recrutement est mieux isolé, mais `_on_invite_pressed()` garde :

- des logs `Debug:` visibles en production ;
- `"hardcore": false` ;
- `"recent_raid_success": false`.

Impact gameplay : les motivations des candidats ne reflètent pas encore le vrai profil de guilde, donc le recrutement peut sembler arbitraire.

Recommandation :

- extraire un `GuildManager.get_recruitment_context()` ;
- alimenter `hardcore`, succès récents, réputation, phase, culture ;
- enlever les logs debug ou les passer derrière un flag.

### P2 - Le menu debug annonce une action non implémentée

Références :

- `scripts/ui/components/debug_menu.gd:34`
- `scripts/ui/components/debug_menu.gd:88`
- `scripts/ui/components/debug_menu.gd:90`
- `scripts/ui/components/debug_menu.gd:91`
- `scripts/ui/components/debug_menu.gd:92`

L'action "Donner équipement aux membres" fait `pass`, mais loggue quand même "+10 équipement". Même en debug, c'est trompeur pour tester l'équilibrage.

Recommandation :

- l'implémenter réellement ;
- ou la désactiver/renommer "TODO équipement" ;
- ou ne rien logger si l'action ne fait rien.

## Propreté de code et architecture

### P1 - SystemNotifier doit être idempotent

Références :

- `scripts/systems/system_notifier.gd:14`
- `scripts/systems/system_notifier.gd:24`
- `scripts/systems/system_notifier.gd:30`
- `scripts/systems/system_notifier.gd:76`
- `scripts/systems/system_notifier.gd:119`
- `scripts/main.gd:440`
- `scripts/main.gd:443`

Le refactor est positif, mais `setup()` connecte beaucoup de signaux sans garde `is_connected`. En hot reload, reload de scène, ou double setup accidentel, les notifications peuvent être doublées.

Recommandation :

- ajouter une méthode `_connect_once(signal, callable)` ;
- ou stocker un bool `_is_setup`;
- typer `_chat_panel` au lieu de `var _chat_panel = null`;
- prévoir `_exit_tree()` si ce Node peut être supprimé.

### P2 - DebugMenuPanel appelle des méthodes privées d'autres UI

Références :

- `scripts/ui/components/debug_menu.gd:97`
- `scripts/ui/components/debug_menu.gd:147`
- `scripts/ui/components/debug_menu.gd:148`

Le menu debug force `server_version._check_version_update()`, `guilde_inst._refresh_member_list()` et `_update_guild_info()`. Ce n'est pas catastrophique pour du debug, mais cela crée un couplage à des détails internes.

Recommandation :

- exposer des méthodes publiques `refresh()`, `force_version_check()`, etc. ;
- ou envoyer un signal debug consommé par la fenêtre.

### P2 - RecruitmentPanel a encore des types faibles

Références :

- `scripts/ui/windows/recruitment_panel.gd:16`
- `scripts/ui/windows/recruitment_panel.gd:17`
- `scripts/ui/windows/recruitment_panel.gd:126`
- `scripts/ui/windows/recruitment_panel.gd:172`

`available_players`, `selected_recruit`, `filters` restent peu typés. Sur un composant UI aussi central, les erreurs d'index ou d'objet se verront tard.

Recommandation :

- `var selected_recruit: SimulatedPlayer = null` ;
- `var _visible_recruits: Array[SimulatedPlayer] = []` ;
- `var filters: Dictionary[String, Variant] = {}` si supporté par la version GDScript ciblée, sinon `Dictionary` mais documenté.

### P2 - Les autoloads MCP sont encore dans `project.godot`

Références :

- `project.godot:45`
- `project.godot:46`
- `project.godot:47`

Les services MCP sont chargés comme autoloads du projet. C'est pratique en dev, mais à contrôler avant build/export Steam.

Recommandation :

- vérifier si ces autoloads doivent être exclus en export ;
- ou les protéger par une config dev ;
- documenter explicitement leur statut dans le pipeline de build.

### P3 - Le projet reste fixe en 1920x1080 non redimensionnable

Références :

- `project.godot:54`
- `project.godot:55`
- `project.godot:56`

`window/size/resizable=false` et viewport 1920x1080 facilitent le dev, mais limitent les vérifications d'UI responsive.

Recommandation :

- ajouter au moins des tests/smoke à 1366x768, 1600x900, 1920x1080 ;
- rendre les fenêtres internes robustes avant de rendre la fenêtre OS redimensionnable.

## Tests à ajouter en priorité

1. `EventManager.dismiss_event()` ne doit pas deref `choice == null`.
2. `NotificationManager` doit se connecter à `RecruitmentPool.pool_refreshed`.
3. `PlayerControlPanel.set_player_character()` doit déconnecter l'ancien joueur.
4. `RecruitmentPanel` doit conserver la bonne recrue si le pool refresh entre rendu et clic.
5. `SystemNotifier.setup()` doit être idempotent.
6. `ActivityManager` doit avancer un donjon de manière déterministe à vitesse élevée et à FPS variable.
7. `WindowManager` doit rester synchronisé après fermeture de chaque fenêtre principale.

## Ordre d'attaque conseillé

1. Corriger `dismiss_event()` : petit patch, gros impact.
2. Corriger les signaux driftés : `pool_refreshed`, `PlayerControlPanel`, `SystemNotifier`.
3. Stabiliser `RecruitmentPanel` : metadata de liste + scroll + données de guilde réelles.
4. Sortir `update_dungeons()` de `main._process()` et unifier le temps de simulation.
5. Standardiser les fermetures de fenêtres via `WindowManager`.
6. Une fois Godot relançable, faire une passe visuelle : recrutement, event popup, donjon actif, raccourcis de phase, fermeture de chaque fenêtre.

## Note tooling

Le crash montré par la popup est sur Godot 4.5, mais le projet indique Godot 4.6.2 dans `AGENTS.md`. À court terme, la priorité tooling est de retrouver une validation stable avec :

```powershell
& "C:\Users\gaeta\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe" --rendering-driver opengl3 --headless --path . "res://tests/CheckScripts.tscn"
```

Tant que cette commande et le MCP ne sont pas stables, chaque changement UI/gameplay reste plus coûteux à sécuriser.
