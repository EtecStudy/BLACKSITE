extends "res://match/scripts/modular_demo.gd"
## Sessão do primeiro andar do laboratório (Etapa 12A).
##
## Reaproveita **toda** a infraestrutura já aprovada da demonstração modular —
## pausa com ESC, HUD, captura de mouse, troca de cena adiada e reset de
## corrida — mudando apenas o cenário (`maps/scenes/laboratory_first_floor.tscn`)
## e o ponto de nascimento (`FirstFloor/Spawn`). Nenhum sistema de gameplay é
## recriado, e o controlador do jogador continua sendo o mesmo.
##
## Responsabilidade extra desta cena: informar em que ambiente o jogador está.
## O texto é apenas leitura da planta (`ambientes` vêm do marcador `Center` de
## cada ambiente) — não há objetivo, gatilho, criatura ou item aqui.

const FLOOR_NAME: String = "PRIMEIRO ANDAR"
const HINT_DEFAULT: String = "PRIMEIRO ANDAR — W A S D ANDAR · SHIFT CORRER · CTRL AGACHAR · ESC PAUSA"

var _rooms: Array[Dictionary] = []


func _ready() -> void:
	_collect_rooms()
	super._ready()
	print("[Black Sight] Primeiro andar carregado — %d módulos de cenário, %d ambientes"
		% [count_modules(), _rooms.size()])


## Coleta os ambientes da planta (nome e centro) para leitura de posição.
func _collect_rooms() -> void:
	_rooms.clear()
	if _room == null:
		return
	for group: Node in _room.get_children():
		if group.name != "ROOMS" and group.name != "CORRIDORS":
			continue
		for room: Node in group.get_children():
			var center: Node3D = room.get_node_or_null("Center") as Node3D
			if center == null:
				continue
			_rooms.append({"name": String(room.name), "center": center.global_position})


## Ambientes declarados na planta (leitura para testes e HUD).
func get_room_names() -> PackedStringArray:
	var names := PackedStringArray()
	for room: Dictionary in _rooms:
		names.append(String(room["name"]))
	return names


## Nome do ambiente mais próximo do jogador (vazio se a planta não carregou).
func get_current_room() -> String:
	if _player == null or _rooms.is_empty():
		return ""
	var best: String = ""
	var best_distance: float = INF
	for room: Dictionary in _rooms:
		var center: Vector3 = room["center"]
		var distance: float = Vector2(center.x - _player.global_position.x,
			center.z - _player.global_position.z).length()
		if distance < best_distance:
			best_distance = distance
			best = String(room["name"])
	return best


## Conta todas as instâncias de módulo da planta (não só os filhos diretos).
func count_modules() -> int:
	return count_instances()
