class_name Ambiance
extends RefCounted
## La lumière du jeu, façon Diablo IV (06/11 : choisie par Téo sur la planche d'essai, tools/capture_style.gd) :
## presque tout dans l'ombre, couleurs ternes, brume, torches orangées qui font des taches de lumière, une lumière
## qui suit chaque héros (HaloHeros) et les bords de l'écran assombris (EffetsUI.vignette, dans les HUD).
## Partagée par l'arène, les salles d'expédition et le repaire.

const TORCHE := Color(1.0, 0.52, 0.22)
const LUNE := Color(0.55, 0.62, 0.8)


## L'environnement : fond presque noir, lumière ambiante faible et grise, étalonnage terne et contrasté (AgX).
static func environnement(densite_brume := 0.022) -> WorldEnvironment:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.008, 0.01, 0.012)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.36, 0.4, 0.44)
	e.ambient_light_energy = 0.5
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.6
	e.fog_enabled = true
	e.fog_light_color = Color(0.035, 0.05, 0.05)
	e.fog_density = densite_brume
	e.glow_enabled = true
	e.glow_intensity = 1.1
	e.glow_bloom = 0.08
	e.adjustment_enabled = true
	e.adjustment_brightness = 0.95
	e.adjustment_contrast = 1.14
	e.adjustment_saturation = 0.6
	we.environment = e
	return we


## La lune : froide et faible (elle dessine les ombres sans éclairer la salle).
static func lune(energie: float, portee_ombres: float) -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-55, -30, 0)
	l.light_color = LUNE
	l.light_energy = energie
	l.shadow_enabled = true
	l.directional_shadow_max_distance = portee_ombres
	return l


## Une torche : orangée, qui s'éteint vite en s'éloignant (des taches de lumière, pas une salle éclairée).
static func torche(pos: Vector3, ombre: bool) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = TORCHE
	l.light_energy = 2.4
	l.omni_range = 9.2
	l.omni_attenuation = 1.25
	l.shadow_enabled = ombre
	l.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
	return l
