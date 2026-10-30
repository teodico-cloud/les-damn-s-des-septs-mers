class_name SynchroArene
extends Node
## Coop : tient les deux téléphones d'accord pendant le combat (nœud « Synchro » de l'arène, même
## chemin des deux côtés pour que les messages arrivent au bon endroit).
##
## L'HÔTE décide de tout : il fait tourner les deux héros et les squelettes, et envoie 30 fois par
## seconde un « instantané » (positions, états, animations, PV, marques), plus les événements
## ponctuels (coups portés, projectiles, ce qui arrive au héros de l'invité).
## L'INVITÉ déplace son propre héros tout de suite (sans attendre le réseau) et envoie ce qu'il
## demande à l'hôte ; s'il s'écarte de la position décidée par l'hôte, il est recalé (le corps
## d'un coup, l'image en douceur). Le reste du monde (héros de l'hôte, squelettes) est affiché
## avec 0,1 s de retard, en glissant entre deux instantanés : c'est ce qui rend le mouvement fluide.

const FREQUENCE := 30.0             ## instantanés par seconde
const RETARD_AFFICHAGE := 0.1       ## secondes : l'invité affiche le monde un peu en retard, sans saccades
const SEUIL_CORRECTION := 0.08      ## mètres d'écart ignorés (bruit normal)
const SEUIL_SAUT := 2.5             ## au-delà, on recale sans douceur
const DELAI_SANS_ENTREE := 0.25     ## hôte : sans nouvelles de l'invité, son héros s'arrête
const ACTIONS := [&"attaque", &"esquive", &"competence_1", &"competence_2"]
const DELAI_INSTABLE := 1.0         ## secondes sans nouvelles de l'autre téléphone avant d'avertir

signal connexion_instable(oui: bool)

var hote := false
var arene: Node3D
var heros_local: Heros
var heros_partenaire: Heros
var generateur: Node3D

# côté hôte
var _invite_pret := false
var _attente_invite := 0.0
var _minuterie := 0.0
var _ack := 0
var _temps_sans_entree := 0.0
var _numero := 0                    ## n° de l'instantané envoyé
# côté invité
var _seq := 0
var _historique := {}               ## n° d'entrée -> position prédite du héros local
var _decalage_visuel := Vector3.ZERO
var _instantanes: Array = []        ## [heure de l'hôte, héros, ennemis], du plus ancien au plus récent
var _decalage_horloge := INF        ## heure locale − heure de l'hôte, au plus juste (trajet le plus court vu)
var _dernier_envoi := {}            ## action -> heure du dernier envoi (on n'en envoie pas 60 par seconde)
var _relance_pret := 0.0
var _silence := 0.0                 ## secondes depuis le dernier message reçu de l'autre téléphone
var _instable := false
var _dernier_numero := 0
var recalages := 0                  ## mesures (essais) : nombre et taille des recalages du héros local
var plus_grand_recalage := 0.0
# essais : messages reçus mis en attente (Wi-Fi imparfait simulé, voir Reseau.latence_simulee)
var _attente: Array = []
var _derniere_heure_fiable := 0.0


func configurer(p_arene: Node3D, local: Heros, partenaire: Heros, p_generateur: Node3D) -> void:
	arene = p_arene
	heros_local = local
	heros_partenaire = partenaire
	generateur = p_generateur
	hote = Reseau.est_hote()


func _ready() -> void:
	process_physics_priority = 10   # après les combattants : on lit les positions de cette image
	Reseau.synchro = self
	if hote:
		EventBus.coup_porte.connect(_on_coup_porte)
		EventBus.projectile_tire.connect(_on_projectile_tire)
		EventBus.effet_visuel.connect(_on_effet_visuel)
		EventBus.parade_parfaite.connect(_on_parade_parfaite)
		EventBus.heros_mort.connect(_on_heros_mort)
		EventBus.heros_reapparu.connect(_on_heros_reapparu)
		heros_partenaire.etat_change.connect(_on_etat_partenaire)
	else:
		heros_local.commandes.action_demandee.connect(_on_action_locale)


func _maintenant() -> float:
	return Time.get_ticks_msec() / 1000.0


func _exit_tree() -> void:
	if Reseau.synchro == self:
		Reseau.synchro = null


# ================================================================ HÔTE
# (les messages de l'invité arrivent par Reseau, qui vérifie qu'ils viennent bien du partenaire)
func invite_pret() -> void:
	_invite_pret = true
	_silence = 0.0
	if generateur.has_method("demarrer"):
		generateur.demarrer()   # les squelettes sortent de terre quand les deux joueurs sont là


func recevoir_entrees(seq: int, x: float, z: float) -> void:
	_differer(_traiter_entrees.bind(seq, x, z), false)


func _traiter_entrees(seq: int, x: float, z: float) -> void:
	_silence = 0.0
	if not hote or not is_instance_valid(heros_partenaire):
		return
	if seq <= _ack:
		return   # message en retard sur un plus récent
	_ack = seq
	_temps_sans_entree = 0.0
	var d := Vector3(x, 0, z)
	heros_partenaire.commandes.deplacement = d.normalized() if d.length() > 1.0 else d


func recevoir_action(nom: StringName) -> void:
	_differer(_traiter_action.bind(nom), true)


func _traiter_action(nom: StringName) -> void:
	if not hote or not is_instance_valid(heros_partenaire):
		return
	if nom in ACTIONS:
		heros_partenaire.commandes.demander(nom, heros_partenaire.horloge)


## Essais : traite un message reçu plus tard, ou le perd (messages non garantis seulement).
func _differer(appel: Callable, fiable: bool) -> void:
	if Reseau.latence_simulee <= 0.0 and Reseau.perte_simulee <= 0.0:
		appel.call()
		return
	if not fiable and randf() < Reseau.perte_simulee:
		return
	var t := _maintenant() + Reseau.latence_simulee + randf() * Reseau.gigue_simulee
	if fiable:   # les messages garantis gardent leur ordre
		t = maxf(t, _derniere_heure_fiable)
		_derniere_heure_fiable = t
	_attente.append([t, appel])


func _traiter_attente() -> void:
	var maintenant := _maintenant()
	var restants := []
	for m in _attente:
		if m[0] <= maintenant:
			m[1].call()
		else:
			restants.append(m)
	_attente = restants


func _physics_process(delta: float) -> void:
	if not _attente.is_empty():
		_traiter_attente()
	if _invite_pret or not _instantanes.is_empty():   # une fois la partie vraiment commencée
		_silence += delta
		var instable := _silence > DELAI_INSTABLE
		if instable != _instable:
			_instable = instable
			connexion_instable.emit(instable)
	if hote:
		_hote_image(delta)
	else:
		_invite_image(delta)


func _hote_image(delta: float) -> void:
	if not _invite_pret:
		_attente_invite += delta
		if _attente_invite > 10.0 and generateur.has_method("demarrer"):
			generateur.demarrer()   # l'invité tarde : on ne laisse pas l'hôte dans une salle vide
		return
	if Reseau.id_partenaire == 0:
		return
	if is_instance_valid(heros_partenaire):
		_temps_sans_entree += delta
		if _temps_sans_entree > DELAI_SANS_ENTREE:
			heros_partenaire.commandes.deplacement = Vector3.ZERO
	_minuterie -= delta
	if _minuterie > 0.0:
		return
	_minuterie += 1.0 / FREQUENCE
	_numero += 1
	_instantane.rpc_id(Reseau.id_partenaire, _numero, _etat_heros(), _etat_ennemis(), _ack)


func _etat_heros() -> Dictionary:
	var d := {}
	for h in [heros_local, heros_partenaire]:
		if is_instance_valid(h):
			d[String(h.name)] = h.instantane()
	return d


func _etat_ennemis() -> Dictionary:
	var d := {}
	for e in generateur.get_children():
		if e is Ennemi:
			d[String(e.name)] = e.instantane()
	return d


func _on_coup_porte(pos: Vector3, degats: float, lourd: bool, cible_est_heros: bool, cible: Node3D, source: Node3D, critique: bool) -> void:
	if not _invite_pret:
		return
	_coup.rpc_id(Reseau.id_partenaire, pos, degats, lourd, cible_est_heros, _nom(cible), _nom(source), critique)
	if cible == heros_partenaire and source:
		_autorite.rpc_id(Reseau.id_partenaire, "touche", heros_partenaire.sante.pv, source.global_position)


func _on_projectile_tire(tireur: Node3D, depart: Vector3, direction: Vector3) -> void:
	if _invite_pret:
		_projectile.rpc_id(Reseau.id_partenaire, _nom(tireur), depart, direction)


func _on_effet_visuel(lanceur: Node3D, type: String, position: Vector3) -> void:
	if _invite_pret:
		_effet.rpc_id(Reseau.id_partenaire, _nom(lanceur), type, position)


func _on_parade_parfaite(heros: Node3D, point: Vector3) -> void:
	if _invite_pret:
		_effet.rpc_id(Reseau.id_partenaire, _nom(heros), "parade_parfaite", point)


func _on_heros_mort(h: Node) -> void:
	if _invite_pret and h == heros_partenaire:
		_autorite.rpc_id(Reseau.id_partenaire, "mort", 0.0, heros_partenaire.global_position)


func _on_heros_reapparu(h: Node) -> void:
	if _invite_pret and h == heros_partenaire:
		_autorite.rpc_id(Reseau.id_partenaire, "reapparu", heros_partenaire.sante.pv, heros_partenaire.global_position)


func _on_etat_partenaire(etat: Heros.Etat) -> void:
	if _invite_pret and etat == Heros.Etat.RIPOSTE:
		var cible = heros_partenaire.get("_cible_riposte")
		var point: Vector3 = cible.global_position if cible is Node3D and is_instance_valid(cible) else heros_partenaire.global_position + heros_partenaire.avant()
		_autorite.rpc_id(Reseau.id_partenaire, "riposte", heros_partenaire.sante.pv, point)


func _nom(n: Node) -> String:
	return String(n.name) if n != null and is_instance_valid(n) else ""


# ================================================================ INVITÉ
func _on_action_locale(action: StringName) -> void:
	if hote or not (action in ACTIONS) or _instantanes.is_empty():
		return
	var t := _maintenant()
	if t - float(_dernier_envoi.get(action, -1.0)) < 0.1:
		return   # l'attaque maintenue est redemandée à chaque image : une fois tous les 0,1 s suffit
	_dernier_envoi[action] = t
	Reseau.envoyer_action(action)


func _invite_image(delta: float) -> void:
	if Reseau.id_partenaire == 0:
		return
	# tant que rien n'arrive, on redit à l'hôte qu'on est prêt (son arène peut s'ouvrir après la nôtre) ;
	# on n'envoie rien d'autre avant son premier instantané
	if _instantanes.is_empty():
		_relance_pret -= delta
		if _relance_pret <= 0.0:
			_relance_pret = 0.5
			Reseau.envoyer_arene_prete()
		return
	# 1) ce que demande le joueur, numéroté, et où notre héros est arrivé avec
	_seq += 1
	var d := heros_local.commandes.deplacement
	Reseau.envoyer_entrees(_seq, d.x, d.z)
	_historique[_seq] = heros_local.global_position
	_historique.erase(_seq - 120)
	# 2) l'image du héros rattrape doucement son corps après un recalage
	_decalage_visuel *= 0.8
	if _decalage_visuel.length() < 0.01:
		_decalage_visuel = Vector3.ZERO
	heros_local.visuel.position = heros_local.global_transform.basis.inverse() * _decalage_visuel
	# 3) le reste du monde, affiché un peu en retard entre deux instantanés
	_afficher_monde()


@rpc("authority", "unreliable_ordered")
func _instantane(numero: int, heros: Dictionary, ennemis: Dictionary, ack: int) -> void:
	_differer(_traiter_instantane.bind(numero, heros, ennemis, ack), false)


func _traiter_instantane(numero: int, heros: Dictionary, ennemis: Dictionary, ack: int) -> void:
	_silence = 0.0
	if numero <= _dernier_numero:
		return   # arrivé après un plus récent : ignoré
	_dernier_numero = numero
	# heure de l'hôte au moment de l'envoi (il envoie à cadence fixe) ; l'écart avec notre horloge est
	# estimé par le trajet le plus rapide observé, qui remonte doucement si les horloges dérivent
	var t_hote := numero / FREQUENCE
	_decalage_horloge = minf(_decalage_horloge + 0.0005, _maintenant() - t_hote)
	_instantanes.append([t_hote, heros, ennemis])
	if _instantanes.size() > 12:
		_instantanes.pop_front()
	_recaler(heros, ack)
	_creer_ou_retirer_ennemis(ennemis)


## Compare la position décidée par l'hôte à celle que nous avions prédite au même moment (même n°
## d'entrée). Un petit écart est normal ; au-delà, le corps est recalé et l'image suit en douceur.
func _recaler(heros: Dictionary, ack: int) -> void:
	var cle := String(heros_local.name)
	if not heros.has(cle):
		return
	var donnees: Array = heros[cle]
	heros_local.sante.definir_pv(donnees[5])
	heros_local.afficher_reanimation(donnees[7], heros_local.etat == Heros.Etat.MORT)
	if not _historique.has(ack):
		return
	var ecart: Vector3 = donnees[0] - _historique[ack]
	ecart.y = 0.0
	if ecart.length() < SEUIL_CORRECTION:
		return
	heros_local.global_position += ecart
	recalages += 1
	plus_grand_recalage = maxf(plus_grand_recalage, ecart.length())
	if ecart.length() < SEUIL_SAUT:
		_decalage_visuel -= ecart   # l'image reste où elle était, puis rejoint le corps
	# les prédictions à partir de ce n° partaient de la mauvaise position : on les corrige aussi.
	# (Y compris celle de ce n° : sinon un instantané suivant portant le même n° — l'hôte n'a rien
	# reçu de neuf entre-temps — referait la même correction, et le héros dériverait.)
	for s in _historique:
		if s >= ack:
			_historique[s] += ecart


func _creer_ou_retirer_ennemis(ennemis: Dictionary) -> void:
	for nom in ennemis:
		if generateur.get_node_or_null(NodePath(nom)) == null:
			var donnees: Array = ennemis[nom]
			var e := Ennemi.creer()
			e.marionnette = true
			e.name = nom
			e.position = donnees[0]
			e.rotation.y = donnees[1]
			generateur.add_child(e)
	for e in generateur.get_children():
		if e is Ennemi and not ennemis.has(String(e.name)):
			e.queue_free()   # disparu chez l'hôte


## Place le héros de l'hôte et les squelettes à l'instant « heure de l'hôte − 0,1 s », en glissant entre
## les deux instantanés qui l'entourent (calés sur l'horloge de l'hôte : l'irrégularité du Wi-Fi ne
## se voit pas). Les états, animations et minutages viennent du DERNIER instantané reçu, avancé de son
## âge : l'annonce d'un squelette se remplit chez l'invité au même rythme que chez l'hôte.
func _afficher_monde() -> void:
	if _instantanes.is_empty():
		return
	var heure_hote := _maintenant() - _decalage_horloge
	var dernier: Array = _instantanes[-1]
	var age := maxf(heure_hote - dernier[0], 0.0)
	var t := heure_hote - RETARD_AFFICHAGE
	var a: Array = _instantanes[0]
	var b: Array = _instantanes[0]
	for i in _instantanes.size():
		b = _instantanes[i]
		if b[0] >= t:
			a = _instantanes[maxi(i - 1, 0)]
			break
		a = b
	var f := 0.0
	if b[0] > a[0]:
		f = clampf((t - a[0]) / (b[0] - a[0]), 0.0, 1.0)
	# héros de l'hôte (marionnette)
	if is_instance_valid(heros_partenaire):
		var cle := String(heros_partenaire.name)
		if a[1].has(cle) and b[1].has(cle):
			var da: Array = a[1][cle]
			var db: Array = b[1][cle]
			heros_partenaire.global_position = (da[0] as Vector3).lerp(db[0], f)
			heros_partenaire.rotation.y = lerp_angle(da[1], db[1], f)
		if dernier[1].has(cle):
			var dn: Array = dernier[1][cle]
			heros_partenaire.appliquer_instantane(dn[2], dn[3], dn[4], dn[5], dn[6], dn[7], dn[8] + age)
	# squelettes (marionnettes)
	for e in generateur.get_children():
		if not (e is Ennemi):
			continue
		var cle := String(e.name)
		if b[2].has(cle):
			var db: Array = b[2][cle]
			var da: Array = a[2][cle] if a[2].has(cle) else db
			e.global_position = (da[0] as Vector3).lerp(db[0], f)
			e.rotation.y = lerp_angle(da[1], db[1], f)
		if dernier[2].has(cle):
			var dn: Array = dernier[2][cle]
			e.appliquer_instantane(dn[2], dn[3], dn[4], dn[5], dn[6], dn[7] + age)


@rpc("authority", "reliable")
func _coup(pos: Vector3, degats: float, lourd: bool, cible_est_heros: bool, nom_cible: String, nom_source: String, critique: bool) -> void:
	_differer(_coup_recu.bind(pos, degats, lourd, cible_est_heros, nom_cible, nom_source, critique), true)


func _coup_recu(pos: Vector3, degats: float, lourd: bool, cible_est_heros: bool, nom_cible: String, nom_source: String, critique: bool) -> void:
	var cible := _trouver(nom_cible)
	var source := _trouver(nom_source)
	EventBus.coup_porte.emit(pos, degats, lourd, cible_est_heros, cible, source, critique)
	if cible is Ennemi:
		cible.flash_coup()


@rpc("authority", "reliable")
func _projectile(nom_tireur: String, depart: Vector3, direction: Vector3) -> void:
	_differer(_projectile_recu.bind(nom_tireur, depart, direction), true)


func _projectile_recu(nom_tireur: String, depart: Vector3, direction: Vector3) -> void:
	if nom_tireur == String(heros_local.name):
		return   # notre propre tir : déjà affiché chez nous au moment de l'appui
	Projectile.tirer(arene, _trouver(nom_tireur), depart, direction, Heros.EQ)


@rpc("authority", "reliable")
func _effet(nom_lanceur: String, type: String, position: Vector3) -> void:
	_differer(_effet_recu.bind(nom_lanceur, type, position), true)


func _effet_recu(nom_lanceur: String, type: String, position: Vector3) -> void:
	if type == "parade_parfaite":
		# décidée par l'hôte, même pour notre propre héros : on ne l'a pas encore vue ici
		var heros := _trouver(nom_lanceur)
		EventBus.parade_parfaite.emit(heros, position)
		if heros == heros_local and heros.has_method("parade_parfaite_recue"):
			heros.parade_parfaite_recue()
		return
	if nom_lanceur == String(heros_local.name):
		return   # notre propre sort : déjà affiché chez nous
	if type == "cercle_chaines":
		EffetsMagie.cercle(arene, position, Heros.EQ.occ_chaines_rayon, 0.8)
	elif type.begins_with("trainee_"):
		var lanceur := _trouver(nom_lanceur)
		if lanceur:
			var dir := Combat.direction_plate(lanceur.global_position, position)
			EffetsMagie.trainee_sabre(arene, lanceur.global_position, dir, int(type.substr(8)))


@rpc("authority", "reliable")
func _autorite(type: String, pv: float, point: Vector3) -> void:
	_differer(_autorite_recu.bind(type, pv, point), true)


func _autorite_recu(type: String, pv: float, point: Vector3) -> void:
	if type == "reapparu":
		# notre héros est replacé par l'hôte : les prédictions d'avant ne valent plus (sinon un
		# instantané encore en route referait le déplacement une seconde fois)
		_historique.clear()
		_decalage_visuel = Vector3.ZERO
	heros_local.evenement_autorite(type, pv, point)


func _trouver(nom: String) -> Node3D:
	if nom == "":
		return null
	var n := arene.get_node_or_null(NodePath(nom))
	if n == null:
		n = generateur.get_node_or_null(NodePath(nom))
	return n as Node3D
