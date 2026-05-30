# Roadmap Complète - RaidLead
*Document unifié - État au 10 avril 2026*

## Vue d'ensemble du projet

**RaidLead** est un jeu de gestion de guilde MMORPG développé avec **Godot Engine 4.5** et **GDScript**. Le joueur manage une guilde d'élite à travers 4 phases de progression : Leveling (0) → Serveur (1) → National (2) → Esport (3).

### État actuel
- ✅ **Phase active** : Phase 0 "Leveling" 
- ✅ **Compilation** : Sans erreurs, jeu fonctionnel
- ✅ **Systèmes core** : Tous implémentés et opérationnels
- ✅ **Refactoring majeur** : WindowManager, GuildManager, autoloads, save/load
- 🎯 **Progression** : ~55% du projet total terminé

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
> - ✅ **Tests automatisés** : harnais maison `res://tests/` (36 assertions, 100 % vertes) lançable en headless (`tests/run_tests.ps1`).
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
- ✅ **Suites** : Item/Equipment, SimulatedPlayer (stress/burnout), BalanceManager, AdvisorManager, SaveManager (round-trip), PhaseManager — **36 assertions, 100 % vertes**
- ✅ **Exécution CI-friendly** : `tests/run_tests.ps1` (détecte Godot, code de sortie 0/1) + `tests/README.md`
- ✅ **Validation runtime via MCP** : chaque milestone validé en jeu (screenshots, scripts d'inspection)
- 📋 **Playtests externes / optimisation perf sessions longues** : à faire (hors automatisation)

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
- **Tooling Claude Code** : 100% ✅ *(Godot 4.5, MCP Pro, LSP, godot-docs)*
- **Infrastructure UI Phase 3** : 0% 📋 *(Phase 3 - Polish)*
- **Thème UI global** : 100% ✅ *(UITheme appliqué partout)*
- **Milestone 3** : 100% ✅ *(National : célébrité, médias, sponsors, dramas, recrutement national + salaires, progression Phase 2→3 branchée)*
- **Milestone 4** : 100% ✅ *(Esport : staff pro, tournois internationaux, burnout/stress, transferts internationaux, legacy/Hall of Fame)*
- **Milestone 5** : 100% ✅ *(Transversales : dynamiques de groupe, moral collectif + contagion, team-building, traditions, gestion des conflits)*
- **Milestone 6** : 95% ✅ *(Polish : conseiller adaptatif, dashboard de stats, auto-sauvegarde + backup, équilibrage adaptatif BalanceManager, harnais de tests automatisés 36/36 ; calibrage fin et playtests externes restants)*

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
