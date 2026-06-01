extends RefCounted

static func calculate_performance_score(success: bool, total_time: float, gold_reward: int, loot_count: int, run_details: Dictionary) -> int:
	var total_bosses: int = max(1, int(run_details.get("total_bosses", 1)))
	var bosses_defeated: int = clamp(int(run_details.get("bosses_defeated", 0)), 0, total_bosses)
	var wipes: int = max(0, int(run_details.get("wipes", 0)))
	var expected_duration: float = max(60.0, float(run_details.get("expected_duration_seconds", total_time)))
	
	var score: float = 20.0 + (float(bosses_defeated) / float(total_bosses)) * 45.0
	if success:
		score += 20.0
	score -= min(30.0, wipes * 7.0)
	
	if total_time > 0.0 and expected_duration > 0.0:
		var duration_ratio: float = total_time / expected_duration
		if duration_ratio <= 0.85:
			score += 10.0
		elif duration_ratio <= 1.1:
			score += 5.0
		elif duration_ratio > 1.4:
			score -= 10.0
	
	score += min(5.0, loot_count * 1.5)
	if gold_reward <= 0 and success:
		score -= 5.0
	
	return int(clamp(round(score), 0.0, 100.0))

static func get_performance_label(score: int) -> String:
	if score >= 85:
		return "excellent"
	if score >= 65:
		return "solide"
	if score >= 45:
		return "fragile"
	return "critique"
