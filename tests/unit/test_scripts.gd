extends GutTest
## Charge chaque script du jeu : une erreur de syntaxe ou un identifiant inconnu fait échouer ce test
## (et la fabrication de l'APK). Remplace la vérification « --check-only », qui ne connaît pas les
## services globaux (EventBus) et signalait donc de fausses erreurs.

const DOSSIERS := ["res://autoload", "res://core", "res://game", "res://ui"]


func _scripts(dossier: String, acc: Array[String]) -> void:
	var d := DirAccess.open(dossier)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			acc.append(dossier.path_join(f))
	for sous in d.get_directories():
		_scripts(dossier.path_join(sous), acc)


func test_tous_les_scripts_du_jeu_se_chargent() -> void:
	var tous: Array[String] = []
	for d in DOSSIERS:
		_scripts(d, tous)
	assert_gt(tous.size(), 10, "Les scripts du jeu doivent être trouvés")
	for chemin in tous:
		var s = load(chemin)
		assert_not_null(s, "Script illisible : %s" % chemin)
		if s:
			assert_true(s.can_instantiate(), "Script en erreur : %s" % chemin)
