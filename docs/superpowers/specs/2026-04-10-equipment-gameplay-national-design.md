# Design : Equipement + Gameplay + Milestone 3 National
*10 avril 2026*

## Feature 1 : Ameliorations Equipement

### 1.1 Historique de Loot
- Stockage dans `GuildManager` : Array `loot_history` de dictionnaires `{item: Item, member_name: String, dungeon_name: String, boss_name: String, timestamp: Dictionary}`
- Methode `GuildManager.add_loot_entry(item, member_name, dungeon_name, boss_name)`
- Appele depuis `DungeonRun` apres chaque distribution de loot
- Limite a 200 entrees (FIFO)
- Sauvegarde/chargement via SaveManager (`save_data.loot_history`)
- UI : nouvel onglet "Historique" dans `Fenetre_Guilde` via AdvancedTabs, avec filtre par joueur et par rarete

### 1.2 Auto-Equipement
- Methode `SimulatedPlayer.try_auto_equip(item: Item) -> Dictionary` retourne `{equipped: bool, old_item: Item}`
- Logique : compare iLvl + stat prefere (voir 2.1). Si upgrade net, equipe automatiquement
- Appele dans `DungeonRun._distribute_loot()` juste apres attribution
- Message ChatPanel : "[Equip] {joueur} equipe {item} (iLvl {old} -> {new})"
- Si pas d'upgrade, l'item est juste ajoute a l'historique sans equipement

### 1.3 Comparaison d'Items
- Dans `Fenetre_Equipement._update_equipment_display()`, afficher les deltas stats sous chaque item
- Format : "FOR +5 / AGI -2 / INT +0" avec couleurs vert/rouge
- Compare avec le slot vide (deltas = stats de l'item) ou l'item precedent si historique disponible

## Feature 2 : Mecaniques Gameplay

### 2.1 Preferences Equipement IA
- Dictionnaire `STAT_PREFERENCES` dans `SimulatedPlayer` :
  ```
  Guerrier, Paladin -> "strength"
  Voleur, Chasseur -> "agility"  
  Mage, Pretre, Demoniste, Chaman, Druide -> "intelligence"
  ```
- Score d'item : `ilvl * 1.0 + preferred_stat * 0.3`
- `try_auto_equip` utilise ce score au lieu du simple iLvl
- Les NPCs refusent un item avec +3 iLvl mais sans leur stat preferee si l'actuel en a

### 2.2 Conflits de Loot
- Dans `DungeonRun._distribute_loot()`, avant attribution :
  - Identifier tous les membres eligibles (meme slot, upgrade pour eux)
  - Si item rarete >= RARE et 2+ eligibles : creer un `LootConflict`
- Resource `LootConflict` : `{item: Item, candidates: Array[SimulatedPlayer], dungeon_name: String, boss_name: String}`
- Signal `GuildManager.loot_conflict_occurred(conflict)` connecte a Main
- Popup dans Main : affiche les candidats avec leurs stats actuelles dans le slot, le joueur choisit
- Candidats non retenus : `satisfaction -= 5`, message ChatPanel
- Si le joueur ne choisit pas (timeout ou fermeture) : attribution aleatoire

## Feature 3 : Milestone 3 - Phase Nationale

### 3.1 Systeme de Celebrite
**Fichier** : proprietes dans `SimulatedPlayer`
- `celebrity_level: float` (0.0 - 100.0)
- `public_recognition: float` (0.0 - 1.0) = celebrity_level / 100
- Gains : +2 par first kill, +1 par raid reussi, +5 si tag "social"/"drama_queen", +0.5 par semaine si skill > 80
- Decroissance : -1 par semaine naturellement
- Effets :
  - celebrity > 30 : +10% chance recrutement accepte
  - celebrity > 60 : debauchage cible (+20% tentatives IA)
  - celebrity > 80 : risque drama spontane (+15%)
- Interface : barre celebrity dans details membre, badge "star" si > 50

### 3.2 Streaming et Medias
**Fichier** : `scripts/systems/media_manager.gd` (autoload)
- Proprietes SimulatedPlayer : `is_streamer: bool`, `audience_size: int` (0-100000), `stream_revenue: float`
- Probabilite de devenir streamer : 10% si celebrity > 40 et tag "social"
- `audience_size` croit avec celebrity et regularite, decroit si absences
- Revenus : `audience_size * 0.01` or/semaine pour la guilde (partage 50/50)
- Conflits generes :
  - "streaming_vs_raid" : streamer rate un raid pour streamer (5% chance/semaine si streamer)
  - "strategy_leak" : divulgation strat (3% chance si streamer + raid prevu)
  - "live_incident" : incident en live (2% chance, impact reputation)
- Interface : icone stream dans liste membres, revenus dans Fenetre_Personnage

### 3.3 Systeme de Sponsors  
**Fichier** : `scripts/systems/sponsorship_manager.gd` (autoload)
- Resource `Sponsor` (`scripts/resources/sponsor.gd`) :
  - `sponsor_name: String`
  - `sponsor_type: String` ("equipementier" | "marque_gaming" | "plateforme")
  - `weekly_revenue: int` (50-500 or/semaine)
  - `duration_weeks: int` (4-52)
  - `requirements: Dictionary` (min_reputation, min_members, min_audience, no_scandal_weeks)
  - `weeks_remaining: int`
  - `satisfaction: float` (0-100)
- Pool de 5-10 sponsors disponibles, rotation mensuelle
- Negociation : proposition basee sur reputation + audience totale des streamers
- Obligations verifiees chaque semaine : si non remplies, `satisfaction -= 10`
- Satisfaction < 30 : sponsor rompt le contrat, -10 reputation
- Max 3 sponsors actifs simultanement
- Interface : section "Sponsors" dans Fenetre_Personnage avec contrats actifs et offres

### 3.4 Gestion des Dramas et Crises
**Fichier** : `scripts/systems/drama_manager.gd` (autoload)
- Resource `Drama` (`scripts/resources/drama.gd`) :
  - `drama_type: String` ("scandal" | "internal_conflict" | "public_controversy" | "loot_rage")
  - `severity: int` (1-3)
  - `source_member: String`
  - `description: String`
  - `active: bool`
  - `resolution_weeks: int`
- Declencheurs :
  - Celebrity > 80 : 15% chance/semaine de scandale
  - Conflit loot non resolu : 30% de declencher "loot_rage"
  - Streamer incident : genere "public_controversy"
  - 2 membres avec tag "drama_queen" : 10%/semaine "internal_conflict"
- Reponses (via EventPopup) :
  - "Silence" : resolution lente (4 sem), faible impact reputation
  - "Communication" : resolution moyenne (2 sem), reputation neutre
  - "Sanctions" : resolution rapide (1 sem), moral -15, reputation +5
  - "Exclusion du membre" : immediat, moral -25 mais reputation +10
- Impact : reputation -= severity * 5, moral -= severity * 3, sponsors satisfaction -= severity * 8
- Recuperation : cooldown de `resolution_weeks` avant que les effets se dissipent

### 3.5 Pool de Recrutement National
**Fichier** : extension de `scripts/autoloads/recruitment_pool.gd`
- Quand phase >= NATIONAL :
  - Pool etendu a 50-100 joueurs
  - Joueurs niveau 55-60 avec skills 60-90
  - Qualite globalement superieure
- Semi-professionnels : propriete `salary_demand: int` (10-100 or/semaine)
- Negociation multi-etapes :
  1. Proposition initiale (le joueur offre un salaire)
  2. Contre-proposition possible (NPC demande +20-50%)
  3. Acceptation/Refus
  - Facteurs : reputation guilde, salaire offert vs demande, competition IA
- Agents : 20% des recrues nationales ont un agent, commission de 2 semaines de salaire
- Scouting : methode `scout_player(player)` revele stats cachees, coute reputation points
- Filtrage etendu : par skill minimum, par salary range

### Conditions de progression Phase 2 -> Phase 3
- Deja definies dans PhaseManager : TOP 1 serveur 2 semaines + 15 membres + 80% contenu

### Integration entre systemes
- Celebrity alimente Streaming (prerequis), Sponsors (audience), Dramas (declencheur)
- Streaming genere revenus pour Sponsors, declencheurs pour Dramas
- Sponsors dependent de reputation (impactee par Dramas)
- Dramas impactent tout : reputation, moral, sponsors, recrutement
- Recrutement National beneficie de reputation haute et sponsors actifs

### Fichiers a creer
- `scripts/resources/sponsor.gd`
- `scripts/resources/drama.gd`
- `scripts/systems/media_manager.gd`
- `scripts/systems/sponsorship_manager.gd`
- `scripts/systems/drama_manager.gd`

### Fichiers a modifier
- `scripts/autoloads/guild_manager.gd` : loot_history, loot_conflict signal
- `scripts/resources/simulated_player.gd` : celebrity, streamer, salary, stat preferences, try_auto_equip
- `scripts/systems/dungeon_run.gd` ou `dungeon_instance.gd` : auto-equip + loot conflict
- `scripts/autoloads/recruitment_pool.gd` : pool national, negociation
- `scripts/ui/windows/fenetre_guilde.gd` : onglet historique, celebrity display
- `scripts/ui/windows/fenetre_equipement.gd` : comparaison deltas
- `scripts/ui/windows/fenetre_personnage.gd` : section sponsors, revenus
- `scripts/main.gd` : connexion loot conflict popup, drama popup
- `project.godot` : autoloads MediaManager, SponsorshipManager, DramaManager
