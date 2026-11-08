class_name PanneauCommentJouer
extends PanneauRepaire
## « Comment jouer » (jalon 6, écrans restants ; choix de Téo du 08/11 : ouvert depuis l'écran titre seulement, jamais
## tout seul). Le même parchemin que les Réglages, en six onglets : gestes, Bretteur, Occultiste, expédition, repaire,
## à deux. Chaque ligne : un bouton du jeu (le vrai dessin du HUD, BoutonAction) ou une porte, un titre, deux lignes.
## Les noms et dessins des boutons viennent des héros eux-mêmes (`noms_boutons`, `icones_boutons`) et les nombres de
## l'équilibrage : si un réglage change, le texte suit.

const EQ: Equilibrage = preload("res://data/equilibrage.tres")
const ONGLETS: Array[StringName] = [&"gestes", &"bretteur", &"occultiste", &"expedition", &"repaire", &"deux"]
const NOMS_ONGLETS := {
	&"gestes": "Gestes", &"bretteur": "Bretteur", &"occultiste": "Occultiste",
	&"expedition": "Expédition", &"repaire": "Repaire", &"deux": "À deux",
}
const ICONES := "res://assets/ui/icones/"
const PORTES := "res://assets/ui/portes/"
const RAYON_DESSIN := 40.0   ## rayon des boutons dessinés dans la marge (le HUD les fait de 60 à 80)

var onglet: StringName = &"gestes"
var boutons_onglets := {}    ## onglet -> Button
var lignes: Array = []       ## lignes affichées : [dessin (Texture2D ou null), titre, texte] (pour les tests)
var _heros := {}             ## archétype -> {"noms": {…}, "icones": {…}}


func _init() -> void:
	titre = "Comment jouer"
	marge_x = 120.0
	marge_haut = 86.0
	marge_bas = 40.0
	for a in [&"bretteur", &"occultiste"]:
		var h := Heros.creer(a)   # (pas dans l'arbre : seulement pour lire ses boutons)
		_heros[a] = {"noms": h.noms_boutons(), "icones": h.icones_boutons()}
		h.free()


func choisir_onglet(o: StringName) -> void:
	onglet = o
	rafraichir()


func _remplir() -> void:
	lignes.clear()
	boutons_onglets.clear()
	# (deux rangées de trois : six onglets sur une seule rangée débordaient du parchemin sur un écran 16/9)
	var rangee := GridContainer.new()
	rangee.columns = 3
	rangee.add_theme_constant_override("h_separation", 12)
	rangee.add_theme_constant_override("v_separation", 8)
	contenu.add_child(rangee)
	for o in ONGLETS:
		var b := StyleRepaire.bouton(NOMS_ONGLETS[o], Vector2(290, 52), 24)
		b.theme_type_variation = &"BoutonOngletActif" if o == onglet else &"BoutonOnglet"
		b.pressed.connect(choisir_onglet.bind(o))
		rangee.add_child(b)
		boutons_onglets[o] = b
	for l in page(onglet):
		_ligne(l[0], l[1], l[2])


## Les lignes d'un onglet : [dessin, titre, texte] ; le dessin est une Texture2D (bouton du HUD, porte) ou null.
func page(o: StringName) -> Array:
	match o:
		&"gestes":
			return [
				[null, "Se déplacer", "Pose le pouce sur la moitié gauche de l'écran : le joystick apparaît sous ton pouce."],
				[_icone(&"bretteur", &"attaque"), "Attaquer",
					"Garde le doigt sur Attaque : ton héros frappe sans s'arrêter. Il vise tout seul le squelette le plus proche, ou "
					+ "celui vers lequel tu pousses le joystick."],
				[_icone(&"bretteur", &"esquive"), "Esquiver",
					"Roulade ou Téléport : pendant le saut, aucun coup ne te touche."],
				[null, "Compétences", "Les deux autres boutons. Un chiffre sur un bouton : les secondes avant de pouvoir le relancer."],
				[null, "Le globe", "À droite, au-dessus des boutons : ta jauge (Fureur ou Âmes). Tes coups la remplissent, "
					+ "certaines compétences la dépensent ; un bouton sombre manque de jauge. Hors combat, elle baisse doucement."],
				[null, "Zone rouge au sol", "Un squelette va frapper là : sors-en, ou pare. Quand elle devient dorée, c'est le "
					+ "moment de la parade parfaite."],
				[null, "Orbes de vie", "Les squelettes vaincus en lâchent parfois : passe dessus pour te soigner (%d %% de tes PV)."
					% roundi(EQ.orbe_soin * 100.0)],
				[null, "S'entraîner", "« Combat d'entraînement » : des squelettes sans fin, rien à perdre."],
			]
		&"bretteur":
			return [
				[null, "Le Bretteur", "Au corps-à-corps, solide. Sa jauge : la Fureur, rouge sang."],
				[_icone(&"bretteur", &"attaque"), _nom(&"bretteur", &"attaque"),
					"Trois coups : deux taillades, puis un moulinet qui touche tout autour. Il bondit sur le squelette visé."],
				[_icone(&"bretteur", &"esquive"), _nom(&"bretteur", &"esquive"), "Un saut rapide qui traverse les squelettes."],
				[_icone(&"bretteur", &"competence_1"), _nom(&"bretteur", &"competence_1"),
					"Pare un coup de face, puis riposte et étourdit. Parée quand la zone devient dorée : parade parfaite, riposte "
					+ "critique et Parade aussitôt prête. Elle renvoie aussi les carreaux d'arbalète."],
				[_icone(&"bretteur", &"competence_2"), _nom(&"bretteur", &"competence_2"),
					"Une ruée droit devant qui traverse et blesse tout sur son passage. Coûte %d de Fureur." % roundi(EQ.fente_cout)],
				[null, "La Fureur", "Elle monte à chaque squelette touché, et beaucoup avec une parade parfaite."],
			]
		&"occultiste":
			return [
				[null, "L'Occultiste", "À distance, fragile : reste loin. Sa jauge : les Âmes, vert maudit."],
				[_icone(&"occultiste", &"attaque"), _nom(&"occultiste", &"attaque"),
					"Un projectile maudit, en continu tant que tu gardes le doigt. Il file vers sa cible et explose sur ses voisins."],
				[_icone(&"occultiste", &"esquive"), _nom(&"occultiste", &"esquive"),
					"Un saut court, %d fois de suite ; ensuite, attendre que les charges reviennent." % EQ.occ_tele_charges],
				[_icone(&"occultiste", &"competence_1"), _nom(&"occultiste", &"competence_1"),
					"Marque un squelette : ton partenaire lui fait +%d %% de dégâts, toi +%d %%."
					% [roundi(EQ.occ_marque_bonus_partenaire * 100.0), roundi(EQ.occ_marque_bonus_soi * 100.0)]],
				[_icone(&"occultiste", &"competence_2"), _nom(&"occultiste", &"competence_2"),
					"Immobilisent les squelettes d'une zone pendant %s s. Coûtent %d Âmes." % [_nombre(EQ.occ_chaines_duree),
					roundi(EQ.occ_chaines_cout)]],
				[null, "Les Âmes", "Elles montent à chaque squelette touché par un tir ou son explosion."],
			]
		&"expedition":
			return [
				[null, "Partir", "Au repaire, la Salle des cartes : ton héros, la malédiction, puis « Lever l'ancre ! »."],
				[_porte("combat"), "Une salle", "Vaincs tous ses squelettes : les portes s'ouvrent. Place-toi devant celle de ton choix."],
				[_porte("tresor"), "Trésor", "Un coffre qui soigne et donne des objets."],
				[_porte("piege"), "Piège", "Dalles à pics et tonneaux de poudre : un tonneau frappé explose et blesse les "
					+ "squelettes autour."],
				[_porte("bosco"), "Le Bosco Maudit", "Après %d salles, son antre. Son coup au sol se pare ; son tourbillon et sa "
					% EQ.exp_nb_salles + "charge s'esquivent (contre un mur, il reste sonné)."],
				[_porte("chaloupe"), "La chaloupe", "Pour rentrer : monte à bord et tiens %d s (moins avec de meilleures voiles) "
					% roundi(EQ.chaloupe_duree) + "pendant que des squelettes sortent de l'eau. Le compte n'avance que si tu es à bord."],
				[null, "Le butin", "Ramasse-le en passant dessus. Si l'expédition est perdue, ton sac l'est aussi."],
				[null, "La malédiction", "De 0 à 5 : tout est plus dur, mais +%d %% de chance d'objet par niveau."
					% roundi(EQ.mal_butin * 100.0)],
				[_dessin(ICONES + "canon.svg"), "La bordée", "Si ton bateau a des canons : garde le bouton, glisse le pouce pour "
					+ "viser, lâche pour tirer."],
			]
		&"repaire":
			return [
				[null, "Se déplacer", "Marche vers un lieu puis « Ouvrir », ou touche son nom à droite de l'écran. Un « ! » : "
					+ "il y a quelque chose à faire."],
				[null, "Salle des cartes", "Partir en expédition."],
				[_dessin(ICONES + "doublon.svg"), "Entrepôt", "Tes doublons, tes matériaux, tes objets ; l'Équipement : armes et "
					+ "reliques de chaque héros."],
				[_dessin(ICONES + "bois.svg"), "Chantier naval", "Améliorer le bateau : la cale (objets rapportés), les voiles "
					+ "(moins de temps dans la chaloupe), la coque (malédiction plus haute), la bordée (canons)."],
				[_dessin(ICONES + "fer.svg"), "Forge", "Monter une arme d'une rareté, recycler un objet en matériaux ; au niveau 2, "
					+ "relancer un effet."],
				[_dessin(ICONES + "essence.svg"), "Les matériaux", "Bois, fer et essence maudite, lâchés par les squelettes."],
			]
		&"deux":
			return [
				[null, "Se connecter", "Les deux téléphones sur le même Wi-Fi. « Jouer à deux » : l'un héberge, l'autre rejoint "
					+ "(si la partie n'apparaît pas, tape le code affiché chez l'hôte)."],
				[null, "Lancer", "L'hôte choisit son héros, puis l'expédition ou l'arène ; son partenaire prend l'autre héros."],
				[null, "Relever", "Un héros à terre : reste près de lui %s s pour le relever. Tous les deux à terre : l'expédition "
					% _nombre(EQ.reanimation_duree) + "est perdue."],
				[null, "Chacun son butin", "Ce que tu vois au sol est à toi seul."],
				[_porte("combat"), "Les portes", "Elles se prennent quand vous êtes tous les deux devant."],
				[_icone(&"occultiste", &"competence_1"), "Ensemble", "La Marque de l'Occultiste profite surtout au Bretteur."],
			]
	return []


func _ligne(dessin: Texture2D, t: String, texte: String) -> void:
	lignes.append([dessin, t, texte])
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	contenu.add_child(h)
	var marge := Control.new()
	marge.custom_minimum_size = Vector2(RAYON_DESSIN * 2 + 8, RAYON_DESSIN * 2)
	marge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(marge)
	if dessin:
		var b := BoutonAction.new()   # (le vrai bouton du HUD, sans toucher : on le reconnaît en jeu)
		b.configurer("", RAYON_DESSIN)
		b.icone = dessin
		b.position = Vector2(4, 0)
		marge.add_child(b)
	else:
		var puce := StyleRepaire.texte("◆", 26, StyleRepaire.COULEUR_OR)
		puce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		puce.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		puce.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		marge.add_child(puce)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 0)
	colonne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colonne.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(colonne)
	var titre_ligne := StyleRepaire.texte(t, 26, StyleRepaire.OR_VIF)
	titre_ligne.theme_type_variation = &"LabelEncreGras"
	colonne.add_child(titre_ligne)
	var l := StyleRepaire.texte(texte, 22)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	colonne.add_child(l)


func _icone(archetype: StringName, bouton: StringName) -> Texture2D:
	return _heros[archetype]["icones"].get(bouton)


func _nom(archetype: StringName, bouton: StringName) -> String:
	return _heros[archetype]["noms"].get(bouton, "")


func _porte(nom: String) -> Texture2D:
	return _dessin(PORTES + "porte_%s.svg" % nom)


func _dessin(chemin: String) -> Texture2D:
	return load(chemin) if ResourceLoader.exists(chemin) else null


## 2.0 → « 2 », 1.5 → « 1,5 ».
static func _nombre(v: float) -> String:
	return str(roundi(v)) if is_equal_approx(v, roundf(v)) else ("%.1f" % v).replace(".", ",")
