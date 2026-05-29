## Accès dynamique aux autoloads depuis n'importe quel script, y compris les
## Resources (qui n'ont pas get_node).
##
## ⚠️ Les autoloads ne sont PAS des singletons moteur : Engine.get_singleton()
## ne les trouve jamais (retourne null + log d'erreur). On passe par la
## SceneTree. Le retour est volontairement non typé (Variant) pour préserver
## l'accès dynamique aux propriétés et éviter tout couplage de types cyclique.

static func get_autoload(autoload_name: String):
	var loop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("/root/" + autoload_name)
	return null
