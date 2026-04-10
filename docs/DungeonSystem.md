# Système de Donjons

## Vue d'ensemble

Le système de donjons est un élément central du gameplay où les groupes de joueurs progressent à travers des défis PvE. Chaque donjon offre une expérience unique avec sa propre difficulté, durée et récompenses.

## Structure d'un Donjon

### Propriétés principales
- **Difficulté** : Niveau de défi du donjon (échelle à définir)
- **Durée** : Temps estimé pour compléter le donjon
- **Récompense en or** : Or distribué à la fin du donjon
- **Boss** : Série de boss à vaincre séquentiellement

### Système de Boss
- Chaque donjon contient plusieurs boss
- Tous les boss ont la même difficulté que le donjon
- Le boss final a une difficulté légèrement supérieure
- Chaque boss vaincu donne aléatoirement un bonus d'équipement à un membre du groupe

## Interface de Donjon

### Visualisation
- **Gauche** : Points représentant les personnages du groupe
- **Centre** : Chemin horizontal vers la droite
- **Droite** : Gros points représentant les boss

### Animation
- Les points des personnages se déplacent vers la droite au fil du temps
- La progression est visuellement liée au temps qui passe

## Mécanique de Combat

### Rencontre avec un Boss
1. Le groupe arrive sur la position du boss
2. Calcul automatique pour déterminer la victoire ou l'échec
3. **En cas de victoire** :
   - Le boss est vaincu
   - Distribution aléatoire d'un bonus d'équipement
   - Progression vers le boss suivant
4. **En cas d'échec** :
   - Perte de temps (pénalité temporelle)
   - Perte de moral pour le groupe
   - Le groupe recommence le combat contre ce boss

### Facteurs de Réussite
Les calculs de réussite prendront en compte :
- Niveau des personnages
- Composition du groupe (tanks, healers, DPS)
- Compétences des joueurs
- Moral du groupe
- Équipement (dans les versions futures)

## Récompenses

### Pendant le Donjon
- Bonus d'équipement aléatoire après chaque boss
- Distribution équitable entre les membres du groupe

### Fin du Donjon
- Récompense en or distribuée à tous les participants
- Potentiellement d'autres récompenses (réputation, objets spéciaux)

## Évolutions Futures

### Système d'Équipement
- Gestion complète de l'équipement des personnages
- Impact de l'équipement sur les chances de réussite
- Système de loot plus complexe

### Mécaniques Avancées
- Boss avec des mécaniques spécifiques
- Événements aléatoires pendant la progression
- Choix de chemins multiples dans certains donjons