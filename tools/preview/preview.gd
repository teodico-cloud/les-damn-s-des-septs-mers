extends Node3D
# Aperçu de modèles .glb (lancé par render.sh).
# Config JSON : {"out": png, "dark": bool, "floor": bool,
#   "items": [{"glb": chemin, "hide": [noms de meshes], "anim": nom, "t": 0.5, "pos": [x,y,z], "rot": degrés,
#              "scale": 1, "label": texte, "label_h": hauteur}],
#   "lights": [{"pos": [x,y,z], "color": [r,g,b], "energy": 2, "range": 5}],
#   "cam": {"target": [x,y,z], "dir": [x,y,z], "dist": d, "fov": f}}  (ou "ortho": taille)
# Les chemins relatifs sont résolus depuis le dossier du fichier de config.

var cfg_dir := ""

func resolve(p: String) -> String:
	return p if p.is_absolute_path() else cfg_dir.path_join(p).simplify_path()

func load_glb(path: String) -> Node3D:
	var doc := GLTFDocument.new(); var st := GLTFState.new()
	var err := doc.append_from_file(path, st)
	if err != OK: push_error("load fail " + path); return Node3D.new()
	return doc.generate_scene(st)

func _ready() -> void:
	var cfg_path: String = OS.get_cmdline_user_args()[0]
	cfg_dir = cfg_path.get_base_dir()
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(cfg_path))
	var dark: bool = cfg.get("dark", false)
	var we := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var sun := DirectionalLight3D.new(); add_child(sun); sun.shadow_enabled = true
	if dark:
		e.background_color = Color(0.03, 0.04, 0.06); e.ambient_light_color = Color(0.3, 0.4, 0.55); e.ambient_light_energy = 0.45
		e.glow_enabled = true; e.glow_intensity = 1.0; e.glow_bloom = 0.1
		sun.light_color = Color(0.55, 0.65, 1.0); sun.light_energy = 0.4; sun.rotation_degrees = Vector3(-50, 40, 0)
		var key := OmniLight3D.new(); add_child(key); key.position = Vector3(-3, 3.5, 4); key.light_color = Color(1, 0.6, 0.25); key.light_energy = 2.5; key.omni_range = 14
	else:
		e.background_color = Color(0.2, 0.22, 0.26); e.ambient_light_color = Color(1, 1, 1); e.ambient_light_energy = 0.55
		sun.light_energy = 0.9; sun.rotation_degrees = Vector3(-40, 25, 0)
	we.environment = e; add_child(we)
	if cfg.get("floor", true):
		var f := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(60, 60); f.mesh = pm
		var fm := StandardMaterial3D.new(); fm.albedo_color = Color(0.32, 0.3, 0.28) if not dark else Color(0.2, 0.2, 0.22); f.material_override = fm; add_child(f)
	for it in cfg["items"]:
		var n := load_glb(resolve(it["glb"])); add_child(n)
		var p: Array = it.get("pos", [0, 0, 0]); n.position = Vector3(p[0], p[1], p[2])
		n.rotation_degrees.y = it.get("rot", 0.0); n.scale = Vector3.ONE * it.get("scale", 1.0)
		var hide: Array = it.get("hide", [])
		for m in n.find_children("*", "MeshInstance3D", true, false):
			if m.name in hide: m.visible = false
		var ap: AnimationPlayer = n.find_child("AnimationPlayer", true, false)
		if ap and it.has("anim") and ap.has_animation(it["anim"]):
			ap.play(it["anim"]); ap.seek(it.get("t", 0.5), true); ap.pause()
		if it.has("label"):
			var l := Label3D.new(); add_child(l); l.text = it["label"]; l.position = n.position + Vector3(0, it.get("label_h", 2.9), 0)
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.font_size = 26; l.pixel_size = 0.01; l.outline_size = 8; l.no_depth_test = true
	for li in cfg.get("lights", []):
		var o := OmniLight3D.new(); add_child(o); o.position = Vector3(li["pos"][0], li["pos"][1], li["pos"][2])
		o.light_color = Color(li["color"][0], li["color"][1], li["color"][2]); o.light_energy = li.get("energy", 2.0); o.omni_range = li.get("range", 5.0)
	var c := Camera3D.new(); add_child(c)
	var cc: Dictionary = cfg["cam"]
	var tg := Vector3(cc["target"][0], cc["target"][1], cc["target"][2]); var d := Vector3(cc["dir"][0], cc["dir"][1], cc["dir"][2]).normalized()
	c.look_at_from_position(tg + d * cc.get("dist", 10.0), tg, Vector3.UP)
	if cc.has("ortho"): c.projection = Camera3D.PROJECTION_ORTHOGONAL; c.size = cc["ortho"]
	else: c.fov = cc.get("fov", 35.0)
	c.current = true
	for i in 12: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var out := resolve(cfg["out"])
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
