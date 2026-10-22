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
const VERSION_RESEAU := 1        ## à augmenter quand le protocole change (refuse un autre APK)
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
	var err := pair.create_server(PORT_JEU, 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = pair
	role = Role.HOTE
	_infos_hote = {"jeu": "damnes", "v": VERSION_RESEAU, "heros": String(heros), "code": code_local()}
	_annonceur = PacketPeerUDP.new()
	_annonceur.set_broadcast_enabled(true)
	_annonceur.set_dest_address("255.255.255.255", PORT_ANNONCE)
	_minuterie = 0.0
	return OK


func _on_pair_connecte(id: int) -> void:
	if role != Role.HOTE:
		return
	if id_partenaire != 0:
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id)   # déjà deux joueurs
		return
	id_partenaire = id
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


## L'hôte lance le combat : les deux téléphones ouvrent l'arène.
func lancer_combat() -> void:
	if role == Role.HOTE and id_partenaire != 0:
		_lancer.rpc()


@rpc("authority", "call_local", "reliable")
func _lancer() -> void:
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
			_annonceur.put_packet(JSON.stringify(_infos_hote).to_utf8_buffer())
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
## Adresse de ce téléphone sur le Wi-Fi (adresse privée IPv4), ou "" s'il n'y en a pas.
func adresse_locale() -> String:
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or _est_172_prive(a):
			return a
	return ""


func _est_172_prive(a: String) -> bool:
	if not a.begins_with("172."):
		return false
	var b := a.split(".")
	return b.size() == 4 and int(b[1]) >= 16 and int(b[1]) <= 31


## Petit code à taper chez l'invité : le dernier nombre de l'adresse de l'hôte (1 à 254).
func code_local() -> int:
	var a := adresse_locale()
	return int(a.split(".")[3]) if a != "" else 0


## Adresse de l'hôte à partir de son code, en supposant le même réseau (même début d'adresse).
func adresse_depuis_code(code: int) -> String:
	var a := adresse_locale()
	if a == "" or code < 1 or code > 254:
		return ""
	var b := a.split(".")
	return "%s.%s.%s.%d" % [b[0], b[1], b[2], code]


static func _autre_heros(h: StringName) -> StringName:
	return &"occultiste" if h == &"bretteur" else &"bretteur"
