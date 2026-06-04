# Systeme de quetes de guidage et campagne

*Spec de design v1 - 3 juin 2026. Statut : specification pre-implementation.*

## 0. Intention

Le systeme de quetes doit servir de couche de guidage pour RaidLead. Son role n'est pas de
remplacer la simulation, les phases ou les objectifs de progression existants : il doit aider le
joueur a comprendre ce qui est actionnable, dans quel ordre explorer les interfaces, et pourquoi
une nouvelle feature vient d'apparaitre.

Le nom public recommande est **Objectifs** plutot que "Quetes". "Quetes" reste le nom technique si
utile, mais l'UI doit parler en termes d'objectifs de manager : recruter, organiser, inspecter,
stabiliser, viser le classement, negocier, etc.

### Objectifs produit

- Guider fortement les 20 a 40 premieres minutes sans transformer le jeu en tutoriel bloque.
- Donner au joueur un objectif immediat et lisible quand il ne sait pas quoi faire.
- Faire decouvrir les fenetres existantes au moment ou elles deviennent utiles.
- Accompagner les transitions de phase avec une courte sequence de decouverte.
- Espacer progressivement les quetes : beaucoup au debut, quelques rappels en Phase Serveur, puis
  uniquement des quetes de decouverte de nouvelles UI en National/Esport.
- Ne jamais faire concurrence a `PhaseManager` : les quetes lisent les requirements de phase, elles
  ne definissent pas la progression canonique.

### Non-objectifs

- Pas de campagne narrative lourde.
- Pas de quetes journalieres/grind qui forceraient une routine artificielle.
- Pas de systeme de recompenses economiques dominant la meta.
- Pas de modales intrusives apres l'onboarding initial.
- Pas de duplication des conditions de victoire de phase dans un second manager.

## 1. Principes UX

### 1.1 Guidage progressif

Le systeme doit suivre une courbe claire :

| Moment | Densite | But |
| --- | --- | --- |
| Debut Phase 0 | Tres dense | Apprendre les controles, lire son perso, lancer une activite, recruter, organiser un donjon |
| Fin Phase 0 | Dense mais non bloquant | Introduire groupe, loot, equipement, donjon heroique, transition de phase |
| Phase Serveur | Moderee | Construire un roster, comprendre classement, integration, contenu PvE |
| Phase Nationale | Faible | Decouvrir recrutement national, medias, sponsors, dramas publics |
| Phase Esport | Tres faible | Decouvrir staff, tournois, bootcamps, stabilite, legacy |

### 1.2 Une seule intention principale

L'UI ne doit jamais afficher dix objectifs concurrents. La forme recommandee :

- 1 objectif principal de campagne.
- 0 a 2 objectifs secondaires contextuels.
- 1 bouton d'action maximum par objectif : "Aller".
- Un etat clair : disponible, en cours, termine, masque.

### 1.3 Non-bloquant par defaut

Le joueur peut ignorer les objectifs. Le systeme peut recommander, pointer, feliciter, mais ne doit
pas empecher les actions normales sauf dans une micro-sequence de tout debut de partie si on veut
forcer l'ouverture de la premiere fenetre.

### 1.4 Retroactif

Si le joueur a deja fait l'action avant que la quete s'affiche, elle doit se valider
automatiquement. Exemple : si le joueur a deja recrute un membre, "Recruter votre premier membre"
est terminee au moment ou elle devient disponible.

### 1.5 Diegetique legere

Le ton doit venir du role de leader de guilde :

- "Votre guilde a besoin d'un premier noyau solide."
- "Regardez le classement serveur pour savoir qui vous menace."
- "Un sponsor peut stabiliser vos finances avant la scene nationale."

Pas de longs paragraphes expliquant l'UI. Le bouton "Aller" et le highlight visuel doivent faire le
travail.

## 2. Surface UI

### 2.1 Tracker d'objectifs

Ajouter un tracker compact, visible sur l'ecran principal, idealement au-dessus de la barre de menu
ou dans un coin lateral qui ne masque pas les fenetres.

Contenu :

- Titre court de l'objectif actif.
- Progression compacte : `2/5 membres`, `60/80% contenu`, `0/1 sponsor`.
- Bouton "Aller" si une cible UI existe.
- Bouton discret pour masquer l'objectif.

Contraintes :

- Le tracker doit rester utilisable a toutes les vitesses de temps.
- Il ne doit pas ouvrir de popup pendant un repos accelere, un donjon en cours ou une decision modale
  de loot/drama/event.
- Un objectif termine affiche un toast court, puis passe au suivant sans interrompre la simulation.

### 2.2 Fenetre Objectifs

Nouvelle fenetre recommandee : `Fenetre_Objectifs`.

Onglets :

- **Campagne** : la ligne directrice active par phase.
- **Decouverte** : features UI debloquees mais pas encore vues.
- **Termines** : historique compact.

Chaque entree affiche :

- titre;
- texte court;
- objectifs atomiques;
- recompense/eventuelle consequence;
- bouton "Aller" si applicable;
- statut.

### 2.3 Highlight UI

Le bouton "Aller" doit :

1. ouvrir la bonne fenetre via `WindowManager.show_window(window_name)`;
2. demander a la fenetre de highlight un controle semantique si elle expose l'API;
3. ne jamais chercher un node via chemin profond fragile.

API proposee cote fenetres :

```gdscript
func highlight_guidance_target(target_id: String) -> void:
	# Exemple: "recruitment_tab", "first_candidate", "start_dungeon_button"
	pass
```

Le `QuestManager` ne connait que des cibles semantiques :

```gdscript
{
	"window": "monde",
	"target": "recruitment_panel"
}
```

## 3. Architecture

### 3.1 Autoload `QuestManager`

Responsabilites :

- charger le catalogue de quetes;
- calculer disponibilite et progression;
- ecouter les signaux existants;
- emettre les changements pour l'UI;
- sauvegarder/restaurer l'etat;
- exposer l'objectif principal courant.

Signaux recommandes :

```gdscript
signal quest_available(quest_id: String)
signal quest_started(quest_id: String)
signal quest_progress_changed(quest_id: String, progress: Dictionary)
signal quest_completed(quest_id: String)
signal quest_claimed(quest_id: String)
signal active_quest_changed(quest_id: String)
signal guidance_target_requested(window_name: String, target_id: String)
```

API publique recommandee :

```gdscript
func get_active_campaign_quest() -> Dictionary
func get_visible_quests() -> Array[Dictionary]
func start_quest(quest_id: String) -> bool
func hide_quest(quest_id: String) -> void
func claim_quest(quest_id: String) -> void
func notify_event(event_type: String, payload: Dictionary = {}) -> void
func save_quest_data() -> Dictionary
func load_quest_data(data: Dictionary) -> void
```

### 3.2 Catalogue de donnees

MVP recommande : `scripts/data/quest_data.gd` avec dictionnaires valides par tests.

Evolution possible : migrer vers des `Resource` (`QuestDefinition`, `QuestObjectiveDefinition`) si
on veut edition Godot/editor-friendly.

Schema logique :

```gdscript
{
	"id": "p0_recruit_first_member",
	"title": "Recruter un premier membre",
	"phase_min": PhaseManager.GamePhase.LEVELING,
	"phase_max": PhaseManager.GamePhase.LEVELING,
	"category": "campaign",
	"priority": 100,
	"availability": [
		{"type": "quest_completed", "id": "p0_open_guild"}
	],
	"objectives": [
		{
			"id": "member_count",
			"type": "metric_at_least",
			"metric": "guild.member_count",
			"target": 2
		}
	],
	"ui_target": {"window": "monde", "target": "recruitment_panel"},
	"rewards": [
		{"type": "toast", "text": "La guilde commence a prendre forme."}
	],
	"skip_policy": "optional",
	"spacing": {"min_days_after_previous": 0}
}
```

### 3.3 Objectifs atomiques

Types d'objectifs suffisants pour le MVP :

| Type | Exemple | Source |
| --- | --- | --- |
| `window_opened` | Ouvrir la fenetre Guilde | `WindowManager.window_opened` |
| `metric_at_least` | Avoir 5 membres | `GuildManager`, `GuildRanking`, `PhaseManager` |
| `metric_at_most` | Avoir max 2 dramas/an | `DramaManager` |
| `event_seen` | Premier loot rare obtenu | `QuestManager.notify_event` |
| `event_count` | Completer 1 donjon | signaux PvE |
| `phase_reached` | Atteindre Niveau Serveur | `PhaseManager.phase_changed` |
| `ui_action` | Lancer une organisation de groupe | signal ajoute par la fenetre concernee |
| `compound_all` | Lire ranking + recruter + lancer donjon | agrege plusieurs objectifs |

Chaque objectif doit etre :

- testable sans scene UI;
- recalculable depuis l'etat courant autant que possible;
- event-driven quand l'action n'est pas reconstructible.

### 3.4 Sources de verite

Le systeme doit lire les managers existants :

- `PhaseManager` : phase courante, requirements, progression.
- `WindowManager` : decouverte des fenetres.
- `GuildManager` : membres, online, recrutement, moral, banque.
- `RecruitmentPool` : candidats, offres, refus, cooldowns.
- `ActivityManager` / PvE : activites, donjons, raids.
- `GuildRanking` : rang, clears, server/world first.
- `MediaManager`, `SponsorshipManager`, `DramaManager`, `StaffManager`, `TournamentManager` : objectifs de phases avancees.
- `AdvisorManager` : peut fournir des recommandations, mais ne doit pas piloter les quetes.

### 3.5 Persistance

`SaveManager` doit inclure :

```gdscript
{
	"completed_quests": Array[String],
	"claimed_quests": Array[String],
	"hidden_quests": Array[String],
	"active_campaign_quest": String,
	"objective_progress": Dictionary,
	"seen_features": Array[String],
	"quest_save_version": int
}
```

Migration :

- save sans bloc quetes = initialiser vide;
- quetes deja satisfaites = auto-complete au chargement;
- quete supprimee du catalogue = conserver en historique "obsolete" sans crash.

## 4. Progression de campagne proposee

### 4.1 Phase 0 - Onboarding et leveling

But : apprendre les actions minimales et amener vers le premier donjon heroique.

| Ordre | Quete | Objectif joueur | Cible UI |
| --- | --- | --- | --- |
| 1 | Prendre ses reperes | Ouvrir Personnage, lire energie/niveau | `personnage` |
| 2 | Donner un premier ordre | Lancer Leveling ou Farming | panneau joueur |
| 3 | Lire sa guilde | Ouvrir Guilde, inspecter un membre | `guilde` |
| 4 | Trouver du renfort | Ouvrir Monde/Recrutement | `monde.recruitment_panel` |
| 5 | Recruter un premier membre | Avoir au moins 2 membres | recrutement |
| 6 | Former un groupe | Ouvrir Organisation | `organisation` |
| 7 | Premier donjon | Lancer et terminer un donjon normal | organisation/donjon |
| 8 | Comprendre le loot | Ouvrir rapport ou banque/equipement apres loot | loot/equipement |
| 9 | Preparer l'heroique | Avoir un groupe adapte niveau/equipement | organisation |
| 10 | Passer le cap | Terminer 1 donjon heroique | PhaseManager |

Regles :

- Les quetes 1 a 5 peuvent etre tres rapprochees.
- A partir de la quete 6, laisser le temps respirer : pas de nouvelle quete tant qu'un donjon, un
  event modal ou un repos est actif.
- Si le joueur rush directement le donjon heroique, auto-completer toute la chaine Phase 0 avec une
  notification unique.

### 4.2 Phase Serveur - Stabiliser et viser le rang 1

But : convertir l'apprentissage en objectifs de management.

| Quete | Objectif | Feature introduite |
| --- | --- | --- |
| Lire le classement serveur | Ouvrir Monde et consulter le classement | Ranking |
| Construire le noyau | Atteindre 10 puis 15 membres | Roster/recrutement |
| Connaitre son effectif | Atteindre une integration moyenne cible | Tags/integration |
| Planifier le PvE | Completer X contenus ou 80% du contenu disponible | PvE progression |
| Tenir la premiere place | Atteindre puis maintenir rang 1 | Phase requirements |
| Utiliser les conseils | Ouvrir Conseils et lire le resume hebdo | AdvisorManager |

Espacement :

- minimum 2 a 4 jours de jeu entre nouvelles quetes de campagne;
- pas plus d'un objectif principal serveur actif a la fois;
- les requirements exacts restent ceux de `PhaseManager`.

### 4.3 Phase Nationale - Decouverte des nouvelles interfaces

But : introduire les systemes plus complexes sans re-tutoriser tout le jeu.

Quetes ponctuelles :

- Ouvrir l'interface Nationale.
- Examiner un candidat semi-pro ou national.
- Signer ou refuser une offre avec agent.
- Ouvrir Medias et comprendre la reputation publique.
- Signer un premier sponsor.
- Repondre a un drama public.
- Obtenir ou viser un world first.

Espacement :

- 1 quete de decouverte au debut de phase;
- puis uniquement lorsqu'une feature devient disponible ou qu'un evenement la rend pertinente;
- cooldown recommande : 7 a 14 jours de jeu entre quetes non critiques.

### 4.4 Phase Esport - Excellence et legacy

But : rappeler les nouveaux leviers, pas guider chaque decision.

Quetes ponctuelles :

- Ouvrir Esport.
- Recruter ou consulter le staff professionnel.
- Programmer un bootcamp.
- Participer a un tournoi international.
- Stabiliser l'equipe sous pression.
- Ouvrir Legacy/Hall of Fame quand disponible.

Espacement :

- quetes rares, declenchees par unlock;
- aucun tracker permanent si le joueur a masque la campagne;
- favoriser des objectifs de decouverte UI plutot que des objectifs de grind.

## 5. Recompenses

Les recompenses doivent etre faibles et surtout informatives.

Recommande :

- toast de succes;
- petite reputation de guilde en onboarding;
- petite somme d'or uniquement au debut si l'economie le permet;
- unlock de badges/cosmetiques plus tard;
- entree dans l'historique de campagne.

A eviter :

- recompenses necessaires a la progression;
- grosses injections d'or;
- boosts de skill/equipement;
- quetes repetables optimisables.

Les valeurs numeriques doivent passer par `BalanceManager` si elles existent.

## 6. Regles de declenchement

### 6.1 Disponibilite

Une quete devient disponible si :

- sa phase est compatible;
- ses prerequis sont remplis;
- elle n'est pas terminee/masquee;
- son cooldown de spacing est expire;
- aucun verrou de contexte ne l'interdit.

Verrous de contexte :

- repos accelere en cours;
- donjon/raid en cours;
- popup event/loot/drama actif;
- sauvegarde/chargement en cours;
- changement de phase en train de se resoudre.

### 6.2 Auto-completion

Au chargement, au changement de phase et toutes les fins de jour, `QuestManager` recalcule les
objectifs de type metric. Les objectifs event-only restent bases sur l'historique conserve dans la
save.

### 6.3 Priorite

Ordre de selection de l'objectif principal :

1. quete de phase nouvellement debloquee;
2. quete de campagne active;
3. quete de decouverte d'une feature jamais vue;
4. objectif de phase lu depuis `PhaseManager`;
5. aucun objectif, tracker replie.

## 7. Relations avec les systemes existants

### PhaseManager

`PhaseManager` reste la source de verite pour les phases. `QuestManager` peut generer des quetes
qui pointent vers les requirements courants, mais ne doit pas stocker une version parallele de ces
requirements.

### AdvisorManager

`AdvisorManager` donne des conseils tactiques et contextuels. `QuestManager` donne une direction de
campagne. Les deux peuvent coexister :

- Objectifs = "quoi decouvrir / quel cap viser".
- Conseils = "quoi faire cette semaine vu l'etat actuel".

### NotificationManager

Utiliser des toasts courts :

- quete terminee;
- nouvelle etape majeure;
- feature debloquee.

Pas de spam : regrouper les completions retroactives.

### WindowManager

Le bouton "Aller" passe toujours par `WindowManager.show_window`. Les fenetres doivent exposer des
cibles semantiques pour le highlight.

## 8. Tests et validation

### Tests unitaires

- chargement du catalogue sans id duplique;
- quete disponible selon phase/prerequis;
- progression `metric_at_least`;
- progression `window_opened`;
- auto-completion retroactive;
- save/load round-trip;
- quete obsolette ignoree sans crash;
- spacing respecte;
- suppression/masquage d'une quete.

### Tests integration

- ouvrir une fenetre emet une progression de quete;
- recruter un membre valide la quete de recrutement;
- completer un donjon heroique auto-complete la fin de Phase 0;
- changement de phase declenche la premiere quete de decouverte de phase;
- bouton "Aller" ouvre la bonne fenetre.

### Tests UX manuels

- demarrer une nouvelle partie et suivre les 10 premieres quetes;
- ignorer les quetes et verifier que le jeu reste jouable;
- charger une save avancee et verifier que le systeme ne rejoue pas tout le tutoriel;
- passer de Phase Serveur a Nationale et verifier que seules les nouvelles UI sont introduites;
- jouer en vitesse elevee sans avalanche de toasts.

## 9. Plan d'implementation recommande

### Lot 1 - Socle data et manager

- Ajouter `QuestManager` autoload.
- Ajouter `QuestData`.
- Ajouter sauvegarde/restauration.
- Ajouter tests catalogue/progression.

### Lot 2 - Tracker minimal

- Ajouter composant `QuestTrackerPanel`.
- Brancher `WindowManager.window_opened`.
- Bouton "Aller" vers fenetre cible.
- Implementer les 5 premieres quetes Phase 0.

### Lot 3 - Campagne Phase 0 complete

- Ajouter objectifs donjon, loot, equipement, heroique.
- Brancher signaux PvE et recrutement.
- Auto-completion retroactive.
- Tests integration.

### Lot 4 - Fenetre Objectifs

- Ajouter `Fenetre_Objectifs`.
- Historique, campagne, decouverte.
- Masquage et affichage des quetes terminees.

### Lot 5 - Phases avancees

- Ajouter quetes Serveur/National/Esport.
- Brancher managers medias/sponsors/staff/tournois.
- Ajouter spacing avance et verrous de contexte.

## 10. Criteres d'acceptation MVP

Le MVP est considere pret si :

- une nouvelle partie affiche un objectif principal clair sans popup bloquante;
- le joueur peut suivre une chaine jusqu'au premier donjon heroique;
- ouvrir les fenetres principales valide les quetes de decouverte;
- les quetes deja remplies se completent automatiquement;
- une save avancee ne rejoue pas l'onboarding;
- les quetes ne bloquent jamais recrutement, donjons, repos, events ou changement de phase;
- `CheckScripts` compile;
- `TestRunner` couvre au minimum catalogue, progression, save/load et Phase 0.

## 11. Risques

| Risque | Mitigation |
| --- | --- |
| Systeme trop intrusif | Tracker repliable, quetes optionnelles, peu de modales |
| Duplication de PhaseManager | Lire les requirements, ne pas les redefinir |
| Trop de texte | Texte court + bouton Aller + highlight |
| Flaky tests avec simulation aleatoire | Tests sur etat controle, pas sur tirages random |
| Couplage UI fragile | Cibles semantiques, pas de chemins de nodes profonds |
| Save casse lors d'ajout/retrait de quetes | Version de save + ids obsoletes toleres |

## 12. Decision de design

Le systeme doit etre traite comme une **surcouche d'orientation** :

- il observe la simulation;
- il met en avant le prochain cap utile;
- il ouvre les bonnes interfaces;
- il felicite les accomplissements;
- puis il s'efface.

Cette approche garde RaidLead dans son genre principal : un jeu de management systemique, pas une
suite de missions lineaires.
