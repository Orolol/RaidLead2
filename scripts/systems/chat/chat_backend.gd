extends RefCounted
## ChatBackend — interface (STUB) pour un futur backend de génération de répliques.
##
## Palier 3 (optionnel, opt-in) du design (docs/design §0, §12) : brancher un LLM
## *live* sur 2-3 grands moments (débrief post-raid, escalade de drama) SANS toucher
## au moteur par défaut.
##
## Aujourd'hui le ChatDirector utilise le backend "template" (scoring + corpus, 100%
## offline/déterministe). Pour ajouter un LLM live plus tard :
##   1. créer une sous-classe (ex. LLMBackend) qui implémente generate_reaction() ;
##   2. l'appeler de façon ASYNCHRONE avec repli template si indisponible/hors-ligne ;
##   3. la garder OPT-IN (clé API du joueur ou petit modèle local) — le build de base
##      reste offline et déterministe.
##
## Ce fichier est un stub documenté : il n'est PAS branché. Il fixe le contrat.

## Contexte fourni au backend : {kind, subject_name, speaker_name, vars, history...}.
## Retourne une réplique générée, ou "" pour signifier « utilise le template par défaut ».
func generate_reaction(_context: Dictionary) -> String:
	return ""

## Vrai si le backend est prêt (modèle chargé / clé API valide / en ligne).
func is_available() -> bool:
	return false
