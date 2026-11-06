extends Node
## Réglages du joueur (jalon 6, refonte de l'interface, choix de Téo : la qualité graphique). Rangés à part de la
## sauvegarde (user://reglages.json) : une remise à zéro de la partie ne les efface pas.
##
## Qualité graphique, appliquée à tout ce qui entre en scène (lumières, environnement) et à l'écran lui-même :
## - ECONOMIE : sans ombres ni halo ni brume, moins de poussière, image 3D à 75 % (le téléphone chauffe moins, la
##   batterie dure plus) ;
## - NORMALE : le jeu tel qu'il a été réglé (réglage de départ) ;
## - BELLE : bords lissés (MSAA ×2) et ombres plus douces.
## Volumes (jalon 6, avec les sons) : Général, Effets, Ambiances, de 0 à 1 (le service Sons les applique). Pendant
## qu'un curseur glisse, le fichier n'est écrit qu'une fois le doigt arrêté (pas à chaque cran).
##
## Chaque scène continue de régler ses lumières comme avant : on note ce qu'elle voulait (méta « ombre_voulue »,
## « halo_voulu ») et on l'applique ou non selon la qualité, ce qui permet de revenir en arrière à chaud.

signal change

enum Qualite { ECONOMIE, NORMALE, BELLE }

const VERSION := 1
const NOMS := {Qualite.ECONOMIE: "economie", Qualite.NORMALE: "normale", Qualite.BELLE: "belle"}
const ECHELLE_ECONOMIE := 0.75
const ECO_POUSSIERE := 0.4   ## part de la poussière gardée en Économie
const CANAUX := ["general", "effets", "ambiances"]
const DELAI_ECRITURE := 0.4

var chemin := "user://reglages.json"
var qualite: int = Qualite.NORMALE
var volumes := {"general": 1.0, "effets": 1.0, "ambiances": 1.0}
var _ecriture_prevue: SceneTreeTimer


func _ready() -> void:
	charger()
	get_tree().node_added.connect(_sur_noeud_ajoute)
	appliquer()


func charger() -> void:
	qualite = Qualite.NORMALE
	for c in CANAUX:
		volumes[c] = 1.0
	if not FileAccess.file_exists(chemin):
		return
	var json := JSON.new()   # (et non JSON.parse_string : un fichier abîmé ne doit pas inonder le journal d'erreurs)
	var d = json.data if json.parse(FileAccess.get_file_as_string(chemin)) == OK else null
	if not (d is Dictionary):
		push_warning("Réglages illisibles : réglages de départ")
		return
	var nom := String(d.get("qualite", ""))
	for q in NOMS:
		if NOMS[q] == nom:
			qualite = q
	var lus = d.get("volumes", {})
	if lus is Dictionary:
		for c in CANAUX:
			var v = lus.get(c)
			if v is float or v is int:
				volumes[c] = clampf(float(v), 0.0, 1.0)


## Écrit les réglages (fichier temporaire puis renommé : une coupure ne laisse pas un fichier à moitié écrit).
func enregistrer() -> bool:
	var temporaire := chemin + ".tmp"
	var f := FileAccess.open(temporaire, FileAccess.WRITE)
	if f == null:
		push_warning("Réglages : écriture impossible (%s)" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify({"version": VERSION, "qualite": NOMS[qualite], "volumes": volumes}, "\t"))
	f.close()
	DirAccess.remove_absolute(chemin)
	return DirAccess.rename_absolute(temporaire, chemin) == OK


func choisir_qualite(q: int) -> void:
	q = clampi(q, Qualite.ECONOMIE, Qualite.BELLE)
	if q == qualite:
		return
	qualite = q
	enregistrer()
	appliquer()
	change.emit()


func volume(canal: String) -> float:
	return float(volumes.get(canal, 1.0))


## Change un volume (0 à 1) : appliqué tout de suite, écrit un peu plus tard (un curseur qui glisse en change
## des dizaines de fois par seconde).
func choisir_volume(canal: String, v: float) -> void:
	if not (canal in CANAUX):
		return
	v = clampf(v, 0.0, 1.0)
	if is_equal_approx(v, volume(canal)):
		return
	volumes[canal] = v
	change.emit()
	if _ecriture_prevue == null:
		_ecriture_prevue = get_tree().create_timer(DELAI_ECRITURE, true, false, true)
		_ecriture_prevue.timeout.connect(func():
			_ecriture_prevue = null
			enregistrer())


## Applique la qualité à l'écran et à tout ce qui est déjà en scène.
func appliquer() -> void:
	var ecran := get_tree().root
	ecran.scaling_3d_scale = ECHELLE_ECONOMIE if qualite == Qualite.ECONOMIE else 1.0
	ecran.msaa_3d = Viewport.MSAA_2X if qualite == Qualite.BELLE else Viewport.MSAA_DISABLED
	var douces := qualite == Qualite.BELLE
	RenderingServer.directional_soft_shadow_filter_set_quality(
			RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM if douces else RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	RenderingServer.positional_soft_shadow_filter_set_quality(
			RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM if douces else RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	for n in ecran.find_children("*", "Light3D", true, false):
		ajuster(n)
	for n in ecran.find_children("*", "WorldEnvironment", true, false):
		ajuster(n)
	for groupe in [&"brume", &"poussiere"]:
		for n in get_tree().get_nodes_in_group(groupe):
			ajuster(n)


## Une lumière ou un environnement, selon la qualité (ce que la scène voulait est gardé en méta).
func ajuster(n: Node) -> void:
	if not is_instance_valid(n):
		return
	var sobre := qualite == Qualite.ECONOMIE
	if n is Light3D:
		if not n.has_meta(&"ombre_voulue"):
			n.set_meta(&"ombre_voulue", n.shadow_enabled)
		n.shadow_enabled = bool(n.get_meta(&"ombre_voulue")) and not sobre
	elif n is WorldEnvironment and n.environment:
		var e: Environment = n.environment
		if not e.has_meta(&"halo_voulu"):
			e.set_meta(&"halo_voulu", e.glow_enabled)
		e.glow_enabled = bool(e.get_meta(&"halo_voulu")) and not sobre
	elif n is Node3D and n.is_in_group(&"brume"):
		n.visible = not sobre
	elif n is CPUParticles3D and n.is_in_group(&"poussiere"):
		var voulu := int(n.get_meta(&"nombre_voulu", n.amount))
		var nombre := maxi(4, roundi(voulu * ECO_POUSSIERE)) if sobre else voulu
		if n.amount != nombre:
			n.amount = nombre


func _sur_noeud_ajoute(n: Node) -> void:
	if n is Light3D or n is WorldEnvironment or n.is_in_group(&"brume") or n.is_in_group(&"poussiere"):
		# (plus tard dans l'image : la scène finit de régler la lumière après l'avoir ajoutée). Par son numéro et
		# non le nœud lui-même : un éclair de lumière peut disparaître dans la même image (erreur à l'appel sinon).
		_ajuster_plus_tard.call_deferred(n.get_instance_id())


func _ajuster_plus_tard(id: int) -> void:
	var n := instance_from_id(id)
	if n is Node and not n.is_queued_for_deletion():
		ajuster(n)
