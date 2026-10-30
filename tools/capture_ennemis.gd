extends SceneTree
## Captures du jalon 3, étape 2 : arbalétrier squelette (trait rouge, carreau, renvoi par la Parade),
## prêtre noyé (cercle sur une tombe, mort relevé, flaque annoncée puis posée), salles piège (dalles
## à pics, tonneaux de poudre, explosion), porte « piège ». Affiche aussi l'état dans la console.
## Usage : xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3
##         --resolution 1280x720 -s <chemin absolu>/tools/capture_ennemis.gd -- <dossier>
## Ne pas typer avec les classes du jeu (voir CLAUDE.md, pièges).

const PREPARATION := 2
const FRAPPE := 3
const INCANTATION := 9

var dossier := ""
var partie
var cam: Camera3D


func _initialize() -> void:
	_go()


func _images(n: int) -> void:
	for i in n:
		await physics_frame


func _capture(nom: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(dossier)
	var chemin := dossier.path_join(nom)
	if root.get_texture().get_image().save_png(chemin) != OK:
		push_error("capture impossible : " + chemin)
		quit(1)
	print("Capture : ", chemin)


## Attend (au plus `max` images) que `condition` soit vraie.
func _attendre(condition: Callable, max := 600) -> bool:
	for i in max:
		if condition.call():
			return true
		await physics_frame
	print("  (attente trop longue)")
	return false


func _expedition():
	partie.debug_depart = &""
	var e = load("res://game/expedition/expedition.tscn").instantiate()
	root.add_child(e)
	await _images(5)
	e.hud.menu_demande.disconnect(e.retour_menu)
	e.heros.sante.rendre_invulnerable(1000.0)
	return e


## Vide la horde de la salle (sans tombes) : on place nous-mêmes les ennemis.
func _vider(e) -> void:
	e.generateur.reserve = 0
	e.generateur.a_venir.clear()
	for s in e.generateur.get_children():
		s.queue_free()
	await _images(2)
	e.generateur.tombes.clear()


func _carreau_a_moins_de(e, h, d: float) -> bool:
	for c in e.get_children():
		if c.get("renvoye") == false and c.global_position.distance_to(h.global_position + Vector3.UP * 1.25) < d:
			return true
	return false


func _renvoye(e) -> bool:
	for c in e.get_children():
		if c.get("renvoye") == true:
			return true
	return false


## Un moment où des dalles rougeoient et d'autres ont leurs pics sortis.
func _phases_melees(e) -> bool:
	var phases := {}
	for p in e.salle.pics:
		phases[p.phase(e.temps_salle)] = true
	return phases.has(1) and (phases.has(2) or e.salle.pics.size() < 3)


func _pics_sortis(e) -> bool:
	for p in e.salle.pics:
		if p.phase(e.temps_salle) == 2:
			return true
	return false


func _regarder(depuis: Vector3, vers: Vector3, fov := 45.0) -> void:
	cam.fov = fov
	cam.look_at_from_position(depuis, vers)
	cam.current = true


## Les trois squelettes seuls, sur fond neutre, en pose d'attaque : vérifier modèles et armes.
func _portraits() -> void:
	var studio := Node3D.new()
	root.add_child(studio)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.17, 0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.8)
	env.ambient_light_energy = 0.6
	we.environment = env
	studio.add_child(we)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-45, 30, 0)
	soleil.light_energy = 1.1
	studio.add_child(soleil)
	var sol := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(20, 20)
	sol.mesh = plan
	studio.add_child(sol)
	var dur := StaticBody3D.new()   # sinon ils tombent (pesanteur)
	dur.collision_layer = 1
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(20, 0.2, 20)
	forme.shape = boite
	forme.position.y = -0.1
	dur.add_child(forme)
	studio.add_child(dur)
	var Ennemi = load("res://game/enemies/ennemi.gd")
	var poses := {&"matelot": ["1H_Melee_Attack_Chop", Vector3(-2.2, 0, 0)], &"arbaletrier": ["2H_Ranged_Aiming", Vector3(0, 0, 0)],
			&"pretre": ["Spellcasting", Vector3(2.2, 0, 0)]}
	var liste := []
	for type in poses:
		var x = Ennemi.creer_type(type, true)
		x.position = poses[type][1]
		studio.add_child(x)
		liste.append([x, poses[type][0]])
	await _images(90)   # (sortie de terre rapide)
	for l in liste:
		l[0].set_physics_process(false)
		l[0].rotation.y = 0.35
		l[0]._jouer(l[1], 1.0, 0.0, true)
		l[0].anim.seek(0.45, true)
		l[0].anim.pause()
	cam = Camera3D.new()
	studio.add_child(cam)
	_regarder(Vector3(1.2, 2.6, 7.2), Vector3(0.0, 1.0, 0.0), 40.0)
	await _images(4)
	await _capture("ens_portraits.png")
	_regarder(Vector3(7.5, 1.8, 1.2), Vector3(0.0, 1.0, 0.0), 40.0)
	await _images(2)
	await _capture("ens_portraits_cote.png")
	# l'effet d'explosion d'un tonneau, seul, à trois instants
	for l in liste:
		l[0].queue_free()
	_regarder(Vector3(3.0, 4.5, 7.5), Vector3(0.0, 0.8, 0.0), 45.0)
	load("res://game/combat/effets_magie.gd").explosion(studio, Vector3(0, 0.5, 0))
	for n in [2, 8, 20]:
		await _images(n if n == 2 else 6 if n == 8 else 12)
		await _capture("ens_effet_explosion_%d.png" % n)
	studio.queue_free()
	await _images(2)


func _go() -> void:
	dossier = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "build/apercus"
	partie = root.get_node("Partie")
	partie.heros_local = &"bretteur"
	partie.debug_sante_infinie = true
	await _portraits()
	var e = await _expedition()
	cam = Camera3D.new()
	e.add_child(cam)
	await _vider(e)
	# une salle connue, au centre dégagé (piliers en (-2,6 ; -3,2), (4,2 ; -2,6), (-2,8 ; 2,6))
	e._construire_salle(1, &"combat", "salle_gardes", [&"piege", &"combat"])
	e.hud.afficher_salle(e._texte_salle())
	var h = e.heros

	# ---- les trois squelettes côte à côte
	var arb = e.generateur._faire_apparaitre(Vector3(0.2, 0, -0.6), &"arbaletrier")
	var pretre = e.generateur._faire_apparaitre(Vector3(-1.6, 0, 0.4), &"pretre")
	var mat = e.generateur._faire_apparaitre(Vector3(1.9, 0, 0.5), &"matelot")
	h.global_position = Vector3(30, 0, 30)   # loin : ils restent tranquilles le temps de sortir de terre
	await _images(170)
	_regarder(Vector3(0.5, 3.0, 7.8), Vector3(0.2, 0.9, -0.1), 40.0)
	for x in [arb, pretre, mat]:
		x.set_physics_process(false)
		x.velocity = Vector3.ZERO
		x.rotation.y = atan2(cam.global_position.x - x.global_position.x, cam.global_position.z - x.global_position.z)
		x._jouer("Idle_Combat")
	await _images(20)
	await _capture("ens_trio.png")
	for x in [arb, pretre, mat]:
		x.set_physics_process(true)
	pretre._recharge_relever = 99.0
	pretre._recharge_attaque = 99.0
	mat.sante.subir(9999.0, h)   # il laisse une tombe pour le prêtre
	await _images(60)
	for o in e.orbes.get_children():
		o.queue_free()

	# ---- arbalétrier : il vise (trait rouge), puis le carreau file
	h.global_position = Vector3(3.2, 0, 3.6)
	h.rotation.y = -PI * 0.75
	pretre.global_position = Vector3(-4.0, 0, -0.6)
	arb.global_position = Vector3(-1.0, 0, -3.0)
	arb._recharge_attaque = 0.0
	await _attendre(func(): return arb.etat == PREPARATION)
	await _images(int(0.45 * 60))
	_regarder(Vector3(6.5, 6.0, 8.0), Vector3(0.6, 0.6, -0.2), 50.0)
	print("arbalétrier : état %d, trait visible %s" % [arb.etat, arb._visee.visible])
	await _capture("ens_arbaletrier_vise.png")
	await _attendre(func(): return arb.etat == FRAPPE)
	await _images(14)   # le carreau est à mi-chemin
	Engine.time_scale = 0.05
	await _capture("ens_carreau.png")
	Engine.time_scale = 1.0
	await _images(60)

	# ---- Parade parfaite : le carreau repart vers l'arbalétrier (héros plus intouchable : sinon le
	# carreau le traverse comme pendant une roulade ; santé infinie à la place)
	h.sante.invulnerable_jusqua = 0.0
	arb.sante.pv_max = 500.0   # qu'il survive au carreau renvoyé, le temps de la capture
	arb.sante.definir_pv(500.0)
	arb._recharge_attaque = 0.0
	await _attendre(func(): return arb.etat == FRAPPE)
	# la Parade part quand le carreau arrive (fenêtre parfaite : 0,35 s)
	await _attendre(_carreau_a_moins_de.bind(e, h, 2.6), 120)
	h.commandes.demander(&"competence_1", h.horloge)
	for i in 40:
		await physics_frame
		if _renvoye(e):
			break
	print("héros : état %d (t = %.2f) ; carreau renvoyé : %s" % [h.etat, h._t, _renvoye(e)])
	Engine.time_scale = 0.1
	await _images(3)
	await _capture("ens_carreau_renvoye.png")
	Engine.time_scale = 1.0
	await _images(90)
	print("arbalétrier après le renvoi : %.0f / %.0f PV" % [arb.sante.pv, arb.sante.pv_max])
	arb.set_physics_process(false)
	arb.global_position = Vector3(30, 0, -30)

	# ---- prêtre : il relève le matelot tombé (cercle vert sur la tombe)
	print("tombes : %s" % [e.generateur.tombes])
	var tombe := Vector3(1.4, 0, 0.8)
	e.generateur.tombes[0]["pos"] = tombe   # (posée au bon endroit pour la photo)
	pretre.global_position = Vector3(-1.4, 0, -0.6)
	h.global_position = Vector3(30, 0, 30)
	pretre._recharge_relever = 0.0
	await _attendre(func(): return pretre.etat == INCANTATION, 200)
	await _images(int(1.0 * 60))
	var milieu: Vector3 = (pretre.global_position + tombe) * 0.5
	_regarder(milieu + Vector3(1.8, 4.6, 6.0), milieu + Vector3(0.9, 0.4, 0.5), 50.0)
	await _capture("ens_pretre_releve.png")
	await _images(int(1.2 * 60))
	await _capture("ens_mort_releve.png")
	for x in e.generateur.get_children():
		if x != pretre and x != arb:
			x.queue_free()

	# ---- prêtre : la flaque maudite, annoncée puis posée
	h.global_position = Vector3(0.8, 0, 2.6)
	pretre._recharge_relever = 99.0
	pretre._recharge_attaque = 0.0
	await _attendre(func(): return pretre.etat == PREPARATION, 300)
	await _images(int(0.6 * 60))
	milieu = (pretre.global_position + h.global_position) * 0.5
	_regarder(milieu + Vector3(2.4, 6.0, 7.5), milieu + Vector3(1.1, 0.4, 0.8), 50.0)
	await _capture("ens_flaque_annonce.png")
	await _images(int(1.0 * 60))
	h.global_position += Vector3(1.6, 0, 1.0)
	await _images(10)
	await _capture("ens_flaque.png")

	# ---- porte « piège » (salle nettoyée)
	pretre.queue_free()
	arb.queue_free()
	e.salle.ouvrir_portes()
	h.global_position = Vector3(3.2, 0, 3.6)
	_regarder(Vector3(7.0, 9.5, 8.0), Vector3(-1.6, 0.8, -2.6), 55.0)
	await _images(40)
	await _capture("ens_porte_piege.png")

	# ---- salles piège
	for m in ["salle_pics", "poudriere"]:
		e._changer_de_salle(2, &"piege", m, [&"combat", &"tresor"])
		await _images(5)
		e.heros.sante.rendre_invulnerable(1000.0)
		await _images(200)   # le message d'accueil s'efface
		print("%s : %d dalles à pics, %d tonneaux" % [m, e.salle.pics.size(), e.salle.tonneaux.size()])
		# un moment où des dalles rougeoient et d'autres ont leurs pics sortis
		await _attendre(_phases_melees.bind(e), 400)
		await _images(4)
		_regarder(Vector3(10.5, 15.0, 10.5), Vector3(-0.6, 0, -0.6), 50.0)
		await _capture("ens_%s.png" % m)
		await _attendre(_pics_sortis.bind(e), 400)
		await _images(6)
		var p0 = null
		for p in e.salle.pics:
			if p.phase(e.temps_salle) == 2:
				p0 = p
		var c: Vector3 = p0.global_position
		_regarder(c + Vector3(3.2, 3.4, 4.2), c + Vector3(0, 0.4, 0), 45.0)
		await _capture("ens_%s_pics.png" % m)

	# ---- explosion d'un tonneau de la poudrière (squelettes autour)
	var t = e.salle.tonneaux[2]
	e.heros.global_position = t.global_position + Vector3(-2.0, 0, -1.4)   # derrière le tonneau (vu d'ici)
	for i in 3:
		e.generateur._faire_apparaitre(t.global_position + Vector3(1.3 * cos(i * 2.1), 0, 1.3 * sin(i * 2.1) + 0.8), &"matelot")
	await _images(170)
	_regarder(t.global_position + Vector3(5.0, 5.5, 7.0), t.global_position + Vector3(0, 0.6, 0), 48.0)
	await _capture("ens_tonneau_avant.png")
	load("res://game/combat/combat.gd").porter_coup(e.heros, t, 10.0, false)
	await _attendre(func(): return t.explose, 120)
	Engine.time_scale = 0.15
	await _images(2)
	await _capture("ens_explosion.png")
	Engine.time_scale = 1.0
	await _images(30)
	await _capture("ens_apres_explosion.png")
	var vivants := 0
	for x in e.generateur.get_children():
		if x.est_vivant():
			vivants += 1
	print("après l'explosion : %d squelettes debout, héros %.0f PV" % [vivants, e.heros.sante.pv])
	e.queue_free()
	await _images(3)
	quit()
