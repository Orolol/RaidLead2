class_name GameLog

## Journalisation de debug : silencieuse en build release.
static func d(message: String) -> void:
	if OS.is_debug_build():
		print(message)
