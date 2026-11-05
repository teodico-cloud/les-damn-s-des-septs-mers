extends Control
## Écran « Jouer à deux » (même Wi-Fi). Héberger : on choisit son héros, l'écran montre un code et
## attend le partenaire, puis l'hôte lance le combat. Rejoindre : les parties trouvées sur le Wi-Fi
## s'affichent ; sinon on tape le code de l'hôte. L'invité prend l'autre héros (héros différents).
## Refonte de l'interface (05/11) : derrière, le navire au ponton de l'écran titre, dans l'ombre ; au milieu, le
## rôle d'équipage sur un parchemin, sa plaque de titre qui déborde ; les choix en planches, le code sur cuir.

const SCENE_MENU := "res://ui/screens/demarrage.tscn"
const SCENE_CHOIX := "res://ui/screens/choix_heros.tscn"
const NOMS := {&"bretteur": "le Bretteur", &"occultiste": "l'Occultiste"}

enum Vue { ACCUEIL, ATTENTE_HOTE, RECHERCHE, CONNEXION, PRET_INVITE }

var vue := Vue.ACCUEIL
var changer_de_scene := true     ## faux dans les tests
var titre: Label
var message: Label
var zone: VBoxContainer          ## contenu qui change selon la vue
var bouton_lancer: Button       ## l'expédition
var bouton_arene: Button        ## l'arène d'entraînement
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
		message.text = "Code invalide : c'est le nombre affiché sur l'écran de l'hôte (1 à 254),\nou son adresse complète."
		return
	var err := Reseau.rejoindre(adresse)
	if err != OK:
		_on_echec("Connexion impossible (erreur %d)." % err)
		return
	_afficher(Vue.CONNEXION)


func rejoindre_par_code() -> void:
	rejoindre(Reseau.adresse_depuis_saisie(champ_code.text))


func lancer(destination: StringName = &"expedition") -> void:
	Reseau.lancer_combat(destination)


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
	if int(infos.get("v", -1)) != Reseau.VERSION_RESEAU:
		b.text = "Partie trouvée, mais autre version du jeu"
		b.disabled = true
	b.pressed.connect(rejoindre.bind(adresse))
	zone.add_child(b)
	zone.move_child(b, 0)
	_parties[adresse] = b


func _on_partenaire_connecte(infos: Dictionary) -> void:
	var h: StringName = infos.get("heros", &"")
	if Reseau.est_hote():
		message.text = "Ton partenaire est là : il joue %s." % NOMS.get(h, "?")
		bouton_lancer.disabled = false
		bouton_arene.disabled = false
	else:
		_afficher(Vue.PRET_INVITE)
		message.text = "Connecté ! Ton partenaire joue %s, tu joues %s.\nEn attente du lancement par l'hôte…" \
				% [NOMS.get(h, "?"), NOMS.get(Partie.heros_local, "?")]


func _on_partenaire_parti(raison: String) -> void:
	if Reseau.est_hote():
		message.text = raison + "\nEn attente d'un nouveau partenaire…"
		bouton_lancer.disabled = true
		bouton_arene.disabled = true
		Reseau.heberger(Partie.heros_local)   # on se ré-annonce
	else:
		_afficher(Vue.ACCUEIL)
		message.text = raison


func _on_echec(raison: String) -> void:
	_afficher(Vue.ACCUEIL)
	message.text = raison


func _on_combat_lance() -> void:
	if changer_de_scene:
		get_tree().change_scene_to_file(Partie.scene_destination())


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
			var choix := ChoixMalediction.new()   # l'hôte choisit la malédiction (envoyée au lancement)
			zone.add_child(choix)
			bouton_lancer = _bouton("Lancer l'expédition", 520)
			bouton_lancer.disabled = true
			bouton_lancer.pressed.connect(lancer.bind(&"expedition"))
			zone.add_child(bouton_lancer)
			bouton_arene = _bouton("Arène d'entraînement", 520)
			bouton_arene.disabled = true
			bouton_arene.pressed.connect(lancer.bind(&"arene"))
			zone.add_child(bouton_arene)
		Vue.RECHERCHE:
			titre.text = "Rejoindre une partie"
			message.text = "Recherche des parties sur le Wi-Fi…"
			var ligne := HBoxContainer.new()
			ligne.alignment = BoxContainer.ALIGNMENT_CENTER
			ligne.add_theme_constant_override("separation", 16)
			champ_code = LineEdit.new()
			champ_code.placeholder_text = "Code"
			champ_code.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL   # chiffres et point
			champ_code.custom_minimum_size = Vector2(240, 88)
			champ_code.add_theme_font_size_override("font_size", 40)
			champ_code.alignment = HORIZONTAL_ALIGNMENT_CENTER
			champ_code.max_length = 15   # (cuir cousu : le thème commun)
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
	add_child(DecorMenu.new())
	var ombre := ColorRect.new()
	ombre.color = Color(0.02, 0.015, 0.01, 0.6)
	ombre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ombre)
	# la plaque du titre déborde sur le haut du parchemin (séparation négative ; dessinée par-dessus)
	var bloc := VBoxContainer.new()
	bloc.set_anchors_preset(Control.PRESET_CENTER)
	bloc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bloc.grow_vertical = Control.GROW_DIRECTION_BOTH
	bloc.add_theme_constant_override("separation", -22)
	add_child(bloc)
	var plaque := PanelContainer.new()
	plaque.theme_type_variation = &"PanelPlaque"
	plaque.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	plaque.z_index = 1
	bloc.add_child(plaque)
	titre = Label.new()
	titre.theme_type_variation = &"LabelTitre"
	titre.add_theme_font_size_override("font_size", 40)
	plaque.add_child(titre)
	var feuille := PanelContainer.new()
	feuille.theme_type_variation = &"PanelParchemin"
	feuille.custom_minimum_size = Vector2(880, 0)
	bloc.add_child(feuille)
	var colonne := VBoxContainer.new()
	colonne.alignment = BoxContainer.ALIGNMENT_CENTER
	colonne.add_theme_constant_override("separation", 18)
	feuille.add_child(colonne)
	message = Label.new()
	message.theme_type_variation = &"LabelEncre"
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 26)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size = Vector2(740, 0)
	colonne.add_child(message)
	colonne.add_child(StyleRepaire.separateur(320.0))
	var centre := CenterContainer.new()
	colonne.add_child(centre)
	zone = VBoxContainer.new()
	zone.add_theme_constant_override("separation", 14)
	centre.add_child(zone)
	var retour_b := Button.new()
	retour_b.text = "Retour"
	retour_b.theme_type_variation = &"BoutonPetit"
	retour_b.custom_minimum_size = Vector2(150, 60)
	retour_b.position = Vector2(22, 18)
	retour_b.pressed.connect(retour)
	add_child(retour_b)
	EffetsUI.animer_bouton(retour_b)
	EffetsUI.voile(self)


func _label(taille: int, couleur: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	return l


func _bouton(texte: String, largeur: float) -> Button:
	var b := Button.new()
	b.text = texte
	b.custom_minimum_size = Vector2(largeur, 86)
	b.add_theme_font_size_override("font_size", 32)
	EffetsUI.animer_bouton(b)
	return b
