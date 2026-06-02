extends Node
## Soak / aperçu textuel du chat vivant (Phase E).
##
## Lance en headless :
##   Godot ... --headless --path . res://tests/ChatSoak.tscn
##
## Met en place un roster varié en ligne, génère un flux de banter + des réactions,
## joue les scènes en mode synchrone, et imprime un transcript + des stats (variété,
## locuteurs actifs). Sert à juger le *feeling* du chat sans GUI. Déterministe (seed).

func _ready() -> void:
	await get_tree().process_frame
	_run()
	get_tree().quit(0)

func _run() -> void:
	GameRandom.seed_rng(424242)

	var traits_pool: Array = [
		["social"], ["drama_queen"], ["solitaire"], ["perfectionniste"], ["tryhard"],
		["serviable"], ["casual"], ["rage_quitter"], [], ["greedy"]
	]
	var classes: Array = ["Mage", "Guerrier", "Prêtre"]
	var added: Array = []
	for i in range(10):
		var p := SimulatedPlayer.new()
		p.nom = "Soak%02d" % i
		p.player_id = "soak_%d" % i
		p.is_online = true
		p.mood = clampf(45.0 + i * 5.0, 30.0, 95.0)
		p.personnage_classe = classes[i % classes.size()]
		p.tags_comportement = traits_pool[i % traits_pool.size()]
		GuildManager.guild_members.append(p)
		added.append(p)

	var transcript: Array = []
	var cb: Callable = func(speaker, text, _c): transcript.append([speaker, text])
	ChatDirector.line_emitted.connect(cb)

	# Flux de one-liners (ambient) + réactions ponctuelles.
	ChatDirector.scenes_enabled = false
	for i in range(60):
		ChatDirector.debug_force_ambient()
		if i == 20:
			ChatDirector.debug_force_reactive("level_up", added[3], {"subject": added[3].nom, "lvl": "60"}, 1.0)
		elif i == 35:
			ChatDirector.debug_force_reactive("loot_epic", added[1], {"subject": added[1].nom, "item": "Lame Bénie de Tonnerre"}, 0.9)
		elif i == 50:
			ChatDirector.debug_force_reactive("wipe", null, {"boss": "Onyxia", "wipes": "4"}, 0.75)
	ChatDirector.scenes_enabled = true
	ChatDirector.line_emitted.disconnect(cb)

	# Stats
	var n: int = transcript.size()
	var distinct: Dictionary = {}
	var speakers: Dictionary = {}
	for e in transcript:
		distinct[e[1]] = true
		speakers[e[0]] = int(speakers.get(e[0], 0)) + 1

	print("\n========== CHAT SOAK — APERÇU DU CHAT VIVANT ==========")
	print("Émissions (one-liner + réactif) : %d" % n)
	print("Répliques distinctes : %d (%.0f%%)" % [distinct.size(), 100.0 * distinct.size() / float(maxi(1, n))])
	print("Locuteurs actifs : %d / %d membres" % [speakers.size(), added.size()])
	print("\n--- Transcript (50 premières lignes) ---")
	for i in range(mini(50, n)):
		print("  %s: %s" % [transcript[i][0], transcript[i][1]])

	print("\n--- Scènes (jeu synchrone, branches résolues par traits) ---")
	var scene_specs: Array = [
		["rickroll", null, {}],
		["duel_bank", null, {}],
		["blame_pull", null, {"boss": "Ragnaros"}],
		["tribunal_ninja", null, {"item": "Lame Bénie de Tonnerre"}],
		["mankrik_gag", null, {}],
		["worldbuff_panic", null, {}],
		["recruit_haze", added[5], {}]
	]
	for spec in scene_specs:
		var sc_transcript: Array = ChatDirector.debug_play_scene_sync(spec[0], spec[1], spec[2])
		print("  [%s]" % spec[0])
		for line in sc_transcript:
			print("    %s: %s" % [line[0], line[1]])

	for p in added:
		GuildManager.guild_members.erase(p)
	GameRandom.randomize_rng()
	print("=======================================================")
