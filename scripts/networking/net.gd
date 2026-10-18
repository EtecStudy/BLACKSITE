extends Node
## Host-authoritative ENet session; server simulates accepted movement input.
signal status_changed(message: String)
signal roster_changed
const PORT_DEFAULT := 24560
const MAX_PLAYERS := 4
const WORLD_SCENE := "res://scenes/maps/sector.tscn"
var players: Dictionary = {}  # peer id -> {position, yaw, pitch, input, sprint}
var status := "Offline"
var _snapshot_clock := 0.0


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host(port: int = PORT_DEFAULT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		_set_status("Falha ao hospedar: %s" % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	players.clear()
	_accept_peer(1)
	_open_world()
	_set_status("Servidor aberto na porta UDP %d" % port)
	return OK


func join(address: String, port: int = PORT_DEFAULT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address.strip_edges(), port)
	if err != OK:
		_set_status("Endereço/porta inválidos: %s" % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	_set_status("Conectando a %s:%d…" % [address, port])
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	players.clear()
	_set_status("Sessão encerrada")
	if get_tree().current_scene and get_tree().current_scene.scene_file_path == WORLD_SCENE:
		get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	if players.size() >= MAX_PLAYERS:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	_accept_peer(id)
	for existing in players.keys():
		_rpc_add_player.rpc_id(id, int(existing), players[existing].position)
	_rpc_add_player.rpc(int(id), players[id].position)
	status = "Jogador %d conectado (%d/%d)" % [id, players.size(), MAX_PLAYERS]
	status_changed.emit(status)
	roster_changed.emit()


func _accept_peer(id: int) -> void:
	var index := players.size()
	players[id] = {
		"position": Vector3((index % 2) * 2.0, 1.0, float(index / 2) * 2.0),
		"yaw": 0.0,
		"pitch": 0.0,
		"input": Vector2.ZERO,
		"sprint": false
	}


func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	if multiplayer.is_server():
		_rpc_remove_player.rpc(id)
	roster_changed.emit()
	_set_status("Jogador %d saiu" % id)


func _on_connected() -> void:
	_open_world()
	_set_status("Conectado ao servidor")


func _on_connection_failed() -> void:
	_set_status("Conexão recusada/expirada. Verifique IP, porta UDP e firewall.")
	multiplayer.multiplayer_peer = null


func _on_server_disconnected() -> void:
	_set_status("Servidor desconectado")
	players.clear()
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


func _open_world() -> void:
	get_tree().change_scene_to_file(WORLD_SCENE)


@rpc("authority", "call_local", "reliable")
func _rpc_add_player(id: int, at: Vector3) -> void:
	players[id] = {"position": at, "yaw": 0.0, "pitch": 0.0, "input": Vector2.ZERO, "sprint": false}
	var world := get_tree().current_scene
	if world and world.has_method("add_player_avatar"):
		world.add_player_avatar(id, at)
	roster_changed.emit()


@rpc("authority", "call_local", "reliable")
func _rpc_remove_player(id: int) -> void:
	players.erase(id)
	var world := get_tree().current_scene
	if world and world.has_method("remove_player_avatar"):
		world.remove_player_avatar(id)
	roster_changed.emit()


func submit_input(move: Vector2, yaw: float, pitch: float, sprinting: bool) -> void:
	if multiplayer.is_server():
		_server_input(1, move, yaw, pitch, sprinting)
	else:
		_send_input.rpc_id(1, move, yaw, pitch, sprinting)


@rpc("any_peer", "call_remote", "unreliable")
func _send_input(move: Vector2, yaw: float, pitch: float, sprinting: bool) -> void:
	if multiplayer.is_server():
		_server_input(
			multiplayer.get_remote_sender_id(),
			move.limit_length(1.0),
			yaw,
			clampf(pitch, -1.45, 1.45),
			sprinting
		)


func _server_input(id: int, move: Vector2, yaw: float, pitch: float, sprinting: bool) -> void:
	if not players.has(id):
		return
	players[id].input = move.limit_length(1.0)
	players[id].yaw = yaw
	players[id].pitch = clampf(pitch, -1.45, 1.45)
	players[id].sprint = sprinting


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or players.is_empty():
		return
	for id in players:
		var p: Dictionary = players[id]
		var speed := 6.5 if p.sprint else 3.8
		var direction := Vector3(p.input.x, 0.0, p.input.y).rotated(Vector3.UP, p.yaw)
		var target: Vector3 = p.position + direction * speed * delta
		# Authoritative bounds protect the demo sector. Character collision is resolved by scene capsule.
		target.x = clampf(target.x, -28.0, 28.0)
		target.z = clampf(target.z, -28.0, 28.0)
		p.position = target
	_snapshot_clock += delta
	if _snapshot_clock >= 0.05:
		_snapshot_clock = 0.0
		_rpc_snapshot.rpc(_snapshot_data())


func _snapshot_data() -> Dictionary:
	var out := {}
	for id in players:
		out[id] = [players[id].position, players[id].yaw, players[id].pitch]
	return out


@rpc("authority", "call_local", "unreliable")
func _rpc_snapshot(data: Dictionary) -> void:
	for id in data:
		if players.has(id):
			players[id].position = data[id][0]
			players[id].yaw = data[id][1]
			players[id].pitch = data[id][2]
	var world := get_tree().current_scene
	if world and world.has_method("apply_snapshot"):
		world.apply_snapshot(data)


func _set_status(message: String) -> void:
	status = message
	status_changed.emit(message)
