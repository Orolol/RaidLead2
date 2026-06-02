class_name TestFramework
extends RefCounted

## Framework de test léger (Milestone 6, US 6.5) — sans dépendance externe.
## Enregistre les assertions et produit un rapport PASS/FAIL.

var passed: int = 0
var failed: int = 0
var failures: Array[String] = []
var _suite: String = ""

func suite(suite_name: String) -> void:
	_suite = suite_name

func _record(is_ok: bool, message: String) -> void:
	if is_ok:
		passed += 1
	else:
		failed += 1
		failures.append("[%s] %s" % [_suite, message])

func ok(condition: bool, message: String) -> void:
	_record(condition, message)

func eq(actual, expected, message: String) -> void:
	_record(actual == expected, "%s (attendu %s, obtenu %s)" % [message, str(expected), str(actual)])

func approx(actual: float, expected: float, message: String, tol: float = 0.001) -> void:
	_record(absf(actual - expected) <= tol, "%s (attendu ~%.4f, obtenu %.4f)" % [message, expected, actual])

func between(actual: float, lo: float, hi: float, message: String) -> void:
	_record(actual >= lo and actual <= hi, "%s (%.4f hors [%.2f, %.2f])" % [message, actual, lo, hi])

func summary() -> String:
	var lines: Array[String] = []
	for f in failures:
		lines.append("  FAIL %s" % f)
	lines.append("TESTS : %d total | %d réussis | %d échoués" % [passed + failed, passed, failed])
	return "\n".join(lines)
