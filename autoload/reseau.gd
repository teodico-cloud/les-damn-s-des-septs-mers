extends Node
## Session de coop sur le même Wi-Fi (autoload « Reseau »). Un téléphone héberge (il devient l'hôte et
## décide de tout), l'autre le rejoint. L'hôte s'annonce sur le Wi-Fi toutes les demi-secondes ;
## l'invité écoute ces annonces et affiche les parties trouvées. Si le Wi-Fi bloque les annonces,
## l'invité tape le petit code affiché chez l'hôte (le dernier nombre de son adresse sur le Wi-Fi).

signal partie_trouvee(adresse: String, infos: Dictionary)
signal partenaire_connecte(infos: Dictionary)   ## les deux côtés : la partie à deux est prête
signal partenaire_parti(raison: String)
signal echec(raison: String)
signal combat_lance

const PORT_JEU := 34778
const PORT_ANNONCE := 34779
const VERSION_RESEAU := 7        ## à augmenter quand le protocole change (refuse un autre APK) ; 7 : Bosco, malédiction, chaloupe
const DELAI_ANNONCE := 0.5

enum Role { AUCUN, HOTE, INVITE }

var role := Role.AUCUN
var id_partenaire := 0
var heros_partenaire: StringName = &""
## Arène en cours (SynchroArene) : les messages de l'invité passent par ce nœud-ci, qui existe des
## deux côtés dès le démarrage, puis lui sont transmis (l'arène de l'hôte peut s'ouvrir après).
var synchro: Node
## Essais seulement (tools/test_coop.sh) : retard, irrégularité (secondes) et part de messages perdus
## simulés à la réception, pour vérifier la coop sur un Wi-Fi imparfait. Toujours 0 dans le jeu.
var latence_simulee := 0.0
var gigue_simulee := 0.0
var perte_simulee := 0.0
var _annonceur: PacketPeerUDP
var _ecouteur: PacketPeerUDP
var _minuterie := 0.0
var _infos_hote := {}


func _ready() -> void:
	# vérification au tout premier contact (avant tout message du jeu) : même version, place libre.
	# Faite ici et non par un message du jeu : si deux versions n'ont pas les mêmes messages, Godot
	# refuserait de les échanger et l'invité resterait bloqué sur « Connexion… ».
	var sm := multiplayer as SceneMultiplayer
	sm.auth_callback = _on_authentification
	sm.auth_timeout = 4.0
	sm.peer_authenticating.connect(_on_debut_authentification)
	multiplayer.peer_connected.connect(_on_pair_connecte)
	multiplayer.peer_disconnected.connect(_on_pair_deconnecte)
	multiplayer.connected_to_server.connect(_on_connecte_a_l_hote)
	multiplayer.connection_failed.connect(_on_connexion_ratee)
	multiplayer.server_disconnected.connect(_on_hote_parti)


func est_en_coop() -> bool:
	return role != Role.AUCUN and id_partenaire != 0


func est_hote() -> bool:
	return role == Role.HOTE


func est_invite() -> bool:
	return role == Role.INVITE


# ---------------------------------------------------------------- héberger
func heberger(heros: StringName) -> Error:
	quitter()
	var pair := ENetMultiplayerPeer.new()
	var err := pair.create_server(PORT_JEU, 2)   # 2 : un 3e téléphone peut entrer juste le temps d'apprendre que c'est complet
	if err != OK:
		return err
	multiplayer.multiplayer_peer = pair
	role = Role.HOTE
	_infos_hote = {"jeu": "damnes", "v": VERSION_RESEAU, "heros": String(heros), "code": code_local()}
	_annonceur = PacketPeerUDP.new()
	_annonceur.set_broadcast_enabled(true)
	_minuterie = 0.0
	return OK


# ---------------------------------------------------------------- premier contact
func _on_debut_authentification(id: int) -> void:
	var infos := {"v": VERSION_RESEAU}
	if role == Role.HOTE:
		infos["plein"] = id_partenaire != 0
	(multiplayer as SceneMultiplayer).send_auth(id, var_to_bytes(infos))


func _on_authentification(id: int, donnees: PackedByteArray) -> void:
	var sm := multiplayer as SceneMultiplayer
	var infos = bytes_to_var(donnees)
	var version_ok: bool = infos is Dictionary and infos.get("v", -1) == VERSION_RESEAU
	if role == Role.HOTE:
		if version_ok and id_partenaire == 0:
			sm.complete_auth(id)
		else:   # l'autre côté lit notre réponse et affiche pourquoi ; on raccroche un peu après
			get_tree().create_timer(1.0).timeout.connect(_raccrocher.bind(id))
		return
	if not version_ok:
		_abandonner("Versions différentes : installez le même APK sur les deux téléphones.")
	elif infos.get("plein", false):
		_abandonner("Cette partie est déjà complète (deux joueurs).")
	else:
		sm.complete_auth(id)


## Raccroche un téléphone refusé, s'il n'est pas déjà parti de lui-même.
func _raccrocher(id: int) -> void:
	var sm := multiplayer as SceneMultiplayer
	if id in sm.get_authenticating_peers() or id in sm.get_peers():
		sm.disconnect_peer(id)


func _abandonner(raison: String) -> void:
	quitter()
	echec.emit(raison)


## Une coupure (Wi-Fi perdu, téléphone éteint) est détectée en 3 à 5 s au lieu de 5 à 30 s.
func _delai_court(id: int) -> void:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet and enet.get_peer(id):
		enet.get_peer(id).set_timeout(32, 3000, 5000)


func _on_pair_connecte(id: int) -> void:
	if role != Role.HOTE:
		return
	if id_partenaire != 0:
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id)   # déjà deux joueurs
		return
	id_partenaire = id
	_delai_court(id)
	_arreter_annonce()


## Appelé par l'invité juste après la connexion : version du jeu et accord sur les héros.
@rpc("any_peer", "reliable")
func _bonjour(version: int) -> void:
	if role != Role.HOTE or multiplayer.get_remote_sender_id() != id_partenaire:
		return
	if version != VERSION_RESEAU:
		_refuser.rpc_id(id_partenaire, "Versions différentes : installez le même APK sur les deux téléphones.")
		return
	heros_partenaire = _autre_heros(StringName(_infos_hote["heros"]))
	_bienvenue.rpc_id(id_partenaire, _infos_hote["heros"], String(heros_partenaire))
	partenaire_connecte.emit({"heros": heros_partenaire})


@rpc("authority", "reliable")
func _bienvenue(heros_hote: String, heros_invite: String) -> void:
	heros_partenaire = StringName(heros_hote)
	Partie.heros_local = StringName(heros_invite)
	partenaire_connecte.emit({"heros": heros_partenaire})


@rpc("authority", "reliable")
func _refuser(raison: String) -> void:
	echec.emit(raison)
	quitter()


## L'hôte lance la partie : les deux téléphones ouvrent l'arène (&"arene") ou l'expédition, avec le
## niveau de malédiction choisi par l'hôte.
func lancer_combat(destination: StringName = &"arene") -> void:
	if role == Role.HOTE and id_partenaire != 0:
		_lancer.rpc(String(destination), Partie.malediction)


@rpc("authority", "call_local", "reliable")
func _lancer(destination: String, malediction: int) -> void:
	Partie.destination = StringName(destination)
	Partie.malediction = clampi(malediction, 0, Malediction.MAX)
	combat_lance.emit()


# ---------------------------------------------------------------- messages de l'invité pendant le combat
func envoyer_arene_prete() -> void:
	_arene_prete.rpc_id(1)


func envoyer_entrees(seq: int, x: float, z: float) -> void:
	_entrees.rpc_id(1, seq, x, z)


func envoyer_action(nom: StringName) -> void:
	_action.rpc_id(1, nom)


func _depuis_partenaire() -> bool:
	return role == Role.HOTE and multiplayer.get_remote_sender_id() == id_partenaire and is_instance_valid(synchro)


@rpc("any_peer", "reliable")
func _arene_prete() -> void:
	if _depuis_partenaire():
		synchro.invite_pret()


@rpc("any_peer", "unreliable_ordered")
func _entrees(seq: int, x: float, z: float) -> void:
	if _depuis_partenaire():
		synchro.recevoir_entrees(seq, x, z)


@rpc("any_peer", "reliable")
func _action(nom: StringName) -> void:
	if _depuis_partenaire():
		synchro.recevoir_action(nom)


# ---------------------------------------------------------------- rejoindre
func chercher() -> Error:
	_arreter_recherche()
	_ecouteur = PacketPeerUDP.new()
	_ecouteur.set_broadcast_enabled(true)   # certains Android ne reçoivent les annonces qu'avec ceci
	return _ecouteur.bind(PORT_ANNONCE)


func rejoindre(adresse: String) -> Error:
	_arreter_recherche()
	quitter()
	var pair := ENetMultiplayerPeer.new()
	var err := pair.create_client(adresse, PORT_JEU)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = pair
	role = Role.INVITE
	return OK


func _on_connecte_a_l_hote() -> void:
	id_partenaire = 1
	_delai_court(1)
	_bonjour.rpc_id(1, VERSION_RESEAU)


func _on_connexion_ratee() -> void:
	quitter()
	echec.emit("Impossible de joindre l'autre téléphone. Êtes-vous sur le même Wi-Fi ?")


func _on_hote_parti() -> void:
	quitter()
	partenaire_parti.emit("Ton partenaire a quitté la partie.")


func _on_pair_deconnecte(id: int) -> void:
	if role == Role.HOTE and id == id_partenaire:
		id_partenaire = 0
		heros_partenaire = &""
		partenaire_parti.emit("Ton partenaire a quitté la partie.")


# ---------------------------------------------------------------- annonces sur le Wi-Fi
func _process(delta: float) -> void:
	if _annonceur and role == Role.HOTE and id_partenaire == 0:
		_minuterie -= delta
		if _minuterie <= 0.0:
			_minuterie = DELAI_ANNONCE
			var paquet := JSON.stringify(_infos_hote).to_utf8_buffer()
			# à tout le monde, et à tout le sous-réseau du Wi-Fi (sinon, avec les données mobiles
			# actives, certains téléphones envoient l'annonce du mauvais côté)
			for dest in _destinations_annonce():
				_annonceur.set_dest_address(dest, PORT_ANNONCE)
				_annonceur.put_packet(paquet)
	if _ecouteur:
		while _ecouteur.get_available_packet_count() > 0:
			var donnees := _ecouteur.get_packet()
			var adresse := _ecouteur.get_packet_ip()
			var infos = JSON.parse_string(donnees.get_string_from_utf8())
			if infos is Dictionary and infos.get("jeu") == "damnes":
				partie_trouvee.emit(adresse, infos)


func _arreter_annonce() -> void:
	if _annonceur:
		_annonceur.close()
		_annonceur = null


func _arreter_recherche() -> void:
	if _ecouteur:
		_ecouteur.close()
		_ecouteur = null


func quitter() -> void:
	_arreter_annonce()
	_arreter_recherche()
	if multiplayer.multiplayer_peer and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	role = Role.AUCUN
	id_partenaire = 0
	heros_partenaire = &""


# ---------------------------------------------------------------- adresse et code
## Adresse de ce téléphone sur le Wi-Fi (IPv4), "" s'il n'y en a pas. Choisie par interface : d'abord
## le Wi-Fi ou le partage de connexion (wlan, swlan, ap…), jamais les données mobiles s'il y a mieux
## (avec « données mobiles toujours actives », leur adresse 10.x peut être listée avant celle du Wi-Fi) ;
## puis 192.168… avant 172.16-31… avant 10… avant le reste.
func adresse_locale() -> String:
	var meilleure := ""
	var meilleur_score := -1
	for interface in IP.get_local_interfaces():
		var nom := String(interface.get("name", "")).to_lower()
		for a in interface.get("addresses", []):
			var score := _score_adresse(nom, String(a))
			if score > meilleur_score:
				meilleur_score = score
				meilleure = a
	return meilleure


static func _score_adresse(interface: String, a: String) -> int:
	if a.count(".") != 3 or a.begins_with("127.") or a.begins_with("169.254."):
		return -1
	var score := 0
	if a.begins_with("192.168."):
		score += 30
	elif _est_172_prive(a):
		score += 20
	elif a.begins_with("10."):
		score += 10
	for wifi in ["wlan", "swlan", "ap", "wifi", "wl", "eth", "en"]:
		if interface.begins_with(wifi):
			score += 100
			break
	for mobile in ["rmnet", "ccmni", "pdp", "rev_rmnet", "v4-rmnet", "clat", "tun"]:
		if interface.begins_with(mobile):
			score -= 100
			break
	return maxi(score, 0)


func _destinations_annonce() -> PackedStringArray:
	var dest := PackedStringArray(["255.255.255.255"])
	var a := adresse_locale()
	if a != "":
		var b := a.split(".")
		dest.append("%s.%s.%s.255" % [b[0], b[1], b[2]])
	return dest


static func _est_172_prive(a: String) -> bool:
	if not a.begins_with("172."):
		return false
	var b := a.split(".")
	return b.size() == 4 and int(b[1]) >= 16 and int(b[1]) <= 31


## Petit code à taper chez l'invité : le dernier nombre de l'adresse de l'hôte (1 à 254).
func code_local() -> int:
	var a := adresse_locale()
	return int(a.split(".")[3]) if a != "" else 0


## Ce que l'invité a tapé : soit le code (1 à 254), soit l'adresse complète de l'hôte (192.168.1.42).
func adresse_depuis_saisie(texte: String) -> String:
	texte = texte.strip_edges()
	if texte.count(".") == 3 and texte.is_valid_ip_address():
		return texte
	return adresse_depuis_code(int(texte)) if texte.is_valid_int() else ""


## Adresse de l'hôte à partir de son code, en supposant le même réseau (même début d'adresse).
func adresse_depuis_code(code: int) -> String:
	var a := adresse_locale()
	if a == "" or code < 1 or code > 254:
		return ""
	var b := a.split(".")
	return "%s.%s.%s.%d" % [b[0], b[1], b[2], code]


static func _autre_heros(h: StringName) -> StringName:
	return &"occultiste" if h == &"bretteur" else &"bretteur"
