extends SceneTree
## Captures du jalon 3, étape 3 : le Bosco Maudit (portrait à côté d'un matelot et d'un héros, sortie
## de terre et barre de vie, coup au sol puis doré, tourbillon, charge, sonné contre un mur, rage et
## renforts), le choix de la malédiction, la chaloupe sous les vagues (compte à rebours, vagues), l'écran
## de fin enrichi. Affiche aussi l'état dans la console.
## Usage : xvfb-run -a godot --path . --rendering-method gl_compatibility --rendering-driver opengl3
##         --resolution 1280x720 -s <chemin absolu>/tools/capture_bosco.gd -- <dossier>
## Ne pas typer avec les classes du jeu (voir CLAUDE.md, pièges).

const PREPARATION := 2
const FRAPPE := 3
const ETOURDI := 6
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


func _attendre(condition: Callable, max := 600) -> bool:
	for i in max:
		if condition.call():
			return true
		await physics_frame
	print("  (attente trop longue)")
	return false


func _regarder(depuis: Vector3, vers: Vector3, fov := 45.0) -> void:
	cam.fov = fov
	cam.look_at_from_position(depuis, vers)
	cam.current = true


func _expedition(depart: StringName):
	partie.debug_depart = depart
	var e = load("res://game/expedition/expedition.tscn").instantiate()
	root.add_child(e)
	await _images(5)
	e.hud.menu_demande.disconnect(e.retour_menu)
	cam = Camera3D.new()
	e.add_child(cam)
	return e


func _go() -> void:
	dossier = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "build/apercus"
	partie = root.get_node("Partie")
	partie.heros_local = &"bretteur"
	partie.debug_sante_infinie = true
	await _portrait()
	await _choix_malediction()

	# ---- l'antre : le Bosco surgit (malédiction 3 : le niveau s'affiche sous les PV)
	partie.destination = &"expedition"
	partie.malediction = 3
	var e = await _expedition(&"bosco")
	var b = e.bosco
	var h = e.heros
	h.sante.rendre_invulnerable(1000.0)
	await _images(40)
	e.camera.current = true
	await _capture("bosco_surgit.png")
	await _attendre(func(): return b.etat != 0, 400)
	b.set_physics_process(false)
	await _images(10)
	print("Bosco : %.0f PV, état %d" % [b.sante.pv, b.etat])

	# ---- coup au sol : la zone rouge, puis dorée (le moment de parer)
	h.global_position = Vector3(-0.4, 0, 1.0)
	b.global_position = Vector3(-0.4, 0, -2.4)
	b.rotation.y = 0.0
	h.rotation.y = PI
	b.set_physics_process(true)
	b._commencer(1, Vector3(0, 0, 1))
	await _images(int(0.4 * 60))
	Engine.time_scale = 0.05   # (le rendu sans carte graphique est lent : on fige presque le jeu)
	await _capture("bosco_coup_annonce.png")
	Engine.time_scale = 1.0
	await _attendre(func(): return b.signal_parade(), 120)
	Engine.time_scale = 0.05
	await _capture("bosco_coup_dore.png")
	Engine.time_scale = 1.0
	await _attendre(func(): return b.etat != PREPARATION and b.etat != FRAPPE, 200)

	# ---- tourbillon : cercle rouge sombre (imparable)
	b._commencer(2, Vector3(0, 0, 1))
	await _images(int(0.7 * 60))
	Engine.time_scale = 0.05
	await _capture("bosco_tourbillon_annonce.png")
	Engine.time_scale = 1.0
	await _attendre(func(): return b.etat == FRAPPE, 200)
	await _images(10)
	await _capture("bosco_tourbillon.png")
	await _attendre(func(): return b.etat != FRAPPE, 200)
	await _images(70)

	# ---- charge vers le héros, contre le mur du fond : sonné
	b.global_position = Vector3(-0.4, 0, 3.6)
	b.rotation.y = PI
	h.global_position = Vector3(-1.4, 0, -0.6)
	h.rotation.y = 0.0
	b._recharge_attaque = 0.0
	b._commencer(3, Vector3(0, 0, -1))
	print("charge : %.1f m, mur %s" % [b._longueur_charge, b._mur])
	await _images(int(0.6 * 60))
	_regarder(Vector3(7.0, 7.5, 6.5), Vector3(-0.4, 0.5, -0.8), 52.0)
	await _capture("bosco_charge_annonce.png")
	await _attendre(func(): return b.etat == FRAPPE, 200)
	await _images(16)
	await _capture("bosco_charge.png")
	await _attendre(func(): return b.etat == ETOURDI, 200)
	await _images(25)
	_regarder(b.global_position + Vector3(4.5, 5.0, 6.0), b.global_position + Vector3(0, 1.4, 0), 45.0)
	print("après la charge : état %d (6 = sonné), position %s" % [b.etat, b.global_position])
	await _capture("bosco_sonne.png")
	await _attendre(func(): return b.etat != ETOURDI, 300)

	# ---- rage à mi-vie : cri, lueur rouge, trois matelots
	h.global_position = Vector3(2.8, 0, 3.6)
	b.sante.subir(b.sante.pv - b.sante.pv_max * 0.45, h)
	await _attendre(func(): return b.etat == INCANTATION, 200)
	await _images(int(1.1 * 60))
	_regarder(b.global_position + Vector3(5.0, 6.0, 7.5), b.global_position + Vector3(0, 0.8, 0.5), 52.0)
	e.camera.current = false
	cam.current = true
	await _capture("bosco_rage.png")
	await _images(60)
	e.camera.current = true
	await _images(20)
	await _capture("bosco_enrage_hud.png")
	print("rage : enragé %s, %d squelettes dans l'antre" % [b.enrage, e.generateur.get_child_count()])
	e.queue_free()
	await _images(3)

	# ---- la chaloupe sous les vagues
	partie.malediction = 2
	e = await _expedition(&"chaloupe")
	h = e.heros
	h.sante.rendre_invulnerable(1000.0)
	h.global_position = e.salle.zone_chaloupe
	await _images(10)
	e._verifier_chaloupe(20.0)   # 20 s plus tard : la houle a grossi, trois vagues sont sorties
	await _images(150)
	print("chaloupe : %.1f s restantes, %d vagues, houle %.2f" % [e.chaloupe_restant, e.vagues_lancees, e.salle.houle])
	e.camera.current = true
	await _capture("chaloupe_compte.png")
	_regarder(Vector3(3.0, 8.0, 9.0), Vector3(-3.6, 0, 0.0), 55.0)
	await _capture("chaloupe_vagues.png")
	e.salle.houle = 1.0
	_regarder(Vector3(-0.5, 3.2, 4.5), Vector3(-4.8, -0.3, -0.5), 50.0)
	await _images(10)
	await _capture("chaloupe_houle.png")
	h.global_position = e.salle.zone_chaloupe + Vector3(4.8, 0, -1.0)
	await _images(4)
	e.camera.current = true
	await _images(20)
	await _capture("chaloupe_remontez.png")
	h.global_position = e.salle.zone_chaloupe
	await _images(4)
	e._verifier_chaloupe(60.0)
	await _images(60)
	await _capture("fin_enrichie.png")
	e.queue_free()
	await _images(3)
	quit()


## Le Bosco à côté d'un matelot et du Bretteur, sur fond neutre, en pose d'attaque.
func _portrait() -> void:
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
	var b = Ennemi.creer_type(&"bosco", true)
	b.position = Vector3(0.6, 0, 0)
	studio.add_child(b)
	var m = Ennemi.creer_type(&"matelot", true)
	m.position = Vector3(-1.9, 0, 0.4)
	studio.add_child(m)
	var h = load("res://game/player/heros.gd").creer(&"bretteur")
	h.position = Vector3(3.2, 0, 0.6)
	studio.add_child(h)
	await _images(30)
	for x in [b, m]:
		x.set_physics_process(false)
		x.rotation.y = 0.3
	b._jouer("2H_Melee_Attack_Chop", 1.0, 0.0, true)
	b.anim.seek(0.57, true)
	b.anim.pause()
	m._jouer("Idle_Combat")
	h.set_physics_process(false)
	h.rotation.y = -0.4
	cam = Camera3D.new()
	studio.add_child(cam)
	_regarder(Vector3(0.6, 2.8, 8.5), Vector3(0.4, 1.4, 0.0), 42.0)
	await _images(4)
	await _capture("bosco_portrait.png")
	studio.queue_free()
	await _images(2)


## Le choix de la malédiction sur l'écran du héros (expédition en solo).
func _choix_malediction() -> void:
	partie.destination = &"expedition"
	partie.malediction = 3
	var ecran = load("res://ui/screens/choix_heros.tscn").instantiate()
	ecran.changer_de_scene = false
	root.add_child(ecran)
	await _images(10)
	await _capture("malediction_choix.png")
	ecran.queue_free()
	await _images(2)
	partie.malediction = 0
