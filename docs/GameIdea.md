Spécifications Initiales - Jeu de Gestion de Guilde MMORPG
1. Concept Général

    Type de jeu : Jeu de gestion solo sur PC (distribution via Steam envisagée).

    Thème : Gestion d'une guilde de haut niveau dans un MMORPG fictif.

    Modèle : Inspiré des jeux de gestion d'équipe sportive (ex: Football Manager), adapté à l'univers MMORPG.

    Environnement : Le jeu simule un environnement MMORPG avec d'autres guildes et joueurs (PNJ). Le joueur interagissant avec le jeu est désigné comme le "vrai-joueur".

2. Objectifs du Vrai-Joueur

    Créer et gérer une guilde.

    Recruter des joueurs simulés.

    Former des groupes pour réussir des donjons et raids de difficulté croissante.

    Faire progresser les personnages des joueurs (niveau, équipement, compétences).

    Gérer les relations, l'intégration et conflits au sein de la guilde (via des événements aléatoires et la gestion des joueurs).

    Progresser plus vite que les guildes concurrentes simulées.

3. Joueurs Simulés (Caractéristiques)

Chaque membre potentiel ou membre de la guilde est un PNJ avec les caractéristiques suivantes :

    Tags comportementaux : Des traits qui influencent ses réactions et décisions (ex: greedy, loyal, impatient, helpful). Certains sont cachés au début et révélés via l'Intégration.

    Énergie : Une barre qui diminue avec l'activité. Influence la performance en donjon/raid. Si vide, le joueur se déconnecte.

    Humeur : Une barre qui varie selon les succès, échecs, interactions et événements.

    Skill : Une valeur numérique représentant le talent brut du joueur (peut être partiellement masquée au début, précision affinée via l'Intégration).

    Connaissance des Donjons/Raids : Des valeurs distinctes indiquant sa maîtrise de chaque boss/mécanique par instance (0% à 100%). Généralement faible pour les nouvelles recrues sur le contenu récent.

    Planning : Définit ses jours et heures de connexion habituels (peut être visible approximativement avant recrutement, précision affinée via l'Intégration).

    Intégration : Une barre (ex: 0 à 100) représentant à quel point le joueur se sent intégré et à l'aise dans la guilde.

        Commence bas pour les nouvelles recrues.

        Augmente lentement avec le temps passé dans la guilde et les activités solo (Leveling, Farming).

        Augmente significativement plus vite lors de la participation à des activités de groupe réussies (Donjons, Raids, Activités Fun).

        Atteindre certains paliers d'Intégration révèle progressivement les Tags cachés du joueur, et peut affiner la visibilité de son Skill et de son Planning.

        Une faible Intégration peut augmenter le risque de départ du joueur.

4. Personnages des Joueurs Simulés (Caractéristiques)

Chaque joueur simulé contrôle un personnage dans le MMORPG fictif :

    Classe : Rôle spécifique dans un groupe.

        Guerrier : Rôle = Tank (initialement).

        Mage : Rôle = DPS (Dégâts par seconde).

        Prêtre : Rôle = Soigneur (Healer).

    Niveau d'Équipement : Une valeur numérique globale représentant la puissance de son équipement (améliorable via les donjons/raids). Visible lors du recrutement.

    Niveau d'Expérience : De 1 à 60 (maximum actuel), progresse via l'activité "Leveling". Visible lors du recrutement.

    (Futur) Inventaire : Golds, potions, composants d'artisanat, pièces d'équipement spécifiques.

5. Activités des Joueurs Simulés (Quand Connectés)

Lorsqu'un joueur simulé est connecté, il peut participer aux activités suivantes :

    Leveling : Activité par défaut si le personnage n'est pas niveau 60. Fait gagner de l'expérience. Augmente légèrement l'Intégration.

    Donjons / Raids :

        Proposés par le vrai-joueur.

        Les joueurs acceptent/refusent selon leur humeur, énergie, planning, disponibilité du rôle, statut de reset du raid, Intégration, etc.

        Nécessitent une composition de groupe spécifique (voir section 8).

        Possibilité de compléter le groupe avec des "pick-ups" (joueurs externes temporaires) si nécessaire (principalement pour les donjons).

        Permettent d'améliorer l'équipement et la connaissance de l'instance.

        Augmentent significativement l'Intégration des participants en cas de succès.

    Farming :

        Activité principale une fois niveau 60 en dehors des raids/donjons.

        Objectif : Accumuler des golds, avec une très faible chance d'améliorer l'équipement.

        Diminue l'énergie et l'humeur. Augmente très légèrement l'Intégration.

    Activité Fun :

        Proposée par le vrai-joueur.

        Objectif : Augmenter l'humeur des participants.

        Aucune restriction de niveau, classe ou nombre de participants.

        Ne donne aucune récompense matérielle.

        Augmente fortement l'Intégration des participants.

6. Compétition

    Le vrai-joueur est en compétition avec 9 autres guildes simulées.

    Un pool de joueurs simulés (libres ou cherchant une guilde) est disponible pour le recrutement et se renouvelle.

7. Éléments Futurs / Simplifications Actuelles

    Simplification actuelle : L'équipement est une valeur numérique unique. (Futur: gestion par pièces d'équipement).

    Simplification actuelle : Classes limitées à Guerrier, Mage, Prêtre avec rôles fixes initiaux.

    Éléments futurs : Gestion détaillée de l'inventaire (golds, potions, artisanat), plus de classes/spécialisations (ex: Guerrier DPS), système d'artisanat, événements de guilde plus complexes, difficultés de donjon/raid (Normal/Héroïque), système de butin plus détaillé (pièces spécifiques), réputation de guilde, impact plus profond de l'Intégration (synergies, conflits).

8. Système de Donjons et Raids (Inspiration WoW)

    Types d'Instances :

        Donjons (Niveau < 60) : Instances à 5 joueurs (1 Tank, 1 Soigneur, 3 DPS). Constituent le contenu principal de progression en groupe avant le niveau maximum.

        Raids (Niveau 60+) : Instances de haut niveau conçues pour des groupes plus larges (ex: 10, 20 joueurs ou plus). Contiennent plus de boss, souvent plus difficiles.

            Réinitialisation (Reset) : Les raids ont une progression sauvegardée et se réinitialisent hebdomadairement (tous les 7 jours). Une guilde ne peut obtenir les récompenses d'un boss de raid qu'une fois par semaine.

            Progression sur plusieurs sessions : Un raid peut nécessiter plusieurs sessions de jeu pour être terminé.

    Composition de Groupe :

        Donjon (5 joueurs) : 1 Tank, 1 Soigneur, 3 DPS.

        Raid (ex: 10 joueurs) : Composition plus large (ex: 2 Tanks, 2-3 Soigneurs, 5-6 DPS). À définir par raid.

        Le vrai-joueur sélectionne les membres pour remplir les rôles requis.

        Le non-respect de la composition rend le lancement difficile ou impossible.

    Déroulement d'une Instance (Simulation) :

        Phase simulée, non jouée en temps réel.

        Calcul d'une "Performance Globale" basée sur les facteurs de succès.

        Division en étapes clés (trash mobs, boss). Performance évaluée par étape.

        Événements aléatoires possibles basés sur les tags des joueurs.

    Facteurs de Succès :

        Niveau d'Équipement moyen vs niveau requis.

        Skill individuel.

        Connaissance de l'Instance (boss et mécaniques).

        Énergie (initiale et consommation).

        Synergie de groupe (humeur mutuelle, compatibilité des tags, niveau d'Intégration moyen ? - à développer).

        Respect de la composition des rôles.

    Récompenses (Butin / Loot) :

        Timing : Après chaque boss vaincu, une chance d'obtenir une récompense d'équipement. La chance/qualité est meilleure sur le boss final de l'instance.

        Attribution (Guilde) : Pour chaque récompense d'équipement générée pour le groupe, le vrai-joueur choisit quel membre de la guilde présent la reçoit (sous forme d'une augmentation de sa valeur d'équipement pour le moment).

        Attribution (Pick-ups / PUGs) : Si des PUGs sont présents dans le groupe, il existe une chance prédéfinie que la récompense d'équipement leur soit automatiquement attribuée (via un "jet de dés" simulé), auquel cas le vrai-joueur ne peut pas choisir.

        Autres récompenses :

            Augmentation de la Connaissance de l'Instance pour les boss rencontrés/vaincus.

            Expérience (si non niveau 60, principalement dans les donjons).

            Augmentation de l'Humeur (variable selon succès et obtention de loot - attention aux greedy).

            Augmentation de l'Intégration (voir Section 5).

            (Futur) : Golds, composants, objets spécifiques.

    Échec ("Wipe") :

        Conséquences : Baisse Humeur/Énergie, conflits potentiels, pas de récompenses de boss, faible gain/perte de connaissance, peut légèrement nuire à l'Intégration.

        Abandon possible par le vrai-joueur (avec pénalités).

    Pick-ups (PUGs) :

        Utilisés principalement pour combler les donjons à 5. Moins courants/fiables pour les raids.

        Statistiques et comportement incertains.

        Peuvent recevoir du butin (voir "Récompenses"). N'ont pas de barre d'Intégration vis-à-vis de la guilde.

9. Système de Recrutement

    Le Pool de Recrutement :

        Une liste de joueurs simulés sans guilde ou cherchant à en changer est disponible.

        Cette liste est accessible via une interface dédiée ("Recherche de Guilde" / "Recrutement").

    Interface de Recrutement :

        Affiche les candidats disponibles avec des informations limitées.

        Permet de filtrer par classe, niveau, peut-être rôle.

        Bouton pour "Envoyer une invitation de guilde".

    Informations sur les Candidats (Visibles avant invitation) :

        Nom du Personnage

        Classe

        Niveau d'Expérience

        Niveau d'Équipement (la valeur numérique)

        Un ou deux Tags comportementaux (visibles, ex: cherche groupe donjon, ambitieux) pour donner une idée de ses motivations ou de son caractère.

        Potentiellement une indication vague de son planning (ex: joueur du soir, actif le week-end).

    Informations Cachées (Découvertes après recrutement via l'Intégration) :

        La valeur exacte de Skill (précision augmente avec l'Intégration).

        La liste complète des Tags (révélés progressivement avec l'Intégration).

        L'état exact de son Humeur / Énergie (visible une fois recruté).

        Sa Connaissance détaillée des instances (visible une fois recruté, progresse avec l'activité).

        Son Planning précis (précision augmente avec l'Intégration).

    Processus d'Invitation :

        Le vrai-joueur clique sur "Inviter" pour un candidat sélectionné.

        L'invitation est envoyée (simulation d'un message privé dans le jeu fictif).

    Acceptation / Refus des Candidats :

        Le candidat évalue l'offre. Sa décision dépend de :

            Réputation / Progression de la guilde : Une guilde qui réussit des raids ou qui est bien classée est plus attractive. (Système de réputation à développer).

            Adéquation des Objectifs : Le joueur est plus enclin à accepter si les activités récentes de la guilde (visibles publiquement, ex: "Guilde X a vaincu Boss Y") correspondent à ses tags visibles (ex: un joueur cherche raid rejoindra plus volontiers une guilde qui tombe des boss de raid).

            Composition de la Guilde : Peut refuser si la guilde a déjà trop de joueurs de sa classe/rôle.

            Tags/Personnalité : Certains tags peuvent influencer (un Loner préfèrera une petite guilde, un Social une grande).

            Facteur Aléatoire : Une part de hasard simulant les préférences personnelles.

    Intégration dans la Guilde :

        Si accepté, le joueur apparaît dans le roster de la guilde avec une barre d'Intégration basse.

        Le vrai-joueur a accès à ses informations de base (Humeur, Énergie, Connaissance actuelle). Les informations cachées (Tags, Skill précis, Planning précis) se débloquent avec l'augmentation de l'Intégration.

        Le joueur devient gérable (assignable aux activités, etc.).

    Renouvellement du Pool :

        La liste des candidats dans le pool se met à jour périodiquement (ex: chaque jour ou semaine dans le temps du jeu), avec de nouveaux joueurs qui apparaissent et d'autres qui trouvent une guilde (la vôtre ou une concurrente).