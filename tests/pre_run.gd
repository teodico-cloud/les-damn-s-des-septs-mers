extends GutHookScript
## Avant tous les tests : la sauvegarde va dans un fichier à part (jamais celle du jeu), repartie de zéro.


func run() -> void:
	var s = gut.get_tree().root.get_node("Sauvegarde")
	s.chemin = "user://sauvegarde_tests.json"
	for suffixe in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(s.chemin + suffixe)
	s.reinitialiser()
