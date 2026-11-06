extends Node
## Réglages du joueur (jalon 6, refonte de l'interface, choix de Téo : la qualité graphique). Rangés à part de la
## sauvegarde (user://reglages.json) : une remise à zéro de la partie ne les efface pas.
##
## Qualité graphique, appliquée à tout ce qui entre en scène (lumières, environnement) et à l'écran lui-même :
## - ECONOMIE : sans ombres ni halo, image 3D à 75 % (le téléphone chauffe moins, la batterie dure plus) ;
## - NORMALE : le jeu tel qu'il a été réglé (réglage de départ) ;
## - BELLE : bords lissés (MSAA ×2) et ombres plus douces.
## Chaque scène continue de régler ses lumières comme avant : on note ce qu'elle voulait (méta « ombre_voulue »,
## « halo_voulu ») et on l'applique ou non selon la qualité, ce qui permet de revenir en arrière à chaud.

signal change

enum Qualite { ECONOMIE, NORMALE, BELLE }

const VERSION := 1
const NOMS := {Qualite.ECONOMIE: "economie", Qualite.NORMALE: "normale", Qualite.BELLE: "belle"}
const ECHELLE_ECONOMIE := 0.75

var chemin := "user://reglages.json"
var qualite: int = Qualite.NORMALE


func _ready() -> void:
	charger()
	get_tree().node_added.connect(_sur_noeud_ajoute)
	appliquer()


func charger() -> void:
	qualite = Qualite.NORMALE
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


## Écrit les réglages (fichier temporaire puis renommé : une coupure ne laisse pas un fichier à moitié écrit).
func enregistrer() -> bool:
	var temporaire := chemin + ".tmp"
	var f := FileAccess.open(temporaire, FileAccess.WRITE)
	if f == null:
		push_warning("Réglages : écriture impossible (%s)" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify({"version": VERSION, "qualite": NOMS[qualite]}, "\t"))
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


func _sur_noeud_ajoute(n: Node) -> void:
	if n is Light3D or n is WorldEnvironment:
		# (plus tard dans l'image : la scène finit de régler la lumière après l'avoir ajoutée). Par son numéro et
		# non le nœud lui-même : un éclair de lumière peut disparaître dans la même image (erreur à l'appel sinon).
		_ajuster_plus_tard.call_deferred(n.get_instance_id())


func _ajuster_plus_tard(id: int) -> void:
	var n := instance_from_id(id)
	if n is Node and not n.is_queued_for_deletion():
		ajuster(n)
