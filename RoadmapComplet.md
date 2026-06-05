# Roadmap Complète - RaidLead
*Document unifié - État au 10 avril 2026*

## Vue d'ensemble du projet

**RaidLead** est un jeu de gestion de guilde MMORPG développé avec **Godot Engine 4.6.2** et **GDScript**. Le joueur manage une guilde d'élite à travers 4 phases de progression : Leveling (0) → Serveur (1) → National (2) → Esport (3).

### État actuel
- ✅ **Phase active** : Phase 0 "Leveling" 
- ✅ **Compilation** : Sans erreurs, jeu fonctionnel
- ✅ **Systèmes core** : Tous implémentés et opérationnels
- ✅ **Refactoring majeur** : WindowManager, GuildManager, autoloads, save/load
- 🎯 **Progression** : ~55% du projet total terminé

### Mise a jour - Correctifs audit cohesion & branchement (5 juin 2026)
Implementation des correctifs de l'audit `docs/audit/2026-06-04-cohesion-branchement.md` (plan : `docs/audit/2026-06-04-plan-implementation.md`), en 3 lots + revue de coherence adversariale, valides en headless (Godot 4.6.2). Branche `feat/audit-cohesion-fixes`. **Etat final : 107 scripts compilent (CheckScripts), 319/319 tests verts (264 -> +55), Main.tscn boote sans erreur.**
- 🔴 **Soft-lock de progression de phase corrige (CRITIQUE)** : Serveur->National->Esport etait impossible en partie normale (aucun chemin n'appelait `unlock_next_phase()` au-dela de la Phase 0). Ajout de `PhaseManager.can_advance_phase()` (pur) + bouton manuel « Passer a la phase suivante » (popup + onglet Progression). National & Esport sont desormais reellement atteignables. Test E2E sans `force_phase_change`. (Revue : suppression du dialog de confirmation fantome qui apparaissait au clic d'avance.)
- 🟠 **2 crashes runtime latents** : drag&drop d'organisation (`item.get_drag_data()` inexistant -> `item.drag_data`) ; `Object.get()` a 2 args dans l'eval d'activite (-> `set_meta`/`get_meta`).
- 🟠 **Boucles de gameplay rebranchees** : reputation PvE (`on_raid_success`/`on_raid_failure`/`on_server_first` appelees, guildes IA exclues) ; effets/bonus de guilde et de joueur reellement consommes (routage vers `get_effective_*`/`get_modified_*`, zero regression hors effet actif) ; effet `injured` applique (branche `TargetType.PLAYER`) + blocage des blesses en compo ; debauchage/contre-offre rendu jouable (retrait differe apres decision joueur, chemin de mutation unique idempotent).
- 🟠 **Garde `is_player`** : le personnage joueur ne peut plus etre retire (`remove_member` + redirection drama « exclusion » -> sanctions).
- 🟠 **Save/load** : merge non destructif de `phase_progress` (achievements/milestones preserves), serialisation de `scheduled_absences` + `active_effects`, autosave differee si run de donjon en cours (plus de run tue silencieusement), re-wiring de `fenetre_personnage` apres load.
- 🟡 **Rang & equilibrage** : compteurs `server_days_at_rank_1` / `national_days_at_rank_1` separes + reset au changement de phase ; `TOTAL_GUILDS` au runtime ; cap `gold_storage` (200000) et `max_members` (20) en `max` (plus d'addition entre paliers) ; gardes de phase Esport sur tournois/transferts/salaires staff.
- 🟡 **Signaux & coherence** : `gold_changed` emis/consomme, `catchup_applied`/`content_unlocked` branches (toast/chat) ; chat recalibre (`loot_epic` EPIC strict, `ninja` reserve aux tagges reveles) ; comportement (bonus_session_active arme, jours absolus) ; RNG `randomize_rng()` au boot d'une nouvelle partie.
- 🧹 **Code mort supprime** (14 fichiers, ~3000 lignes) : `fast_forward_manager`/`fast_forward_dialog` (~852 l.), suite `scripts/ui/dialogs/` (doublon de `components/confirm_dialog.gd`), `tooltip.gd`, `_simulate_dungeon_run` + fonctions/signaux orphelins (re-confirmes zero-appelant ; items reactives par les lots et `chat_backend.gd`/`singletons.gd` preserves). Palette alignee sur `UITheme`. Typage statique renforce. CI : etape d'import durcie.
- 📋 **Reporte (decision a arbitrer)** : modificateurs Phase 0 (`skill_malus`/`tag_reveal_rate`/`connection_bonus`) — les cabler change l'equilibrage de la phase de depart (et le test PvE reproductible) ; a trancher : cabler vs retirer la config morte.

### Mise a jour - HUD gameplay persistant (4 juin 2026)
- ✅ **ResourceBar** : or, reputation, moral, membres en ligne, serveur/hype, date/heure et vitesse sont visibles en permanence dans une top bar reactive.
- ✅ **ObjectiveTracker** : objectif de phase et progression globale visibles en HUD, recalcules au chargement et sur les signaux de progression/roster/ranking.
- ✅ **AlertRail** : rail d'alertes persistant branche sur dramas, conseils prioritaires, recrues qui expirent et risques burnout/stress, avec routage vers les fenetres existantes.
- ✅ **Navigation hubs** : barre basse reduite a 5 entrees (Guilde, Competition, Business, Recrutement, Conseil) avec scenes Hub_* servant de facade vers les fenetres existantes.
- ✅ **Sections embarquees ciblees** : les hubs embarquent les fenetres legacy compatibles dans leurs onglets, avec relais des signaux critiques comme le recrutement ; les vues roster/equipement restent en facade jusqu'a extraction en composants dedies.
- ✅ **Signal economie** : `Guild.gold_changed(old_gold, new_gold)` ajoute sur `add_gold`, `spend_gold` et `set_gold`, pour eviter le polling UI.
- ✅ **Inspecteur contextuel** : selection partagee via `GuildManager.member_selected`, panneau `MemberInspector` persistant, actions directes roster/cohesion/equipement/PvE.
- ✅ **Deep-links UI** : ResourceBar, ObjectiveTracker, AlertRail et anciens raccourcis routent vers hub + section ; les alertes burnout/recrutement transmettent le membre ou candidat concerne.
- ✅ **Polish hubs** : sections non embarquees converties en syntheses jouables (roster, equipement, profil joueur, groupe PvE, progression, besoins roster), raccourcis internes Tab/1-9 et refresh reactif.
- ✅ **Correction layout hubs** : contenus d'onglets ancres plein panneau, clipping actif, chrome et sous-onglets legacy masques dans les sections embarquees pour eviter debordements et doublons visuels.
- 📋 **Reste a faire** : extraction complete des dernieres fenetres legacy lourdes en composants dedies et screenshots MCP quand l'editeur est connecte.

---

# PARTIE A : CE QUI EST FAIT ✅

## 1. Systèmes Core (100% complets)

### 1.1 Système de Temps (GameTime)
- ✅ Calendrier complet (jours, semaines 1-52, années)
- ✅ Horloge 24h avec contrôles de vitesse (0.1x à 2400x)
- ✅ Signaux pour changements temporels
- ✅ Interface de contrôle avec pause

### 1.2 Joueurs Simulés (SimulatedPlayer)  
- ✅ Génération procédurale (noms, classes, stats)
- ✅ Système de tags comportementaux (6 catégories, 50+ tags)
- ✅ Révélation progressive des traits cachés
- ✅ Planning hebdomadaire de disponibilité
- ✅ États : énergie, humeur, skill, intégration
- ✅ Connexion/déconnexion automatiques
- ✅ **Dynamic Behavior System** : Comportements adaptatifs basés sur profils psychologiques
- ✅ **Fatigue & Burnout** : Système à 3 niveaux avec impacts progressifs
- ✅ **Relations sociales** : Amitiés, rivalités, cliques avec influence sur présence

### 1.3 Système d'Activités (Activity & ActivityManager)
- ✅ 6 types : Leveling, Farming, Fun, Donjon, Raid, Offline
- ✅ Gestion automatique selon état du joueur
- ✅ Effets sur énergie, humeur, intégration
- ✅ Zones de leveling authentiques WoW Vanilla
- ✅ Calcul de progression XP
- ✅ **Préférences dynamiques** : Choix d'activités basés sur personnalité et expériences
- ✅ **Apprentissage** : Ajustement des préférences selon succès/échecs

### 1.4 Système de Donjons/Raids (DungeonData & DungeonRun)
- ✅ Base de données complète WoW Vanilla
- ✅ Simulation combats de boss avec probabilités
- ✅ Calcul basé sur niveau, équipement, skill, composition
- ✅ Système de loot avec distribution
- ✅ Gestion des wipes et conséquences
- ✅ Compositions requises (tanks, healers, DPS)

- ✅ Polish UI donjon : timeline lisible, marqueurs de boss stylés, liste de groupe clarifiée, rapport de loot sans débordement horizontal

### 1.5 Pool de Recrutement (RecruitmentPool)
- ✅ Pool dynamique de 15-30 joueurs disponibles
- ✅ Actualisation quotidienne
- ✅ Refresh complet tous les 3 jours
- ✅ Compétition avec 9 guildes IA
- ✅ Difficulté basée sur qualité du joueur
- ✅ Filtrage par classe, niveau, rôle

### 1.6 Gestionnaire de Guilde (GuildManager)
- ✅ Gestion centralisée des membres
- ✅ Connexion/déconnexion selon horaires
- ✅ Attribution d'activités par défaut
- ✅ Signaux pour changements d'état
- ✅ Intégration avec tous les systèmes
- ✅ **Intégration BehaviorSystem** : Connexions/déconnexions dynamiques
- ✅ **Gestion événements personnels** : Urgences, obligations, temps bonus

### 1.7 Dynamic Behavior System (100% complet) - NOUVEAU
- ✅ **BehaviorProfile** : Profils psychologiques uniques (stress_tolerance, flexibility, social_needs)
- ✅ **Système de Fatigue** : Accumulation progressive avec 3 niveaux de burnout
- ✅ **SocialDynamics** : Relations bidirectionnelles (amitié, rivalité, mentor/élève)
- ✅ **Formation de Cliques** : Sous-groupes avec horaires synchronisés
- ✅ **PersonalEvents** : 20+ événements (urgences 5%, obligations 10%, temps bonus 8%)
- ✅ **Horaires Dynamiques** : Variance ±30min, influence sociale +40% si amis en ligne
- ✅ **Préférences Circadiennes** : Types matin/soir/flexible avec impacts performance
- ✅ **Mémoire Émotionnelle** : Impact durable des succès/échecs sur comportement
- ✅ **Contagion Sociale** : Propagation d'humeur et influence sur connexions
- ✅ **Patterns Détectables** : "always_late_monday", "weekend_warrior", etc.

## 2. Phase 0 "Leveling" (100% complète)

### 2.1 Configuration Phase
- ✅ **Enum** : `GamePhase.LEVELING = 0`
- ✅ **Objectif** : Compléter 1 donjon héroïque pour progresser
- ✅ **Modificateurs spéciaux** :
  - `connection_bonus: 0.2` (+20% aux horaires)
  - `skill_malus: 0.2` (-20% skill, non-familiarité)
  - `tag_reveal_rate: 0.2` (seulement 20% des tags révélés)

### 2.2 Progression Automatique
- ✅ Tracking des donjons héroïques complétés
- ✅ Transition automatique Phase 0 → Phase 1
- ✅ Notifications dans le chat
- ✅ Achievements pour accomplissements

## 3. Système d'Équipement (100% complet)

### 3.1 Classes Core
- ✅ **Item** : 5 slots (HELMET, SHOULDERS, CHEST, WEAPON, RING)
- ✅ **Rareté** : 4 niveaux (COMMON, UNCOMMON, RARE, EPIC)
- ✅ **iLvl** : Système d'item level remplaçant ancienne valeur
- ✅ **Equipment** : Gestion complète des 5 slots

### 3.2 Tables de Loot
- ✅ Base de données complète de noms d'objets
- ✅ Génération procédurale avec calculs de rareté
- ✅ Support donjons héroïques (+10-15 iLvl bonus)
- ✅ Balance équilibrée par niveau :
  - Niv 1-20: iLvl 1-15
  - Niv 21-40: iLvl 15-35
  - Niv 41-50: iLvl 35-50
  - Niv 51-60: iLvl 50-65
  - Héroïque 60: iLvl 70-85

### 3.3 Interface Équipement
- ✅ Menu contextuel (clic droit sur membre)
- ✅ Fenêtre dédiée (`Fenetre_Equipement.tscn`)
- ✅ Affichage détaillé des 5 slots
- ✅ Couleurs de rareté
- ✅ iLvl total avec code couleur

### 3.4 Notifications de Loot
- ✅ Messages dans ChatPanel avec couleurs
- ✅ Format : "[Loot] {joueur} a obtenu {objet} (iLvl {niveau})"
- ✅ Signaux connectés automatiquement

## 4. Milestone 1 : Infrastructure de Progression (100% complète)

### 4.1 Système de Phases (PhaseManager)
- ✅ **4 Phases** : LEVELING (0), SERVEUR (1), NATIONAL (2), ESPORT (3)
- ✅ **Gestion d'état** : `current_phase`, progression, requirements
- ✅ **Signaux** : `phase_changed`, `requirements_met`, `unlocked`
- ✅ **Méthodes** : progression check, unlock, achievements
- ✅ **Sauvegarde/chargement** des données de phase

### 4.2 Système de Classement (GuildRanking)
- ✅ **Calcul de score** basé sur progression PvE, membres, réputation
- ✅ **Mise à jour périodique** des classements
- ✅ **Signal** `ranking_updated` pour notifier changements
- ✅ **Interface** dans Fenetre_Monde pour affichage

### 4.3 Guildes IA Concurrentes (AIGuild + AIGuildManager)
- ✅ **9 guildes IA** avec stratégies variées (Aggressive, Balanced, Defensive, Hardcore, Casual)
- ✅ **Simulation mensuelle** de progression
- ✅ **Comportements réalistes** : recrutement, raids, turnover
- ✅ **Intégration** avec GuildRanking
- ✅ **Configuration** par stratégie avec stats différenciées

### 4.4 Système de Débauchage
- ✅ **Tentatives IA** basées sur strategy et aggressiveness
- ✅ **Logique** : integration, satisfaction, skill du membre
- ✅ **Calcul probabilité** de départ avec facteurs multiples
- ✅ **Événements** de débauchage avec notifications
- ✅ **Contre-offres** possibles (framework en place)

### 4.5 Conditions de Progression
- ✅ **Critères Phase 0→1** : 1 donjon héroïque complété
- ✅ **Critères Phase 1→2** : TOP 1 serveur 2 semaines + 15 membres + 80% contenu
- ✅ **Critères Phase 2→3** : TOP 1 national 1 mois + sponsors + world firsts
- ✅ **Interface progression** dans Fenetre_Personnage
- ✅ **Notifications** pour objectifs atteints

## 5. Milestone 2 : Phase 1 - Niveau Serveur (100% complète)

### 5.1 Interface de Classement Serveur
- ✅ **Affichage détaillé** : rang, nom, score, progression
- ✅ **Interface** dans Fenetre_Monde avec données en temps réel
- ✅ **Indicateurs visuels** pour performance des guildes
- ✅ **Intégration** avec système de ranking

### 5.2 Système de Réputation
- ✅ **Réputation guilde** impactant recrutement
- ✅ **Gains** : succès, recrutement qualité, stabilité
- ✅ **Pertes** : échecs, turnover, dramas
- ✅ **Impact** sur probabilité acceptation recrues
- ✅ **Affichage** dans interface avec historique

### 5.3 Mécaniques de Fidélité et Satisfaction
- ✅ **Variables** satisfaction et loyalty dans SimulatedPlayer
- ✅ **Facteurs** : équipement, temps de jeu, succès, compatibilité
- ✅ **Système** de réaction aux événements
- ✅ **Impact** sur débauchage et performances
- ✅ **Interface** pour monitoring dans Fenetre_Guilde

### 5.4 Système d'Événements Serveur
- ✅ **EventManager** avec 13+ événements programmés
- ✅ **Types** : disputes, succès, défis, situations spéciales
- ✅ **Système** de choix multiples avec conséquences
- ✅ **Impact** sur moral, réputation, cohésion
- ✅ **Interface** popup pour interactions

### 5.5 Pool de Recrutement Serveur Amélioré  
- ✅ **Niveaux de qualité** : rotation basée sur performance
- ✅ **Compétition** avec guildes IA pour meilleurs joueurs
- ✅ **Informations partielles** pré-recrutement
- ✅ **Révélation progressive** des traits
- ✅ **Système** de recommandations entre joueurs

## 6. Interface Utilisateur (100% complète)

### 6.1 Architecture Fenêtrage
- ✅ **Menu bar fixe** en bas avec 4 boutons principaux
- ✅ **Fenêtres redimensionnables** avec drag & drop
- ✅ **WindowManager** pour gestion centralisée
- ✅ **Raccourcis clavier** (Ctrl+P, G, M, O)

### 6.2 Fenêtres Principales
- ✅ **Fenetre_Personnage** : infos joueur, progression phase
- ✅ **Fenetre_Guilde** : liste membres, détails, tags, menu contextuel
- ✅ **Fenetre_Monde** : classement guildes + recrutement  
- ✅ **Fenetre_OrganisationGroupe** : création groupes pour activités
- ✅ **Fenetre_Equipement** : inspection équipement détaillé

### 6.3 Composants UI
- ✅ **TimeDisplay** : horloge + contrôles de vitesse
- ✅ **ChatPanel** : messages système + notifications loot
- ✅ **EventPopup** : gestion des événements aléatoires
- ✅ **Menu debug** : outils de développement

---

# PARTIE B : CE QUI RESTE À FAIRE 📋

## 1. Prochaines Étapes Moyen Terme (priorité haute)

### 1.1 Amélioration Système d'Équipement
**Temps estimé : 3-5 jours**

- ✅ **Stats détaillées** : Force/Agilité/Intelligence générées sur chaque loot, affichées dans l'UI et cumulées par membre
- ✅ **Interface de loot** : Fenêtre dédiée après les donjons avec récap des objets, stats et gagnants
- ✅ **Historique** : Journal des objets obtenus par la guilde (onglet Historique dans Fenetre_Guilde, 200 entrées max, sauvegardé)
- ✅ **Comparaison** : Deltas de stats colorés (vert/rouge) dans la fenêtre d'équipement
- ✅ **Auto-équipement** : Gestion automatique des upgrades basée sur préférences de classe (FOR/AGI/INT)
- 📋 **Équilibrage stats** : Ajuster les multiplicateurs de génération selon slots/raretés après premiers tests
- 📋 **Filtres loot** : Ajouter filtres (joueur/rareté) et export dans la nouvelle fenêtre de butin

### 1.2 Mécaniques de Gameplay Manquantes
**Temps estimé : 2-3 jours**

- ✅ **Preferences équipement** : Préférences de stats par classe (FOR/AGI/INT) avec scoring automatique
- ✅ **Conflits de loot** : Popup de résolution pour items rares+ avec choix du joueur, impact moral des perdants
- 📋 **Système d'enchantement** : Amélioration objets existants (basique)
- 📋 **Sets d'équipement** : Bonus quand plusieurs pièces équipées

## 2. Amélioration Infrastructure UI (priorité haute)
**Temps estimé : 10-15 jours total**

### 2.1 Analyse de l'Existant ✅
**Architecture UI actuelle analysée** :
- ✅ **WindowManager** : Gestion basique des fenêtres (show/hide/close)
- ✅ **ResizableWindow** : Composant de base pour fenêtres draggables
- ✅ **ChatPanel** : Messages colorés et notifications
- ✅ **EventPopup** et **PoachingPopup** : Dialogs modales
- ✅ **TabContainer** : Navigation par onglets (utilisé dans Fenetre_Monde)
- ✅ **ContextMenu** et **Tooltip** : Interactions de base

### 2.2 Lacunes Identifiées 🔍
- 📋 **Notifications persistantes** : Pas de système toast/alerts
- 📋 **Multi-fenêtres** : WindowManager trop basique pour z-order, layout
- 📋 **Drag & Drop** : Absent pour inventaire/équipement/organisation
- 📋 **Composants réutilisables** : Manque progress bars, badges, stat displays
- 📋 **Raccourcis globaux** : Navigation clavier limitée
- 📋 **Thème unifié** : Styles incohérents entre fenêtres
- 📋 **Sauvegarde layout** : Positions/tailles non mémorisées

### 2.3 Phase 1 - Fondations ✅ (terminé : 5 jours)

#### NotificationManager - Système de Notifications ✅
**Fichier** : `/scripts/managers/notification_manager.gd`
- ✅ **Notifications toast** : Coin supérieur droit, auto-dismiss
- ✅ **Types multiples** : info, success, warning, error, achievement
- ✅ **Queue système** : Éviter spam, affichage séquentiel
- ✅ **Animations** : Feedback visuel par type
- ✅ **Historique** : Journal des notifications accessibles
- ✅ **Intégration** : PhaseManager, ChatPanel connectés

#### WindowManager Avancé ✅
**Améliorer** : `/scripts/managers/window_manager.gd`
- ✅ **Multi-fenêtres** : Support simultané avec z-order
- ✅ **Layout mémorisation** : Positions/tailles sauvegardées
- ✅ **Minimisation** : Support fenêtres minimisées
- ✅ **Navigation clavier** : Alt+Tab entre fenêtres
- ✅ **Animations** : Transitions fluides ouverture/fermeture
- ✅ **Arrangements** : Cascade et tuiles

#### Composants UI de Base ✅
**Nouveaux fichiers** :
- ✅ **CustomProgressBar** (`/scripts/ui/components/custom_progress_bar.gd`) : Barres segmentées avec animations
- ✅ **Badge** (`/scripts/ui/components/badge.gd`) : 9 types, 3 tailles, animations
- ✅ **StatDisplay** (`/scripts/ui/components/stat_display.gd`) : Affichage uniforme stats avec icônes

### 2.4 Phase 2 - Interactions ✅ (terminé : 4 jours)

#### Système Drag & Drop ✅
**Nouveaux fichiers** :
- ✅ **DraggableItem** (`/scripts/ui/components/draggable_item.gd`) : Items draggables avec ghost image
- ✅ **DropZone** (`/scripts/ui/components/drop_zone.gd`) : Zones de drop avec validation et highlight
- ✅ **4 policies** : Replace, Stack, Reject, Swap
- ✅ **Feedback visuel** : Highlight valide/invalide
- ✅ **Applications** : Organisation raid (membres dans groupes) avec validation de rôles et feedback visuel
- 📋 **Applications** : Équipement (items entre slots)

#### Dialogs Avancés ✅
**Nouveaux fichiers** :
- ✅ **BaseDialog** (`/scripts/ui/dialogs/base_dialog.gd`) : Template réutilisable avec styles cohérents
- ✅ **ConfirmDialog** (`/scripts/ui/dialogs/confirm_dialog.gd`) : 5 types avec icônes et callbacks
- ✅ **InputDialog** (`/scripts/ui/dialogs/input_dialog.gd`) : 8 types de saisie avec validation
- ✅ **ProgressDialog** (`/scripts/ui/dialogs/progress_dialog.gd`) : Opérations longues avec détails

#### Tabs Améliorés ✅
**Nouveau** : `/scripts/ui/components/advanced_tabs.gd`
- ✅ **Onglets fermables** : Bouton X sur chaque onglet
- ✅ **Badges** : Integration avec Badge component
- ✅ **Drag & Drop** : Réorganisation des onglets
- ✅ **Overflow** : Menu ... pour trop d'onglets
- ✅ **Support icônes** : Icônes dans les onglets

### 2.5 Phase 3 - Polish (long terme : 4-5 jours)

#### Configuration et Layout
**Nouveaux fichiers** :
- 📋 **LayoutManager** (`/scripts/managers/layout_manager.gd`) : Presets, workspaces, restauration
- 📋 **OptionsWindow** (`/scripts/ui/windows/fenetre_options.gd`) : Paramètres UI, raccourcis, thème
- 📋 **HelpOverlay** (`/scripts/ui/components/help_overlay.gd`) : Tutoriels et aide contextuelle

#### ChatPanel Amélioré
**Améliorer** : `/scripts/ui/components/chat_panel.gd`
- 📋 **Multiple channels** : Guild, Raid, System, Whisper avec tabs
- 📋 **Filtres et recherche** : Par type, timestamp, contenu
- 📋 **Commandes slash** : /help, /clear, /timestamp, etc.
- 📋 **Export/logs** : Sauvegarde historique

### 2.6 Justification pour les Futures Features

#### Phase 2 National - UI Requirements
- **Célébrité** → NotificationManager (achievements), StatDisplay (popularity)
- **Streaming/Médias** → AdvancedTabs (multiple streams), ProgressDialog (upload)
- **Sponsors** → Drag&Drop (logos), Dialogs (négociations complexes)
- **Dramas** → NotificationManager (alertes), HelpOverlay (gestion crise)

#### Phase 3 Esport - UI Requirements  
- **Staff Pro** → Layout multi-fenêtres (dashboard complexe)
- **Tournois** → ProgressBar (brackets), Badge (achievements), Chat (live)
- **Burnout** → StatDisplay (stress), NotificationManager (alertes préventives)
- **Transferts** → Drag&Drop (négociations), Dialogs (multi-étapes)

### 2.7 Dépendances et Ordre d'Implémentation
1. **Phase 1 UI** → **Avant Milestone 3** (National) - Fondations nécessaires
2. **Phase 2 UI** → **Parallèle Milestone 3** - Interactions pour features complexes
3. **Phase 3 UI** → **Avant Milestone 4** (Esport) - Polish pour UX professionnelle

**Impact sur planning** : +10-15 jours mais **facilitera énormément** l'implémentation des Milestones 3-4 (+30-40% efficiency gain estimé)

## 3. Milestone 3 : Phase 2 - Niveau National (100% ✅)
**Temps estimé : 7-10 jours**

> **MàJ 29 mai 2026** — Backends médias/sponsors/dramas branchés et fonctionnels :
> - ✅ **3 managers enregistrés en autoloads** (`MediaManager`, `SponsorshipManager`, `DramaManager`) — ils étaient écrits mais orphelins (jamais exécutés).
> - ✅ **Bug critique corrigé** : fonction `trigger_loot_conflict` dupliquée dans `simulated_player.gd` (l.241 + l.405) → cassait *toute* la compilation à froid. Le jeu ne s'instanciait plus hors éditeur chaud.
> - ✅ **Célébrité** : lecture corrigée (propriété `celebrity_level`, plus `get_meta`), croissance hebdo (talent + streaming) dans `MediaManager`.
> - ✅ **Revenus** : sponsors + part streaming (30%) versés à l'or de la guilde chaque semaine.
> - ✅ **Fenêtre `National`** (`Fenetre_National.tscn`) : onglets Célébrité / Médias / Sponsors / Dramas + bouton menu + raccourci Ctrl+N.
> - ✅ **Popup de résolution de drama** (silence / communication / sanctions / exclusion) + notifications toast + pause auto.
> - ✅ **Sauvegarde/chargement** des 3 systèmes dans `SaveManager`.
> - ✅ **Thème UI global** (`UITheme`) appliqué à toute l'interface.
> - ✅ **US 3.5** (recrutement national) branchée : pool élargi, semi-pros avec salaires/agents, négociation, scouting, masse salariale hebdo (commit dédié).
> - ✅ **Progression Phase 2→3 branchée** : `PhaseManager` lit désormais de vraies valeurs — `active_sponsors` (SponsorshipManager), `max_dramas_per_year` (compteur annuel DramaManager), `media_reputation` (MediaManager), `world_first_count` (server firsts du joueur), `national_rank_position`/`duration` (GuildRanking + suivi `days_at_rank_1`). Sémantique de rang corrigée (plus petit = meilleur).

### US 3.1 : Système de Célébrité des Joueurs
- 📋 **Propriétés** : `celebrity_level`, `public_recognition` pour SimulatedPlayer  
- 📋 **Conditions** : performance exceptionnelle, personnalité marquante
- 📋 **Avantages** : bonus recrutement, revenus sponsors, influence
- 📋 **Inconvénients** : pression médiatique, risque drama, attention concurrents
- 📋 **Interface** : gestion exposition médiatique par membre

### US 3.2 : Mécaniques de Streaming et Médias
- 📋 **MediaManager** : nouveau système de gestion
- 📋 **Streamers** : propriété `is_streamer` avec audience, revenus, planning
- 📋 **Conflits** : divulgation stratégies, temps partagé, pression performance
- 📋 **Gestion éditoriale** : choix contenu, gestion incidents live
- 📋 **Revenus partagés** : négociation guilde/joueur

### US 3.3 : Système de Sponsors
- 📋 **SponsorshipManager** : nouveau système
- 📋 **Types sponsors** : équipementiers, marques gaming, plateformes
- 📋 **Contrats** : obligations, quotas exposition, exclusivités
- 📋 **Négociation** : basée sur performance, audience, réputation
- 📋 **Conflits** : sponsors concurrents, impact budget

### US 3.4 : Gestion des Dramas et Crises  
- 📋 **DramaManager** : nouveau système de crise
- 📋 **Types dramas** : conflits publics, scandales, polémiques gameplay
- 📋 **Réponses** : silence, démentis, sanctions, communication crise
- 📋 **Impact** : recrutement, sponsors, moral équipe
- 📋 **Récupération** : mécaniques de reconstruction réputation

### US 3.5 : Pool de Recrutement National ✅
- ✅ **Extension pool** : 50-100 joueurs en phase nationale (`_get_current_pool_limits`), ~40% de semi-pros (`_spawn_player`)
- ✅ **Semi-professionnels** : `salary_demand` (or/sem), agents avec commission, masse salariale hebdomadaire prélevée sur l'or (GuildManager `_pay_salaries`, impact moral si impayé)
- ✅ **Négociations** : offre via SpinBox, acceptation directe / contre-proposition (ConfirmationDialog) / refus (`attempt_national_recruitment`, `accept_counter_offer`)
- ✅ **Historique public / préférences** : motivation, activité attendue, salaire, agent affichés dans la fiche recrue ; recrues nationales marquées 💼 dans la liste
- ✅ **Scouting** : bouton « Scouter » révèle traits cachés + skill réel (coût -2 réputation, `scout_player`)
- ✅ **Bonus** : fix d'un bug pré-existant `notification_manager._on_phase_changed` (`.name` sur un int) qui plantait à chaque changement de phase

## 3. Milestone 4 : Phase 3 - Niveau Esport (100% ✅)
**Temps estimé : 7-10 jours**

> **MàJ 30 mai 2026** — Phase Esport implémentée et validée dans l'éditeur Godot 4.6 (MCP).
> - ✅ **4 nouveaux autoloads** : `StaffManager`, `TournamentManager`, `TransferManager`, `LegacyManager`.
> - ✅ **2 nouvelles resources** : `StaffMember` (rôles + bonus), `Tournament` (types + brackets).
> - ✅ **Fenêtre `Esport`** (`Fenetre_Esport.tscn`, 6 onglets) + bouton menu + raccourci **Ctrl+E**.
> - ✅ **PhaseManager** : objectifs de maîtrise branchés sur de vraies valeurs (`world_championship_wins`, `professional_staff_count`, `international_reputation`, `team_stability`) + helper public `get_requirements_progress()`.
> - ✅ **Sauvegarde/chargement** des 4 systèmes + `stress_level` et métadonnées internationales des membres.
> - ✅ **Validation runtime** : boucle tournoi → récompenses → legacy → notifications → stress vérifiée bout-en-bout, sans erreur.

### US 4.1 : Système de Staff Professionnel ✅
- ✅ **StaffMember** : resource avec rôle, skill (1-100), salaire, bonus par rôle
- ✅ **Rôles** : coach stratégique (perf/stratégie), analyste (stratégie), psychologue (relief stress/moral), manager (stabilité/efficacité salariale)
- ✅ **Compétences** : bonus mis à l'échelle par le skill, agrégés dans `StaffManager`
- ✅ **Salaires** : frais d'embauche + masse salariale hebdo prélevée sur l'or (départ possible si impayé)
- ✅ **Synergies** : +5% par rôle distinct présent (max +15%)

### US 4.2 : Système de Tournois Internationaux ✅
- ✅ **TournamentManager** : pool d'offres rafraîchi, autoload
- ✅ **Types** : World Championship, Regional Qualifiers, Invitationals (difficulté/prix/prestige différenciés)
- ✅ **Format** : simulation de bracket (force roster + staff − stress), tours successifs plus difficiles
- ✅ **Préparation** : bootcamp (coût or, +perf prochain tournoi, +stress équipe)
- ✅ **Récompenses** : or + prestige (réputation internationale), titres mondiaux comptabilisés

### US 4.3 : Gestion du Burnout et Pression ✅
- ✅ **Propriétés** : `stress_level` (0-100) + `get_burnout_risk()` sur SimulatedPlayer (combiné à la fatigue existante)
- ✅ **Facteurs** : tournois, bootcamps, wipes ajoutent du stress ; pression de base hebdo en phase Esport
- ✅ **Prévention** : action « repos de l'équipe » (cooldown) + psychologue (relief hebdo)
- ✅ **Conséquences** : `get_esport_performance_factor()` (malus en compétition), baisse de moral, alimente la fatigue/burnout
- ✅ **Staff spécialisé** : `StaffManager._process_wellbeing()` orchestre le bien-être hebdomadaire

### US 4.4 : Système de Transferts Internationaux ✅
- ✅ **Pool mondial** : joueurs d'élite (skill 78-98, niveau 60) par régions
- ✅ **Complexités** : adaptation culturelle (malus moral/intégration temporaire à l'arrivée)
- ✅ **Agents professionnels** : négociation (offre / contre-proposition / refus), commission d'agent
- ✅ **Fenêtres transfert** : 2 périodes/an (semaines 1-4 et 26-29) ; recrutement bloqué hors fenêtre
- ✅ **Prime de transfert** : 4 semaines de salaire + commission (sink d'or)
- 📋 **Fair-play financier** (salary cap) : non implémenté (option d'équilibrage future)

### US 4.5 : Système de Legacy et Recognition ✅
- ✅ **Hall of Fame** : entrées d'accomplissements (titres de tournois, accession à l'esport) avec points et date
- ✅ **Titres permanents** : déblocage par paliers de points de legacy (Espoir → Immortel) + titre « Champion du Monde »
- ✅ **Notifications** : toasts achievement + messages chat à chaque accomplissement
- 📋 **Stratégies innovantes / Mentoring / Impact meta-game** : non implémentés (extensions futures, recoupent Milestone 5)

## 4. Milestone 5 : Mécaniques Transversales (100% ✅)
**Temps estimé : 5-7 jours**

> **MàJ 30 mai 2026** — Implémenté et validé dans l'éditeur Godot 4.6 (MCP).
> - ✅ **Réveil du système social dormant** : `SocialDynamics` (relations/cliques/conflits) existait mais n'était jamais alimenté ; `GuildCultureManager` forme désormais les relations chaque semaine via les profils comportementaux. Vérifié en jeu : amitiés, rivalités, mentorats et cliques se forment.
> - ✅ **Nouvel autoload** `GuildCultureManager` (1 fichier, catalogues statiques — pas de nouvelle resource).
> - ✅ **Fenêtre `Cohésion`** (`Fenetre_Social.tscn`, 6 onglets) + bouton menu + raccourci **Ctrl+K**.
> - ✅ **Sauvegarde** du moral et des traditions établies.
> - ✅ **Validation runtime** : team-building (moral +10, coût or, cooldown), médiation d'une rivalité (tension résolue), affichage relations/cliques — tout vérifié par screenshots.

### US 5.1 : Système de Dynamiques de Groupe ✅
- ✅ **GroupDynamics** : `GuildCultureManager` pilote le `SocialDynamics` existant (auparavant inerte)
- ✅ **Cliques** : formation, leader (plus haute influence), cohésion, affichées dans l'onglet Cliques
- ✅ **Leaders naturels** : influence sociale calculée, leader de clique désigné
- ✅ **Conflits personnalité** : relations formées selon compatibilité des profils comportementaux
- ✅ **Relations individuelles** : amitié, rivalité, mentor/élève, inimitié (affichées par membre)

### US 5.2 : Moral Collectif et Ambiance ✅
- ✅ **guild_morale** : métrique globale 0-100 (humeur moyenne + santé sociale + traditions)
- ✅ **Contagion émotionnelle** : l'humeur dérive chaque semaine vers celle du cercle social (pondérée par la force des liens)
- ✅ **Actions amélioration** : team-building, traditions
- ✅ **Impact visible** : santé sociale (amitiés/rivalités/inimitiés) affichée, tiers d'ambiance
- 📋 **Événements ambiance dédiés** : réutilisent le système d'événements existant (non étendu)

### US 5.3 : Système d'Événements Team-Building ✅
- ✅ **Types événements** : soirée détente, challenge interne, sortie virtuelle, célébration
- ✅ **Coût vs bénéfices** : or + énergie contre moral + humeur + cohésion + nouveaux liens
- ✅ **Cooldown** : un seul événement à la fois, cooldown par activité
- 📋 **Préférences individuelles / saisonniers** : non implémentés (extension future)

### US 5.4 : Système de Rituels et Traditions ✅
- ✅ **Traditions** : discours d'avant-raid, célébration de victoire, mentorat, anniversaire
- ✅ **Bonus passifs** : moral/cohésion hebdomadaires par tradition établie
- ✅ **Conditions** : seuils de membres + coût en or (gating vérifié en jeu)
- ✅ **Persistance** : traditions établies sauvegardées

### US 5.5 : Gestion Avancée des Conflits ✅
- ✅ **Détection** : tensions (rivalités/inimitiés) listées dans l'onglet Conflits
- ✅ **Options résolution** : médiation (un membre ami des deux arbitre) + apaisement direct
- ✅ **Déclenchement dynamique** : plus le moral est bas, plus des tensions éclatent
- 📋 **Conflits leadership / formation staff** : non implémentés (recoupent Milestone 4 staff)

## 5. Milestone 6 : Polish et Équilibrage (95% ✅)
**Temps estimé : 3-5 jours**

> **MàJ 30 mai 2026** — Polish complet : conseiller adaptatif, dashboard de stats, auto-sauvegarde, équilibrage adaptatif et tests automatisés. Validé en jeu (MCP) et en headless.
> - ✅ **Nouvel autoload** `AdvisorManager` : analyse l'état réel de la guilde et produit des conseils priorisés (alerte/attention/astuce/opportunité).
> - ✅ **Nouvel autoload** `BalanceManager` : difficulté réglable + catch-up (joueur à la traîne) + rubber-band (IA quand le joueur domine), branchés sur le recrutement et la progression PvE des IA.
> - ✅ **Fenêtre `Conseils`** (`Fenetre_Conseils.tscn`, onglets Conseils / Statistiques / Équilibrage) + bouton menu + raccourci **Ctrl+A**.
> - ✅ **Auto-sauvegarde** (changement de phase + toutes les 4 semaines) avec **backup** de la save précédente et **repli automatique** sur le backup si la sauvegarde principale est corrompue.
> - ✅ **Tests automatisés** : harnais maison `res://tests/` (57 assertions, 100 % vertes) lançable en headless (`tests/run_tests.ps1`).
> - ✅ **Validation runtime** : conseil contextuel par phase, dashboard live, équilibrage (catch-up/rubber-band), backup à la sauvegarde — vérifiés par screenshots et tests.

### US 6.1 : Système de Conseils et Tutoriels Adaptatifs ✅
- ✅ **IA conseil** : `AdvisorManager` analyse trésorerie/salaires, burnout/stress, moral, tensions, recrutement, équipement et progression de phase → conseils priorisés par sévérité
- ✅ **Conseils par phase** : guidage contextuel (ex. « compléter un donjon héroïque » en Phase 0, objectifs de maîtrise en Esport)
- ✅ **Alertes prédictives** : l'alerte la plus critique est poussée en notification chaque semaine (anti-spam)
- ✅ **Interface dédiée** : onglet Conseils avec pastilles de sévérité colorées
- 📋 **Tutoriels intégrés pas-à-pas / aide désactivable** : non implémentés (extension future)

### US 6.2 : Outils d'Analyse et Statistiques ✅
- ✅ **Dashboard métriques** : vue d'ensemble (phase, niveau, or, réputation, moral) + effectif (moyennes niveau/skill/intégration/moral/stress)
- ✅ **Détail par membre** : table triée (niveau, skill, moral, énergie, stress, intégration) avec code couleur
- 📋 **Graphiques d'évolution / projections / export** : non implémentés (extension future)

### US 6.3 : Système de Sauvegarde de Progression ✅
- ✅ **Auto-sauvegarde** : aux moments critiques (changement de phase) + périodique (toutes les 4 semaines)
- ✅ **Backup automatique** : la sauvegarde précédente est copiée avant écrasement
- ✅ **Repli sur backup** : chargement automatique du backup si la save principale est illisible/corrompue
- ✅ **Continuité inter-phases** : phases, relations, réputation déjà sauvegardées (SaveManager existant)
- 📋 **Slots de sauvegarde multiples** : non implémentés (nécessite une UI de gestion des saves)

### US 6.4 : Équilibrage de la Courbe de Difficulté ✅
- ✅ **Difficulté réglable** : `BalanceManager` (autoload) avec 3 presets (Détendu / Normal / Difficile) modifiant catch-up, recrutement, progression IA et stipend hebdomadaire
- ✅ **Scaling adaptatif / catch-up** : aide douce (or + soutien moral) quand le joueur décroche (rang, trésorerie, moral), proportionnelle à la galère et à la difficulté
- ✅ **Rubber-band IA** : les guildes IA progressent plus vite (`AIGuild._simulate_pve_progression`) quand le joueur domine durablement le classement
- ✅ **Bonus de recrutement** : `RecruitmentPool.attempt_recruitment` lit le multiplicateur catch-up (joueur uniquement)
- ✅ **Interface** : onglet Équilibrage (sélecteur de difficulté + statut d'adaptation en direct) ; réglage sauvegardé
- 📋 **Défis optionnels / analyse de playtest fine** : non implémentés (calibrage à affiner avec des données réelles)

### US 6.5 : Tests et Validation Finale ✅
- ✅ **Framework de tests automatisés** : harnais léger maison dans `res://tests/` (`test_framework.gd` + `run_tests.gd` + `TestRunner.tscn`), lançable en headless
- ✅ **Suites** : GameTime, Item/Equipment, SimulatedPlayer (stress/burnout), BalanceManager, AdvisorManager, SaveManager (round-trip), AIGuild, PvE Progression, ActivityManager, PhaseManager — **57 assertions, 100 % vertes**
- ✅ **Exécution CI-friendly** : `tests/run_tests.ps1` (détecte Godot, code de sortie 0/1) + `tests/README.md`
- ✅ **Validation runtime via MCP** : chaque milestone validé en jeu (screenshots, scripts d'inspection)
- ✅ **Playtest interne complet (MCP)** : parcours des 4 phases ; **5 bugs corrigés** dont 1 bloquant critique (voir ci-dessous)
- 📋 **Playtests externes / optimisation perf sessions longues** : à faire (hors automatisation)

> **Playtest 31 mai 2026 — bugs trouvés & corrigés**
> - 🔴 **CRITIQUE (corrigé)** : récursion infinie figeant le jeu dès qu'une phase remplit ses objectifs (`check_phase_progression` → `phase_requirements_met` → `fenetre_personnage._on_requirements_met` → `_refresh_phase_progression` → `check_phase_progression`). **Bloquait toute progression de phase.** Fix : la fenêtre lit `get_requirements_progress()` (sans effet de bord).
> - 🟠 **Donjons héroïques inatteignables (corrigé)** : `get_instance_data` ne résolvait pas les ids `_heroic`, l'UI ne les listait pas, et `DungeonInstance` ne déclenchait pas `complete_heroic_dungeon`. La Phase 0→1 était donc impossible en jeu normal. Fix en 3 points.
> - 🟠 **Énergie qui explose (corrigé)** : les activités reposantes ajoutaient de l'énergie sans plafond (978, 1009…). Fix : `clampf(0,100)`.
> - 🟡 **Erreurs de notification de donjon (corrigées)** : `instance_data`/`defeated_bosses` (DungeonRun) lus sur un `DungeonInstance` ; signal `boss_defeated` émis avec 4 args pour 3 déclarés.
> - **Observations (non corrigées, mineures/équilibrage)** : carte « Phase actuelle » de la fenêtre Personnage non rafraîchie au chargement ; connexions des membres concentrées en soirée (early-game peu peuplé) ; à haute vitesse les événements pausent le jeu en continu (slider de test) ; 99 guildes IA en phase Esport.

## 6. Améliorations Long Terme (priorité basse)

### 6.1 Extensions Système d'Équipement
- 📋 **Gemmes/Sockets** : modification objets
- 📋 **Durabilité** : usure et réparation
- 📋 **Objets légendaires** : rareté supérieure avec effets uniques
- 📋 **Commerce** : échanges entre guildes IA
- 📋 **Craft/Artisanat** : création objets

### 6.2 Fonctionnalités Avancées
- 📋 **Système économique** : marché, inflation, investissements
- 📋 **Multi-serveurs** : compétition cross-server
- 📋 **Saisons compétitives** : cycles réguliers
- 📋 **Modding support** : contenu communautaire
- 📋 **Replay system** : revisionner performances passées

---

# PARTIE C : PLANNING ET MÉTRIQUES

## Planning Recommandé (Révisé avec Infrastructure UI)

### Phase Immédiate (Semaines 1-3)
1. **Améliorations équipement** (3-5 jours)
2. **Mécaniques gameplay manquantes** (2-3 jours)
3. **Infrastructure UI - Phase 1** (5-6 jours) - NotificationManager, WindowManager avancé, Composants de base

### Phase Infrastructure (Semaines 4-5)  
4. **Infrastructure UI - Phase 2** (4-5 jours) - Drag & Drop, Dialogs avancés, Tabs
5. **Infrastructure UI - Phase 3** (4-5 jours) - LayoutManager, Options, ChatPanel amélioré

### Phase Features Principales (Semaines 6-11)
6. **Milestone 3 - Phase Nationale** (7-10 jours) ⚡ *Facilitée par nouvelle UI*
7. **Milestone 4 - Phase Esport** (7-10 jours) ⚡ *Facilitée par nouvelle UI*

### Phase Finalisation (Semaines 12-14)
8. **Milestone 5 - Transversales** (5-7 jours - en parallèle)
9. **Milestone 6 - Polish** (3-5 jours)

### Extensions (Semaines 15+)
10. **Améliorations long terme** (selon priorités)

## Métriques de Progression (Révisé)

### État Actuel
- **Global** : ~92% terminé *(+Milestone 6 Polish 95% : conseiller adaptatif, dashboard de statistiques, auto-sauvegarde + backup, équilibrage adaptatif, tests automatisés ; validé dans Godot 4.6 et en headless)*
- **Systèmes Core** : 100% ✅
- **Phase 0** : 100% ✅  
- **Milestone 1** : 100% ✅
- **Milestone 2** : 100% ✅
- **Infrastructure UI Phase 1** : 100% ✅ *(Phase 1 - Fondations)*
- **Infrastructure UI Phase 2** : 100% ✅ *(Phase 2 - Interactions)*
- **Refactoring Architecture** : 100% ✅ *(WindowManager, GuildManager, autoloads, positions)*
- **Système Save/Load** : 100% ✅ *(SaveManager autoload, JSON, F5 manual save)*
- **Tooling Claude Code** : 100% ✅ *(Godot 4.6.2, MCP Pro, LSP, godot-docs)*
- **Infrastructure UI Phase 3** : 0% 📋 *(Phase 3 - Polish)*
- **Thème UI global** : 100% ✅ *(UITheme appliqué partout)*
- **Milestone 3** : 100% ✅ *(National : célébrité, médias, sponsors, dramas, recrutement national + salaires, progression Phase 2→3 branchée)*
- **Milestone 4** : 100% ✅ *(Esport : staff pro, tournois internationaux, burnout/stress, transferts internationaux, legacy/Hall of Fame)*
- **Milestone 5** : 100% ✅ *(Transversales : dynamiques de groupe, moral collectif + contagion, team-building, traditions, gestion des conflits)*
- **Milestone 6** : 95% ✅ *(Polish : conseiller adaptatif, dashboard de stats, auto-sauvegarde + backup, équilibrage adaptatif BalanceManager, harnais de tests automatisés ; calibrage fin et playtests externes restants)*

### Statuts détaillés (Implémenté / Jouable / Validé)

> Grille honnête demandée par l'audit (Priorité 6) pour éviter le faux confort du « 100 % ».
> **Implémenté** = code présent et branché. **Jouable** = accessible et utile dans l'UI.
> **Validé** = couvert par un test automatisé ou un scénario E2E.
> *État au 1er juin 2026 — 98 assertions vertes (Godot 4.6.2 headless).*

| Système | Implémenté | Jouable | Validé | Commentaire |
|---|---|---|---|---|
| Boucle de temps (GameTime) | Oui | Oui | Oui | jour absolu + calendrier testés |
| Recrutement serveur | Oui | Oui | Oui | acceptation/refus + difficulté |
| Recrutement national (salaires/agents) | Oui | Oui | Oui | commission d'agent prélevée **tous chemins** + solvabilité testées |
| Progression PvE (clears/historique/meilleur clear) | Oui | Oui | Oui | suite PvE dédiée |
| Composition de groupe + lancement de run | Oui | Oui | Partiel | logique de compo testée ; aperçu de run avec fatigue/stress |
| Classement serveur | Oui | Oui | Partiel | branché sur clears réels + réputation |
| Classement national / mondial | Oui | Partiel | Partiel | calcul branché, multiplicateurs de phase ; équilibrage à affiner |
| Phases 0→1→2→3 | Oui | Oui | Partiel | 0→1 (héroïque) testé ; transitions supérieures non E2E |
| Médias / Sponsors / Dramas (National) | Oui | Oui | Partiel | back-ends branchés ; peu de tests dédiés |
| Staff / Tournois / Transferts / Legacy (Esport) | Oui | Oui | Partiel | boucle validée en éditeur ; tests unitaires partiels |
| Cohésion / Culture (Milestone 5) | Oui | Oui | Partiel | relations/cliques/traditions ; sérialisation testée |
| Conseiller + vue « Cette semaine » | Oui | Oui | Oui | conseils priorisés + synthèse hebdo testés (unit + smoke UI) |
| Équilibrage adaptatif (BalanceManager) | Oui | Oui | Oui | presets + catch-up + rubber-band testés |
| Sauvegarde + migration + backup | Oui | Oui | Oui | round-trip + migration v1→v2 + repli backup testés |
| RNG déterministe (GameRandom.seed_rng) | Oui | — | Oui | séquence reproductible testée |

### Dépendances Critiques (Mises à jour)
- ✅ Milestone 1 requis avant tous (FAIT)
- ✅ Milestone 2 doit être stable avant 3 (FAIT)
- ✅ **Infrastructure UI Phase 1** requis **AVANT** Milestone 3 (FAIT)
- ✅ **Infrastructure UI Phase 2** requis pour **features complexes** (FAIT)
- 📋 **Infrastructure UI Phase 3** en **PARALLÈLE** Milestone 3-4 *(optionnel)*
- 📋 Milestone 3 requis avant 4
- 📋 Milestone 5 développable en parallèle 3-4
- 📋 Milestone 6 nécessite tous les autres terminés

### Risques Identifiés (Mis à jour)
- **Complexité croissante** : Chaque milestone plus complexe que précédente
- ✅ **Infrastructure UI critique** : Foundation UI mal faite ralentirait énormément Milestones 3-4 *(RÉSOLU)*
- ✅ **Temps d'investissement UI** : +9 jours mais ROI déjà visible avec composants réutilisables *(RÉSOLU)*
- **Équilibrage** : Mécaniques multiples nécessitent calibrage fin
- **Performance** : Systèmes IA multiples peuvent impacter fluidité
- ✅ **UX cohérente** : Thème unifié implémenté avec composants standards *(RÉSOLU)*

---

# CONCLUSION (Révisée)

RaidLead a franchi une **étape majeure** avec **~50% du projet terminé**. Les **fondations sont excellentes** avec tous les systèmes core opérationnels, les 2 premières milestones complètes et **l'infrastructure UI moderne** implémentée.

## Accomplissements Récents ✅

### Specs refonte UI — 2 chantiers (3 juin 2026)
*Deux documents de design prêts à arbitrage/phasage. Décisions verrouillées avec le dev.*
- 📋 **Chantier 1 — Refonte visuelle « MMO pixel-art »** : `docs/design/2026-06-03-ui-refonte-visuelle-mmo.md`. Sortir du thème `StyleBoxFlat` plat + police système → identité MMO fantasy (or/pierre/parchemin) **rendue en pixel-art** cohérent avec `umempart`. **Décidé** : chrome via **kits tiers licenciés/CC0** (pas de rip WoW), **style pixel-art unifié**. Couvre : police pixel (⚠ accents FR), 9-slice `StyleBoxTexture`, pixel-perfect (`Nearest`), inventaire d'assets exhaustif, manifeste de licences Steam, phasage A→E.
- 📋 **Chantier 2 — UI au service du gameplay** : `docs/design/2026-06-03-ui-architecture-gameplay.md`. **Décidé en scope** : (1) **HUD permanent persistant** (or/réput/moral/online/temps + tracker d'objectif de phase + rail d'alertes actionnables) ; (2) **refonte navigation** (8+ fenêtres → ~5 hubs par boucle de jeu). **Non-goals** : pas de docking/multi-fenêtres (reste mono-fenêtre), pas de multi-résolution. Note technique : `Guild.gold` doit gagner un `signal gold_changed` (pas de polling).
- 🔗 **Séquencement croisé** : Chantier 2 Phases 1-2 (HUD additif) + Chantier 1 Phases A-C (skin) en parallèle → Chantier 2 Phase 3 (regroupement) → Chantier 1 Phases D-E (icônes) → Chantier 2 Phases 4-5.

### Spec système de quêtes de guidage (3 juin 2026)
*Document de design prêt à implémenter : `docs/design/2026-06-03-systeme-quetes-guidage.md`.*
- 📋 **Objectif produit cadré** : onboarding fort en Phase 0, puis objectifs de campagne de plus en plus espacés, centrés sur la découverte des nouvelles UI et la compréhension des caps de phase.
- 📋 **Architecture proposée** : `QuestManager` comme surcouche d'orientation, branchée sur `PhaseManager`, `WindowManager`, `GuildManager`, `RecruitmentPool`, PvE, ranking et managers avancés, sans dupliquer les sources de vérité.
- 📋 **UX spécifiée** : tracker compact, fenêtre Objectifs, bouton "Aller", highlights sémantiques par fenêtre, auto-completion rétroactive et quêtes optionnelles/non bloquantes.
- 📋 **Roadmap d'implémentation** : socle data/manager, tracker minimal, chaîne Phase 0 complète, fenêtre Objectifs, puis quêtes Serveur/National/Esport.

### Chat de guilde vivant — moteur + scènes à branches (2 juin 2026)
*Branche `feat/chat-vivant` (worktree). Implémenté en 7 phases A→G. Validé : CheckScripts 108 scripts OK + TestRunner 220/220 + soak headless. Doc : `docs/design/2026-06-02-chat-guilde-vivant.md`.*

Transformation du `ChatPanel` (ancien log d'événements) en **chat de guilde vivant** style WoW Vanilla, **data-driven** (zéro `if` par réplique), **offline/gratuit/déterministe** (pas de LLM au runtime ; corpus authored au dev-time).

- 🟢 **Nouvel autoload `ChatDirector`** : décide *qui dit quoi quand*. Le `ChatPanel` devient une vue passive (`line_emitted`). Contenu = JSON dans `res://data/chat/`.
- 🟢 **Moteur de scoring d'utilité** (`ChatScoring`, pur/testable) : `score = (base + Σbonus) × (Π veto)` ; considérations data-driven (axe + courbe + kind) ; **softmax à température** ; vetos `[0,1]` (un 0 élimine) au lieu de `-9999`. Explicateur de score (debug).
- 🟢 **Vibe-space** (l'idée « embeddings » bakée au dev-time) : coords `[serieux, toxicite, sweat]` par réplique + dérivées du locuteur (traits/humeur) → affinité gaussienne (une réplique « dans le ton » score plus haut).
- 🟢 **Blackboard de stimuli réactifs** branché sur les vrais signaux : level up (60 = saillance 1.0), recrutement, départ, loot/loot_epic, wipe, boss_kill, drama, tension, burnout, conflit de loot. Injection de variables réelles (`#subject# #item# #boss# #wipes# #lvl#…`). Sélection du locuteur pondérée par la **relation** au sujet (SocialDynamics : un rival se moque, un ami félicite).
- 🟢 **`SceneRunner` — scènes scriptées multi-acteurs à branches** (le cœur « vivant ») : casting (réutilise le scoring + `relation_to_role`), beats joués **avec pauses** (délais temps-réel), **branches résolues par roll pondéré sur les traits** de l'acteur (rickroll : timide=« haha », perfectionniste=« c'est un rickroll », rage_quitter=« MAIS BORDEL… »), **effets sur la sim** (mood/stress). 7 scènes : rickroll, duel, blame_pull (wipe), tribunal du ninja, Mankrik, world-buff panic, bizutage de recrue.
- 🟢 **Cadence** ∝ nombre de joueurs en ligne et bavardise ; **plancher temps-réel** (anti-flood à 2400× / fast-forward) ; chat supprimé en fast-forward ; **anti-répétition** (ring buffer + pénalité) + **équité de parole** (les muets reprennent la parole).
- 🟢 **Corpus** : 85 lignes ambient + ~45 réactives + 7 scènes (Barrens chat, LFG, mage/utility, DKP/ninja, attunements, world buffs, corpse runs, PvP/honor, clichés de classe…).
- 🟢 **Outillage** : soak-test headless (`tests/ChatSoak.tscn`, aperçu + stats), validation de schéma en CI, actions chat dans le menu debug, indicateur « est en train d'écrire… », stub `ChatBackend` (point d'extension Palier 3 LLM live opt-in). 33 nouvelles assertions de test.

### Passe de typage statique (2 juin 2026)
*3 lots, ~60 fichiers. Validé : TestRunner 172/172 + **CheckScripts 104 scripts compilés sans erreur** + boot live.*
- 🟠 **Typage statique conservateur** appliqué à tout le code (mandat CLAUDE.md) : types de retour (`-> void`/concret), paramètres, variables locales et collections homogènes (`Array[T]`).
  - **Lot 1** : resources + data (modèle de données).
  - **Lot 2** : systèmes + autoloads + utils (`save_manager` laissé intact — blobs JSON).
  - **Lot 3** : UI (fenêtres, composants, dialogs, managers).
- **Règle d'or** : les Variants (issus de `Dictionary.get`, `JSON`, autoloads dynamiques, duck-typing `player`/`member`, API drag&drop Godot) laissés **non typés** pour ne pas casser la compilation.
- **Outillage** : `tests/CheckScripts.tscn` (validateur de compile complet, **104 scripts**) ajouté au flux de vérif — il attrape les erreurs de compilation de `main.gd`/UI que `TestRunner` n'exerce pas (ex. une inférence `:=` cassée corrigée dans `player_control_panel.gd`).

### Refactor god-object — main.gd dégonflé (2 juin 2026)
*172/172 assertions vertes + boot live vérifié (MCP). Comportement identique.*
- 🟠 **`main.gd` : ~1080 → ~720 lignes** via 2 extractions à comportement identique :
  - **`DebugMenuPanel`** (`scripts/ui/components/debug_menu.gd`) : le menu de debug (debug-only) + ses actions, instancié par `main` (qui lui passe le `WindowManager`). F1/F2 → `trigger()`.
  - **`SystemNotifier`** (`scripts/systems/system_notifier.gd`) : relais des signaux managers (National/Esport/Cohésion) → chat/toast. Le seul cas couplé (popup modal de drama, qui met le jeu en pause) reste dans `main`, re-signalé via `drama_response_needed`.
- 🟠 **`fenetre_monde.gd` : 1222 → 768 lignes** — extraction de tout l'onglet Recrutement dans **`RecruitmentPanel`** (`scripts/ui/windows/recruitment_panel.gd`, composant autonome). Émet `player_recruited`, ré-émis par la fenêtre. Bonus : suppression d'un hack de navigation d'arbre (remplacé par une réf membre). **Flux de recrutement vérifié en live** (liste, sélection, détails, filtre, signal) ; classement conservé dans la fenêtre. Référencé via `preload` (robuste cache/export/CI).

### Refonte recrutement vivant + signature atomique (2 juin 2026)
*Implémenté côté modèle/UI/tests. Validation Godot locale bloquée par un crash natif `signal 11` du binaire 4.6.2 pendant `CheckScripts`, à relancer dès que l'exécutable est stable.*
- ✅ **Bug d'acceptation aléatoire corrigé à la racine** : la signature est désormais atomique dans `RecruitmentPool._finalize_recruitment()` (`GuildManager.add_member` avant retrait du pool/émission signal). L'ancien chemin où l'UI devait ajouter le membre après coup ne peut plus avaler une recrue acceptée sans roster.
- ✅ **Cycle de vie des candidats** : les recrues arrivent avec niveaux variés, équipement cohérent, valeur/difficulté recalculée, durée de marché 3-8 jours, progression quotidienne et départ vers une guilde concurrente à expiration ou via compétition.
- ✅ **Refus exploitable** : un refus pose un cooldown de 24h, grise la ligne dans `RecruitmentPanel`, affiche le délai restant et permet une nouvelle approche après expiration.
- ✅ **Difficulté plus systémique** : niveau, skill, iLvl, traits sociaux/exigeants/risqués, offres concurrentes, statut national, réputation/perks de guilde et fit hardcore/casual influencent la chance affichée et le résultat.
- ✅ **UI plus lisible/fun** : liste enrichie (`[Pro]`, `[Pause]`, niveau, iLvl, label de chance, statut marché), fiche candidat avec rumeur, motivation, lecture des facteurs, disponibilité et négociation/scouting national conservés.
- ✅ **Tests ajoutés** : nouvelle suite `Recrutement (refonte)` couvrant génération non niveau 1, finalisation atomique, cooldown de refus et départ de marché ; suite économie nationale renforcée pour vérifier l'ajout réel au roster.

### Planning joueur systémique + hype serveur (2 juin 2026)
- ✅ **Hype serveur branchée** : `ServerVersion` expose une hype 100 au lancement, 75 après patch, puis décroissance progressive jusqu'à 35 ; elle augmente les connexions et ralentit le drain d'énergie quand le serveur est au pic.
- ✅ **Profils de connexion individuels** : chaque `SimulatedPlayer` possède jours actifs, archétype horaire, fiabilité, spontanéité, heure de départ et durée de session, générés depuis traits + profil comportemental puis sauvegardés.
- ✅ **Traits dédiés planning** : ajout de `hardcore_gamer`, `nocturne`, `diurne`, `joueur_weekend`, `planning_chaotique`, `insomniaque`, avec effets sur fréquence, fenêtre horaire, retards et disponibilité nocturne.
- ✅ **Présence logique mais incertaine** : `BehaviorSystem` planifie en minutes absolues, évite les connexions absurdes à 4h sauf profils insomniaques, ajoute jitter/spontanéité, morale de guilde, intégration, fatigue, humeur et amis en ligne.
- ✅ **Énergie cohérente** : joueurs PNJ et personnage joueur consomment moins d'énergie en période de forte hype ; les sessions durent plus longtemps quand motivation/morale/énergie sont bonnes et s'écourtent avec burnout/fatigue.
- ✅ **UI et persistance** : résumé planning affiché dans le panneau recrutement, hype visible dans l'horloge serveur, champs planning inclus dans les saves et migration depuis l'ancien dictionnaire `planning`.

### Correctifs d'audit — vague 1 : bugs critiques UI/Gameplay/Code (2 juin 2026)
*172 assertions vertes (Godot 4.6.2 headless) + validation runtime MCP. Implémentation de `AuditAmeliorations2.md` via 8 sous-agents (modules isolés) + correctifs cœur. Codes C* = entrées de la synthèse de l'audit.*

- 🔴 **C1 — Désync du perso-joueur après chargement (root cause trouvée en live)** : après un load, `SaveManager` reconstruit le joueur et remplace `GuildManager.player_character`, mais `main` + le panneau de contrôle continuaient de piloter l'**ancien** objet orphelin (hors guilde) → le joueur « montait niveau 17 au chat » tout en restant « Niv.1 » dans l'UI/guilde, objectif Phase 0 inatteignable. **Fix** : re-wiring sur `SaveManager.load_completed` (`_rewire_player_after_load` dans `main.gd`) qui re-pointe main + panneau + signaux vers le personnage chargé. Vérifié en jeu : niveau 1→19, toutes les références cohérentes.
- 🔴 **C3 — Or détruit + spam de toasts** : `gold_storage` niv 3 relevé 1000→8000 (`guild_perks_data.gd`) ; `Guild.add_gold` ne notifie qu'**une fois** à la transition « trésorerie pleine » (fin du spam).
- 🔴 **C4 — Boucle énergie/épuisement intrusive** : `_perform_rest` rendu **non bloquant** (plus de modale « Épuisement total » → repos accéléré par ticks + toast) ; drains d'énergie adoucis (LEVELING 15→9/h, etc.), seuil de fatigue 4h→6h.
- 🟠 **C5** : recalcul de classement débouncé sur `day_changed` (flag « dirty » au lieu de `create_timer` empilés) ; graphe social ré-indexé (`id→membre` + adjacence) → O(degré) au lieu de O(M⁴).
- 🔴 **C6** : ternaire à précédence piégeuse corrigé (`guild_ranking.gd`).
- 🟠 **C7** : signal `member_left` déclaré + émis dans `remove_member` (la notif de départ se déclenche enfin).
- ✅ **C9** : déjà câblé (`main._process` → `update_dungeons`). **C10** : l'activité ne produit plus de gains hors-ligne (garde `is_online`). **C11** : rôles de combat lus via `get_role()`. **C12** : binding de signaux d'`EffectSystem` réparé (lambdas à signature exacte + disconnect symétrique). **C13** : fermer un événement le résout (plus de file figée). **C14** : popups loot/drama résolus par défaut à la fermeture (plus de soft-lock) + abandon de donjon idempotent à propriétaire unique. **C15** : le perso-joueur protégé des départs aléatoires. **C16** : raccourcis clavier respectent les verrous de phase.
- 🧹 **Propreté** : ~couleurs sémantiques dérivées de `UIConstants` (source unique), polling UI supprimé (`time_display`/`player_control_panel` → signaux), clamp des fenêtres au viewport, activité « Fun » retirée de l'organisation de groupe, contenu de donjon gaté par phase/niveau, nombreux warnings éditeur réglés (params/signaux/shadowing/division entière).

### Correctifs d'audit — vague 2 : réactivité UI, BBCode, scaling IA, CI (2 juin 2026)
*172/172 assertions vertes + validation runtime MCP. Warnings éditeur 273→111.*
- 🟠 **Fermeture propre des fenêtres** : Personnage/Guilde/Monde émettent désormais `close_requested` (teardown propre par `WindowManager`) au lieu de `hide()` qui désynchronisait l'état (bouton de menu actif incorrect).
- 🟠 **Réactivité live** : fenêtre Personnage rafraîchit le niveau sur `member_leveled_up` (polling 3 s supprimé) ; liste Guilde réactive aux level-up / recrutements / départs ; classement Monde réactif à `ranking_updated`.
- 🟠 **Fuite BBCode** : panneaux de description (recrue / guilde) passés de `Label` à `RichTextLabel` (`bbcode_enabled`).
- 🟠 **Équilibrage IA** : nombre de guildes National 49→13, Esport 99→15 ; progression **hebdomadaire lissée** (fin du gate `week % 4` → classement en marches d'escalier à haute vitesse).
- ✅ **CI** : workflow GitHub Actions (`.github/workflows/tests.yml`) — Godot 4.6.2 → `CheckScripts` + `TestRunner` sur PR/push main.

### Banque de guilde + drag&drop d'équipement (2 juin 2026)
*171 assertions vertes + E2E drag&drop 5/5 (Godot 4.6.2). Dernier lot « reporté » de l'audit livré.*
- ✅ **Banque de guilde** : `Guild.bank_items` devient une vraie banque d'`Item` (`add_to_bank`/`remove_from_bank`/`get_bank_items`, plafonnée à 60 avec trim par rareté/iLvl). Sérialisée dans `SaveManager` (rétrocompatible).
- ✅ **Plus de loot perdu** : le loot non auto-équipé **et** les objets remplacés (swap) vont à la banque au lieu d'être jetés (`GuildManager.route_loot` branché dans `DungeonInstance` et la résolution de conflit). Seule la camelote commune est jetée.
- ✅ **Fenêtre « Banque & Équipement »** réécrite (de l'`AcceptDialog` lecture-seule vers un `PanelContainer` thémé) : sélecteur de membre, 5 slots, banque scrollable. **Drag & drop natif Godot** (`_get_drag_data`/`_can_drop_data`/`_drop_data`) via un composant `EquipDragCell` : glisser un objet de la banque sur un slot l'équipe (l'ancien retourne en banque, validation du type de slot) ; glisser un objet équipé sur la banque le range. `GuildManager.equip_from_bank`/`unequip_to_bank` opèrent sur le modèle, signal `bank_changed` pour le rafraîchissement live.
- ✅ **Validation** : suite `Banque & équipement` (modèle, swap, route_loot, round-trip de save) + `e2e_equipment.gd` (banque→slot→banque vérifié) + screenshot.

### Reprise des améliorations de l'audit — santé/simulation/UI (2 juin 2026)
*155 assertions vertes + 2 E2E (Godot 4.6.2). Lots « volontairement reportés » de l'audit repris.*
- ✅ **Santé du code** : 38 `get_node("/root/X")` remplacés par les identifiants globaux d'autoload ; nouveau `GameLog` (debug gardé par `OS.is_debug_build()`) avec 132 `print()` de boucle migrés. `singletons.gd` laissé intact (résolveur dynamique).
- ✅ **Profondeur de simulation** : connexion dynamique branchée — fatigue/burnout/humeur/amis en ligne influencent enfin la présence (`_connection_state_modifier` + déconnexion forcée sur épuisement) ; `PersonalEvents` routé via la vraie API (`should_trigger_event`/`get_event_for_player`, ~18 events au lieu de 3 ids en dur dont un inexistant), `player.has(...)` corrigé, effets (humeur/énergie/tous types) réellement appliqués, **temps bonus** (soirée libre/congé) consommé.
- ✅ **UI — multi-fenêtres mort tranché** : mode **mono-fenêtre** assumé. Retrait du code mort/cassé (Alt+Tab `cycle_windows`, cascade/tuiles, minimisation/taskbar, layouts nommés, signaux et constantes orphelins). Bonus : la **mémorisation des positions** de fenêtres devient réellement persistée (écrite à la fermeture, relue au boot).
- ✅ **UI — source unique de couleurs** : `UITheme` est la palette canonique ; `UIConstants` en dérive ses couleurs structurelles et `chat_panel.MESSAGE_COLORS` cesse d'être une 3e source (dérive de `UIConstants`). Rendu vérifié par screenshot (aucune régression).

### Prompt d'oisiveté thémé + Donjon/Raid au choix joueur (2 juin 2026)
*E2E dédiés : flow 8/8 + organisation 4/4, 145/145 assertions vertes (Godot 4.6.2).*
- ✅ **(b) Prompt d'oisiveté thémé** : l'`AcceptDialog` brut est remplacé par un **overlay in-game** (CanvasLayer + fond assombri à 72 % + `PanelContainer` à bordure accent) qui hérite du thème global `UITheme`. Titre « Jeu en pause », énergie, boutons d'activité avec descriptions, séparateurs — rendu vérifié par screenshot.
- ✅ **(a) Donjon/Raid comme choix joueur** : nouveau bouton « ⚔️ Donjon / Raid » dans le prompt **et** le panneau de contrôle. Il route vers la **vraie fenêtre d'organisation de groupe** (flow PvE existant : composition → `DungeonInstance`), présélectionnée sur le bon contenu via `Fenetre_OrganisationGroupe.preselect_activity()`. Pas de fausse activité solo : Donjon/Raid restent du contenu de groupe. Choisir « organiser » relance le temps (c'est un ordre donné).

### Refonte de la gestion du personnage joueur (2 juin 2026)
*Suite de tests : 131 → 145 assertions, 100 % vertes + E2E dédié 8/8 (Godot 4.6.2 headless).*
- 🔴 **Bug corrigé — l'énergie ne baissait jamais** : le personnage joueur démarrait connecté **sans activité** (`current_activity == null`), or les deux chemins de drain faisaient un *early-return*. Désormais le drain a une **source unique** (tick 5 min de l'`ActivityManager`) — suppression du double-drain horaire dans `GuildManager._update_player_character`.
- ✅ **Pause-si-oisif (style Football Manager)** : quand le joueur est connecté sans activité, `GameTime` se met en **pause** et un **prompt modal** demande un ordre (Leveling / Farming / Détente / Se reposer). Le temps repart automatiquement dès qu'une activité est choisie (via le prompt **ou** le panneau de contrôle). Déclenché aussi au démarrage de partie.
- ✅ **Reprise auto après repos** : nouvelle propriété persistante `last_activity_choice` (conservée à la déconnexion) ; après un repos (forcé par épuisement **ou** volontaire), le joueur se **reconnecte et reprend automatiquement** sa dernière activité. Repos unifié et **accéléré par ticks** (8h ≈ 10s réelles à x2880) : la guilde continue de recevoir les ticks de temps, donc les membres peuvent progresser, se connecter et se déconnecter pendant l'absence du joueur.
- ✅ **UI temps réel** : nouveau signal `PlayerCharacter.player_state_changed` ; la jauge d'énergie du panneau et la fenêtre Personnage se rafraîchissent **à l'instant** (plus seulement par polling 3-5 s). La fenêtre Personnage affiche désormais l'**activité courante** (🎯 en cours / ⏸️ en attente / 😴 hors ligne).
- ✅ **Robustesse** : bouton « Se reposer » fonctionnel (l'ancien était un TODO désactivé) ; fermeture du dialog de repos via la croix routée vers la confirmation (évite un gel du verrou de repos) ; nettoyage des `print()` de debug (gated `OS.is_debug_build()`).
- ✅ **Persistance** : `last_activity_choice` sauvegardée/chargée (`SaveManager`). Nouveau test `e2e_player_flow.gd` (pause → choix → drain) + suite unitaire `PlayerCharacter (flow)`.

### Implémentation de l'audit AuditAmeliorations.md (1er juin 2026)
*Suite de tests : 57 → 101 assertions, 100 % vertes (Godot 4.6.2 headless).*
- **Recrutement national (P5)** : la commission d'agent est désormais prélevée sur l'or dans **tous** les chemins d'acceptation (offre directe ET contre-proposition), avec contrôle de solvabilité, centralisé dans `RecruitmentPool._finalize_national_recruit()` (à l'image de `TransferManager`). UI mise à jour (message de signature + cas « inabordable »).
- **RNG déterministe (P5)** : `GameRandom.seed_rng()/randomize_rng()/get_seed()/is_seeded()` ; en fixant le générateur global, **toute** la simulation devient reproductible (tests/E2E rejouables).
- **Sources de vérité (P3)** : suppression du chemin de node mort `/root/root2` dans `EventManager` (la popup passe uniquement par le signal `event_triggered`) ; lookups autoload→autoload (`MediaManager`/`SponsorshipManager`) convertis en références globales ; E2E migrés vers `WindowManager.get_window_instance()`.
- **Sauvegarde versionnée (P11)** : mécanisme de **migration** (`CURRENT_SAVE_VERSION=2`, registre de migrations séquentielles, garde « save plus récente que le build ») ; migration v1→v2 qui normalise les blocs systèmes manquants des anciennes saves.
- **Façade d'équilibrage (P12)** : `BalanceManager.BALANCE` + `tunable()/tunable_float()` centralisent les nombres magiques (recrutement, salaires, réputation, PvE, poids de ranking) ; points d'appel clés routés sans changement de comportement.
- **Conseiller « Cette semaine » (P9)** : `AdvisorManager.get_weekly_summary()` (membres à risque, objectifs accessibles, recrutement, contenu conseillé, activités) + nouvel onglet dans `Fenetre_Conseils`.
- **Boucle PvE (P1)** : aperçu de run enrichi (énergie/stress moyens, alertes de fatigue/burnout, score ajusté, code couleur) dans `Fenetre_OrganisationGroupe`.
- **Tests (P10)** : nouvelles suites PvE (composition, run reproductible, phase 0→1), calendrier (salaires, refresh), économie de recrutement, RNG, migration de save, smoke UI.
- **Typage GDScript (P7)** : types de retour ajoutés aux 6 fichiers centraux (`main`, `guild_manager`, `recruitment_pool`, `activity_manager`, `phase_manager`, `guild_ranking`).
- **Outillage** : `tests/CheckScripts.tscn` — validateur de syntaxe terminant (alternative à `--check-only` qui peut se suspendre sous Windows) ; docs mises à jour (grille Implémenté/Jouable/Validé, note Windows vs WSL).

### Stabilisation technique (31 mai 2026)
- **GameTime** : ajout d'un compteur de jours absolus (`get_total_days_elapsed`) pour fiabiliser les systèmes calendaires.
- **RecruitmentPool** : refresh complet basé sur le jour absolu, corrigé autour des changements de semaine/année.
- **AIGuildManager/GuildRanking** : suppression du double enregistrement initial des guildes IA.
- **GuildRanking** : score de réputation branché sur la vraie réputation de la guilde joueur.
- **WindowManager** : API publique `get_window_instance()` et `refresh_window()` pour éviter les appels externes à `_get_existing_instance()`.
- **Debug UI** : menu Debug, raccourcis F1/F2 et bouton `Next Version` limités aux builds debug.
- **Fenetre_Personnage** : onglet Progression stabilisé avec objectifs lisibles, largeur minimale, barre par objectif et scroll vertical.
- **PhaseManager/Main** : notification de changement de phase relayée par `phase_changed` au lieu d'un chemin direct vers `ChatPanel`.
- **Main/tests** : flag `--no-save-autoload` pour vérifier `Main.tscn` sans dépendre de la save locale.
- **Scènes** : UID invalides nettoyés dans `Main.tscn` et `Fenetre_Personnage.tscn`.
- **CustomProgressBar** : positionnement du label corrigé pour supprimer le warning d'ancrage au lancement.
- **AIGuild** : restauration de save sans génération temporaire de guildes ni logs `Ma Guilde` parasites.
- **PvE minimal** : clears joueur enregistrés depuis `DungeonInstance`, sauvegardés dans `GuildRanking`, utilisés par le ranking et `PhaseManager.content_cleared_percent`.
- **ActivityManager** : préférences automatiques Donjon/Raid converties en activités PvE dédiées plutôt qu'en farming.
- **Historique PvE** : `GuildRanking` expose l'historique des runs joueur et le meilleur clear connu par contenu.
- **Fenetre_Personnage** : derniers runs PvE affichés dans l'onglet Progression.
- **ChatPanel** : fin de donjon enrichie en mini rapport avec durée, boss, wipes et or.
- **Fenetre_Personnage** : meilleur clear du dernier contenu PvE affiché depuis `GuildRanking.get_player_best_clear(content_id)`.
- **DungeonInstance** : émission de `boss_defeated` corrigée pendant les conflits de loot pour respecter la signature du signal.
- **Fenetre_OrganisationGroupe** : aperçu de run ajouté avec score estimé, rôles manquants et moyennes niveau/équipement/skill.
- **DungeonData** : `calculate_difficulty_score()` protège maintenant les groupes vides.
- **GuildRanking** : classements National et Mondial branchés sur le calcul existant avec multiplicateurs de phase.
- **GuildRanking** : score d'activité protégé contre les guildes vides.
- **Fenetre_Loot/Fenetre_Donjon** : rapport PvE dédié en fin de run avec score de performance, boss, wipes, participants et butin.
- **PveRunReport** : calcul de score de performance partagé entre rapport, historique et tests.
- **Fenetre_Personnage** : historique PvE enrichi avec score de performance persisté.
- **Tests** : suite automatisée étendue à 98 assertions (PvE, calendrier, économie de recrutement, RNG déterministe, migration de save, smoke UI), validée avec Godot 4.6.2.

### Infrastructure UI Phases 1 & 2 (9 jours)
- **NotificationManager** : Système toast professionnel avec 5 types et animations
- **WindowManager Avancé** : Multi-fenêtres, z-order, layouts, Alt+Tab
- **8 Composants UI** : CustomProgressBar, Badge, StatDisplay, DraggableItem, DropZone, BaseDialog, dialogs spécialisés, AdvancedTabs
- **Système Drag & Drop** : Complet avec 4 policies et feedback visuel
- **Dialogues Modernes** : Confirmation, saisie, progression avec validation

### Système de Comportement Dynamique Avancé (15 août 2025)
- **BehaviorSystem** : Système complet de comportement dynamique avec variations réalistes
- **Granularité temporelle** : Passage de l'heure à la minute pour plus de réalisme
- **Planification dynamique** : Horaires de connexion/déconnexion avec variance personnalisée
- **Profils psychologiques** : Stress, fatigue, burnout affectant les comportements
- **Événements spontanés** : Connexions/déconnexions imprévues selon contexte
- **Relations sociales** : Système de relations influençant les décisions
- **Préférences d'activités** : Apprentissage et adaptation selon expériences

### Système d'Activités Amélioré (15 août 2025)
- **Mise à jour granulaire** : Activités mises à jour toutes les 5 minutes au lieu de chaque heure
- **Gains progressifs** : XP, énergie et humeur calculés proportionnellement au temps
- **Durées variables** : Chaque activité a une durée planifiée (15-120 min selon le type)
- **Changements dynamiques** : Les joueurs changent d'activité naturellement
- **Courbe d'XP réaliste** : Progression plus rapide au début, ralentissement progressif
- **Variance dans les gains** : ±20% de variation dans les gains d'XP pour plus de réalisme

### Bénéfices Immédiats
- **Code réutilisable** : 11 nouveaux composants modulaires
- **UX professionnelle** : Interface cohérente et moderne
- **Développement accéléré** : Infrastructure prête pour features complexes
- **Maintenance simplifiée** : Code organisé et documenté

## Chemin Restant (25-30 jours estimés)

**Prochaines actions recommandées** :
1. ✅ **Infrastructure UI Phases 1-2** (TERMINÉ)
2. **Milestone 3 - Phase Nationale** (7-10 jours) - *Fondation solide acquise*
3. **Milestone 4 - Phase Esport** (7-10 jours) - *UI avancée disponible*
4. **Infrastructure UI Phase 3** (optionnel, 4-5 jours) - *Polish final*
5. **Milestones 5-6** (8-12 jours) - *Finalisation et équilibrage*

**Avantage stratégique réalisé** : L'infrastructure UI robuste **accélère déjà** le développement. Les Milestones 3-4 bénéficieront de composants drag & drop, dialogues avancés et notifications pour implémenter rapidement les features complexes.

## Position Stratégique
RaidLead possède maintenant une **base technique solide** comparable aux jeux commerciaux modernes, prête pour les phases avancées du gameplay.

---
*Document mis à jour le 15 août 2025 - Version 2.1 avec Dynamic Behavior System*
