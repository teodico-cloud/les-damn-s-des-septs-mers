extends GutHookScript
## Avant tous les tests : la sauvegarde va dans un fichier à part (jamais celle du jeu), repartie de zéro ; les réglages
## aussi (le bouton « Héros Meshy » les écrit : sinon un test laisserait les héros Meshy aux tests suivants).


func run() -> void:
	var s = gut.get_tree().root.get_node("Sauvegarde")
	s.chemin = "user://sauvegarde_tests.json"
	for suffixe in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(s.chemin + suffixe)
	s.reinitialiser()
	var r = gut.get_tree().root.get_node("Reglages")
	r.chemin = "user://reglages_tests.json"
	for suffixe in ["", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(r.chemin + suffixe))
	r.charger()
	r.appliquer()
