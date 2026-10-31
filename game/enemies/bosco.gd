class_name Bosco
extends Ennemi
## Le Bosco Maudit (jalon 3, mini-boss de l'antre). Choix de Téo : une brute à la hache, environ
## 1 min 30 de combat en solo (plus de PV à deux), des coups « mi-parables ».
## - Coup de hache au sol, droit devant : zone rouge qui devient dorée à la fin ; le seul qui se pare.
## - Tourbillon : zone ronde rouge sombre autour de lui ; imparable, il faut s'éloigner ou rouler.
## - Charge : ligne rouge sombre vers le héros, puis il fonce ; imparable. S'il finit contre un mur, il
##   reste sonné 2 s (étoiles au-dessus de la tête) : c'est le moment de le punir.
## - À mi-vie : il enrage (cri, yeux et lueur rouges, plus rapide) et appelle 3 matelots. Malédiction 5 :
##   enragé dès le début.
## Il ne recule pas sous les coups et n'est pas interrompu (sauf étourdi, sonné ou enchaîné, deux fois
## moins longtemps qu'un matelot). Vaincu, son équipage s'effondre avec lui.
## En coop, l'hôte décide ; l'invité reçoit l'attaque choisie par EventBus.effet_visuel (« bosco_… »)
## pour dessiner la bonne zone, et la rage aussi.

const MODELE_BOSCO := preload("res://assets/models/enemies/Skeleton_Warrior.glb")
const HACHE := preload("res://assets/models/enemies/Skeleton_Axe.gltf")
const IMPACT_COUP := 0.82          ## secondes dans « 2H_Melee_Attack_Chop » où la hache touche le sol
enum Attaque { AUCUNE, COUP, TOURBILLON, CHARGE }
const NOMS_ATTAQUES := ["", "coup", "tourbillon", "charge"]
const ROUGE_SOMBRE := Color(0.5, 0.0, 0.06)

var attaque := Attaque.AUCUNE
var enrage := false
var _rage_faite := false
var _renforts_appeles := false
var renforts: Array[Ennemi] = []
var _recharge_charge := 2.5
var _dernier_tourbillon := false
var _longueur_charge := 0.0
var _mur := false                  ## la charge finit contre un mur (ou un meuble) : il sera sonné
var _depart_charge := Vector3.ZERO
var _touches: Array = []           ## héros déjà touchés par l'attaque en cours
var _annonce: Node3D               ## zone au sol de l'attaque en cours (rectangle, disque ou ligne)
var _jauge: Node3D                 ## ce qui grandit pendant l'annonce (pivot du remplissage)
var _mat_zone_annonce: StandardMaterial3D
var _mat_rempli: StandardMaterial3D
var _etoiles: Node3D               ## sonné
var _lueur: OmniLight3D


func type_ennemi() -> StringName:
	return &"bosco"


func _modele() -> PackedScene:
	return MODELE_BOSCO


func _arme() -> PackedScene:
	return HACHE


func _prefixe() -> String:
	return "Skeleton_Warrior"


func _taille() -> float:
	return EQ.bosco_taille


## PV : les mêmes sur les deux téléphones (tous deux savent s'ils jouent à deux).
func _pv() -> float:
	return EQ.bosco_pv * (EQ.bosco_pv_coop if Reseau.est_en_coop() else 1.0)


func _boucles() -> Array:
	return ["Idle_Combat", "2H_Melee_Idle", "Walking_D_Skeletons", "2H_Melee_Attack_Spinning", "Running_A"]


## Une hache géante (la sonde tools/sonde_arme.gd : elle se tient bien sans la tourner).
func _orienter_arme(arme: Node3D) -> void:
	arme.scale = Vector3.ONE * 1.4


func _preparer_modele() -> void:
	add_to_group("boss")
	collision_mask = Combat.COUCHE_MONDE   # il passe à travers son équipage (sa charge ne s'y bloque pas)
	_lueur = OmniLight3D.new()
	_lueur.light_color = Color(1.0, 0.15, 0.08)
	_lueur.light_energy = 0.0
	_lueur.omni_range = 4.5
	_lueur.position = Vector3(0, 2.6, 0.4)
	add_child(_lueur)
	_annonce = Node3D.new()
	_annonce.position.y = 0.09   # au-dessus des dalles
	_annonce.visible = false
	add_child(_annonce)
	_mat_zone_annonce = _mat_annonce()
	_mat_rempli = _mat_annonce()
	_mat_rempli.render_priority = 1
	if Malediction.bosco_enrage():
		_devenir_enrage()


static func _mat_annonce() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


# ---------------------------------------------------------------- vitesse (rage)
func _rythme() -> float:
	return EQ.bosco_rage_vitesse if enrage else 1.0


func _duree_annonce() -> float:
	match attaque:
		Attaque.COUP: return EQ.bosco_coup_annonce / _rythme()
		Attaque.TOURBILLON: return EQ.bosco_tourbillon_annonce / _rythme()
		Attaque.CHARGE: return EQ.bosco_charge_annonce / _rythme()
	return 1.0


func _devenir_enrage() -> void:
	enrage = true
	if _lueur:
		_lueur.light_energy = 1.8
	_yeux_rouges(true)


## Enragé, ses yeux restent rouges.
func _yeux_rouges(actif: bool) -> void:
	super._yeux_rouges(actif or enrage)


# ---------------------------------------------------------------- comportement (hôte)
func _poursuivre(delta: float) -> void:
	_recharge_charge = maxf(0.0, _recharge_charge - delta)
	if not _rage_faite and sante.pv <= sante.pv_max * EQ.bosco_rage_seuil:
		_crier()
		return
	var cible := heros_le_plus_proche()
	if cible == null:
		_jouer("2H_Melee_Idle")
		return
	var dir := Combat.direction_plate(global_position, cible.global_position)
	var dist := global_position.distance_to(cible.global_position)
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), clampf(5.0 * delta, 0.0, 1.0))
	if _recharge_attaque <= 0.0:
		if dist >= EQ.bosco_charge_distance and _recharge_charge <= 0.0:
			_commencer(Attaque.CHARGE, dir)
			return
		if dist <= EQ.bosco_tourbillon_portee and not _dernier_tourbillon and randf() < 0.5:
			_commencer(Attaque.TOURBILLON, dir)
			return
		if dist <= EQ.bosco_coup_portee:
			_commencer(Attaque.COUP, dir)
			return
	if dist > 2.2:
		velocity.x = dir.x * EQ.bosco_vitesse * _rythme()
		velocity.z = dir.z * EQ.bosco_vitesse * _rythme()
		_jouer("Walking_D_Skeletons", 1.1 * _rythme())
	else:
		_jouer("2H_Melee_Idle")


func _commencer(a: Attaque, dir: Vector3) -> void:
	attaque = a
	_dernier_tourbillon = a == Attaque.TOURBILLON
	rotation.y = atan2(dir.x, dir.z)
	_touches.clear()
	_impact_fait = false
	var point := global_position
	match a:
		Attaque.COUP:
			# l'animation est ralentie pour que la hache touche le sol à la fin de l'annonce
			_jouer("2H_Melee_Attack_Chop", IMPACT_COUP / _duree_annonce(), 0.08, true)
		Attaque.TOURBILLON:
			_jouer("2H_Melee_Idle", 0.6, 0.1)
		Attaque.CHARGE:
			_mesurer_charge(dir)
			point = global_position + dir * _longueur_charge
			_jouer("2H_Melee_Idle", 0.6, 0.1)
	_construire_annonce()
	_changer(Etat.PREPARATION, _duree_annonce())
	_montrer_annonce(true)
	_yeux_rouges(true)
	_preparer_visuel()
	EventBus.effet_visuel.emit(self, "bosco_" + NOMS_ATTAQUES[a], point)


## Jusqu'où il chargera : le premier mur ou meuble devant lui, au plus bosco_charge_longueur.
func _mesurer_charge(dir: Vector3) -> void:
	var r := PhysicsRayQueryParameters3D.new()
	r.collision_mask = Combat.COUCHE_MONDE
	r.from = global_position + Vector3.UP * 1.0
	r.to = r.from + dir * (EQ.bosco_charge_longueur + 1.0)
	var touche := get_world_3d().direct_space_state.intersect_ray(r)
	_mur = not touche.is_empty()
	var jusqu_au_mur: float = r.from.distance_to(touche["position"]) - 0.85 if _mur else INF
	_longueur_charge = maxf(minf(jusqu_au_mur, EQ.bosco_charge_longueur), 1.0)
	if not is_inf(jusqu_au_mur) and jusqu_au_mur > EQ.bosco_charge_longueur:
		_mur = false


func _preparer() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_preparer_visuel()
	if _t >= _duree_annonce():
		_changer(Etat.FRAPPE)
		_montrer_annonce(false)
		match attaque:
			Attaque.TOURBILLON:
				_jouer("2H_Melee_Attack_Spinning", 1.3, 0.05, true)
			Attaque.CHARGE:
				_depart_charge = global_position
				_jouer("Running_A", 1.6, 0.05, true)


func _frapper() -> void:
	match attaque:
		Attaque.COUP:
			if not _impact_fait:
				_impact_fait = true
				for h in _heros_vivants():
					var l := to_local(h.global_position)
					if l.z >= 0.2 and l.z <= 0.6 + EQ.bosco_coup_longueur and absf(l.x) <= EQ.bosco_coup_largeur * 0.5 + 0.35:
						Combat.porter_coup(self, h, EQ.bosco_coup_degats, true)
				EffetsMagie.eclat(_monde(), global_position + global_transform.basis.z * 2.2)
			if _t >= 0.35:
				_finir(EQ.bosco_coup_recuperation)
		Attaque.TOURBILLON:
			# dangereux tant qu'il tourne (une fois par héros) : entrer dans le cercle pendant la rotation blesse aussi
			for h in _heros_vivants():
				if h in _touches:
					continue
				var d: Vector3 = h.global_position - global_position
				d.y = 0.0
				if d.length() <= EQ.bosco_tourbillon_rayon + 0.3:
					_touches.append(h)
					Combat.porter_coup(self, h, EQ.bosco_tourbillon_degats, true)
			if _t >= EQ.bosco_tourbillon_duree:
				_finir(EQ.bosco_tourbillon_recuperation)
		Attaque.CHARGE:
			var avant := Vector3(sin(rotation.y), 0, cos(rotation.y))
			velocity.x = avant.x * EQ.bosco_charge_vitesse
			velocity.z = avant.z * EQ.bosco_charge_vitesse
			for h in _heros_vivants():
				if h in _touches:
					continue
				var d: Vector3 = h.global_position - global_position
				d.y = 0.0
				if d.length() <= EQ.bosco_charge_largeur * 0.5 + 0.45:
					_touches.append(h)
					Combat.porter_coup(self, h, EQ.bosco_charge_degats, true)
			var parcouru := _depart_charge.distance_to(global_position)
			var bloque := _t > _longueur_charge / EQ.bosco_charge_vitesse + 0.35   # coincé avant le bout
			if parcouru >= _longueur_charge - 0.05 or bloque:
				velocity.x = 0.0
				velocity.z = 0.0
				_recharge_charge = EQ.bosco_charge_recharge
				if _mur or bloque:
					_sonner()
				else:
					_finir(EQ.bosco_charge_recuperation)
		_:
			_finir(0.5)


func _finir(recuperation: float) -> void:
	_recharge_attaque = EQ.bosco_pause / _rythme()
	_jouer("2H_Melee_Idle", 1.0, 0.2)
	_changer(Etat.RECUPERATION, recuperation / _rythme())


## Contre un mur au bout de sa charge : sonné (choix de Téo).
func _sonner() -> void:
	EffetsMagie.etincelles(_monde(), global_position + global_transform.basis.z * 0.9 + Vector3.UP * 1.6)
	_recharge_attaque = EQ.bosco_pause
	_jouer("Hit_B", 0.7, 0.04, true)
	_changer(Etat.ETOURDI, EQ.bosco_charge_sonne)


func _heros_vivants() -> Array:
	return get_tree().get_nodes_in_group("heros").filter(
			func(h): return h is Node3D and h.has_method("est_vivant") and h.est_vivant() and h.get("marionnette") != true)


func _monde() -> Node:
	return get_parent().get_parent() if get_parent() is GenerateurEnnemis else get_parent()


# ---------------------------------------------------------------- rage (mi-vie)
func _crier() -> void:
	_rage_faite = true
	_renforts_appeles = false
	attaque = Attaque.AUCUNE
	_jouer("Taunt", 1.0, 0.1, true)
	_changer(Etat.INCANTATION, EQ.bosco_rage_cri)
	_devenir_enrage()
	EventBus.effet_visuel.emit(self, "bosco_rage", global_position)


func _incanter() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if not _renforts_appeles and _t >= EQ.bosco_rage_cri * 0.4:
		_renforts_appeles = true
		_appeler_renforts()
	if _t >= EQ.bosco_rage_cri:
		_recharge_attaque = 0.4
		_changer(Etat.POURSUITE)


func _appeler_renforts() -> void:
	var gen := get_parent() as GenerateurEnnemis
	if gen == null:
		return
	var n := EQ.bosco_rage_renforts
	for i in n:
		var a := rotation.y - PI * 0.5 + PI * (i + 0.5) / n   # en arc devant lui
		var pos := global_position + Vector3(sin(a), 0, cos(a)) * 3.0
		pos.x = clampf(pos.x, -Salle.DEMI + 0.8, Salle.DEMI - 0.8)   # jamais dans un mur
		pos.z = clampf(pos.z, -Salle.DEMI + 0.8, Salle.DEMI - 0.8)
		renforts.append(gen._faire_apparaitre(Vector3(pos.x, 0, pos.z), &"matelot"))


# ---------------------------------------------------------------- coups reçus
## Il ne recule pas et n'est pas interrompu par les coups (un boss) ; seuls l'étourdissement de la
## riposte, les chaînes et le mur l'arrêtent.
func recevoir_coup(degats: float, source: Node3D, lourd: bool, critique := false) -> float:
	if marionnette or etat == Etat.MORT or etat == Etat.APPARITION:
		return 0.0
	var reel := sante.subir(degats * multiplicateur_degats(source), source)
	if reel <= 0.0:
		return 0.0
	EventBus.coup_porte.emit(global_position + Vector3.UP * 3.3, reel, lourd, false, self, source, critique)
	Combat.flash(visuel)
	return reel


func etourdir(duree: float) -> void:
	super.etourdir(duree * EQ.bosco_etourdissement)


func immobiliser(duree: float) -> void:
	super.immobiliser(duree * EQ.bosco_etourdissement)


func coup_parable() -> bool:
	return attaque == Attaque.COUP


## Paré, son coup au sol laisse le héros jusqu'à ~5 m de lui : la riposte doit encore l'atteindre
## (vu par le relecteur : à 4 m, elle frappait dans le vide).
func portee_riposte() -> float:
	return 0.6 + EQ.bosco_coup_longueur + 0.4


## Zone dorée à la fin de l'annonce : seulement pour le coup qui se pare.
func signal_parade() -> bool:
	return attaque == Attaque.COUP and etat == Etat.PREPARATION and _duree_annonce() - _t <= EQ.parade_signal_avance


func _quitter_etat(ancien: Etat, nouvel: Etat) -> void:
	if ancien == Etat.INCANTATION and _rage_faite and not _renforts_appeles and not marionnette and nouvel != Etat.MORT:
		_renforts_appeles = true   # cri coupé (chaînes, étourdissement) : son équipage vient quand même
		_appeler_renforts()
	if nouvel == Etat.ETOURDI or nouvel == Etat.ENCHAINE:
		_montrer_etoiles(nouvel == Etat.ETOURDI)
	elif ancien == Etat.ETOURDI:
		_montrer_etoiles(false)
	if nouvel == Etat.MORT:
		remove_from_group("boss")
		_montrer_etoiles(false)
		if _lueur:
			_lueur.light_energy = 0.0
		if not marionnette:
			for r in renforts:   # son équipage s'effondre avec lui
				if is_instance_valid(r) and r.est_vivant():
					r.sante.subir(r.sante.pv, null)


# ---------------------------------------------------------------- annonces au sol
func _montrer_annonce(oui: bool) -> void:
	marque.visible = false
	if _annonce:
		_annonce.visible = oui and etat == Etat.PREPARATION and attaque != Attaque.AUCUNE


## Construit la zone de l'attaque en cours : rectangle (coup), disque (tourbillon), ligne (charge).
func _construire_annonce() -> void:
	for c in _annonce.get_children():
		c.queue_free()
	var zone := MeshInstance3D.new()
	var plein := MeshInstance3D.new()
	_jauge = Node3D.new()
	match attaque:
		Attaque.COUP, Attaque.CHARGE:
			var longueur := EQ.bosco_coup_longueur if attaque == Attaque.COUP else _longueur_charge
			var largeur := EQ.bosco_coup_largeur if attaque == Attaque.COUP else EQ.bosco_charge_largeur
			var debut := 0.6
			var b := BoxMesh.new()
			b.size = Vector3(largeur, 0.02, longueur)
			zone.mesh = b
			zone.position.z = debut + longueur * 0.5
			plein.mesh = b
			plein.position.z = longueur * 0.5   # dans la jauge, qui part du bord proche
			_jauge.position.z = debut
		Attaque.TOURBILLON:
			var c := CylinderMesh.new()
			c.top_radius = EQ.bosco_tourbillon_rayon
			c.bottom_radius = EQ.bosco_tourbillon_rayon
			c.height = 0.02
			c.radial_segments = 40
			c.rings = 1
			zone.mesh = c
			plein.mesh = c
	zone.material_override = _mat_zone_annonce
	plein.material_override = _mat_rempli
	for m in [zone, plein]:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_annonce.add_child(zone)
	_jauge.add_child(plein)
	plein.position.y = 0.004
	_annonce.add_child(_jauge)
	_jauge.scale = Vector3(0.01, 1, 0.01) if attaque == Attaque.TOURBILLON else Vector3(1, 1, 0.01)


## La zone se remplit pendant l'annonce (aussi chez l'invité). Coup : rouge puis doré à la fin
## (parer maintenant) ; tourbillon et charge : rouge sombre, jamais doré (imparables).
func _preparer_visuel() -> void:
	if _jauge == null or not is_instance_valid(_jauge):
		return
	var p := clampf(_t / maxf(_duree_annonce(), 0.01), 0.01, 1.0)
	_jauge.scale = Vector3(p, 1, p) if attaque == Attaque.TOURBILLON else Vector3(1, 1, p)
	if attaque == Attaque.COUP:
		if signal_parade():
			_mat_rempli.albedo_color = Color(1.0, 0.86, 0.25, 0.85)
			_mat_zone_annonce.albedo_color = Color(1.0, 0.8, 0.2, 0.4)
		else:
			_mat_rempli.albedo_color = Color(1.0, 0.3 + 0.2 * p, 0.1, 0.3 + 0.35 * p)
			_mat_zone_annonce.albedo_color = COULEUR_ZONE
	else:
		_mat_rempli.albedo_color = Color(ROUGE_SOMBRE, 0.55 + 0.3 * p)
		_mat_zone_annonce.albedo_color = Color(0.12, 0.0, 0.02, 0.4)


# ---------------------------------------------------------------- sonné : étoiles
func _montrer_etoiles(oui: bool) -> void:
	if not oui:
		if _etoiles:
			_etoiles.visible = false
		return
	if _etoiles == null:
		_etoiles = Node3D.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.9, 0.3)
		var boule := SphereMesh.new()
		boule.radius = 0.12
		boule.height = 0.24
		boule.radial_segments = 6
		boule.rings = 3
		for i in 4:
			var e := MeshInstance3D.new()
			e.mesh = boule
			e.material_override = mat
			e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var a := TAU * i / 4.0
			e.position = Vector3(cos(a) * 0.55, 0, sin(a) * 0.55)
			_etoiles.add_child(e)
		_etoiles.position = Vector3(0, 3.4, 0)
		add_child(_etoiles)
	_etoiles.visible = true


func _process(delta: float) -> void:
	if _etoiles and _etoiles.visible:
		_etoiles.rotate_y(4.0 * delta)


# ---------------------------------------------------------------- coop (invité)
## L'hôte a lancé une attaque (dessiner la bonne zone) ou la rage de ce Bosco.
func effet_recu(type: String, pos: Vector3) -> void:
	if type == "bosco_rage":
		_rage_faite = true
		_devenir_enrage()
		return
	var i := NOMS_ATTAQUES.find(type.trim_prefix("bosco_"))
	if i <= 0:
		return
	attaque = i as Attaque
	if attaque == Attaque.CHARGE:
		var d := pos - global_position
		d.y = 0.0
		_longueur_charge = maxf(d.length(), 1.0)
	_construire_annonce()
	_preparer_visuel()
	_montrer_annonce(true)
