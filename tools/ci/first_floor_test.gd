extends Node
## Teste da planta do primeiro andar (Etapa 12A).
##
## Uso:
##     godot --headless --path . --fixed-fps 60 --audio-driver Dummy \
##         res://tools/ci/first_floor_test.tscn
##
## Verifica o que o teste manual veria, com física real:
##   1. hierarquia da cena e presença dos ambientes previstos;
##   2. dimensões e posições dos ambientes (tabela PLANTA abaixo, não o nó);
##   3. piso e teto cobrindo cada ambiente, na altura certa;
##   4. vedação das paredes: cada lado é parede, exceto nos vãos previstos;
##   5. vãos: portas de 2,4 × 3,0 m e aberturas de 3,6 × 4,2 m, livres e
##      com batente fechando o resto da parede;
##   6. nenhuma parede duplicada/sobreposta e nenhuma instância repetida;
##   7. conectividade real: o jogador atravessa **cada** vão documentado;
##   8. as duas escadas descem 3,2 m e o hall inferior é navegável;
##   9. rota completa entrada → … → escada → retorno, com o controlador
##      existente (mesma cena de sessão usada no jogo).
##
## Sai com 0 em caso de sucesso e 1 em caso de falha.

const FLOOR_SCENE := "res://maps/scenes/laboratory_first_floor.tscn"
const SESSION_SCENE := "res://match/scenes/laboratory.tscn"

const GRID := 2.0
const STOREY := 6.0
const WALL_T := 0.4
const DOOR_W := 2.4
const DOOR_H := 3.0
const OPEN_W := 3.6
const OPEN_H := 4.2

## Tabela da planta: [nome, i0, i1, j0, j1, altura]. Células da grade de 2 m;
## o interior vai de `2*i + 1,2` a `2*i - 1,2` (parede de 0,40 centrada na
## linha). É a especificação que a cena tem de cumprir — o teste NÃO lê a cena
## para descobrir o gabarito.
const PLANTA := [
	["Lobby", -24, -20, -4, 3, 6.0],
	["Reception", -20, -8, -6, 5, 12.0],
	["Security", -20, -8, -14, -6, 6.0],
	["Control", -8, 6, 1, 11, 6.0],
	["MainCorridorWest", -8, 6, -2, 1, 6.0],
	["CentralHall", 6, 17, -6, 5, 12.0],
	["MainCorridorEast", 17, 38, -2, 1, 6.0],
	["Storage", -8, 6, -12, -2, 6.0],
	["Research", 6, 17, -14, -6, 6.0],
	["Analysis", 17, 29, -14, -2, 6.0],
	["Observation", 29, 36, -14, -2, 12.0],
	["Offices", 17, 29, 1, 11, 6.0],
	["Archive", 29, 36, 1, 11, 6.0],
	["NorthService", 9, 38, -16, -14, 6.0],
	["NorthLink", 36, 38, -14, -2, 6.0],
	["Staff", 6, 17, 5, 11, 6.0],
	["SouthService", 6, 38, 11, 13, 6.0],
	["SouthLink", 36, 38, 1, 11, 6.0],
	["Logistics", 6, 18, 13, 23, 6.0],
	["Electrical", 18, 24, 13, 23, 6.0],
	["Maintenance", 24, 32, 13, 23, 6.0],
	["StairSouthRoom", 32, 40, 13, 23, 12.0],
	["StairNorthRoom", 9, 17, -24, -16, 12.0],
]

## Vãos: [de, para, eixo, célula da parede, célula inicial, células, altura].
## eixo 'x' = parede no plano x = 2*célula + 1.
const VAOS := [
	["Lobby", "Reception", "x", -20, -2, 3, 6.0],
	["Reception", "MainCorridorWest", "x", -8, -2, 3, 6.0],
	["Security", "Reception", "z", -6, -18, 2, 3.0],
	["Reception", "Control", "x", -8, 1, 2, 3.0],
	["Storage", "MainCorridorWest", "z", -2, -4, 2, 3.0],
	["MainCorridorWest", "Control", "z", 1, -4, 2, 3.0],
	["MainCorridorWest", "CentralHall", "x", 6, -2, 3, 6.0],
	["CentralHall", "MainCorridorEast", "x", 17, -2, 3, 6.0],
	["Research", "CentralHall", "z", -6, 10, 2, 4.2],
	["CentralHall", "Staff", "z", 5, 10, 2, 3.0],
	["Storage", "CentralHall", "x", 6, -5, 2, 3.0],
	["Control", "CentralHall", "x", 6, 2, 2, 3.0],
	["CentralHall", "Analysis", "x", 17, -5, 2, 3.0],
	["CentralHall", "Offices", "x", 17, 2, 2, 3.0],
	["Research", "Analysis", "x", 17, -10, 2, 4.2],
	["Storage", "Research", "x", 6, -10, 2, 3.0],
	["Analysis", "Observation", "x", 29, -10, 2, 4.2],
	["Analysis", "Observation", "x", 29, -6, 2, 4.2],
	["Analysis", "MainCorridorEast", "z", -2, 20, 2, 3.0],
	["Observation", "MainCorridorEast", "z", -2, 31, 2, 3.0],
	["MainCorridorEast", "Offices", "z", 1, 20, 2, 3.0],
	["MainCorridorEast", "Archive", "z", 1, 31, 2, 3.0],
	["NorthLink", "MainCorridorEast", "z", -2, 36, 2, 3.0],
	["MainCorridorEast", "SouthLink", "z", 1, 36, 2, 3.0],
	["NorthService", "Research", "z", -14, 10, 2, 3.0],
	["StairNorthRoom", "NorthService", "z", -16, 11, 2, 3.0],
	["NorthService", "NorthLink", "z", -14, 36, 2, 4.2],
	["Staff", "SouthService", "z", 11, 8, 2, 3.0],
	["Offices", "SouthService", "z", 11, 20, 2, 3.0],
	["Archive", "SouthService", "z", 11, 31, 2, 3.0],
	["SouthLink", "SouthService", "z", 11, 36, 2, 4.2],
	["SouthService", "Logistics", "z", 13, 8, 2, 3.0],
	["SouthService", "Electrical", "z", 13, 20, 2, 3.0],
	["SouthService", "Maintenance", "z", 13, 26, 2, 3.0],
	["SouthService", "StairSouthRoom", "z", 13, 34, 2, 3.0],
	["Logistics", "Electrical", "x", 18, 16, 2, 3.0],
	["Electrical", "Maintenance", "x", 24, 16, 2, 3.0],
	["Maintenance", "StairSouthRoom", "x", 32, 16, 2, 3.0],
	["Control", "Staff", "x", 6, 7, 2, 3.0],
	["Offices", "Archive", "x", 29, 4, 2, 3.0],
]

## Portas nas divisórias internas: [eixo, célula, célula inicial, células].
const PORTAS_INTERNAS := [
	["x", 23, 3, 2],
	["x", 23, 7, 2],
	["x", 34, 3, 2],
	["x", 34, 7, 2],
	["z", -8, 19, 2],
	["x", 23, -11, 2],
	["x", 13, 7, 2],
	["x", -14, -11, 2],
	["z", 18, 27, 2],
]

## Escadas: [nome, x do eixo, z do bordo norte do vão, z do fim do hall].
const ESCADAS := [
	["StairNorth", 24.0, -45.0, -35.0],
	["StairSouth", 68.0, 29.0, 39.0],
]

## Pilares (base de 0,92 m): pontos de amostra de piso encostados neles são
## pulados, porque ali o raio bate na base do pilar e não no piso.
const PILARES := [
	Vector2(-32.0, -5.0),
	Vector2(-22.0, -5.0),
	Vector2(-32.0, 5.0),
	Vector2(-22.0, 5.0),
	Vector2(17.2, -6.8),
	Vector2(29.2, -6.8),
	Vector2(17.2, 6.8),
	Vector2(29.2, 6.8),
	Vector2(19.2, -24.0),
	Vector2(27.2, -24.0),
	Vector2(21.2, 37.2),
	Vector2(29.2, 37.2),
	Vector2(-19.2, -15.0),
	Vector2(-35.2, -15.0),
	Vector2(63.2, 8.0)
]

var _checks: int = 0
var _failures: PackedStringArray = PackedStringArray()
var _finished: bool = false
var _last_ms: int = 0
var _step: String = "início"
var _scene: Node = null
var _player: PlayerController = null
var _space: PhysicsDirectSpaceState3D = null
var _floor: Node3D = null

const WATCHDOG_MS := 90000


func _ready() -> void:
	print("=== Black Sight · primeiro andar do laboratório (Etapa 12A) ===")
	_touch("início")
	_space = get_viewport().world_3d.direct_space_state
	var packed: PackedScene = load(FLOOR_SCENE) as PackedScene
	_expect(packed != null, "planta do primeiro andar carrega")
	if packed == null:
		_finish()
		return
	_floor = packed.instantiate() as Node3D
	_expect(_floor != null, "planta instancia")
	if _floor == null:
		_finish()
		return
	add_child(_floor)
	await _frames(4)
	_space = get_viewport().world_3d.direct_space_state

	_test_hierarchy()
	_test_dimensions()
	await _test_floor_and_ceiling()
	_test_walls_and_openings()
	await _test_opening_geometry()
	_test_no_duplicates()
	await _test_session_and_walk()
	_finish()


func _process(_delta: float) -> void:
	if _finished:
		return
	var idle: int = Time.get_ticks_msec() - _last_ms
	if idle <= WATCHDOG_MS:
		return
	_finished = true
	printerr("PRIMEIRO ANDAR TRAVOU — %d ms sem progresso (%s)" % [idle, _step])
	printerr("verificações: %d · falhas: %d" % [_checks, _failures.size()])
	get_tree().quit(2)


func _touch(step: String = "") -> void:
	_last_ms = Time.get_ticks_msec()
	if not step.is_empty():
		_step = step


# --- 1. Hierarquia ----------------------------------------------------------

func _test_hierarchy() -> void:
	print("[1] Hierarquia e ambientes")
	for path: String in ["STRUCTURE", "STRUCTURE/Floors", "STRUCTURE/Walls",
			"STRUCTURE/Ceilings", "STRUCTURE/Doors", "STRUCTURE/Structural",
			"CORRIDORS", "ROOMS", "STAIRS", "LIGHTING"]:
		_expect(_floor.get_node_or_null(path) != null, "grupo %s existe" % path)
	_expect(_floor.get_node_or_null("Spawn") is Marker3D, "ponto de entrada presente")
	for entry: Array in PLANTA:
		var name: String = entry[0]
		var node: Node3D = _find_space(name)
		_expect(node != null, "ambiente %s existe" % name)
		if node == null:
			continue
		var center: Node3D = node.get_node_or_null("Center") as Node3D
		_expect(center != null, "%s: marcador de centro" % name)
		if center != null:
			var inside: Array = _inside(entry)
			var expected := Vector3((inside[0] + inside[1]) / 2.0, 0.05,
				(inside[2] + inside[3]) / 2.0)
			_expect(center.global_position.distance_to(expected) < 0.01,
				"%s: centro em (%.1f, %.1f)" % [name, expected.x, expected.z])
	var rooms: Node = _floor.get_node("ROOMS")
	_expect(rooms.get_child_count() >= 14,
		"pelo menos 14 ambientes em ROOMS (%d)" % rooms.get_child_count())
	_expect(_count_prefix("StairModule") == 2, "duas escadas (%d)" % _count_prefix("StairModule"))
	_expect(_count_prefix("Pillar_") >= 20, "pilares estruturais (%d)" % _count_prefix("Pillar_"))
	_expect(_count_prefix("Beam_") >= 5, "vigas no corredor principal (%d)" % _count_prefix("Beam_"))
	var doors: int = _count_prefix("Door_") + _count_prefix("PartDoor_")
	_expect(doors >= 39, "portas instaladas (%d)" % doors)
	_expect(_count_prefix("PartDoor_") == 9,
		"portas nas divisórias (%d)" % _count_prefix("PartDoor_"))
	_expect(_count_prefix("Opening_") >= 6, "aberturas estruturais (%d)" % _count_prefix("Opening_"))
	var panels: int = _count_prefix("Wall_") + _count_prefix("Part_") \
		+ _count_prefix("ShaftWall")
	_expect(panels >= 740, "painéis de parede (%d)" % panels)
	_expect(_count_prefix("Floor_") >= 1800, "placas de piso (%d)" % _count_prefix("Floor_"))
	_expect(_count_prefix("Ceil_") >= 1800, "placas de teto (%d)" % _count_prefix("Ceil_"))


## Coordenada da linha da célula (centro da parede).
func _line(cell: int) -> float:
	return GRID * cell + 1.0


## Interior do ambiente a partir das células: [x0, x1, z0, z1].
func _inside(entry: Array) -> Array:
	return [
		_line(entry[1]) + WALL_T / 2.0,
		_line(entry[2]) - WALL_T / 2.0,
		_line(entry[3]) + WALL_T / 2.0,
		_line(entry[4]) - WALL_T / 2.0,
	]


func _find_space(name: String) -> Node3D:
	for group_name: String in ["ROOMS", "CORRIDORS"]:
		var group: Node = _floor.get_node_or_null(group_name)
		if group == null:
			continue
		var node: Node3D = group.get_node_or_null(name) as Node3D
		if node != null:
			return node
	return null


func _count_prefix(prefix: String) -> int:
	var total: int = 0
	for node: Node in _floor.find_children("*", "Node3D", true, false):
		if String(node.name).begins_with(prefix):
			total += 1
	return total


# --- 2. Dimensões -----------------------------------------------------------

func _test_dimensions() -> void:
	print("[2] Dimensões e escala")
	var total_area: float = 0.0
	for entry: Array in PLANTA:
		var inside: Array = _inside(entry)
		var width: float = inside[1] - inside[0]
		var depth: float = inside[3] - inside[2]
		total_area += width * depth
		_expect(width >= 3.0 and depth >= 3.0,
			"%s: %.1f × %.1f m" % [entry[0], width, depth])
	# Corredor principal: 5,6 m livres (6 m de largura na grade).
	var main_w: float = _line(1) - WALL_T / 2.0 - (_line(-2) + WALL_T / 2.0)
	_expect(absf(main_w - 5.6) < 0.01, "corredor principal com 5,6 m livres")
	# Corredores de serviço: 4,0 m livres.
	var service_w: float = _line(-14) - WALL_T / 2.0 - (_line(-16) + WALL_T / 2.0)
	_expect(absf(service_w - 3.6) < 0.01, "corredores de serviço com 3,6 m livres")
	# Cruzamento central: 21,6 × 21,6 m e pé-direito duplo.
	var hall: Array = _inside(["CentralHall", 6, 17, -6, 5, 12.0])
	var hall_w: float = hall[1] - hall[0]
	var hall_d: float = hall[3] - hall[2]
	_expect(hall_w > 20.0 and hall_d > 20.0,
		"cruzamento central com %.1f × %.1f m" % [hall_w, hall_d])
	_expect(total_area > 5500.0, "área construída de %.0f m²" % total_area)
	# Nenhuma sala comum com pé-direito abaixo de 6 m.
	for entry: Array in PLANTA:
		_expect(float(entry[5]) >= 6.0, "%s: pé-direito de %.1f m" % [entry[0], entry[5]])
	var tall: int = 0
	for entry: Array in PLANTA:
		if float(entry[5]) >= 12.0:
			tall += 1
	_expect(tall >= 4, "grandes volumes com pé-direito duplo (%d)" % tall)


# --- 3. Piso e teto ---------------------------------------------------------

func _test_floor_and_ceiling() -> void:
	print("[3] Piso e teto")
	var checked: int = 0
	for entry: Array in PLANTA:
		var name: String = entry[0]
		var inside: Array = _inside(entry)
		var x0: float = inside[0]
		var x1: float = inside[1]
		var z0: float = inside[2]
		var z1: float = inside[3]
		var height: float = entry[5]
		var hole: Array = _stair_hole(name)
		var x: float = x0 + 1.0
		while x < x1 - 0.5:
			var z: float = z0 + 1.0
			while z < z1 - 0.5:
				var inside_hole: bool = not hole.is_empty() \
					and x > hole[0] and x < hole[1] and z > hole[2] and z < hole[3]
				if not inside_hole and not _near_pillar(x, z):
					var floor_hit: Dictionary = _ray(Vector3(x, 1.5, z), Vector3(x, -1.0, z))
					if floor_hit.is_empty() or absf((floor_hit["position"] as Vector3).y) > 0.06:
						_expect(false, "%s: piso em (%.1f, %.1f)" % [name, x, z])
					var ceil_hit: Dictionary = _ray(Vector3(x, height - 0.08, z),
						Vector3(x, height + 0.4, z))
					if ceil_hit.is_empty() \
							or absf((ceil_hit["position"] as Vector3).y - height) > 0.1:
						_expect(false, "%s: teto em (%.1f, %.1f)" % [name, x, z])
					checked += 1
				z += 3.0
			x += 3.0
	_touch("piso e teto")
	_expect(checked > 500, "%d pontos com piso e teto conferidos" % checked)
	# O poço da escada é o único vazio no piso: descendo no meio do vão não se
	# encontra o piso do andar (y = 0), só o degrau/rampa; o hall inferior tem
	# piso em -3,2.
	for stair: Array in ESCADAS:
		var x: float = stair[1]
		var z0: float = stair[2]
		var z1: float = stair[3]
		var in_hole: Dictionary = _ray(Vector3(x, 1.0, z0 + 3.0), Vector3(x, -6.0, z0 + 3.0))
		var hit_y: float = (in_hole["position"] as Vector3).y if not in_hole.is_empty() else 99.0
		_expect(not in_hole.is_empty() and hit_y < -0.25,
			"%s: dentro do vão não existe piso em 0 (y = %.2f)" % [stair[0], hit_y])
		# O hall inferior continua sob a laje do andar (z > vão da escada),
		# então a sonda desce de dentro do hall, abaixo da laje em -0,3.
		var landing: Dictionary = _ray(Vector3(x, -1.0, z1 - 1.0), Vector3(x, -6.0, z1 - 1.0))
		_expect(not landing.is_empty()
			and absf((landing["position"] as Vector3).y - (-3.2)) < 0.06,
			"%s: hall inferior com piso em -3,2" % stair[0])


## A amostra está sobre a pegada de um pilar (ou a menos de 0,8 m dela)?
func _near_pillar(x: float, z: float) -> bool:
	for pillar: Vector2 in PILARES:
		if absf(pillar.x - x) < 1.2 and absf(pillar.y - z) < 1.2:
			return true
	return false


func _stair_hole(name: String) -> Array:
	if name == "StairNorthRoom":
		return [23.0, 25.0, -45.0, -39.0]
	if name == "StairSouthRoom":
		return [67.0, 69.0, 29.0, 35.0]
	return []


# --- 4. Paredes e vãos -----------------------------------------------------

func _test_walls_and_openings() -> void:
	print("[4] Paredes e vãos")
	for entry: Array in PLANTA:
		var name: String = entry[0]
		var inside: Array = _inside(entry)
		var sides := [
			["x", inside[0], -1.0, "oeste", inside[2], inside[3]],
			["x", inside[1], 1.0, "leste", inside[2], inside[3]],
			["z", inside[2], -1.0, "norte", inside[0], inside[1]],
			["z", inside[3], 1.0, "sul", inside[0], inside[1]],
		]
		for side: Array in sides:
			var axis: String = side[0]
			var plane: float = side[1]
			var outward: float = side[2]
			var label: String = side[3]
			var a: float = side[4]
			var b: float = side[5]
			var wall_line: float = plane + outward * WALL_T / 2.0
			var t: float = a + 0.5
			var walled: int = 0
			var open: int = 0
			while t < b - 0.4:
				if _is_gap(name, axis, wall_line, t):
					open += 1
				else:
					var inner: Vector3
					var outer: Vector3
					if axis == "x":
						inner = Vector3(plane - outward * 1.2, 1.5, t)
						outer = Vector3(plane + outward * 1.2, 1.5, t)
					else:
						inner = Vector3(t, 1.5, plane - outward * 1.2)
						outer = Vector3(t, 1.5, plane + outward * 1.2)
					if _hits(inner, outer) or _hits(outer, inner):
						walled += 1
					else:
						_expect(false, "%s: parede %s aberta em %.1f" % [name, label, t])
				t += 1.0
			_expect(walled + open >= int((b - a) / 2.0) - 1,
				"%s: lado %s conferido (%d parede, %d vão)" % [name, label, walled, open])


## O ponto (coordenada `t` ao longo do lado) está num vão documentado?
func _is_gap(name: String, axis: String, wall_line: float, t: float) -> bool:
	for v: Array in VAOS:
		if v[0] != name and v[1] != name:
			continue
		if v[2] != axis or absf(_line(int(v[3])) - wall_line) > 0.01:
			continue
		# A largura do módulo não é a largura do vão: a porta ocupa 4 m de
		# parede mas passa 2,4 m; a abertura ocupa 4 m e passa 3,6 m; a boca de
		# corredor passa a largura inteira.
		var height: float = v[6]
		var half: float
		if height >= 5.9:
			half = GRID * float(v[5]) / 2.0
		elif absf(height - 4.2) < 0.01:
			half = OPEN_W / 2.0
		else:
			half = DOOR_W / 2.0
		var center: float = _line(int(v[4])) + GRID * float(v[5]) / 2.0
		if absf(t - center) <= half + 0.01:
			return true
	return false


func _test_opening_geometry() -> void:
	print("[5] Geometria dos vãos")
	for v: Array in VAOS:
		var axis: String = v[2]
		var plane: float = _line(int(v[3]))
		var center: float = _line(int(v[4])) + GRID * float(v[5]) / 2.0
		var height: float = v[6]
		var width: float
		if height >= 5.9:
			width = GRID * float(v[5])
		elif absf(height - 4.2) < 0.01:
			width = OPEN_W
		else:
			width = DOOR_W
		var half: float = width / 2.0
		# livre por dentro do vão, na altura de passagem
		var free_ok: bool = true
		var probe_y: float = minf(height - 0.6, height * 0.6)
		# As paredes perpendiculares encostam no bordo do vão; a sonda mede um
		# canal livre com 0,7 m de folga de cada lado, não o vão inteiro.
		for offset: float in [-half + 0.7, 0.0, half - 0.7]:
			var point := Vector3(plane, probe_y, center + offset) if axis == "x" \
				else Vector3(center + offset, probe_y, plane)
			if not _point_free(point, 0.25):
				free_ok = false
		_expect(free_ok, "%s → %s: vão de %.1f × %.1f m livre na altura %.1f"
			% [v[0], v[1], width, height, probe_y])
		# Fechado acima do vão (verga). As bocas de corredor (6 m) têm altura
		# total e são cobertas pela checagem de parede dos lados.
		if height < 5.9:
			var above := Vector3(plane, height + 0.5, center) if axis == "x" \
				else Vector3(center, height + 0.5, plane)
			_expect(not _point_free(above, 0.15),
				"%s → %s: parede fecha acima do vão (y = %.1f)"
				% [v[0], v[1], height + 0.5])
	_touch("vãos")
	for v: Array in PORTAS_INTERNAS:
		var axis: String = v[0]
		var plane: float = _line(int(v[1]))
		var center: float = _line(int(v[2])) + GRID * float(v[3]) / 2.0
		var point := Vector3(plane, 1.4, center) if axis == "x" \
			else Vector3(center, 1.4, plane)
		_expect(_point_free(point, 0.3), "divisória interna: passagem livre em (%.1f, %.1f)"
			% [plane, center])


# --- 6. Duplicidade ---------------------------------------------------------

func _test_no_duplicates() -> void:
	print("[6] Sem peças duplicadas ou sobrepostas")
	# Só as raízes instanciadas pela planta (filhos dos grupos e das casas de
	# escada). Nós internos de cada módulo (malha, colisão, acabamento) têm a
	# mesma posição global de propósito e não são "peças duplicadas".
	var roots: Array[Node3D] = []
	for path: String in ["STRUCTURE/Floors", "STRUCTURE/Ceilings", "STRUCTURE/Walls",
			"STRUCTURE/Doors", "STRUCTURE/Structural", "STAIRS"]:
		var group: Node = _floor.get_node_or_null(path)
		if group == null:
			continue
		for child: Node in group.get_children():
			if child is Node3D and not String(child.scene_file_path).is_empty():
				roots.append(child as Node3D)
			else:
				_collect_instances(child as Node3D, roots)

	var seen: Dictionary = {}
	var duplicate: int = 0
	for body: Node3D in roots:
		var key: String = "%s|%.2f|%.2f|%.2f" % [body.scene_file_path,
			body.global_position.x, body.global_position.y, body.global_position.z]
		if seen.has(key):
			duplicate += 1
			if duplicate <= 5:
				print("      repetida: %s em %s" % [body.name, key])
		seen[key] = body.name
	_expect(duplicate == 0, "nenhuma peça repetida na mesma posição (%d de %d)"
		% [duplicate, roots.size()])

	# paredes: mesma linha e mesmo nível não podem se sobrepor
	var rows: Dictionary = {}
	for node: Node in _floor.get_node("STRUCTURE/Walls").get_children():
		var body: Node3D = node as Node3D
		if body == null or String(body.scene_file_path).is_empty():
			continue
		var yaw: float = absf(body.global_rotation.y)
		var runs_x: bool = yaw < 0.1 or absf(yaw - PI) < 0.1
		var across: float = round(body.global_position.z) if runs_x else round(body.global_position.x)
		var along: float = body.global_position.x if runs_x else body.global_position.z
		var key: String = "%.0f|%.0f|%d" % [across, body.global_position.y, 1 if runs_x else 0]
		if not rows.has(key):
			rows[key] = []
		(rows[key] as Array).append(along)
	var overlaps: int = 0
	for key: String in rows:
		var list: Array = rows[key]
		list.sort()
		for i: int in range(1, list.size()):
			if float(list[i]) - float(list[i - 1]) < 1.99:
				overlaps += 1
	_expect(overlaps == 0, "nenhum painel de parede sobreposto (%d)" % overlaps)


## Junta as instâncias (raízes) penduradas em nós agrupadores.
func _collect_instances(node: Node3D, out: Array[Node3D]) -> void:
	if node == null:
		return
	for child: Node in node.get_children():
		var body: Node3D = child as Node3D
		if body == null:
			continue
		if not String(body.scene_file_path).is_empty():
			out.append(body)
		else:
			_collect_instances(body, out)


# --- 7. Conectividade e caminhada ------------------------------------------

func _test_session_and_walk() -> void:
	print("[7] Sessão do jogo e caminhada")
	# A cena de sessão instancia a própria planta; a cópia usada na inspeção
	# sai da árvore para não duplicar geometria e colisão.
	remove_child(_floor)
	_floor.queue_free()
	_floor = null
	await _frames(3)
	var packed: PackedScene = load(SESSION_SCENE) as PackedScene
	_expect(packed != null, "cena de sessão do primeiro andar carrega")
	if packed == null:
		return
	_scene = packed.instantiate()
	_expect(_scene != null, "sessão instancia")
	if _scene == null:
		return
	add_child(_scene)
	await _frames(6)
	_player = _scene.get_player()
	_expect(_player is CharacterBody3D, "jogador existente instanciado")
	_expect(_scene.get_hud() != null, "HUD ligada")
	_expect(_scene.get_demo_room() != null, "planta acessível pela sessão")
	if _player == null:
		return
	_space = _player.get_world_3d().direct_space_state
	await _frames(10)
	_expect(_scene.count_modules() > 4000,
		"planta com %d nós de módulo" % _scene.count_modules())
	_expect(_player.global_position.distance_to(Vector3(-45, 0.15, 0)) < 0.4,
		"jogador nasce na entrada (%.1f, %.1f)" % [_player.global_position.x,
			_player.global_position.z])

	# Todos os vãos são atravessáveis pelo controlador real.
	var passed: int = 0
	for v: Array in VAOS:
		if not await _cross_opening(v):
			_expect(false, "atravessa o vão %s → %s" % [v[0], v[1]])
		else:
			passed += 1
	_expect(passed == VAOS.size(), "todos os %d vãos são atravessáveis (%d)"
		% [VAOS.size(), passed])

	# Escadas: desce os 3,2 m e chega ao hall inferior. O módulo da Etapa 11
	# sobe no sentido -Z; instalado com o topo no bordo norte do vão, o jogador
	# desce caminhando para +Z (sul) e sobe caminhando para -Z (norte).
	for stair: Array in ESCADAS:
		var stair_name: String = stair[0]
		var x: float = stair[1]
		var z_top: float = stair[2]
		await _place(Vector3(x, 0.05, z_top - 0.9), PI)
		await _walk(5.2)
		_expect(_player.global_position.y < -2.9,
			"%s: jogador desce ao hall inferior (y = %.2f)"
			% [stair_name, _player.global_position.y])
		_expect(_player.global_position.z > z_top + 3.5,
			"%s: avança no sentido da escada (z = %.1f)"
			% [stair_name, _player.global_position.z])
		await _place(Vector3(x, -3.15, z_top + 5.4), 0.0)
		await _walk(5.4)
		_expect(_player.global_position.y > -0.2,
			"%s: jogador volta a subir (y = %.2f)"
			% [stair_name, _player.global_position.y])
		_expect(_player.global_position.z < z_top + 1.0,
			"%s: chega de volta ao andar (z = %.1f)"
			% [stair_name, _player.global_position.z])

	# Rota completa: entrada → recepção → segurança → controle → corredor →
	# cruzamento → pesquisa → análises → observação → escritórios → logística →
	# setor técnico → escada sul → retorno.
	print("[8] Rota completa")
	var route: Array = _route()
	var reached: int = 0
	for index: int in route.size() - 1:
		var ok: bool = await _walk_to(route[index], route[index + 1], 8.0)
		if ok:
			reached += 1
			continue
		_expect(false, "rota: trecho %d até %s" % [index, route[index + 1]])
	_expect(reached == route.size() - 1, "rota completa percorrida (%d de %d trechos)"
		% [reached, route.size() - 1])

	# Pausa continua funcionando sobre a planta.
	_scene.pause_session()
	_expect(_scene.is_paused(), "pausa funciona no primeiro andar")
	var before: Vector3 = _player.global_position
	Input.action_press("move_forward")
	for _i: int in 20:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	_expect(_player.global_position.distance_to(before) < 0.05, "pausado: jogador parado")
	_scene.resume_session()
	_expect(not _scene.is_paused(), "retomada funciona no primeiro andar")


## Rota obrigatória do teste manual, em pontos já conferidos contra as paredes:
## entrada → recepção → segurança → recepção → controle → corredor principal →
## cruzamento → pesquisa → análises → observação → escritórios → arquivo →
## funcionários → logística → elétrica → manutenção → escada sul.
## Cada ponto atravessa um vão documentado ou contorna uma divisória interna.
const ROTA := [
	Vector3(-43.0, 0.05, 0.0),
	Vector3(-40.9, 0.05, 0.0),
	Vector3(-37.1, 0.05, 0.0),
	Vector3(-33.0, 0.05, -9.1),
	Vector3(-33.0, 0.05, -12.9),
	Vector3(-33.0, 0.05, -9.1),
	Vector3(-16.9, 0.05, 5.0),
	Vector3(-13.1, 0.05, 5.0),
	Vector3(-5.0, 0.05, 4.9),
	Vector3(-5.0, 0.05, 1.1),
	Vector3(11.1, 0.05, 0.0),
	Vector3(14.9, 0.05, 0.0),
	Vector3(23.0, 0.05, -9.1),
	Vector3(23.0, 0.05, -12.9),
	Vector3(33.1, 0.05, -17.0),
	Vector3(36.9, 0.05, -17.0),
	Vector3(43.0, 0.05, -19.0),
	Vector3(57.1, 0.05, -17.0),
	Vector3(60.9, 0.05, -17.0),
	Vector3(65.0, 0.05, -4.9),
	Vector3(65.0, 0.05, -1.1),
	Vector3(43.0, 0.05, 1.1),
	Vector3(43.0, 0.05, 4.9),
	Vector3(47.0, 0.05, 9.0),
	Vector3(57.1, 0.05, 11.0),
	Vector3(60.9, 0.05, 11.0),
	Vector3(65.0, 0.05, 21.1),
	Vector3(65.0, 0.05, 24.9),
	Vector3(19.0, 0.05, 24.9),
	Vector3(19.0, 0.05, 21.1),
	Vector3(19.0, 0.05, 24.9),
	Vector3(19.0, 0.05, 25.1),
	Vector3(19.0, 0.05, 28.9),
	Vector3(35.1, 0.05, 35.0),
	Vector3(38.9, 0.05, 35.0),
	Vector3(47.1, 0.05, 35.0),
	Vector3(50.9, 0.05, 35.0),
	Vector3(63.1, 0.05, 35.0),
	Vector3(66.2, 0.05, 35.0),
	Vector3(66.2, 0.05, 28.3),
	Vector3(68.0, 0.05, 28.3),
]


## Pontos da rota (cópia mutável, para o teste).
func _route() -> Array:
	var points: Array = []
	for point: Vector3 in ROTA:
		points.append(point)
	return points


## Coloca o jogador do lado de origem do vão e caminha para o outro lado.
func _cross_opening(v: Array) -> bool:
	var axis: String = v[2]
	var plane: float = _line(int(v[3]))
	var center: float = _line(int(v[4])) + GRID * float(v[5]) / 2.0
	var from_space: Array = _space_of(String(v[0]))
	if from_space.is_empty():
		return false
	var inside: Array = _inside(from_space)
	# A origem fica a oeste (eixo x) ou ao norte (eixo z) do plano?
	var west: bool = axis == "x" and float(inside[1]) <= plane + 0.01
	var north: bool = axis == "z" and float(inside[3]) <= plane + 0.01
	var start: Vector3
	var expected_after: float
	if axis == "x":
		start = Vector3(plane - 3.6 if west else plane + 3.6, 0.05, center)
		start.x = clampf(start.x, float(inside[0]) + 0.9, float(inside[1]) - 0.9)
		start.x = minf(start.x, plane - 0.9) if west else maxf(start.x, plane + 0.9)
		expected_after = plane + 1.4 if west else plane - 1.4
	else:
		start = Vector3(center, 0.05, plane - 3.6 if north else plane + 3.6)
		start.z = clampf(start.z, float(inside[2]) + 0.9, float(inside[3]) - 0.9)
		start.z = minf(start.z, plane - 0.9) if north else maxf(start.z, plane + 0.9)
		expected_after = plane + 1.4 if north else plane - 1.4
	# O destino fica 2,2 m depois do plano: o controlador caminha de frente
	# para o vão e o teste confere em que lado do plano ele terminou.
	var dest: Vector3
	if axis == "x":
		dest = Vector3(plane + 2.2 if west else plane - 2.2, 0.05, center)
	else:
		dest = Vector3(center, 0.05, plane + 2.2 if north else plane - 2.2)
	await _walk_to(start, dest, 6.0)
	var after: Vector3 = _player.global_position
	var crossed: bool
	if axis == "x":
		crossed = after.x > expected_after if west else after.x < expected_after
	else:
		crossed = after.z > expected_after if north else after.z < expected_after
	if not crossed:
		print("      vão %s → %s: parou em (%.2f, %.2f)" % [v[0], v[1], after.x, after.z])
	return crossed


func _space_of(name: String) -> Array:
	for entry: Array in PLANTA:
		if entry[0] == name:
			return entry
	return []


## Caminha em linha reta até perto do destino (com correção de rumo).
func _walk_to(from: Vector3, to: Vector3, max_seconds: float) -> bool:
	await _place(from, atan2(-(to.x - from.x), -(to.z - from.z)))
	# Velocidade de caminhada medida no controlador: 3,2 m/s. Usa 2,4 m/s de
	# margem para não cortar trechos longos do corredor principal.
	var needed: float = from.distance_to(to) / 2.4 + 3.0
	var budget: int = int(maxf(max_seconds, needed) * 60.0)
	var elapsed: int = 0
	Input.action_press("move_forward")
	while elapsed < budget:
		await get_tree().physics_frame
		elapsed += 1
		var delta: Vector3 = to - _player.global_position
		delta.y = 0.0
		if delta.length() < 0.9:
			break
		_player.set_look(atan2(-delta.x, -delta.z), 0.0)
	Input.action_release("move_forward")
	await _frames(4)
	_touch()
	var remaining: Vector3 = to - _player.global_position
	remaining.y = 0.0
	if remaining.length() > 2.0:
		print("      parou a %.1f m de %s" % [remaining.length(), to])
	return remaining.length() <= 2.0


# --- utilidades de física ---------------------------------------------------

func _point_free(point: Vector3, radius: float) -> bool:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, point)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return _space.intersect_shape(query, 1).is_empty()


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	if _space == null:
		return {}
	var params := PhysicsRayQueryParameters3D.create(from, to, 1)
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.hit_from_inside = false
	return _space.intersect_ray(params)


func _hits(from: Vector3, to: Vector3) -> bool:
	return not _ray(from, to).is_empty()


func _frames(count: int) -> void:
	for _index: int in count:
		await get_tree().physics_frame
	_touch()


func _place(position: Vector3, yaw: float) -> void:
	_release_all()
	_player.velocity = Vector3.ZERO
	_player.global_position = position
	_player.set_look(yaw, 0.0)
	await _frames(8)


func _walk(seconds: float) -> void:
	Input.action_press("move_forward")
	var frames: int = int(round(seconds * 60.0))
	for _index: int in frames:
		await get_tree().physics_frame
	Input.action_release("move_forward")
	await _frames(6)
	_touch()


func _release_all() -> void:
	for action: String in ["move_forward", "move_back", "move_left", "move_right",
			"move_sprint", "move_crouch"]:
		if Input.is_action_pressed(action):
			Input.action_release(action)


# --- resultado --------------------------------------------------------------

func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  ✓ %s" % label)
		return
	_failures.append(label)
	print("  ✗ %s" % label)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("")
	if _failures.is_empty():
		print("PRIMEIRO ANDAR OK — %d verificações aprovadas" % _checks)
		get_tree().quit(0)
		return
	printerr("FALHAS (%d de %d verificações):" % [_failures.size(), _checks])
	for failure: String in _failures:
		printerr("  - %s" % failure)
	get_tree().quit(1)
