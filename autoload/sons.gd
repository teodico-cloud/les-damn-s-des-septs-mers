extends Node
## Sons du jeu (jalon 6, choix de Téo : des ambiances et de petites musiques de fin, pas de musique continue ; les
## sons arrivent directement dans le jeu). Chargé au démarrage sous le nom Sons.
##
## - `jouer(nom, ou)` : un son ponctuel. `ou` : une position ou un nœud 3D (le son vient de là : plus fort près de
##   la caméra, à gauche ou à droite de l'écran), ou rien (interface : au milieu, sans distance).
## - `jouer_plus_tard(nom, delai, ou, geste)` : le même, un peu plus tard (le souffle de la lame juste avant l'impact) ;
##   avec `geste`, il n'est joué que si `ou` fait encore ce geste-là (son `_n_geste`) : geste interrompu, rien.
## - `ambiance([couches])` : les sons d'ambiance en boucle (ressac, vent, torches…) ; passer d'un lieu à l'autre
##   les fond les uns dans les autres, et une couche déjà là continue sans reprendre au début.
## - `jingle(nom)` : petite musique de fin d'expédition (victoire, défaite).
##
## Trois canaux réglables (Reglages : Général, Effets, Ambiances) : les sons ponctuels passent par « Effets », les
## ambiances et les petites musiques par « Ambiances ». Rien ne passe par le réseau : chaque téléphone joue les sons
## de ce qu'il affiche (les coups, effets et animations sont déjà montrés des deux côtés en coop).
##
## Les sons viennent de assets/sons/ (fabriqués par tools/sons/fabriquer_sons.py, et Kenney CC0). Les volumes et
## les variations ci-dessous sont un premier réglage, fait sans les écouter : Téo les juge au téléphone.

const BUS_EFFETS := &"Effets"
const BUS_AMBIANCES := &"Ambiances"
const DOSSIER := "res://assets/sons/"
## Distance à laquelle un son garde tout son volume (la caméra du combat est à 13 m du héros).
const DISTANCE_PLEINE := 13.0
const DISTANCE_MAX := 45.0
const NB_VOIX_3D := 20
const NB_VOIX_2D := 8
## Un même son relancé plus de `max` fois dans cet intervalle est ignoré (la horde qui éclate d'un coup de moulinet).
const FENETRE_REPETITION := 0.07

## nom -> [fichiers (sans .ogg, depuis assets/sons/), volume en dB, variation de hauteur (± part), max dans la fenêtre]
const CATALOGUE := {
	# combat : gestes
	&"lame": [["fabriques/lame_1", "fabriques/lame_2", "fabriques/lame_3"], -7.0, 0.07, 2],
	&"moulinet": [["fabriques/moulinet"], -5.0, 0.05, 1],
	&"roulade": [["kenney/roulade_1", "kenney/roulade_2"], -9.0, 0.08, 1],
	&"tomber": [["kenney/tomber"], -6.0, 0.05, 1],
	&"terre": [["kenney/terre"], -7.0, 0.05, 1],
	&"tir_maudit": [["fabriques/tir_maudit"], -7.0, 0.06, 2],
	&"marque": [["fabriques/marque"], -8.0, 0.03, 1],
	&"chaines": [["fabriques/chaines"], -6.0, 0.04, 1],
	&"teleport": [["fabriques/teleport"], -7.0, 0.05, 1],
	&"carreau": [["kenney/carreau"], -7.0, 0.06, 2],
	&"sol_lourd": [["kenney/sol_lourd"], -3.0, 0.04, 1],
	# pas (10/11) : joués par PasSonores quand un pied touche le sol ; ceux des squelettes plus discrets (ils sont
	# nombreux) et plus aigus (des os), voir Ennemi._hauteur_pas
	&"pas_pierre": [["kenney/pas_pierre_1", "kenney/pas_pierre_2", "kenney/pas_pierre_3", "kenney/pas_pierre_4", "kenney/pas_pierre_5"], -16.0, 0.08, 2],
	&"pas_bois": [["kenney/pas_bois_1", "kenney/pas_bois_2", "kenney/pas_bois_3", "kenney/pas_bois_4", "kenney/pas_bois_5"], -15.0, 0.08, 2],
	&"pas_os_pierre": [["kenney/pas_pierre_1", "kenney/pas_pierre_2", "kenney/pas_pierre_3", "kenney/pas_pierre_4", "kenney/pas_pierre_5"], -21.0, 0.1, 2],
	&"pas_os_bois": [["kenney/pas_bois_1", "kenney/pas_bois_2", "kenney/pas_bois_3", "kenney/pas_bois_4", "kenney/pas_bois_5"], -20.0, 0.1, 2],
	# ennemis (06/11, choix de Téo) : plus discrets que les gestes du héros
	&"lame_squelette": [["fabriques/lame_1", "fabriques/lame_2", "fabriques/lame_3"], -11.0, 0.08, 2],
	&"sortie_terre": [["fabriques/sortie_terre"], -8.0, 0.1, 2],
	&"cri_bosco": [["fabriques/cri_bosco"], -2.0, 0.0, 1],
	&"relever": [["fabriques/relever"], -6.0, 0.04, 1],
	# combat : chocs
	&"coup": [["kenney/coup_1", "kenney/coup_2", "kenney/coup_3"], -5.0, 0.08, 2],
	&"coup_lourd": [["kenney/coup_lourd"], -3.0, 0.06, 2],
	&"critique": [["kenney/critique"], -4.0, 0.04, 1],
	&"touche": [["kenney/touche_1", "kenney/touche_2"], -3.0, 0.06, 1],
	&"parade": [["kenney/parade_1", "kenney/parade_2"], -4.0, 0.06, 1],
	&"parade_parfaite": [["kenney/parade_parfaite"], -2.0, 0.0, 1],
	&"os": [["fabriques/os_1", "fabriques/os_2"], -6.0, 0.1, 2],
	&"explosion_maudite": [["fabriques/explosion_maudite"], -4.0, 0.06, 2],
	&"explosion": [["fabriques/explosion_poudre"], -1.0, 0.06, 2],
	&"canon": [["fabriques/canon"], -8.0, 0.08, 2],
	# butin
	&"pieces": [["kenney/pieces_1", "kenney/pieces_2"], -8.0, 0.06, 1],
	&"objet": [["kenney/objet"], -6.0, 0.05, 1],
	&"objet_rare": [["kenney/objet_rare"], -7.0, 0.0, 1],
	&"bois": [["kenney/bois"], -8.0, 0.06, 1],
	&"fer": [["kenney/fer"], -8.0, 0.06, 1],
	&"essence": [["fabriques/essence"], -9.0, 0.05, 1],
	# lieux, interface
	&"porte": [["kenney/porte"], -6.0, 0.04, 1],
	&"coffre": [["kenney/coffre"], -4.0, 0.0, 1],
	&"loquet": [["kenney/loquet"], -6.0, 0.0, 1],
	&"clic": [["kenney/clic", "kenney/clic_2"], -12.0, 0.05, 1],
	&"parchemin": [["kenney/parchemin"], -6.0, 0.05, 1],
	&"parchemin_ferme": [["kenney/parchemin_ferme"], -10.0, 0.05, 1],
	&"enclume": [["kenney/enclume"], -6.0, 0.03, 1],
	&"marteau": [["kenney/marteau_1", "kenney/marteau_2"], -6.0, 0.05, 1],
}
## Ambiances (en boucle) : nom -> [fichier, volume en dB]
const AMBIANCES := {
	&"ressac": ["fabriques/ressac", -10.0],
	&"houle": ["fabriques/houle", -9.0],
	&"vent": ["fabriques/vent", -14.0],
	&"gouttes": ["fabriques/gouttes", -12.0],
	&"torches": ["fabriques/torches", -15.0],
}
const JINGLES := {
	&"victoire": ["kenney/victoire", -4.0],
	&"defaite": ["kenney/defaite", -4.0],
}
const FONDU_AMBIANCE := 1.5

var _voix_3d: Array[AudioStreamPlayer3D] = []
var _voix_2d: Array[AudioStreamPlayer] = []
var _flux := {}                 ## chemin -> AudioStream (chargés une fois)
var _derniers := {}             ## nom -> heures (s) des derniers départs
var _couches := {}              ## ambiance en cours : nom -> {"lecteur", "niveau" (0..1), "voulu" (0..1)}
var _jingle: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
## Pour les tests : chaque son effectivement lancé, [nom, position ou null].
var journal: Array = []
var garder_journal := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # (les ambiances continuent pendant une pause)
	_rng.randomize()
	_creer_bus(BUS_EFFETS)
	_creer_bus(BUS_AMBIANCES)
	for i in NB_VOIX_3D:
		var v := AudioStreamPlayer3D.new()
		v.bus = BUS_EFFETS
		v.unit_size = DISTANCE_PLEINE
		v.max_distance = DISTANCE_MAX
		v.panning_strength = 0.6      # (sur le haut-parleur d'un téléphone, la stéréo est faible : on reste doux)
		v.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		v.attenuation_filter_cutoff_hz = 20500.0   # (pas d'étouffement des sons lointains : la caméra est loin)
		add_child(v)
		_voix_3d.append(v)
	for i in NB_VOIX_2D:
		var v := AudioStreamPlayer.new()
		v.bus = BUS_EFFETS
		add_child(v)
		_voix_2d.append(v)
	_jingle = AudioStreamPlayer.new()
	_jingle.bus = BUS_AMBIANCES
	add_child(_jingle)
	appliquer_volumes()
	Reglages.change.connect(appliquer_volumes)
	EventBus.coup_porte.connect(_sur_coup)
	EventBus.parade_parfaite.connect(_sur_parade_parfaite)


func _creer_bus(nom: StringName) -> void:
	if AudioServer.get_bus_index(nom) >= 0:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, nom)
	AudioServer.set_bus_send(i, &"Master")


## Les volumes réglés par le joueur (0 à 1) : Général (tout), Effets, Ambiances.
func appliquer_volumes() -> void:
	for paire in [[&"Master", "general"], [BUS_EFFETS, "effets"], [BUS_AMBIANCES, "ambiances"]]:
		var i := AudioServer.get_bus_index(paire[0])
		if i < 0:
			continue
		var v: float = Reglages.volume(paire[1])
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(i, v <= 0.001)


func _flux_de(chemin: String) -> AudioStream:
	if not _flux.has(chemin):
		_flux[chemin] = load(DOSSIER + chemin + ".ogg")
	return _flux[chemin]


## Joue le son `nom`. `ou` : Vector3 ou Node3D (son placé dans le monde), ou null (interface). `hauteur` : 1 = normal.
func jouer(nom: StringName, ou: Variant = null, hauteur := 1.0) -> void:
	var fiche: Array = CATALOGUE.get(nom, [])
	if fiche.is_empty():
		push_warning("Son inconnu : %s" % nom)
		return
	if not _place_pour(nom, int(fiche[3])):
		return
	var fichiers: Array = fiche[0]
	var flux := _flux_de(fichiers[_rng.randi() % fichiers.size()])
	var variation: float = fiche[2]
	var h := hauteur * (1.0 + _rng.randf_range(-variation, variation))
	var pos: Variant = null
	if typeof(ou) == TYPE_OBJECT and is_instance_valid(ou) and ou is Node3D and (ou as Node3D).is_inside_tree():
		pos = (ou as Node3D).global_position
	elif ou is Vector3:
		pos = ou
	if pos is Vector3 and get_viewport().get_camera_3d() != null:
		var v := _voix_libre_3d()
		v.global_position = pos
		_lancer(v, flux, fiche[1], h)
	else:
		_lancer(_voix_libre_2d(), flux, fiche[1], h)
	if garder_journal:
		journal.append([nom, pos])


## Le même, `delai` secondes plus tard (temps de jeu : un ralenti le retarde avec l'animation). `geste` (facultatif) :
## le numéro du geste de `ou` (Heros, Ennemi : `_n_geste`) ; s'il a changé entre-temps, le son n'est pas joué.
func jouer_plus_tard(nom: StringName, delai: float, ou: Variant = null, geste := -1, hauteur := 1.0) -> void:
	# (le nœud est retrouvé par son numéro au dernier moment : gardé tel quel, Godot se plaint s'il a disparu)
	var id := 0
	if typeof(ou) == TYPE_OBJECT:
		if not is_instance_valid(ou):
			return
		id = ou.get_instance_id()
		ou = null
	if delai <= 0.0:
		_jouer_prevu(nom, id, ou, geste, hauteur)
		return
	# (en temps de jeu, comme les gestes : un ralenti retarde le son avec l'animation)
	get_tree().create_timer(delai, false, true).timeout.connect(_jouer_prevu.bind(nom, id, ou, geste, hauteur))


func _jouer_prevu(nom: StringName, id: int, pos: Variant, geste: int, hauteur: float) -> void:
	if id != 0:
		var n := instance_from_id(id) as Node
		if n == null or not n.is_inside_tree():
			return   # (le héros ou le squelette a disparu entre-temps)
		if geste >= 0 and n.get("_n_geste") != geste:
			return   # (geste interrompu)
		jouer(nom, n, hauteur)
	else:
		jouer(nom, pos, hauteur)


func _place_pour(nom: StringName, maximum: int) -> bool:
	var maintenant := Time.get_ticks_msec() / 1000.0
	var recents: Array = _derniers.get(nom, []).filter(func(t): return maintenant - t < FENETRE_REPETITION)
	if recents.size() >= maximum:
		_derniers[nom] = recents
		return false
	recents.append(maintenant)
	_derniers[nom] = recents
	return true


func _lancer(v: Node, flux: AudioStream, db: float, hauteur: float) -> void:
	v.stream = flux
	v.volume_db = db
	v.pitch_scale = clampf(hauteur, 0.5, 2.0)
	v.play()


## Une voix libre ; sinon, celle qui joue depuis le plus longtemps (les sons sont courts).
func _voix_libre_3d() -> AudioStreamPlayer3D:
	var meilleure: AudioStreamPlayer3D = _voix_3d[0]
	for v in _voix_3d:
		if not v.playing:
			return v
		if v.get_playback_position() > meilleure.get_playback_position():
			meilleure = v
	return meilleure


func _voix_libre_2d() -> AudioStreamPlayer:
	var meilleure: AudioStreamPlayer = _voix_2d[0]
	for v in _voix_2d:
		if not v.playing:
			return v
		if v.get_playback_position() > meilleure.get_playback_position():
			meilleure = v
	return meilleure


# ---------------------------------------------------------------- combat
## Un coup a touché (chez l'invité aussi : l'hôte lui envoie chaque coup). Les coups « discrets » (épines, boulets,
## squelettes relevés) ne sonnent pas : leur effet a déjà son son, ou ils sont trop nombreux.
func _sur_coup(pos: Vector3, _degats: float, lourd: bool, cible_est_heros: bool, _cible: Node3D, _source: Node3D,
		critique := false) -> void:
	if Combat.coup_discret:
		return
	if cible_est_heros:
		if lourd:   # (un vrai coup : la flaque maudite, elle, ronge les PV sans « coup »)
			jouer(&"touche", pos)
		return
	if critique:
		jouer(&"critique", pos)
	jouer(&"coup_lourd" if lourd else &"coup", pos)


func _sur_parade_parfaite(_heros: Node3D, point: Vector3) -> void:
	jouer(&"parade_parfaite", point)


# ---------------------------------------------------------------- ambiances
## Les couches d'ambiance du lieu (ex. [&"ressac", &"gouttes", &"torches"]) ; les autres s'éteignent en fondu.
func ambiance(couches: Array, fondu := FONDU_AMBIANCE) -> void:
	for nom in _couches:
		if not (nom in couches):
			_couches[nom]["voulu"] = 0.0
	for nom in couches:
		if not AMBIANCES.has(nom):
			push_warning("Ambiance inconnue : %s" % nom)
			continue
		if not _couches.has(nom):
			var l := AudioStreamPlayer.new()
			l.bus = BUS_AMBIANCES
			l.stream = _flux_de(AMBIANCES[nom][0])
			l.volume_db = -80.0
			add_child(l)
			# (chaque couche part d'un endroit différent de sa boucle : deux lieux n'ont pas les mêmes vagues)
			l.play(_rng.randf_range(0.0, maxf(l.stream.get_length() - 1.0, 0.0)))
			_couches[nom] = {"lecteur": l, "niveau": 0.0}
		_couches[nom]["voulu"] = 1.0
	for nom in _couches:
		_couches[nom]["vitesse"] = 1.0 / maxf(fondu, 0.01)


## Change le volume d'une couche en cours (0 à 1, en fondu) : la houle monte quand la chaloupe va partir.
func niveau_ambiance(nom: StringName, niveau: float) -> void:
	if _couches.has(nom):
		_couches[nom]["voulu"] = clampf(niveau, 0.0, 1.0)


## Couches qui jouent (ou s'éteignent encore).
func couches_ambiance() -> Array:
	return _couches.keys().filter(func(n): return _couches[n]["voulu"] > 0.0)


func _process(delta: float) -> void:
	for nom in _couches.keys():
		var c: Dictionary = _couches[nom]
		c["niveau"] = move_toward(c["niveau"], c["voulu"], delta * c["vitesse"])
		var l: AudioStreamPlayer = c["lecteur"]
		if c["niveau"] <= 0.0 and c["voulu"] <= 0.0:
			l.queue_free()
			_couches.erase(nom)
			continue
		l.volume_db = AMBIANCES[nom][1] + linear_to_db(maxf(c["niveau"], 0.0001))


# ---------------------------------------------------------------- petites musiques
func jingle(nom: StringName) -> void:
	if not JINGLES.has(nom):
		push_warning("Petite musique inconnue : %s" % nom)
		return
	_jingle.stream = _flux_de(JINGLES[nom][0])
	_jingle.volume_db = JINGLES[nom][1]
	_jingle.play()
	if garder_journal:
		journal.append([nom, null])
