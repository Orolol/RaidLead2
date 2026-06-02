extends Node

## Gere les transferts internationaux (Phase Esport, US 4.4).
## Un pool mondial de joueurs d'elite (regions, agents, gros salaires) n'est
## recrutable que pendant les fenetres de transfert. La negociation reprend le
## modele national (acceptation / contre-proposition / refus) avec en plus une
## prime de transfert et une adaptation culturelle a l'arrivee.

signal transfer_window_opened()
signal transfer_window_closed()
signal transfer_completed(player)

const POOL_SIZE := 7
const TRANSFER_FEE_WEEKS := 4   # prime de transfert = 4 semaines de salaire
const ADAPTATION_WEEKS := 4

const REGIONS := ["Europe", "Amérique du Nord", "Corée", "Chine", "Océanie", "Amérique du Sud"]
const MOTIVATIONS := [
	"Veut rejoindre une organisation de classe mondiale",
	"Cherche un nouveau défi à l'international",
	"Ambitionne de remporter le Championnat du Monde",
	"Souhaite évoluer dans une structure professionnelle",
	"Attiré par le prestige de la guilde",
]

var international_pool: Array = []   # Array[SimulatedPlayer]
var transfer_window_open: bool = false

func _ready() -> void:
	if GameTime and GameTime.has_signal("week_changed"):
		GameTime.week_changed.connect(_on_week_changed)
	transfer_window_open = _is_window_week(GameTime.current_week) if GameTime else false
	_refresh_pool()

func _on_week_changed(week: int, _year: int) -> void:
	var was_open: bool = transfer_window_open
	transfer_window_open = _is_window_week(week)
	if transfer_window_open and not was_open:
		_refresh_pool()
		transfer_window_opened.emit()
	elif was_open and not transfer_window_open:
		transfer_window_closed.emit()
	_tick_adaptation()

func _is_window_week(week: int) -> bool:
	"""Deux fenetres de transfert par an : debut et milieu de saison."""
	return (week >= 1 and week <= 4) or (week >= 26 and week <= 29)

func weeks_until_window() -> int:
	"""Nombre de semaines avant la prochaine ouverture (0 si ouverte)."""
	if transfer_window_open or not GameTime:
		return 0
	var w: int = GameTime.current_week
	for offset in range(1, 53):
		if _is_window_week(((w - 1 + offset) % 52) + 1):
			return offset
	return 0

# --- Pool ---

func _refresh_pool() -> void:
	international_pool.clear()
	for i in range(POOL_SIZE):
		international_pool.append(_generate_international_player())

func get_pool() -> Array:
	return international_pool

func _generate_international_player() -> SimulatedPlayer:
	var p := SimulatedPlayer.new()
	p.personnage_niveau = 60
	p.skill = randi_range(78, 98)
	p.salary_demand = randi_range(400, 1500)
	p.set_meta("region", REGIONS[randi() % REGIONS.size()])
	p.set_meta("is_international_prospect", true)
	if randf() < 0.8:
		p.set_meta("has_agent", true)
		p.set_meta("agent_commission", p.salary_demand * 3)
	else:
		p.set_meta("has_agent", false)
		p.set_meta("agent_commission", 0)
	p.set_meta("recruitment_motivation", MOTIVATIONS[randi() % MOTIVATIONS.size()])
	return p

# --- Negociation ---

func _transfer_fee(player, salary: int) -> int:
	var fee: int = salary * TRANSFER_FEE_WEEKS
	if player.get_meta("has_agent", false):
		fee += player.get_meta("agent_commission", 0)
	return fee

func get_transfer_fee(player, salary: int) -> int:
	return _transfer_fee(player, salary)

func make_offer(player, offered_salary: int) -> Dictionary:
	"""Tente un transfert. Retourne un dict avec 'step' : accepted / counter / rejected / closed / error."""
	if not transfer_window_open:
		return {"success": false, "step": "closed", "reason": "Fenêtre de transfert fermée"}
	if player not in international_pool:
		return {"success": false, "step": "error", "reason": "Joueur non disponible"}

	var demand: int = player.salary_demand
	var ratio: float = float(offered_salary) / float(maxi(1, demand))

	if ratio >= 1.0:
		return _try_finalize(player, offered_salary)
	elif ratio >= 0.7:
		var counter: int = int(demand * randf_range(0.9, 1.1))
		return {"success": false, "step": "counter", "counter_offer": counter,
			"reason": "L'agent demande %d or/sem" % counter}
	else:
		return {"success": false, "step": "rejected",
			"reason": "Offre insuffisante (%d/%d or/sem)" % [offered_salary, demand]}

func accept_counter(player, salary: int) -> Dictionary:
	"""Accepte la contre-proposition de l'agent."""
	if not transfer_window_open:
		return {"success": false, "step": "closed", "reason": "Fenêtre de transfert fermée"}
	if player not in international_pool:
		return {"success": false, "step": "error", "reason": "Joueur non disponible"}
	return _try_finalize(player, salary)

func _try_finalize(player, salary: int) -> Dictionary:
	var fee: int = _transfer_fee(player, salary)
	if not GuildManager.guild or GuildManager.guild.gold < fee:
		return {"success": false, "step": "error",
			"reason": "Prime de transfert inabordable (%d or requis)" % fee}
	GuildManager.guild.spend_gold(fee)
	if not _complete_transfer(player, salary):
		GuildManager.guild.add_gold(fee)  # remboursement si effectif complet
		return {"success": false, "step": "error", "reason": "Effectif complet"}
	return {"success": true, "step": "accepted", "player": player, "salary": salary, "fee": fee}

func _complete_transfer(player, salary: int) -> bool:
	player.set_meta("salary", salary)
	player.set_meta("is_international", true)
	player.set_meta("adaptation_weeks", ADAPTATION_WEEKS)
	if player.has_meta("is_international_prospect"):
		player.remove_meta("is_international_prospect")
	if not GuildManager.add_member(player):
		return false
	international_pool.erase(player)
	# Adaptation culturelle : moral reduit a l'arrivee
	player.update_mood(-10.0)
	transfer_completed.emit(player)
	return true

func _tick_adaptation() -> void:
	"""Fait progresser l'adaptation culturelle des recrues internationales."""
	for member in GuildManager.guild_members:
		var weeks: int = member.get_meta("adaptation_weeks", 0)
		if weeks > 0:
			weeks -= 1
			if weeks <= 0:
				member.remove_meta("adaptation_weeks")
				member.update_mood(8.0)  # pleinement adapte
				member.update_integration(10.0)
			else:
				member.set_meta("adaptation_weeks", weeks)

# --- Sauvegarde (pool ephemere, regenere) ---

func serialize() -> Dictionary:
	return {"transfer_window_open": transfer_window_open}

func deserialize(data: Dictionary) -> void:
	transfer_window_open = data.get("transfer_window_open", false)
	if international_pool.is_empty():
		_refresh_pool()
