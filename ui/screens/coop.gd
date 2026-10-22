extends Control
## Écran « Jouer à deux » (même Wi-Fi). Héberger : on choisit son héros, l'écran montre un code et
## attend le partenaire, puis l'hôte lance le combat. Rejoindre : les parties trouvées sur le Wi-Fi
## s'affichent ; sinon on tape le code de l'hôte. L'invité prend l'autre héros (héros différents).

const SCENE_MENU := "res://ui/screens/demarrage.tscn"
const SCENE_CHOIX := "res://ui/screens/choix_heros.tscn"
const SCENE_ARENE := "res://game/arene/arene.tscn"
const COULEUR_OS := Color("e2d6ba")
const COULEUR_OR := Color("ac8036")
const NOMS := {&"bretteur": "le Bretteur", &"occultiste": "l'Occultiste"}

enum Vue { ACCUEIL, ATTENTE_HOTE, RECHERCHE, CONNEXION, PRET_INVITE }

var vue := Vue.ACCUEIL
var changer_de_scene := true     ## faux dans les tests
var titre: Label
var message: Label
var zone: VBoxContainer          ## contenu qui change selon la vue
var bouton_lancer: Button
var champ_code: LineEdit
var _parties := {}               ## adresse -> bouton


func _ready() -> void:
	get_tree().set_quit_on_go_back(false)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_construire()
	Reseau.partie_trouvee.connect(_on_partie_trouvee)
	Reseau.partenaire_connecte.connect(_on_partenaire_connecte)
	Reseau.partenaire_parti.connect(_on_partenaire_parti)
	Reseau.echec.connect(_on_echec)
	Reseau.combat_lance.connect(_on_combat_lance)
	# retour du choix du héros de l'hôte : on héberge tout de suite
	if Partie.mode == Partie.Mode.HOTE and not Reseau.est_hote():
		heberger()
	else:
		_afficher(Vue.ACCUEIL)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		retour()


# ---------------------------------------------------------------- actions
func choisir_heberger() -> void:
	Partie.mode = Partie.Mode.HOTE
	if changer_de_scene:
		get_tree().change_scene_to_file(SCENE_CHOIX)   # le choix du héros revient ici


func heberger() -> void:
	var err := Reseau.heberger(Partie.heros_local)
	if err != OK:
		_on_echec("Impossible d'héberger la partie (erreur %d)." % err)
		return
	_afficher(Vue.ATTENTE_HOTE)


func choisir_rejoindre() -> void:
	Partie.mode = Partie.Mode.INVITE
	var err := Reseau.chercher()
	_afficher(Vue.RECHERCHE)
	if err != OK:
		message.text = "Recherche automatique impossible ici : tape le code de l'hôte."


func rejoindre(adresse: String) -> void:
	if adresse == "":
		message.text = "Code invalide : c'est le nombre affiché sur l'écran de l'hôte (1 à 254)."
		return
	var err := Reseau.rejoindre(adresse)
	if err != OK:
		_on_echec("Connexion impossible (erreur %d)." % err)
		return
	_afficher(Vue.CONNEXION)


func rejoindre_par_code() -> void:
	rejoindre(Reseau.adresse_depuis_code(int(champ_code.text)))


func lancer() -> void:
	Reseau.lancer_combat()


func retour() -> void:
	Reseau.quitter()
	Partie.mode = Partie.Mode.SOLO
	if changer_de_scene:
		get_tree().change_scene_to_file(SCENE_MENU)


# ---------------------------------------------------------------- réactions au réseau
func _on_partie_trouvee(adresse: String, infos: Dictionary) -> void:
	if vue != Vue.RECHERCHE or _parties.has(adresse):
		return
	var heros_hote := StringName(infos.get("heros", ""))
	var b := _bouton("Partie trouvée — l'hôte joue %s" % NOMS.get(heros_hote, "?"), 560)
	b.pressed.connect(rejoindre.bind(adresse))
	zone.add_child(b)
	zone.move_child(b, 0)
	_parties[adresse] = b


func _on_partenaire_connecte(infos: Dictionary) -> void:
	var h: StringName = infos.get("heros", &"")
	if Reseau.est_hote():
		message.text = "Ton partenaire est là : il joue %s." % NOMS.get(h, "?")
		bouton_lancer.disabled = false
	else:
		_afficher(Vue.PRET_INVITE)
		message.text = "Connecté ! Ton partenaire joue %s, tu joues %s.\nEn attente du lancement par l'hôte…" \
				% [NOMS.get(h, "?"), NOMS.get(Partie.heros_local, "?")]


func _on_partenaire_parti(raison: String) -> void:
	if Reseau.est_hote():
		message.text = raison + "\nEn attente d'un nouveau partenaire…"
		bouton_lancer.disabled = true
		Reseau.heberger(Partie.heros_local)   # on se ré-annonce
	else:
		_afficher(Vue.ACCUEIL)
		message.text = raison


func _on_echec(raison: String) -> void:
	_afficher(Vue.ACCUEIL)
	message.text = raison


func _on_combat_lance() -> void:
	if changer_de_scene:
		get_tree().change_scene_to_file(SCENE_ARENE)


# ---------------------------------------------------------------- affichage
func _afficher(v: Vue) -> void:
	vue = v
	for c in zone.get_children():
		c.queue_free()
	_parties.clear()
	message.text = ""
	match v:
		Vue.ACCUEIL:
			titre.text = "Jouer à deux"
			message.text = "Les deux téléphones doivent être sur le même Wi-Fi."
			var h := _bouton("Héberger la partie", 520)
			h.pressed.connect(choisir_heberger)
			zone.add_child(h)
			var r := _bouton("Rejoindre une partie", 520)
			r.pressed.connect(choisir_rejoindre)
			zone.add_child(r)
		Vue.ATTENTE_HOTE:
			var code := Reseau.code_local()
			titre.text = "Tu héberges — code %d" % code if code > 0 else "Tu héberges"
			message.text = "Tu joues %s. En attente de ton partenaire…\n" % NOMS.get(Partie.heros_local, "?")
			message.text += "S'il ne voit pas ta partie, il tape le code %d." % code if code > 0 \
					else "Aucun Wi-Fi détecté : vérifie que le téléphone y est connecté."
			bouton_lancer = _bouton("Lancer le combat", 520)
			bouton_lancer.disabled = true
			bouton_lancer.pressed.connect(lancer)
			zone.add_child(bouton_lancer)
		Vue.RECHERCHE:
			titre.text = "Rejoindre une partie"
			message.text = "Recherche des parties sur le Wi-Fi…"
			var ligne := HBoxContainer.new()
			ligne.alignment = BoxContainer.ALIGNMENT_CENTER
			ligne.add_theme_constant_override("separation", 16)
			champ_code = LineEdit.new()
			champ_code.placeholder_text = "Code"
			champ_code.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
			champ_code.custom_minimum_size = Vector2(200, 90)
			champ_code.add_theme_font_size_override("font_size", 40)
			champ_code.alignment = HORIZONTAL_ALIGNMENT_CENTER
			champ_code.max_length = 3
			for etat in ["normal", "focus"]:
				var st := StyleBoxFlat.new()
				st.bg_color = Color("1a120d")
				st.border_color = COULEUR_OR
				st.set_border_width_all(3 if etat == "normal" else 5)
				st.set_corner_radius_all(14)
				champ_code.add_theme_stylebox_override(etat, st)
			champ_code.add_theme_color_override("font_color", COULEUR_OS)
			ligne.add_child(champ_code)
			var ok := _bouton("Rejoindre", 300)
			ok.pressed.connect(rejoindre_par_code)
			ligne.add_child(ok)
			zone.add_child(ligne)
		Vue.CONNEXION:
			titre.text = "Connexion…"
			message.text = "Connexion à l'autre téléphone…"
		Vue.PRET_INVITE:
			titre.text = "Prêt !"


func _construire() -> void:
	var fond := ColorRect.new()
	fond.color = Color("0b1418")
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)
	var colonne := VBoxContainer.new()
	colonne.set_anchors_preset(Control.PRESET_FULL_RECT)
	colonne.alignment = BoxContainer.ALIGNMENT_CENTER
	colonne.add_theme_constant_override("separation", 26)
	add_child(colonne)
	titre = _label(54, COULEUR_OS)
	colonne.add_child(titre)
	message = _label(28, Color("6cffa0"))
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	colonne.add_child(message)
	var centre := CenterContainer.new()
	colonne.add_child(centre)
	zone = VBoxContainer.new()
	zone.add_theme_constant_override("separation", 18)
	centre.add_child(zone)
	var retour_b := _bouton("Retour", 170)
	retour_b.custom_minimum_size.y = 76
	retour_b.position = Vector2(24, 18)
	retour_b.pressed.connect(retour)
	add_child(retour_b)


func _label(taille: int, couleur: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	return l


func _bouton(texte: String, largeur: float) -> Button:
	var b := Button.new()
	b.text = texte
	b.custom_minimum_size = Vector2(largeur, 100)
	b.add_theme_font_size_override("font_size", 34)
	b.add_theme_color_override("font_color", COULEUR_OS)
	for etat in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = {"normal": Color("3a2a20"), "hover": Color("4a3628"), "pressed": Color("24190f"),
				"focus": Color("3a2a20"), "disabled": Color("231a14")}[etat]
		s.border_color = COULEUR_OR if etat != "disabled" else Color(COULEUR_OR, 0.35)
		s.set_border_width_all(4)
		s.set_corner_radius_all(14)
		b.add_theme_stylebox_override(etat, s)
	return b
